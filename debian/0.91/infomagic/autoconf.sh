#!/bin/sh

debian_install_packages_flat

enable_serial_console

HOSTNAME=debra
IPADDR=10.0.2.91
configure_networking

MOUSEDEV=/dev/cua1
configure_x11
