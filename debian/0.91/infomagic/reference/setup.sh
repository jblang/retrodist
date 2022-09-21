#! /bin/sh

echo ""
echo "*** [1mWelcome to Debian Linux 0.91 BETA![m ***"
echo ""
echo "Making a few final preparations..."
echo ""
if [ -x /var/adm/locate/updatedb ]; then
	echo -n "   Setting up \`find.codes' database..."
	/var/adm/locate/updatedb 2>/dev/null
	echo "done."
fi
echo ""
echo "Login to your new system as \`root'.  To install additional Debian Linux"
echo "packages type \`dpkg' at the shell prompt."
echo ""
echo "Please mail bug reports, comments and suggestions to <[1mdebian-bugs@pixar.com[m>."
echo ""
