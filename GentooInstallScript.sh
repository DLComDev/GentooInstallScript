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
	sfdisk $install_drive << EOF
label:dos
,256M
,4G 0x82
;
EOF
	

fi

