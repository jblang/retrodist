# Autoinstall Scripts for Ancient Slackware

This directory gets copied to /dev/hdb1 for Slackware installations.

Filenames here must be 8.3 so they can be mounted as FAT16. 

These scripts expect to be mounted on `/mnt`. The main script is `autoinst.sh`, which:
- defines some convenience functions (namely `partition`, see below).
- sources each of the scripts in `/mnt/install.d` in numerical order

You have to be careful with your shell scripts here too:
- They'll be running on a boot disk from 1993 that will not have most
  of the expected tools available.
- awk, cut, grep, sort, tr, uniq, etc. are all missing in action.
- You can only count on bash builtins, cat, echo, sed, and test. 
- But beware: this sed is quite old and limited, so don't get too fancy!
- OK, you can be a little fancy if you are creative and patient:
  - See `partition` and associated functions in [autoinst.sh](autoinst.sh)
  - See [autoinst.d/0fdisk.sh](autoinst.d/0fdisk.sh) for example usage