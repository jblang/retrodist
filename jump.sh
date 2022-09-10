#!/usr/bin/env bash
# Runs a jumpbox for retro Linux distros to talk to
set -euo pipefail
SCRIPTDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPTDIR/common.sh

CLOUDIMG=jammy-server-cloudimg-amd64.img
JUMPIMG=$JUMPBASE/retrojump.img
SEEDIMG=""
if [[ ! -f $JUMPIMG ]]; then
  mkdir -p $JUMPBASE
  if [[ ! -f $JUMPBASE/$CLOUDIMG ]]; then
      wget -O $JUMPBASE/$CLOUDIMG https://cloud-images.ubuntu.com/jammy/current/$CLOUDIMG
  fi
  cp $JUMPBASE/$CLOUDIMG $JUMPIMG
  qemu-img resize $JUMPIMG 20G

  if [[ ! -f $JUMPBASE/id_rsa ]]; then
    ssh-keygen -q -C retro@retrojump -f $JUMPBASE/id_rsa -N ""
  fi
  PUBKEY=$(cat $JUMPBASE/id_rsa.pub)

cat > $TEMPDIR/metadata <<EOF
instance-id: retrojump-1
local-hostname: retrojump
EOF

cat > $TEMPDIR/userdata <<EOF
#cloud-config
user: retro
password: retro
chpasswd: { expire: False }
ssh_pwauth: True
ssh_authorized_keys:
  - $PUBKEY
packages:
  - vsftpd
write_files:
  - path: /etc/vsftpd.conf
    content: |
      listen_address=10.0.2.1
      listen=NO
      listen_ipv6=YES
      anonymous_enable=YES
      local_enable=YES
      write_enable=YES
      dirmessage_enable=YES
      use_localtime=YES
      xferlog_enable=YES
      connect_from_port_20=YES
      secure_chroot_dir=/var/run/vsftpd/empty
      pam_service_name=vsftpd
      rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
      rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
      ssl_enable=NO
EOF

cat > $TEMPDIR/networkconfig <<EOF
#cloud-config
network:
  version: 1
  config:
    - type: physical
      name: enp0s2
      subnets:
        - type: dhcp
      routes:
        - network: 10.0.1.0/24
          gateway: 10.0.1.2
    - type: physical
      name: enp0s3
      subnets:
        - type: static
          address: 10.0.2.1/24
          routes:
            - network: 10.0.2.0/24
              gateway: 10.0.2.2
EOF

  cloud-localds $TEMPDIR/seed.img $TEMPDIR/userdata $TEMPDIR/metadata -N $TEMPDIR/networkconfig
  SEEDIMG="-drive if=virtio,format=raw,file=$TEMPDIR/seed.img"

fi

qemu-system-x86_64 \
  -machine accel=kvm,type=q35 \
  -cpu host \
  -m 2G \
  -netdev user,id=internet,net=10.0.1.0/24,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=internet \
  -netdev socket,id=retronet,listen=:1234 \
  -device virtio-net-pci,netdev=retronet \
  -drive if=virtio,format=qcow2,file=$JUMPIMG \
  $SEEDIMG \
  $@
