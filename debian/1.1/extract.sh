rm -rf MODULES.TGZ modules
mcopy -i boot.img ::MODULES.TGZ MODULES.TGZ
mkdir modules
tar -xzf MODULES.TGZ -C modules
cp modules/lib/modules/*/misc/serial.o fat/serial.o
rm -rf MODULES.TGZ modules
