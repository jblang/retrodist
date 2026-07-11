7z x -y -o"$EXTRACT_D" "$DOWNLOAD_D/slackware-3.6.7z" > /dev/null
bchunk "$EXTRACT_D/SLK3609118-1.bin" "$EXTRACT_D/SLK3609118-1.cue" "$EXTRACT_D/SLK3609118-1" > /dev/null
rm "$EXTRACT_D/SLK3609118-1.bin" "$EXTRACT_D/SLK3609118-1.cue"
mv "$EXTRACT_D/SLK3609118-101.iso" "$DOWNLOAD_D/disc1.iso"
extract_link_install_iso "$DOWNLOAD_D/disc1.iso"
