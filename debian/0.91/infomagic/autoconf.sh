#!/bin/sh

TTYDEV=ttyS0
TTYBAUD=9600
HOSTNAME=debra
DOMAINNAME=debian.org
IPADDR=10.0.2.91
NETMASK=255.255.255.0
NETWORK=10.0.2.0
BROADCAST=10.0.2.255
GATEWAY=10.0.2.2
NAMESERVER=10.0.2.1
MOUSEDEV=cua1
MOUSETYPE=Microsoft

debian_install_packages_flat
enable_serial_console
configure_networking
configure_x11
