install_startx_setfont_wrapper() {
  for STARTX in /usr/bin/startx /usr/X386/bin/startx; do
    if [ -f "$STARTX" ] && [ ! -L "$STARTX" ] && [ ! -f "$STARTX.real" ]; then
      mv "$STARTX" "$STARTX.real"
      cat > "$STARTX" <<'EOF'
#!/bin/sh
"$(dirname "$0")/startx.real" "$@"
STATUS=$?
# reset font to fix black screen after XFree86 1.x/2.x runs
if command -v setfont >/dev/null 2>&1; then
  setfont >/dev/null 2>&1
fi
exit $STATUS
EOF
      chmod 755 "$STARTX"
    fi
  done
}

detect_mouse_defaults() {
  if [ -z "$MOUSEDEV" ]; then
    if [ -c /dev/psaux ]; then
      MOUSEDEV=/dev/psaux
    elif [ -c /dev/ps2aux ]; then
      MOUSEDEV=/dev/ps2aux
    else
      MOUSEDEV=/dev/cua1
    fi
  fi

  if [ -z "$MOUSETYPE" ]; then
    case "$MOUSEDEV" in
      /dev/psaux|/dev/ps2aux)
        MOUSETYPE="PS/2"
        ;;
      /dev/cua1)
        MOUSETYPE="Microsoft"
        ;;
    esac
  fi
}

configure_x11r6_svga() {
  SERVER=/usr/X11R6/bin/XF86_SVGA
  echo "Found X11 server at $SERVER"

  if [ -d /var/X11R6/bin ]; then
    (cd /var/X11R6/bin; ln -sf "$SERVER" X)
  fi

  for X11PATH in /usr/X11R6/lib/X11 /var/X11R6/lib /etc; do
    if [ -d "$X11PATH" ]; then
      break
    fi
  done

  XFREECFG="$X11PATH/XF86Config"
  XFREECFG_ETC=/etc/XF86Config

  echo "Creating XF86Config in $XFREECFG"

  if [ -f "$XFREECFG" ]; then
    cp "$XFREECFG" "$XFREECFG.orig"
  fi

  cat > "$XFREECFG" <<EOF
# File and font paths.
Section "Files"
    RgbPath     "/usr/X11R6/lib/X11/rgb"
    FontPath    "/usr/X11R6/lib/X11/fonts/misc/"
    FontPath    "/usr/X11R6/lib/X11/fonts/Type1/"
    FontPath    "/usr/X11R6/lib/X11/fonts/Speedo/"
    FontPath    "/usr/X11R6/lib/X11/fonts/75dpi/"
    FontPath    "/usr/X11R6/lib/X11/fonts/100dpi/"
EndSection

# Server-wide defaults.
Section "ServerFlags"
EndSection

# Keyboard settings.
Section "Keyboard"
    Protocol    "Standard"
    AutoRepeat  500 5
EndSection

# Mouse settings.
Section "Pointer"
    Protocol    "$MOUSETYPE"
    Device      "$MOUSEDEV"
    Emulate3Buttons
EndSection

# Monitor timing ranges and modes.
Section "Monitor"
    Identifier  "QEMU"
    HorizSync   31.5 - 82.0
    VertRefresh 40-150
    Modeline "640x480"   25.175  640  664  760  800   480  491  493  525
    Modeline "800x600"   40      800  840  968 1056   600  601  605  628 +hsync +vsync
    Modeline "1024x768"  65     1024 1032 1176 1344   768  771  777  806 -hsync -vsync
    Modeline "1280x1024" 110    1280 1328 1512 1712  1024 1025 1028 1054
EndSection

# Cirrus SVGA card.
Section "Device"
    Identifier "QEMU"
    Option "noaccel"
    Option "sw_cursor"
EndSection

# Available color depths for the SVGA server.
Section "Screen"
    Driver      "svga"
    Device      "QEMU"
    Monitor     "QEMU"
    Subsection "Display"
        Depth       8
        Modes       "1024x768"
        ViewPort    0 0
    EndSubsection
    Subsection "Display"
        Depth       16
        Modes       "1024x768"
        ViewPort    0 0
    EndSubsection
    Subsection "Display"
        Depth       32
        Modes       "1024x768"
        ViewPort    0 0
    EndSubsection
EndSection
EOF

  if [ "$XFREECFG" != "$XFREECFG_ETC" ]; then
    cp "$XFREECFG" "$XFREECFG_ETC"
  fi
}

