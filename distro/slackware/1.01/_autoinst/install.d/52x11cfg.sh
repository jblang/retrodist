# configure X11 for Cirrus card emulated by QEMU
for X11PATH in etc/X11 var/X11/lib/X11 usr/X386/lib/X11; do
  if [ -d "$ROOTMOUNT/$X11PATH" ]; then
    X11PATH=$ROOTMOUNT/$X11PATH
    break
  fi
done
if [ -d "$X11PATH" ]; then
    echo '## configuring X11...'
    if [ -f "$X11PATH/Xconfig" ]; then
        cp $X11PATH/Xconfig $X11PATH/Xconfig.orig
    fi
    cat > $X11PATH/Xconfig <<EOF
# \$XFree86: mit/server/ddx/x386/Xconfig.cpp,v 2.0 1993/10/08 15:55:00 dawes Exp \$
# \$XConsortium: Xconfig,v 1.2 91/08/26 14:34:55 gildea Exp \$
#
# Copyright 1990,91 by Thomas Roell, Dinkelscherben, Germany.
# Copyright 1992,93 by David Dawes, David Wexelblat
#
# Permission to use, copy, modify, distribute, and sell this software 
# and its documentation for any purpose is hereby granted without fee, 
# provided that the above copyright notice appear in all copies and 
# that both that copyright notice and this permission notice appear in 
# supporting documentation, and that the names of the above listed authors 
# not be used in advertising or publicity pertaining to distribution of 
# the software without specific, written prior permission.  The above 
# listed authors make no representations about the suitability of this 
# software for any purpose.  It is provided "as is" without express or 
# implied warranty.
#
# THE ABOVE LISTED AUTHORS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS 
# SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND 
# FITNESS, IN NO EVENT SHALL THE ABOVE LISTED AUTHORS BE LIABLE FOR 
# ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER 
# RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF 
# CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN 
# CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
# Author:  Thomas Roell, roell@informatik.tu-muenchen.de
#
# Extensive modifications by the XFree86 Core Team

# **********************************************************************
# Refer to the Xconfig(4/5) man page for details about the format of 
# this file. This man page is installed as /usr/X386/man/man5/Xconfig.5x 
# **********************************************************************

# **********************************************************************
# Generic parameters section
# **********************************************************************

#
# some nice paths, to avoid conflicts with other X-servers
#
RGBPath		"/usr/X386/lib/X11/rgb"

#
# Multiple FontPath entries are allowed (which are concatenated together),
# as well as specifying multiple comma-separated entries in one FontPath
# command (or a combination of both methods)
#
FontPath	"/usr/X386/lib/X11/fonts/misc/"
FontPath	"/usr/X386/lib/X11/fonts/Type1/"
FontPath	"/usr/X386/lib/X11/fonts/Speedo/"
FontPath	"/usr/X386/lib/X11/fonts/75dpi/"
# FontPath	"/usr/X386/lib/X11/fonts/100dpi/"

#
# Uncomment this to cause a core dump at the spot where a signal is 
# received.  This may leave the console in an unusable state, but may
# provide a better stack trace in the core dump to aid in debugging
#
# NoTrapSignals

# **********************************************************************
# Input devices
# **********************************************************************

#
# Enable this to use the XQUEUE driver for keyboard and mouse handling
# under System V.  This may go away in the future.
#
# Note - If you use XQUEUE, you must comment out the keyboard and
#        mouse definitions.
#
# Xqueue

#
# Keyboard and various keyboard-related parameters
#
Keyboard
  AutoRepeat 500 5
  ServerNumLock
#  Xleds      1 2 3
#  DontZap
#
# To set the LeftAlt to Meta, RightAlt key to ModeShift, 
# RightCtl key to Compose, and ScrollLock key to ModeLock:
# 
#  LeftAlt     Meta
#  RightAlt    ModeShift
#  RightCtl    Compose
#  ScrollLock  ModeLock

#
# Mouse definition and related parameters
#
PS/2	"/dev/ps2aux"
#  BaudRate	9600
#  SampleRate	150
  Emulate3Buttons

# **********************************************************************
# Graphics drivers
# **********************************************************************

#
# The 8-bit colour SVGA driver
#
VGA256
  Chipset   "clgd5422"
  Virtual   1024 768
  Modes     "1024x768"
  Clocks	  25 40 65
EOF

    if [ -z "$SKIPVGA16" ]; then
        cat >> "$X11PATH/Xconfig" <<EOF
# 
# The 16-colour VGA driver
#
VGA16
  Virtual   800 600
  Modes     "800x600"
  Clocks    25 40 65
EOF
    fi

    cat >> "$X11PATH/Xconfig" <<EOF
#
# The 1-bit mono SVGA driver
#
VGA2
  Virtual   800 600
  Modes	    "800x600"
  Clocks    25 40 65

#
# The Hercules driver.  For Hercules, the only valid configuration option
# is ScreenNo (refer to the manual page).
#
# HGA2

#
# The alternate monochrome driver.  Refer to the XF86_Mono manual page.
#
# BDM2

# 
# The accelerated servers (S3, Mach32, Mach8, 8514)
#
#ACCEL
#  Virtual   1024 768
#  Modes     "1024x768"

#
# For boards with a programmable clock generator, you use a line like:
#
# Clocks "icd2061a"

# **********************************************************************
# Database of video modes
# **********************************************************************
ModeDB
# name        clock   horizontal timing     vertical timing      flags
"640x480"     25      640  664  760  800    480  491  493  525
"800x600"     40      800  840  968 1056    600  601  605  628 +hsync +vsync
"1024x768"    65     1024 1032 1176 1344    768  771  777  806 -hsync -vsync
#
# Refer to README.Config, modeDB.txt, and VideoModes.doc for actual
# modes, and information on how to calculate and adjust them.  
#
# DO NOT BLINDLY USE VIDEO MODES WITHOUT UNDERSTANDING WHAT YOU ARE
# DOING.  IT IS POSSIBLE TO DAMAGE THE MONITOR.  THE XFree86 CORE TEAM
# DISCLAIMS ALL LIABILITY FOR MONITOR DAMAGE, AS THE DOCUMENTATION
# ACCOMPANYING XFree86 HAS BEEN VERIFIED TO CONTAIN VALID AND SAFE
# MODES, AS LONG AS ONLY ONES WITHIN DOCUMENTED MONITOR SPECIFICATIONS
# ARE USED.
#
EOF
fi
# Link to the correct X server
# XFree86 1.2's SVGA server doesn't support Cirrus SVGA emulated by QEMU, so use X386mono instead
for SERVER in usr/X386/bin/X386mono usr/X11/bin/XF86_SVGA usr/X11/bin/XF86_VGA16 usr/X11/bin/XF86_mono; do
  if [ -f "$ROOTMOUNT/$SERVER" ]; then
    (cd $(dirname "$ROOTMOUNT/$SERVER"); ln -sf $(basename "$SERVER") X)
    break
  fi
done