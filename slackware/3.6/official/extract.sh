cp -lR $SLACKBASE/slackware-3.6 install
cp install/bootdsks.144/bare.i boot.img
truncate -s1440k boot.img
cp install/rootdsks/text.gz root.img
autoinst_prep 2G
