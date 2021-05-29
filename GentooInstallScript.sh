EFI="false"
install_drive="/dev/sda"
makeswap="true"
swap_size="4G"
stage3_download="https://bouncer.gentoo.org/fetch/root/all/releases/x86/autobuilds/20210524T214502Z/stage3-i686-20210524T214502Z.tar.xz"


if [ $EFI = "true" ]
then
	echo "test"
fi

if [ $EFI = "false" ]
then

	#prepare file system
	dd if=/dev/zero of=$install_drive bs=512 count=1
	wipefs /dev/sda
	sfdisk $install_drive << EOF
label:dos
,256M
,$swap_size 0x82
;
EOF
	sfdisk -A $install_drive 1
	mkfs.vfat -F 32 "$install_drive"1
	mkfs.ext4 "$install_drive"3
	mkswap "$install_drive"2
	swapon "$install_drive"2
	mount "$install_drive"3 /mnt/gentoo

	#set date
	ntpd -q -g
	

	#get stage3
	cd /mnt/gentoo
	wget $stage3_download
	tar xpvf stage3*.tar.xz --xattrs-include='*.*' --numeric-owner

	#prepare for chroot
	cp --dereference /etc/resolv.conf /mnt/gentoo/etc
	mount --types proc /proc /mnt/gentoo/proc
	mount --rbind /sys /mnt/gentoo/sys
	mount --make-rslave /mnt/gentoo/sys
	mount --rbind /dev /mnt/gentoo/dev
	mount --make-rslave /mnt/gentoo/dev

	#chroot
	chroot /mnt/gentoo /bin/bash
	source /etc/profile
	export PS1="(chroot) $(PS1)"

fi

