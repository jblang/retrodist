#!/bin/sh

TTYDEV=ttyS0
TTYBAUD=9600
HOSTNAME=darkstar
DOMAINNAME=frop.org
IPADDR=10.0.2.36
NETMASK=255.255.255.0
NETWORK=10.0.2.0
BROADCAST=10.0.2.255
GATEWAY=10.0.2.2
NAMESERVER=10.0.2.1
MOUSEDEV=psaux
MOUSETYPE=PS/2

enable_serial_console
configure_networking
configure_mail
configure_x11
