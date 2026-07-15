7z x -y -o"$TEMP_D" "$DOWNLOAD_D/slackware-3.6.7z" > /dev/null
bchunk "$TEMP_D/SLK3609118-1.bin" "$TEMP_D/SLK3609118-1.cue" "$TEMP_D/SLK3609118-1" > /dev/null
mv "$TEMP_D/SLK3609118-101.iso" "$TEMP_D/disc1.iso"
