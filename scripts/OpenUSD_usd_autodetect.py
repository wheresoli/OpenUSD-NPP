# -*- coding: utf-8 -*-
# OpenUSD_usd_autodetect.py
#
# PythonScript hook for Notepad++. On opening a .usd / .usdc file it:
#   * ASCII USD  -> applies the "OpenUSD" User Defined Language (highlighting)
#   * binary USD (crate; starts with the magic bytes "PXR-USDC"):
#       - if a Python with the official 'usd-core' (pxr) package is configured,
#         converts the layer to ASCII and shows it in a READ-ONLY view
#       - otherwise leaves the file untouched (no garbage coloring)
#
# The Python used for conversion is configured by `install.ps1 -BinaryViewer`,
# which writes its full path into  OpenUSD_view.cfg  beside this script. Without
# that file (or without usd-core), binary viewing is simply disabled and the
# rest still works.
#
# Requires the PythonScript plugin. See README for setup.

import os
import subprocess
from Npp import notepad, editor, NOTIFICATION

_UDL_NAME    = 'OpenUSD'
_CRATE_MAGIC = b'PXR-USDC'        # first 8 bytes of a binary USD crate file
_USD_EXTS    = ('.usd', '.usdc')
_seen        = set()              # process each buffer once; respect manual overrides

# Directory containing this script: set by the startup.py loader block, or
# derived when the script is run directly from the PythonScript menu.
try:
    _BASE = _HOOK_DIR
except NameError:
    try:
        _BASE = os.path.dirname(os.path.abspath(__file__))
    except NameError:
        _BASE = ''


def _configured_python():
    """Path to a Python that has usd-core, or None (binary view disabled)."""
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


def _convert_to_usda(python_exe, path):
    """Convert a binary USD layer to ASCII via usd-core, or None on failure."""
    code = ("import sys\n"
            "from pxr import Sdf\n"
            "lyr = Sdf.Layer.FindOrOpen(sys.argv[1])\n"
            "sys.stdout.write(lyr.ExportToString() if lyr else '')\n")
    startupinfo = None
    if os.name == 'nt':
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW   # no console flash
    try:
        proc = subprocess.Popen([python_exe, '-c', code, path],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                startupinfo=startupinfo)
        out, _err = proc.communicate()
        if proc.returncode != 0 or not out:
            return None
        return out.decode('utf-8', 'replace')
    except Exception:
        return None


def _show_readonly(text, src_path):
    notepad.new()
    banner = ('# Read-only view of %s\n'
              '# (binary USD crate converted to ASCII via usd-core)\n\n'
              % os.path.basename(src_path))
    editor.setText(banner + text)
    editor.emptyUndoBuffer()
    editor.setSavePoint()
    notepad.runMenuCommand('Language', _UDL_NAME)
    editor.setReadOnly(True)


def _handle(bufferID):
    if bufferID in _seen:
        return
    _seen.add(bufferID)

    path = notepad.getBufferFilename(bufferID)
    if not path or os.path.splitext(path)[1].lower() not in _USD_EXTS:
        return
    try:
        with open(path, 'rb') as fh:
            head = fh.read(8)
    except (IOError, OSError):
        return

    if head.startswith(_CRATE_MAGIC):
        python_exe = _configured_python()
        if not python_exe:
            return                       # binary view disabled -> leave as-is
        text = _convert_to_usda(python_exe, path)
        if text:
            _show_readonly(text, path)
        return

    # ASCII USD content -> highlight the active document.
    notepad.runMenuCommand('Language', _UDL_NAME)


def _on_buffer_activated(args):
    _handle(args['bufferID'])


notepad.callback(_on_buffer_activated, [NOTIFICATION.BUFFERACTIVATED])
_handle(notepad.getCurrentBufferID())
