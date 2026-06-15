# Emit a startx wrapper that restores console fonts after early XFree86 exits.
x11_build_startx_setfont_wrapper() {
    cat <<'EOF'
#!/bin/sh
"$(dirname "$0")/startx.real" "$@"
X11_STATUS=$?
# reset font to fix black screen after XFree86 1.x/2.x runs
if command -v setfont >/dev/null 2>&1; then
  setfont >/dev/null 2>&1
fi
exit $X11_STATUS
EOF
}

# Emit an Xconfig for XFree86 monochrome servers.
x11_build_1x2x_mono_config() {
    cat <<EOF
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
$X11_MOUSETYPE "$X11_MOUSEDEV"
  Emulate3Buttons

# Mono server mode selection.
VGA2
  Modes     $X11_MODES

# Video mode database.
ModeDB
"640x480"   25   640  664  760  800   480  491  493  525
"800x600"   40   800  840  968 1056   600  601  605  628 +hsync +vsync
EOF
}

# Emit an Xconfig for XFree86 1.x and 2.x SVGA servers.
x11_build_1x2x_svga_config() {
    cat <<EOF
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
$X11_MOUSETYPE "$X11_MOUSEDEV"
  Emulate3Buttons

# Cirrus SVGA mode selection.
VGA256
  Chipset   "clgd5422"
  Modes     $X11_MODES

# Video mode database.
ModeDB
"640x480"   25   640  664  760  800   480  491  493  525
"800x600"   40   800  840  968 1056   600  601  605  628 +hsync +vsync
"1024x768"  65  1024 1032 1176 1344   768  771  777  806 -hsync -vsync
EOF
}

# Emit one XFree86 3.x Display subsection for a color depth.
x11_build_3x_display_subsection() {
    cat <<EOF
    Subsection "Display"
        Depth       $1
        Modes       $X11_MODES
        ViewPort    0 0
    EndSubsection
EOF
}

# Emit XFree86 3.x Display subsections in X11_DEPTHS preference order.
x11_build_3x_display_subsections() {
    # XFree86 3.x has no DefaultColorDepth; it uses the first matching
    # Display subsection as the default, so X11_DEPTHS is an ordered list.
    for X11_DISPLAY_DEPTH in $X11_DEPTHS; do
        x11_build_3x_display_subsection "$X11_DISPLAY_DEPTH"
    done
}

# Emit an XF86Config for XFree86 3.x SVGA servers.
x11_build_3x_config() {
    cat <<EOF
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
    Protocol    "$X11_MOUSETYPE"
    Device      "$X11_MOUSEDEV"
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
EOF
    x11_build_3x_display_subsections
    echo "EndSection"
}

# Emit an XF86Config for XFree86 4.x servers.
x11_build_4x_config() {
    cat <<EOF
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
    Option      "Protocol" "$X11_MOUSETYPE"
    Option      "Device" "$X11_MOUSEDEV"
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
    DefaultDepth $X11_DEFAULT_DEPTH
    SubSection "Display"
        Depth       8
        Modes       $X11_MODES
    EndSubSection
    SubSection "Display"
        Depth       16
        Modes       $X11_MODES
    EndSubSection
    SubSection "Display"
        Depth       24
        Modes       $X11_MODES
    EndSubSection
EndSection

Section "ServerLayout"
    Identifier  "Default Layout"
    Screen      "Screen0"
    InputDevice "Keyboard0" "CoreKeyboard"
    InputDevice "Mouse0" "CorePointer"
EndSection
EOF
}

# Back up an existing X11 config file using the legacy ".orig" suffix.
x11_backup_orig() {
    if [ -f "$1" ]; then
        log_debug "Creating backup file: $1.orig"
        cp "$1" "$1.orig"
    fi
}

