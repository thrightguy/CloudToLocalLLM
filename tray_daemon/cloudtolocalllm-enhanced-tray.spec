# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['enhanced_tray_daemon.py'],
    pathex=[],
    binaries=[],
    datas=[],
    hiddenimports=['gi.repository.AyatanaAppIndicator3', 'gi.repository.Gtk', 'gi.repository.GLib', 'gi.repository.GObject', 'gi.repository.Gio', 'gi.repository.Gdk', 'gi.repository.GdkPixbuf', 'gi.repository.Pango', 'gi.repository.cairo', 'pystray._xorg', 'Xlib', 'Xlib.display', 'Xlib.X', 'Xlib.protocol', 'PIL', 'PIL.Image', 'PIL.ImageDraw', 'PIL.ImageFont'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='cloudtolocalllm-enhanced-tray',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