configure_x11r6_xfree86_4() {
  SERVER=/usr/X11R6/bin/XFree86
  echo "Found X11 server at $SERVER"

  if [ -d /var/X11R6/bin ]; then
    (cd /var/X11R6/bin; ln -sf "$SERVER" X)
  fi

  for X11PATH in /etc/X11 /etc /usr/X11R6/lib/X11; do
    if [ -d "$X11PATH" ]; then
      break
    fi
  done

  XFREECFG="$X11PATH/XF86Config"
  XFREECFG_ETC=/etc/XF86Config

  echo "Creating XFree86 4.x XF86Config in $XFREECFG"

  if [ -f "$XFREECFG" ]; then
    cp "$XFREECFG" "$XFREECFG.orig"
  fi

  cat > "$XFREECFG" <<EOF
Section "Files"
    RgbPath     "/usr/X11R6/lib/X11/rgb"
    FontPath    "/usr/X11R6/lib/X11/fonts/misc/"
    FontPath    "/usr/X11R6/lib/X11/fonts/Type1/"
    FontPath    "/usr/X11R6/lib/X11/fonts/Speedo/"
    FontPath    "/usr/X11R6/lib/X11/fonts/75dpi/"
    FontPath    "/usr/X11R6/lib/X11/fonts/100dpi/"
EndSection

Section "InputDevice"
    Identifier  "Keyboard0"
    Driver      "keyboard"
    Option      "AutoRepeat" "500 5"
EndSection

Section "InputDevice"
    Identifier  "Mouse0"
    Driver      "mouse"
    Option      "Protocol" "$MOUSETYPE"
    Option      "Device" "$MOUSEDEV"
    Option      "Emulate3Buttons"
EndSection

Section "Monitor"
    Identifier  "QEMU"
    HorizSync   31.5 - 82.0
    VertRefresh 40-150
EndSection

Section "Device"
    Identifier  "QEMU"
    Driver      "vesa"
EndSection

Section "Screen"
    Identifier  "Screen0"
    Device      "QEMU"
    Monitor     "QEMU"
    DefaultDepth 16
    SubSection "Display"
        Depth       8
        Modes       "1024x768" "800x600" "640x480"
    EndSubSection
    SubSection "Display"
        Depth       16
        Modes       "1024x768" "800x600" "640x480"
    EndSubSection
    SubSection "Display"
        Depth       24
        Modes       "1024x768" "800x600" "640x480"
    EndSubSection
EndSection

Section "ServerLayout"
    Identifier  "Default Layout"
    Screen      "Screen0"
    InputDevice "Keyboard0" "CoreKeyboard"
    InputDevice "Mouse0" "CorePointer"
EndSection
EOF

  if [ "$XFREECFG" != "$XFREECFG_ETC" ]; then
    cp "$XFREECFG" "$XFREECFG_ETC"
  fi
}

configure_x386_svga() {
  SERVER=/usr/X386/bin/XF86_SVGA
  echo "Found X11 server at $SERVER"
  (cd "$(dirname "$SERVER")"; ln -sf "$(basename "$SERVER")" X)

  for X11PATH in /etc/X11 /var/X11/lib/X11 /usr/X386/lib/X11; do
    if [ -d "$X11PATH" ]; then
      break
    fi
  done

  echo "Creating Xconfig in $X11PATH"

  if [ -f "$X11PATH/Xconfig" ]; then
    cp "$X11PATH/Xconfig" "$X11PATH/Xconfig.orig"
  fi

  cat > "$X11PATH/Xconfig" <<EOF
# Shared resource paths.
RGBPath     "/usr/X386/lib/X11/rgb"
FontPath    "/usr/X386/lib/X11/fonts/misc/"
FontPath    "/usr/X386/lib/X11/fonts/Type1/"
FontPath    "/usr/X386/lib/X11/fonts/Speedo/"
FontPath    "/usr/X386/lib/X11/fonts/75dpi/"

# Keyboard settings.
Keyboard
  AutoRepeat 500 5
  ServerNumLock

# Mouse settings.
$MOUSETYPE "$MOUSEDEV"
  Emulate3Buttons

# Cirrus SVGA mode selection.
VGA256
  Chipset   "clgd5422"
  Modes     "1024x768"

# Video mode database.
ModeDB
"640x480"   25   640  664  760  800   480  491  493  525
"800x600"   40   800  840  968 1056   600  601  605  628 +hsync +vsync
"1024x768"  65  1024 1032 1176 1344   768  771  777  806 -hsync -vsync
EOF
}

configure_x386_mono() {
  if [ -x /usr/X386/bin/XF86_mono ]; then
    SERVER=/usr/X386/bin/XF86_mono
  else
    SERVER=/usr/X386/bin/X386mono
  fi
  echo "Found X11 server at $SERVER"
  (cd "$(dirname "$SERVER")"; ln -sf "$(basename "$SERVER")" X)

  for X11PATH in /etc/X11 /var/X11/lib/X11 /usr/X386/lib/X11; do
    if [ -d "$X11PATH" ]; then
      break
    fi
  done

  echo "Creating mono Xconfig in $X11PATH"

  if [ -f "$X11PATH/Xconfig" ]; then
    cp "$X11PATH/Xconfig" "$X11PATH/Xconfig.orig"
  fi

  cat > "$X11PATH/Xconfig" <<EOF
# Shared resource paths.
RGBPath     "/usr/X386/lib/X11/rgb"
FontPath    "/usr/X386/lib/X11/fonts/misc/"
FontPath    "/usr/X386/lib/X11/fonts/Type1/"
FontPath    "/usr/X386/lib/X11/fonts/Speedo/"
FontPath    "/usr/X386/lib/X11/fonts/75dpi/"

# Keyboard settings.
Keyboard
  AutoRepeat 500 5
  ServerNumLock

# Mouse settings.
$MOUSETYPE "$MOUSEDEV"
  Emulate3Buttons

# Mono server mode selection.
VGA2
  Modes     "640x480"

# Video mode database.
ModeDB
"640x480"   25   640  664  760  800   480  491  493  525
"800x600"   40   800  840  968 1056   600  601  605  628 +hsync +vsync
EOF
}

_configure_x11() {
  echo "### Configuring X11..."

  # Pick mouse defaults once for all X server variants while preserving
  # any values that were already supplied by the installer environment.
  detect_mouse_defaults

  # XFree86 4.x uses a monolithic XFree86 server. XFree86 3.1 uses XF86_SVGA.
  if [ -x /usr/X11R6/bin/XFree86 ]; then
    configure_x11r6_xfree86_4
  elif [ -x /usr/X11R6/bin/XF86_SVGA ]; then
    configure_x11r6_svga
  elif [ -x /usr/X386/bin/XF86_SVGA ]; then
    configure_x386_svga
    install_startx_setfont_wrapper
  elif [ -x /usr/X386/bin/X386mono ]; then
    configure_x386_mono
  else
    echo "No supported X11 server found."
  fi
}
