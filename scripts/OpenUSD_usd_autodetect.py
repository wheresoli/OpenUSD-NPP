# -*- coding: utf-8 -*-
# OpenUSD_usd_autodetect.py
#
# PythonScript hook for Notepad++ that gives .usd / .usdc files USD-aware editing:
#
#   * ASCII USD (.usd whose content is text)  -> applies the "OpenUSD" UDL.
#   * binary USD crate (.usd/.usdc starting with "PXR-USDC"):
#       SIDECAR round-trip editing (requires usd-core, see install.ps1 -BinaryViewer):
#         - on open  : converts the crate to a temp .usda and opens THAT to edit
#         - on save  : converts the temp .usda back to the original .usdc, but ONLY
#                      if it parses cleanly (a bad edit never overwrites the crate)
#       If usd-core is not configured, the crate is left untouched.
#
# The Python used for conversion is recorded in OpenUSD_view.cfg beside this
# script (written by install.ps1 -BinaryViewer).
#
# Caveats (USD facts, not bugs): round-tripping through USD drops inline '#'
# comments and may normalise ordering/formatting. The temp tab shows a path under
# %TEMP%\npp_openusd. Requires the PythonScript plugin.
#
# NOTE: the conversion logic is straightforward; the Notepad++ open/close
# sequencing is the part most worth verifying on a real machine.

import os
import json
import hashlib
import tempfile
import subprocess
from Npp import notepad, editor, NOTIFICATION

_UDL_NAME    = 'OpenUSD'
_CRATE_MAGIC = b'PXR-USDC'
_USD_EXTS    = ('.usd', '.usdc')
_seen_open   = set()      # crate paths already turned into a sidecar this session

# Convert in a fresh subprocess (extension decides the output format):
#   crate -> .usda  (read)   and   .usda -> crate  (write)  use the same code.
_CONV_CODE = (
    "import sys\n"
    "from pxr import Sdf\n"
    "lyr = Sdf.Layer.FindOrOpen(sys.argv[1])\n"
    "if not lyr:\n"
    "    sys.stderr.write('cannot open/parse: ' + sys.argv[1]); sys.exit(3)\n"
    "if not lyr.Export(sys.argv[2]):\n"
    "    sys.stderr.write('export failed: ' + sys.argv[2]); sys.exit(4)\n"
)

# Directory of this script (set by the startup.py loader, or derived if run direct).
try:
    _BASE = _HOOK_DIR
except NameError:
    try:
        _BASE = os.path.dirname(os.path.abspath(__file__))
    except NameError:
        _BASE = ''


# --- usd-core plumbing ----------------------------------------------------
def _configured_python():
    """Path to a Python that has usd-core, or None (crate editing disabled)."""
    try:
        cfg = os.path.join(_BASE, 'OpenUSD_view.cfg')
        if os.path.isfile(cfg):
            with open(cfg) as fh:
                p = fh.readline().strip()
            if p and os.path.isfile(p):
                return p
    except Exception:
        pass
    return None


def _convert(python_exe, src, dst):
    """Run src -> dst conversion. Returns (ok, stderr_text)."""
    startupinfo = None
    if os.name == 'nt':
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW   # no console flash
    try:
        proc = subprocess.Popen([python_exe, '-c', _CONV_CODE, src, dst],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                startupinfo=startupinfo)
        _out, err = proc.communicate()
        return proc.returncode == 0, err.decode('utf-8', 'replace')
    except Exception as exc:
        return False, str(exc)


# --- temp + mapping (temp .usda  <->  original .usdc) ---------------------
def _root():
    d = os.path.join(tempfile.gettempdir(), 'npp_openusd')
    try:
        if not os.path.isdir(d):
            os.makedirs(d)
    except OSError:
        pass
    return d


def _map_path():
    return os.path.join(_root(), 'map.json')


def _load_map():
    try:
        with open(_map_path()) as fh:
            return json.load(fh)
    except Exception:
        return {}


def _save_map(m):
    try:
        with open(_map_path(), 'w') as fh:
            json.dump(m, fh)
    except Exception:
        pass


def _temp_for(original):
    stem = os.path.splitext(os.path.basename(original))[0] or 'layer'
    h = hashlib.md5(original.lower().encode('utf-8')).hexdigest()[:8]
    sub = os.path.join(_root(), h)
    try:
        if not os.path.isdir(sub):
            os.makedirs(sub)
    except OSError:
        pass
    return os.path.join(sub, stem + '.usda')


# --- actions --------------------------------------------------------------
def _open_crate_as_text(original):
    python_exe = _configured_python()
    if not python_exe:
        return                       # crate editing disabled -> leave the file alone

    temp = _temp_for(original)
    ok, err = _convert(python_exe, original, temp)
    if not ok:
        notepad.messageBox('Could not read USD crate:\n%s\n\n%s'
                           % (original, err), 'OpenUSD')
        return

    m = _load_map()
    m[temp.lower()] = original
    _save_map(m)

    # Open the editable temp; then close (or lock) the binary original.
    notepad.open(temp)
    try:
        notepad.activateFile(original)
        notepad.close()
    except Exception:
        try:
            notepad.activateFile(original)
            editor.setReadOnly(True)     # fallback: at least prevent garbage saves
        except Exception:
            pass
    notepad.activateFile(temp)


def _write_back(temp_path):
    m = _load_map()
    original = m.get(temp_path.lower())
    if not original:
        return
    python_exe = _configured_python()
    if not python_exe:
        return
    ok, err = _convert(python_exe, temp_path, original)
    if not ok:
        notepad.messageBox('NOT saved to .usdc (left unchanged) - the text did '
                           'not parse:\n%s\n\n%s' % (original, err), 'OpenUSD')


def _is_crate(path):
    try:
        with open(path, 'rb') as fh:
            return fh.read(8).startswith(_CRATE_MAGIC)
    except (IOError, OSError):
        return False


# --- notifications --------------------------------------------------------
def _on_file_opened(args):
    path = notepad.getBufferFilename(args['bufferID'])
    if not path or os.path.splitext(path)[1].lower() not in _USD_EXTS:
        return
    if path.lower() in _seen_open:
        return
    _seen_open.add(path.lower())
    if _is_crate(path):
        _open_crate_as_text(path)


def _on_buffer_activated(args):
    # Highlight ASCII .usd (a .usda already maps via the UDL extension list).
    path = notepad.getBufferFilename(args['bufferID'])
    if not path or os.path.splitext(path)[1].lower() != '.usd':
        return
    if not _is_crate(path):
        notepad.runMenuCommand('Language', _UDL_NAME)


def _on_file_saved(args):
    path = notepad.getBufferFilename(args['bufferID'])
    if path:
        _write_back(path)


notepad.callback(_on_file_opened,      [NOTIFICATION.FILEOPENED])
notepad.callback(_on_buffer_activated, [NOTIFICATION.BUFFERACTIVATED])
notepad.callback(_on_file_saved,       [NOTIFICATION.FILESAVED])