# Fill unset mouse variables with defaults that work in QEMU.
x11_detect_mouse_defaults() {
    if [ -z "$X11_MOUSEDEV" ]; then
        if [ -c /dev/psaux ]; then
            X11_MOUSEDEV=/dev/psaux
        elif [ -c /dev/ps2aux ]; then
            X11_MOUSEDEV=/dev/ps2aux
        else
            X11_MOUSEDEV=/dev/cua1
        fi
    fi

    if [ -z "$X11_MOUSETYPE" ]; then
        case "$X11_MOUSEDEV" in
            /dev/psaux|/dev/ps2aux)
                X11_MOUSETYPE="PS/2"
                ;;
            /dev/cua*)
                X11_MOUSETYPE="Microsoft"
                ;;
            *)
                log_error "Unknown mouse device: $X11_MOUSEDEV"
                exit 1
                ;;
        esac
    fi
    log_info "X11 mouse configuration:"
    log_info "  X11_MOUSEDEV=$X11_MOUSEDEV"
    log_info "  X11_MOUSETYPE=$X11_MOUSETYPE"
}

# Choose the first existing directory from a caller-provided list.
x11_detect_path() {
    X11_PATH=
    for X11_CANDIDATE in "$@"; do
        log_debug "Checking X11 config directory: $X11_CANDIDATE"
        if [ -d "$X11_CANDIDATE" ]; then
            X11_PATH="$X11_CANDIDATE"
            log_info "Selected X11 config directory: $X11_PATH"
            return 0
        fi
    done
    return 1
}

# Link an X server into a target directory when that layout exists.
x11_link_var_x11r6_bin() {
    if [ -d /var/X11R6/bin ]; then
        log_info "Creating symlink: /var/X11R6/bin/X -> $X11_SERVER"
        (cd /var/X11R6/bin; ln -sf "$X11_SERVER" X)
    else
        log_debug "No /var/X11R6/bin directory; skipping X server symlink"
    fi
}

# Install the startx wrapper around eligible legacy startx scripts.
x11_install_startx_setfont_wrapper() {
    for X11_STARTX in /usr/bin/startx /usr/X386/bin/startx; do
        if [ -f "$X11_STARTX" ] && [ ! -L "$X11_STARTX" ] && [ ! -f "$X11_STARTX.real" ]; then
            log_info "Creating backup file: $X11_STARTX.real"
            mv "$X11_STARTX" "$X11_STARTX.real"
            log_info "Creating file: $X11_STARTX"
            x11_build_startx_setfont_wrapper > "$X11_STARTX"
            chmod 755 "$X11_STARTX"
        else
            log_debug "Skipping startx wrapper candidate: $X11_STARTX"
        fi
    done
}

# Write XF86Config and mirror it to /etc/XF86Config when needed.
x11_write_xf86config() {
    X11_XFREECFG="$1/XF86Config"
    X11_XFREECFG_ETC=/etc/XF86Config

    x11_backup_orig "$X11_XFREECFG"
    log_info "Creating file: $X11_XFREECFG"
    cat > "$X11_XFREECFG"

    if [ "$X11_XFREECFG" != "$X11_XFREECFG_ETC" ]; then
        log_info "Creating symlink: $X11_XFREECFG_ETC -> $X11_XFREECFG"
        ln -sf "$X11_XFREECFG" "$X11_XFREECFG_ETC"
    fi
}

# Prepare the common XF86Config target and derive the first preferred depth.
x11_3x4x_common_config() {
    X11_DEPTHS=${X11_DEPTHS:-"16 8 32"}
    X11_DEFAULT_DEPTH="$(echo $X11_DEPTHS | sed 's/ .*//')"
    X11_MODES=${X11_MODES:-'"1024x768" "800x600" "640x480"'}
    log_info "X11 configuration:"
    log_info "  X11_DEPTHS=$X11_DEPTHS"
    log_info "  X11_DEFAULT_DEPTH=$X11_DEFAULT_DEPTH"
    log_info "  X11_MODES=$X11_MODES"
    log_info "Found X11 server at $X11_SERVER"
    x11_link_var_x11r6_bin

    x11_detect_path "$@" || return 1
    log_info "XF86Config path is $X11_PATH/XF86Config"
}

