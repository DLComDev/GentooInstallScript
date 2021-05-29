EFI="false"
install_drive="/dev/sda"
makeswp="true"

if [ $EFI = "true" ]
then
	echo "test"
fi

if [ $EFI = "false" ]
then
	dd if=/dev/zero of=$install_drive bs=512 count=1
	fdisk $install_drive << EOF
	o
	n
	p
	1
	2048
	+256M
	w
	EOF

fi

