#Configuration section. All variables inside this section need to be configured to fit your personal needs

EFI="true"
install_drive="/dev/sdb"
swap_size="128G"
stage3_download="https://bouncer.gentoo.org/fetch/root/all/releases/amd64/autobuilds/20210711T170538Z/stage3-amd64-systemd-20210711T170538Z.tar.xz"
timezone="Europe/Berlin"
locales="en_US ISO-8859-1
en_US.UTF-8 UTF-8
de_DE ISO-8859-1
de_DE.UTF-8 UTF-8"
hostname="tux"
native="false"

#Program section. Only change stuff if you know what you're doing.

if [ $1 = "--bootstrap" ]
then
	
	#ensure that the GentooInstallScript is available in /mnt/gentoo
	unalias cp
	mkdir /mnt/gentoo
	
	
	if [ $EFI = "true" ]
	then
		dd if=/dev/zero of=$install_drive bs=512 count=1
		wipefs $install_drive
		sfdisk $install_drive << EOF
label:gpt
,5M
,256M
,$swap_size
;
EOF
		mkfs.vfat -F 32 "$install_drive"2
		mkfs.ext4 "$install_drive"4
		mkswap "$install_drive"3
		swapon "$install_drive"3
		mount "$install_drive"4 /mnt/gentoo
		chmod 1777 /mnt/gentoo/tmp	
	fi

	if [ $EFI = "false" ]
	then


		#prepare file system
		dd if=/dev/zero of=$install_drive bs=512 count=1
		wipefs $install_drive
		sfdisk $install_drive << EOF
label:dos
,256M
,$swap_size 0x82
;
EOF
		sfdisk -A "$install_drive"1
		mkfs.ext2 "$install_drive"1
		mkfs.ext4 "$install_drive"3
		mkswap "$install_drive"2
		swapon "$install_drive"2
		mount "$install_drive"3 /mnt/gentoo
	fi
	
	#set date
	ntpd -q -g

	#get stage3
	cp GentooInstallScript.sh /mnt/gentoo
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
	
	if [ $native = "false" ]
	then
		test -L /dev/shm && rm /dev/shm && mkdir /dev/shm
		mount --types tmpfs --options nosuid,nodev,noexec shm /dev/shm
		chmod 1777 /dev/shm
	fi
	
	
	#chroot
	chroot /mnt/gentoo /bin/bash

fi

if [ $1 = "--install" ]
then
	#tty profile
	source /etc/profile
	export PS1="(chroot) $(PS1)"

	#mount boot system
	mount "$install_drive"2 /boot

	#install ebuild snapshot
	emerge-webrsync

	#sync emerge
	emerge --sync --quiet

	#update @world set
	emerge -q --verbose --update --deep --newuse @world

	#allow for all licenses (change this setting if you only want to accept free software on your system)
	echo "ACCEPT_LICENSE=\"@EULA @BINARY-REDISTRIBUTABLE\"" > /etc/portage/make.conf

	#set timezone
	echo $timezone > /etc/timezone
	emerge --config sys-libs/timezone-data

	#add locales
	echo "$locales" > /etc/locale.gen
	locale-gen
	eselect locale list
	echo "Please enter desired locale number:"
	read locale_number
	eselect locale set $locale_number
	env-update && source /etc/profile && export PS1="(chroot) $(PS1)"

	#installing sources and compiling kernel
	emerge -q sys-kernel/gentoo-sources
	emerge -q sys-kernel/genkernel
	emerge -q sys-apps/pciutils
	emerge -q app-arch/lzop app-arch/lz4
	
	echo ""$install_drive"1 /boot ext2 defaults 0 2" > /etc/fstab
	genkernel all

	#install firmware
	emerge -q sys-kernel/linux-firmware

	#setup fstab
	if [ $EFI=false ] 
	then
		rm /etc/fstab
		echo ""$install_drive"1 /boot ext2 defaults 0 2\n" > /etc/fstab
		echo ""$install_drive"2 none swap sw 0 0\n" >> /etc/fstab
		echo ""$install_drive"3 ext4 noatime 0 1\n" >> /etc/fstab
	fi
	if [ $EFI=true ]
	then
		rm /etc/fstab
		echo ""$install_drive"2 /boot/efi vfat defaults 0 2\n" > /etc/fstab
		echo ""$install_drive"3 none swap sw 0 0\n" >> /etc/fstab
		echo ""$install_drive"4 ext4 noatime 0 1\n" >> /etc/fstab
	fi
	#set hostname
	echo "hostname=\"$hostname\"" > /etc/conf.d/hostname
	
	#setup networking
	emerge -q --noreplace net-misc/netifrc
	echo "config_eth0=\"dhcp\"" > /etc/conf.d/net
	cd /etc/init.d
	ln -s net.lo net.eth0
	rc-update add net.eth0 default
	echo "127.0.0.1 tux" > /etc/hosts

	#setup root password


	#setup some tools
	emerge -q app-admin/sysklogd
	rc-update add sysklogd default
	emerge -q sys-process/cronie
	rc-update add cronie default
	emerge -q sys-apps/mlocate
	emerge -q net-misc/dhcpcd
	emerge -q net-wireless/iw net-wireless/wpa_supplicant
	
	if [ $EFI = "false" ]
	then
		#setup boot loader
		emerge -q --verbose sys-boot/grub:2
		grub-install $install_drive
		grub-mkconfig -o /boot/grub/grub.cfg
	fi
	if [ $EFI = "true" ]
	then
		echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf
		emerge -q sys-boot/grub:2
		grub-install --target=x86_64-efi --efi-directory=/boot
		grub-mkconfig -o /boot/grub/grub.cfg
	fi
	
	

fi