# Configure XFree86 3.x using the SVGA server.
x11_3x_config() {
    X11_SERVER=/usr/X11R6/bin/XF86_SVGA
    log_info "Using X11 configuration style: XFree86 3.x SVGA"
    x11_3x4x_common_config /usr/X11R6/lib/X11 /var/X11R6/lib /etc || return 1
    x11_build_3x_config | x11_write_xf86config "$X11_PATH"
}

# Configure XFree86 4.x using its monolithic XFree86 server.
x11_4x_config() {
    X11_SERVER=/usr/X11R6/bin/XFree86
    log_info "Using X11 configuration style: XFree86 4.x"
    x11_3x4x_common_config /etc/X11 /etc /usr/X11R6/lib/X11 || return 1
    x11_build_4x_config | x11_write_xf86config "$X11_PATH"
}

# Prepare the common Xconfig target for XFree86 1.x and 2.x servers.
x11_1x2x_common_config() {
    log_info "Found X11 server at $X11_SERVER"
    log_info "Creating symlink: $(dirname "$X11_SERVER")/X -> $(basename "$X11_SERVER")"
    (cd "$(dirname "$X11_SERVER")"; ln -sf "$(basename "$X11_SERVER")" X)

    x11_detect_path /etc/X11 /var/X11/lib/X11 /usr/X386/lib/X11 || return 1
    X11_XCONFIG="$X11_PATH/Xconfig"
    log_info "Xconfig path is $X11_XCONFIG"

    x11_backup_orig "$X11_XCONFIG"
}

# Configure XFree86 1.x and 2.x using the SVGA server.
x11_1x2x_svga_config() {
    X11_SERVER=/usr/X386/bin/XF86_SVGA
    X11_MODES=${X11_MODES:-'"1024x768" "800x600" "640x480"'}
    log_info "Using X11 configuration style: XFree86 1.x/2.x SVGA"
    log_info "X11 configuration:"
    log_info "  X11_MODES=$X11_MODES"
    x11_1x2x_common_config || return 1
    log_info "Creating file: $X11_XCONFIG"
    x11_build_1x2x_svga_config > "$X11_XCONFIG"
    x11_install_startx_setfont_wrapper
}

# Configure XFree86 1.x and 2.x using a monochrome server.
x11_1x2x_mono_config() {
    X11_SERVER=/usr/X386/bin/X386mono
    X11_MODES=${X11_MODES:-'"640x480"'}
    log_info "Using X11 configuration style: XFree86 1.x/2.x monochrome"
    log_info "X11 configuration:"
    log_info "  X11_MODES=$X11_MODES"
    x11_1x2x_common_config || return 1
    log_info "Creating file: $X11_XCONFIG"
    x11_build_1x2x_mono_config > "$X11_XCONFIG"
}

# Entry point for applying target X11 configuration.
_x11_config() {
    log_div
    log_info "Configuring X11..."

    x11_detect_mouse_defaults

    # Detect the variant of X11 based on the existence of server binaries.
    if [ -x /usr/X11R6/bin/XFree86 ]; then
        log_info "Detected XFree86 4.x server"
        x11_4x_config
    elif [ -x /usr/X11R6/bin/XF86_SVGA ]; then
        log_info "Detected XFree86 3.x SVGA server"
        x11_3x_config
    elif [ -x /usr/X386/bin/XF86_SVGA ]; then
        log_info "Detected XFree86 1.x/2.x SVGA server"
        x11_1x2x_svga_config
    elif [ -x /usr/X386/bin/X386mono ]; then
        log_info "Detected XFree86 1.x/2.x monochrome server"
        x11_1x2x_mono_config
    else
        log_warn "No supported X11 server found."
    fi
}
