# offline-arch-install-unsquashfs


main() {
    # if [ "$1" = yes ]; then
    #     do_task_this
    # else
    #     do_task_that
    # fi

	read -p "Output Device (default: /dev/sda):" Output_Device
	Output_Device=${Output_Device:-/dev/sda}
	echo $Output_Device
	read -p "Root Password (default: root):" root_password;
	root_password=${root_password:-root}
	echo $root_password
	read -p "User Name (default: user):" user_name;
	user_name=${user_name:-user}
	echo $user_name
	read -p "User Password (default: user):" user_password;
	user_password=${user_password:-user}
	echo $user_password

	createAndMountPartitions $Output_Device;
	#installArchLinuxWithUnsquashfs;
	installArchLinuxWithPacstrap;

	genfstab -U -p /mnt >> /mnt/etc/fstab

arch-chroot /mnt << EOF
echo "Entering chroot"
EOF
arch-chroot /mnt << EOF
pacman -Sy

initPacmanEntropy;

# AREA section OLD2

pacman --noconfirm --needed -S sudo glibc git
search="# %wheel ALL=(ALL) ALL"
replace=" %wheel ALL=(ALL) ALL"
sed -i "s|\$search|\$replace|g" /etc/sudoers;
configureUsers $root_password $user_name $user_password;

installTools $user_name $user_password && # fix without subsequent && script exists after installDesktopEnvironment

pacman --noconfirm -S grub efibootmgr &&
#yes | pacman -S grub efibootmgr os-prober intel-ucode amd-ucode

mkinitcpio -p linux && # when pacstrap used
#mkinitcpio -g /boot/initramfs-linux.img && # when unsquashfs used

# AREA section OLD3

grub-install --target=x86_64-efi --efi-directory=/boot &&
#grub-install --target=x86_64-efi --efi-directory=/efi --boot-directory=/boot
grub-mkconfig -o /boot/grub/grub.cfg &&

writeArchIsoToSeperatePartition;

# AREA section OLD4

exit
EOF

copyWallpapers;
cp -av .config/. "/mnt/home/$user_name/.config"
# createArchISO $user_name $user_password;

#umount /mnt/boot
#umount /mnt -l
#umount -l -R /mnt
#umount -l -R /mnt
#reboot
}

createAndMountPartitions() {
	Output_Device="$1"
	ISO_URL="http://mirrors.evowise.com/archlinux/iso/2021.01.01/archlinux-2021.01.01-x86_64.iso"
	ISO_MB=$( curl -sI $ISO_URL | grep -i Content-Length | grep -o '[0-9]\+' )
	# ISO_MB=$( curl -sI $ISO_URL | grep -i Content-Length | awk '{print $2}' | awk '{print $1/1024/1024 + 1}' )
	ISO_MB=$((ISO_MB/1024/1024 + 10 ))
    #boot arhiso
	#create gpt table
	#create boot swap root partitions
	sfdisk --delete "$Output_Device";
	#wipefs --all "$Output_Device";
	#dd if=/dev/zero of="$Output_Device" bs=512 count=1
	partprobe;
	(echo g; echo n; echo p; echo 1; echo ""; echo +$(echo $ISO_MB)M; echo t; echo 0c; echo n; echo p; echo 2; echo ""; echo +1024M; echo t; echo 2; echo 19; echo n; echo p; echo 3; echo ""; echo +512M; echo t; echo 3; echo 1; echo n; echo p; echo 4; echo ""; echo ""; echo w; echo q) | fdisk $(echo $Output_Device);
	# (echo g; echo n; echo p; echo 1; echo ""; echo +$(echo $ISO_MB)M; echo t; echo 0c; echo n; echo p; echo 2; echo ""; echo +512M; echo t; echo 2; echo 1; echo n; echo p; echo 3; echo ""; echo ""; echo w; echo q) | fdisk $(echo $Output_Device);
	# (echo g; echo n; echo p; echo 1; echo ""; echo +1000M; echo t; echo 0c; echo n; echo p; echo 2; echo ""; echo +512M; echo t; echo 2; echo 1; echo n; echo p; echo 3; echo ""; echo ""; echo w; echo q) | fdisk $(echo $Output_Device);
	isopart=$(echo $Output_Device)1;
	swappart=$(echo $Output_Device)2;

	# (echo g; echo n; echo p; echo 1; echo ""; echo +512M; echo t; echo 1; echo n; echo p; echo 2; echo ""; echo ""; echo w; echo q) | fdisk $(echo $Output_Device); # before without isopart
	#(echo g; echo n; echo p; echo 1; echo ""; echo +512M; echo t; echo 1; echo n; echo p; echo 2; echo ""; echo +512M; echo t; echo 2; echo 38; echo n; echo p; echo 3; echo ""; echo ""; echo w; echo q) | fdisk $(echo $Output_Device);
	efipart=$(echo $Output_Device)3;
	#extbootpart=$(echo $Output_Device)2;
	rootpart=$(echo $Output_Device)4;
	# after ls -l /dev/disk/by-label	found ARCH_202011 (before was user -n EFI) on mount of /dev/sr0 at /run/archiso/bootmnt/arch/boot/syslinux/archiso_sys-linux.cfg
	mkfs.fat -F32 -n ARCH_202011 "$efipart";
	#mksfs.ext4 "$extbootpart";
	mkfs.ext4 -L root "$rootpart";
	mount "$rootpart" /mnt
	mkdir -p /mnt/boot
	#mkdir -p /mnt/efi
	#mount "$efipart" /mnt/efi
	mount "$efipart" /mnt/boot
	#mount "$extbootpart" /mnt/boot
	#get file name from disk and partitions
	mkfs.fat -F32 -n ISO "$isopart";
	mkdir -p /mnt/iso
	mount "$isopart" /mnt/iso
	mkswap "$swappart"
	swapon "$swappart"
} 

writeArchIsoToSeperatePartition() {
	# test
	cd /iso
	wget http://mirrors.evowise.com/archlinux/iso/2021.01.01/archlinux-2021.01.01-x86_64.iso
	# dd if=/dev/sdaX of=/dev/sdbY bs=64K conv=noerror,sync
	# dd if=/archlinux-2021.01.01-x86_64.iso of=/sda1 bs=1M conv=noerror,sync

	cat > temp << EOF
menuentry "Archc Linux OS Live ISO" --class arch {
	set root='(hd0,1)'
	set isofile="/archlinux-2021.01.01-x86_64.iso"
	set dri="free"
	search --no-floppy -f --set=root \$isofile
	probe -u \$root --set=abc
	set pqr="/dev/disk/by-uuid/\$abc"
	loopback loop (hd0,1)\$isofile
	linux  (loop)/arch/boot/x86_64/vmlinuz-linux img_dev=\$pqr img_loop=\$isofile driver=\$dri quiet splash vt.global_cursor_default=0 loglevel=2 rd.systemd.show_status=false rd.udev.log-priority=3 sysrq_always_enabled=1 cow_spacesize=2G
	initrd  (loop)/arch/boot/intel-ucode.img (loop)/arch/boot/amd-ucode.img (loop)/arch/boot/x86_64/initramfs-linux.img
}

EOF

	# these 2 below are first lines in 40_custom file
	# #!/bin/sh
	# exec tail -n +3 $0


	cat temp >> /etc/grub.d/40_custom
	rm temp
	grub-mkconfig -o /boot/grub/grub.cfg
}

createArchISO() {
	# TODO
		# slow boottime
		# boot time reflector message bug, dont wait for network initializng
		# configurations dirs wrong
		# cow_device for persistence
	# end TODO
	user_name="$1"
	user_password="$2"
	sudo pacman --needed -Sw $(pacman -Qqn) # redownload native arch packages for caching
	sudo pacman --noconfirm -S archiso
	mkdir -p archlive
	cp -av /usr/share/archiso/configs/releng/. archlive
	# region copy users passwords
	mkdir -p archlive/airootfs/etc/skel/
	cp /etc/passwd archlive/airootfs/etc/passwd;
	cp /etc/shadow archlive/airootfs/etc/shadow;
	cp /etc/group archlive/airootfs/etc/group;
	cp /etc/gshadow archlive/airootfs/etc/gshadow;
	# end region copy users passwords

	mkdir -p archlive/airootfs/etc/skel/.config
	cp -av i3-seperate-install-config/. archlive/airootfs/etc/skel/.config
	cp -av /home/user/{.bashrc,.zshrc,.vimrc} archlive/airootfs/etc/skel
	ln -s /usr/lib/systemd/system/ly.service archlive/airootfs/etc/systemd/system/display-manager.service
	ln -s /usr/lib/systemd/system/connman.service archlive/airootfs/etc/systemd/system/multi-user.target.wants/connman.service
	ln -s /usr/lib/systemd/system/cornie.service archlive/airootfs/etc/systemd/system/multi-user.target.wants/cornie.service
	mkdir -p archlive/airootfs/usr/bin
	cp -r /usr/bin/morc_menu archlive/airootfs/usr/bin
	mkdir -p archlive/airootfs/usr/share/lite-xl/plugins
	cp -r /usr/share/lite-xl/plugins archlive/airootfs/usr/share/lite-xl/plugins
	cp /etc/systemd/system/paccache.timer archlive/airootfs/etc/systemd/system/paccache.timer
	cp /etc/systemd/journald.conf archlive/airootfs/etc/systemd/journald.conf

	# mkdir -p archlive/airootfs/usr/share/morc_menu
	mkdir -p archlive/airootfs/usr/bin
	cp -r /usr/share/morc_menu archlive/airootfs/usr/share
	cp /usr/bin/morc_menu archlive/airootfs/usr/bin/morc_menu

	cp -r /usr/bin/rofi-power-menu archlive/airootfs/usr/bin/rofi-power-menu

	rm archlive/packages.x86_64
	git clone https://github.com/fuad-ibrahimzade/arch-scripts-data 
	mkdir archiso-files
	cp -av arch-scripts-data/archiso-files/. archiso-files
	rm -rf arch-scripts-data
	cp archiso-files/packages.x86_64 archlive/packages.x86_64
	repo-add archiso-files/customrepo/x86_64/custom.db.tar.gz archiso-files/customrepo/x86_64/*
	sudo mkdir -p /archiso-files/customrepo
	sudo mv archiso-files/customrepo/x86_64 /archiso-files/customrepo/x86_64
	# repo-add archiso-files/customrepo/customrepo.db.tar.gz archiso-files/customrepo/x86_64/*.pkg.tar*
	localIP=$(ip route get 1 | sed -n 's/^.*src \([0-9.]*\) .*$/\1/p')
	cat > temp << EOF
[custom]
SigLevel = Optional TrustAll
Server = file:///archiso-files/customrepo/x86_64
EOF
	cat temp >> archlive/pacman.conf
	mkdir -p ./{out,work}
	mkarchiso -v -w ./work -o ./out archlive

	# region virtualbox share
	pacman --noconfirm --needed -S linux-headers
	pacman --noconfirm --needed -S virtualbox-guest-utils
	systemctl enable now vboxservice.service
	usermod -a -G vboxsf "$user_name"
	
	echo "root ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
	sudo chown -R "$user_name":users /media/sf_Public/ #create shared Public folder inside virtualbox
	head -n -1 /etc/sudoers > temp.txt ; mv temp.txt /etc/sudoers # delete NOPASSWD line
	# end region virtualbox share

}

installArchLinuxWithUnsquashfs() {
    unsquashfs -force -dest /mnt /run/archiso/bootmnt/arch/x86_64/airootfs.sfs
	lynx --source https://raw.githubusercontent.com/archlinux/mkinitcpio/master/mkinitcpio.conf | tr -d '\r' > /mnt/etc/mkinitcpio.conf

	lynx --source larbs.xyz/larbs.sh | tr -d '\r' > /mnt/larbs.sh
	# AREA section OLD1

	cp -L /etc/resolv.conf /mnt/etc  ## this is needed to use networking within the chroot
	#reflector --latest 5 --protocol http --protocol https --sort rate --save /mnt/etc/pacman.d/mirrorlist
	#end new

	#cp /run/archiso/bootmnt/arch/x86_64/vmlinuz /mnt/boot/vmlinuz-linux
	cp /run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux /mnt/boot/vmlinuz-linux

} 

installArchLinuxWithPacstrap() {
	yes '' | pacstrap -i /mnt base linux
	arch-chroot /mnt << EOF
#!/usr/bin/bash
ln -s /usr/share/zoneinfo/Asia/Baku /etc/localtime;
hwclock --systohc;
sed  -i 's/\#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen;
locale-gen;
echo "LANG=en_US.UTF-8" >> /etc/locale.conf;
#yes | pacman -S networkmanager;
sudo pacman -S --noconfirm connman

echo "localhost" >> /etc/hostname;# Replace your-hostname with your value;
echo "127.0.0.1 localhost" >> /etc/hosts;
echo "::1 localhost" >> /etc/hosts;

#systemctl enable NetworkManager.service;
systemctl enable connman.service;
EOF

}

# CHROOT functions

initPacmanEntropy() {
	pacman -S --noconfirm archlinux-keyring
	#echo "keyserver hkp://ipv4.pool.sks-keyservers.net:11371" >> /etc/pacman.d/gnupg/gpg.conf
	#pacman-key --init
	#pacman-key --populate archlinux
	#pacman-key --refresh-keys

	sed -i "s/SigLevel    = Required DatabaseOptional/SigLevel = Never/" /etc/pacman.conf
	pacman -Sy haveged procps-ng --noconfirm
	haveged -w 1024
	pacman-key --init
	pkill haveged
	pacman -Rs haveged procps-ng --noconfirm
	pacman-key --populate archlinux
	#pacman-key --refresh-keys
	sed -i "s/SigLevel = Never/SigLevel = Required DatabaseOptional/" /etc/pacman.conf
	yes | pacman -Rns reflector
	yes | pacman -Sc
	pacman -Syy
	yes | pacman -S reflector
	# useradd -m archie # refloctor pacman problem fix
	ln -s /usr/lib/security/pam_loginuid.so /usr/lib/pam_loginuid.so
	sed -i "s/#TotalDownload/TotalDownload/" /etc/pacman.conf
}

installTools() {
	user_name="$1"
	user_password="$2"
	yes '' | pacman -S base-devel

	echo "$user_name ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
	sudo -u "$user_name" sudo pacman -S --noconfirm rsync curl wget python python-pip pyalpm git;
	head -n -1 /etc/sudoers > temp.txt ; mv temp.txt /etc/sudoers # delete NOPASSWD line

	pacman -S --noconfirm snapper vim nano lynx flameshot iwd trash-cli speedreader uniread fd bpytop micro
	pacman -S --noconfirm cronie
	systemctl enable --now cronie.service
	echo "export EDITOR=nano" >> "/home/$user_name/.bashrc"
	echo "export VISUAL=nano" >> "/home/$user_name/.bashrc"
	echo "export EDITOR=nano" >> $HOME/.bashrc
	echo "export VISUAL=nano" >> $HOME/.bashrc

	cat > temp << EOF
bind -r '\C-s'
stty -ixon
EOF
	cat temp >> $HOME/.bashrc
	cat temp >> "/home/$user_name/.bashrc"
	rm temp
	cat > temp << EOF
inoremap <C-s> <esc>:w<cr>                 " save files
nnoremap <C-s> :w<cr>
inoremap <C-d> <esc>:wq!<cr>               " save and exit
nnoremap <C-d> :wq!<cr>
inoremap <C-q> <esc>:qa!<cr>               " quit discarding changes
nnoremap <C-q> :qa!<cr>
EOF
	cat temp >> $HOME/.vimrc
	cat temp >> "/home/$user_name/.vimrc"
	rm temp

	pacman -S --noconfirm abiword zathura zathura-pdf-mupdf zathura-djvu pulseaudio pavucontrol vlc xorg-xbacklight acpi
	# region TODO remove
	# git clone https://github.com/acaloiaro/di-tui
	# cp di-tui/di-tui /usr/bin/di-tui 
	# chmod a+x /usr/bin/di-tui 
	# dunst
	# parcellite
	# pasystray
	# spacefm-gtk3
	# udiskie
	# https://github.com/GeertJohan/tune
	# https://github.com/carstene1ns/difmplay-mod
	# https://github.com/acaloiaro/di-tui
	# https://gist.github.com/hackruu/6fc318e677b899f99751
	# https://gist.github.com/joepie91/08df1ccf3adb00dbce7c
	# https://github.com/wtheisen/TerminusBrowser
	# https://github.com/khanhas/spicetify-cli
	# qt5ct
	# # Use GTK styles for QT apps
	# # requires qt5-style-plugins to be installed
	# export QT_STYLE_OVERRIDE="gtk2"
	# export QT_QPA_PLATFORMTHEME="gtk2"
	# https://www.reddit.com/r/gnome/comments/jaqave/how_do_i_get_qt_apps_to_use_my_installed_qt_theme/
	# https://wiki.manjaro.org/index.php/Set_all_Qt_app%27s_to_use_GTK%2B_font_%26_theme_settings
	# https://www.linuxuprising.com/2018/05/use-custom-themes-for-qt-applications.html
	# https://github.com/EliverLara/Nordic
	# https://github.com/basigur/papirus-folders
	# https://aur.archlinux.org/packages/papirus-folders-nordic/
	# https://www.reddit.com/r/vim/comments/3tluqr/my_list_of_applications_with_vi_keybindings/
	# https://vim.reversed.top/
	# https://reversed.top/2016-08-13/big-list-of-vim-like-software/
	# https://www.freecodecamp.org/news/a-guide-to-modern-web-development-with-neo-vim-333f7efbf8e2/
	# https://github.com/ChristianChiarulli/nvim
	# QGtkStyle vs QGnomePlatform
	# https://www.reddit.com/r/qutebrowser/comments/cc5vov/dark_mode_in_qutebrowser/
	# :set content.user_stylesheets coolsheet.css
	# https://github.com/Catfriend1/syncthing-android
	# https://github.com/syncthing/syncthing-android
	# https://github.com/classicsc/syncthingmanager
	# https://www.reddit.com/r/qutebrowser/comments/9d4px7/sync_qutebrowser_bookmarks_across_several/
	# https://www.reddit.com/r/qutebrowser/comments/9d4px7/sync_qutebrowser_bookmarks_across_several/
	# https://raw.githubusercontent.com/alphapapa/solarized-everything-css/master/css/solarized-dark/solarized-dark-all-sites.css
	# https://qutebrowser.org/doc/help/commands.html
	# https://raw.githubusercontent.com/qutebrowser/qutebrowser/master/doc/img/cheatsheet-big.png
	# https://qutebrowser.org/doc/install.html#_a_href_https_chocolatey_org_packages_qutebrowser_chocolatey_package_a
	# https://www.howtogeek.com/451262/how-to-use-rclone-to-back-up-to-google-drive-on-linux/
	# https://github.com/alichtman/deadbolt
	# https://github.com/alichtman/malware-techniques
	# https://github.com/alichtman/shallow-backup
	# https://wiki.archlinux.org/index.php/Install_Arch_Linux_on_ZFS
	# https://ramsdenj.com/2016/06/23/arch-linux-on-zfs-part-1-embed-zfs-in-archiso.html
	# https://ramsdenj.com/2016/06/23/arch-linux-on-zfs-part-2-installation.html
	# https://ramsdenj.com/2016/08/29/arch-linux-on-zfs-part-3-followup.html
	# https://github.com/dmeulen/Arch_Root_on_encrypted_ZFS

	# https://ramsdenj.com/2017/06/19/switching-to-nixos-from-arch-linux.html
	# https://www.reddit.com/r/NixOS/comments/jo6lv1/nixos_for_pentesting/
	# https://github.com/Pamplemousse/tangerinixos
	# https://github.com/NixOS/nixpkgs/issues/81418
	# https://discourse.nixos.org/t/proposing-tangerinixos-a-nixos-tailored-for-pentesting/10538/3
	# https://www.trustedsec.com/blog/so-you-got-access-to-a-nix-system-now-what/
	# https://dev.to/trusktr/why-i-moved-from-nixos-to-manjaro-linux-36j2
	# http://www.willghatch.net/blog/2020/06/27/nixos-the-good-the-bad-and-the-ugly/
	# trizen -S --noconfirm wyeb-git nyxt cliqz 

	# https://www.reddit.com/r/archlinux/comments/gyhyhr/is_bubblewrap_a_good_replacement_for_firejail/
	# https://www.reddit.com/r/archlinux/comments/gpqbxc/linuxhardened_lts_zen_with_signed_kernel_modules/
	# https://gitlab.com/madaidan/arch-hardening-script
	# https://thacoon.com/posts/arch-linux-hardened-kernel/
	# https://www.reddit.com/r/privacy/comments/7jdr9m/lineageos_vs_copperheados_vs_replicant/
	# endregion


	#region old aur helper pikaur
	# python -m pip install pikaur
	# touch /etc/profile.d/00-aliases.sh
	# echo "alias pikaur='python -m pikaur'" >> /etc/profile.d/00-aliases.sh 
	# source /etc/profile.d/00-aliases.sh

	# source ~/.bash_aliases.sh
	# . ~/.bash_aliases.sh
	# app_outlet_url=$( curl -s https://api.github.com/repos/app-outlet/app-outlet/releases/latest | grep "browser_download_url.*tar.gz" | cut -d : -f 2,3 | tr -d \" )
	# wget $app_outlet_url
	#installAURpackage pikaur
	#endregion
	installAURpackage trizen
	#region additional tools
	pacman -S --noconfirm thefuck python-pywal nmon atop nethogs net-tools
	installAURpackageTrizen $user_name $user_password netatop;
	# endregion
	installCacheCleanTools  $user_name $user_password;
	installBackupTools  $user_name $user_password;
	
	pacman -S --noconfirm p7zip
	installAURpackageTrizen $user_name $user_password p7zip-gui
	installAURpackageTrizen $user_name $user_password fbcat-git
	installAURpackageTrizen $user_name $user_password bauh;
	installAURpackageTrizen $user_name $user_password lite-xl
	# git clone https://github.com/rxi/lite-plugins	# original lite plugins
	git clone https://github.com/franko/lite-plugins # lite-xl plugins
	mkdir -p /usr/share/lite-xl/plugins
	cp -av lite-plugins/plugins/. /usr/share/lite-xl/plugins
	rm -rf lite-plugins
	installAURpackageTrizen $user_name $user_password vscodium-bin
	pacman --noconfirm -S neofetch
	installAURpackageTrizen $user_name $user_password archey4
	# pacman --noconfirm -S cylon #all in one tool for arch

	installAURpackageTrizen $user_name $user_password slimjet
	#region old debtap slimjet install
	# # wget https://www.slimjetbrowser.com/release/slimjet_amd64.tar.xz
	# # tar -xvf slimjet_amd64.tar.xz
	# wget https://www.slimjetbrowser.com/release/slimjet_amd64.deb
	# installAURpackage debtap
	# # debtap -u slimjet_amd64.deb && pacman -U slimjet_amd64.pkg
	# debtap -U slimjet_amd64.deb
	# rm -rf slimjet_amd64*
	#endregion
	installAURpackageTrizen $user_name $user_password freedownloadmanager

	installFISH $user_name $user_password;
	# installZSH $user_name $user_password;
	installBlackArchRepositories;

	installDesktopEnvironment $user_name $user_password;
	#initScriptAtBoot $user_name $user_password;
	#initScriptAtBoot2;
}

installCacheCleanTools() {
	user_name="$1"
	user_password="$2"
	pacman --noconfirm -S pacman-contrib
	paccache -ruk0
	trizen --noconfirm -Scc --aur
	# pikaur --noconfirm -Scc --aur
	pacman --noconfirm -S bleachbit ncdu rmlint
	# bleachbit -c system.*

	# pacman --noconfirm -S qt5-tools qt5-charts python-pyqt5-chart && installAURpackage stacer
	installAURpackageTrizen $user_name $user_password stacer;
	installAURpackageTrizen $user_name $user_password wat-git # Show upgrades since recent -Syu
	# pacman -R --noconfirm $(pacman -Qtdq)
	# du -sh /var/cache

	cat > /etc/systemd/system/paccache.timer << EOF
[Unit]
Description=Clean-up old pacman pkg cache

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=multi-user.target
EOF
	systemctl enable paccache.timer
	
	search="#SystemMaxUse="
	replace="SystemMaxUse=50M"
	sed -i "s|\\$search|\\$replace|g" /etc/systemd/journald.conf;
	systemctl restart systemd-journald

	rm -rf $HOME/.cache/*

	# sudo pacman -Rsn $(pacman -Qdtq)
	# sudo pacman -Rns --noconfirm $(pacman -Qdtq) # removes all unneeded packages, but leaves optional dependencies
	# sudo pacman -Rns --noconfirm $(pacman -Qdttq) # removes all unneeded packages AND optional dependencies as well
}

installBackupTools() {
	user_name="$1"
	user_password="$2"
	pacman --noconfirm -S sparkleshare
	# git clone https://github.com/hbons/Dazzle
}

installDesktopEnvironment() {
	user_name="$1"
	user_password="$2"

	pacman --noconfirm -S archlinux-wallpaper
	installi3Only $user_name $user_password;
	# installLxqtTiling $user_name $user_password;
	# installDEmaterialshell
	# installDEkwin
	# installDEregolith $user_name

	#installDEi3ecly $user_name $user_password
	# installDEsway $user_name $user_password
	# installDEarchi3linux
}

installDEmaterialshell() {
	# sudo pacman -S gnome
	pacman --noconfirm -S gnome-shell gnome-terminal gnome-tweaks gnome-control-center gnome-shell-extensions gdm
	systemctl enable gdm.service
	# python -m pikaur --noconfirm -S gnome-shell-extension-material-shell
	installAURpackage gnome-shell-extension-material-shell
	gnome-extensions enable material-shell@papyelgringo
}

installLxqtTiling() {
	user_name="$1"
	user_password="$2"
	pacman --noconfirm -Syu 
	pacman --noconfirm -S xorg xorg-xinit lxqt breeze-icons kvantum-qt5 pcmanfm-qt krusader 

	pacman -S --needed xdg-utils ttf-freefont ttf-dejavu
	# oxygen-icons
	pacman -S --noconfirm --needed libpulse libstatgrab libsysstat lm_sensors pavucontrol-qt
	# network-manager-applet
	# systemctl enable NetworkManager
	# installAURpackageTrizen $user_name $user_password lxqt-connman-applet
	pacman -S --noconfirm cmst
	systemctl enable connman.service

	# pacman --noconfirm -S sddm
	# git clone https://github.com/mikkeloscar/sddm-gracilis-theme.git
	# mkdir -p /usr/share/sddm/themes
	# mv sddm-gracilis-theme /usr/share/sddm/themes
	# sddm --example-config | tee /etc/sddm.conf
	# search="Current="
	# replace="Current=sddm-gracilis-theme"
	# sed -i "s|\\$search|\\$replace|g" /etc/sddm.conf;
	# systemctl enable sddm.service
	installAURpackageTrizen $user_name $user_password ly-git;
	systemctl enable ly.service

	installi3Seperate $user_name $user_password;
	# installZentile;
}

installi3Only() {
	user_name="$1"
	user_password="$2"
	pacman --noconfirm --needed -S archlinux-wallpaper
	pacman --noconfirm -Syu 
	pacman --noconfirm -S xorg xorg-xinit krusader kitty
	pacman --noconfirm --needed -S xdg-utils ttf-freefont ttf-dejavu
	pacman -S --noconfirm cmst
	systemctl enable connman.service
	installAURpackageTrizen $user_name $user_password ly-git;
	systemctl enable ly.service
	installi3Seperate $user_name $user_password;
}

installi3Seperate() {
	user_name="$1"
	user_password="$2"
	pacman --noconfirm -S i3-gaps ranger rofi vifm
	mkdir -p "/home/$user_name/.config/i3"
	lynx --source https://gist.githubusercontent.com/fuad-ibrahimzade/266441c50e94ba9c8cecbfbdabcf0595/raw | tr -d '\r' > "/home/$user_name/.config/i3/config"
	head -n -3 "/home/$user_name/.config/i3/config" > temp.txt ; mv temp.txt "/home/$user_name/.config/i3/config" # delete bar lines
	echo "gaps inner 15" >> "/home/$user_name/.config/i3/config";
	echo "bindsym $mod+Shift+m move scratchpad" >> "/home/$user_name/.config/i3/config";
	echo "bindsym $mod+m scratchpad show, floating disable" >> "/home/$user_name/.config/i3/config";
	pacman --noconfirm --needed -S flameshot
	echo "bindsym Print exec flameshot gui" >> "/home/$user_name/.config/i3/config";
	pacman --noconfirm --needed -S npm
	sudo npm i -g i3-cycle-focus
	echo "bindsym Mod1+Tab       exec --no-startup-id i3-cycle-focus" >> "/home/$user_name/.config/i3/config";
	echo "bindsym Mod1+Shift+Tab exec --no-startup-id i3-cycle-focus --reverse" >> "/home/$user_name/.config/i3/config";
	#installAURpackageTrizen rofi-dmenu
	# search="bindsym \$mod+d exec --no-startup-id dmenu_run"
	# search="bindsym \$mod+d exec dmenu_run"
	# # replace="bindsym \$super+d exec rofi -lines 12 -padding 18 -width 60 -location 0 -show drun -sidebar-mode -columns 3 -font 'Noto Sans 8'"
	# replace="bindsym \$mod+d exec rofi -show drun -show-icons -modi drun"
	# sed -i "s|\\$search|\\$replace|g" "/home/$user_name/.config/i3/config";
	sed -i 's|bindsym $mod+d exec dmenu_run|bindsym $mod+d exec rofi -show drun -show-icons -modi drun|g' "/home/$user_name/.config/i3/config";
	pacman --noconfirm --needed -S xcompmgr feh
	# picom vs xcompmgr
	installAURpackageTrizen $user_name $user_password quickswitch-i3
	installAURpackageTrizen $user_name $user_password wmfocus;

	pacman --noconfirm -S dmenu
	installGitHubMakepackage "morc_menu" "https://github.com/Boruch-Baum/morc_menu"
	echo "bindsym \$mod+z exec morc_menu" >> "/home/$user_name/.config/i3/config"

	pacman --noconfirm -S jgmenu
	echo "bindsym \$mod+Shift+z exec jgmenu_run" >> "/home/$user_name/.config/i3/config"

	pacman -S --noconfirm tint2
	mkdir -p "/home/$user_name/.config/tint2"
	cp /usr/share/tint2/horizontal-dark-opaque.tint2rc >> "/home/$user_name/.config/tint2/tint2rc";
	echo "exec --no-startup-id tint2 /home/$user_name/.config/tint2/tint2rc" >> "/home/$user_name/.config/i3/config";
	# echo "exec --no-startup-id tint2 --disable-wm-check /home/$user_name/.config/tint2/tint2rc" >> "/home/$user_name/.config/i3/config";

	git clone https://github.com/jluttine/rofi-power-menu
	search="loginctl terminate-session \${XDG_SESSION_ID-}"
	replace="pkill X"
	sed -i "s|\$search|\$replace|g" rofi-power-menu/rofi-power-menu
	installAURpackageTrizen $user_name $user_password i3lock-fancy-git
	cat > temp << EOF
#!/bin/bash
pkill rofi
i3lock-fancy
EOF
	cat temp >> "/usr/bin/i3fancy-locker.sh"
	rm temp
	search="loginctl lock-session \${XDG_SESSION_ID-}"
	replace="sh /usr/bin/i3fancy-locker.sh"
	sed -i "s|\$search|\$replace|g" rofi-power-menu/rofi-power-menu
	cp -av rofi-power-menu/. /usr/bin
	echo "bindsym \$mod+Shift+p exec rofi -show power-menu -modi power-menu:rofi-power-menu" >> "/home/$user_name/.config/i3/config";
	rm -rf rofi-power-menu

	# pacman -S --noconfirm ttf-fira-code otf-font-awesome
	# installAURpackageTrizen $user_name $user_password nerd-fonts-fira-code
	# # installAURpackageTrizen $user_name $user_password otf-nerd-fonts-fira-code

	# initCronScriptAtBootForWallpaper $user_name $user_password;
	# echo "feh --bg-fill /usr/share/backgrounds/archlinux/1403423502665.png" >> /usr/bin/wallpaper-script.sh
	# echo "nohup xcompmgr -o 0.7 &>/dev/null &" >>  /usr/bin/transparency-script.sh
	# sudo chmod 755 /usr/bin/wallpaper-script.sh
	# sudo chmod 755 /usr/bin/transparency-script.sh
	#chmod u+x /usr/bin/wallpaper-script.sh
	mkdir -p "/home/$user_name/.config/autostart"
	# mkdir -p "/home/$user_name/.config/lxqt"
	# echo "window_manager=i3" >> "/home/$user_name/.config/lxqt/session.conf"
	# echo "TERMINAL=urxvt" >> "/home/$user_name/.config/lxqt/session.conf"
	cat > "/home/$user_name/.config/autostart/i3related.desktop" << EOF
[Desktop Entry]
Exec=feh --bg-fill /usr/share/backgrounds/archlinux/1403423502665.png && xcompmgr -o 0.7 &
OnlyShowIn=LXQt
Name=i3related
Type=Application
Version=1.0
EOF

	# Kitty terminal - one dark theme
	mkdir -p "/home/$user_name/.config/kitty"
	https://gist.githubusercontent.com/ggsalas/29ba32e71e313b384d1a887250cd102a/raw/d84f37b1e341c72de5ea4849309bf2b1e084a173/kitty.conf | tr -d '\r' > "/home/$user_name/.config/kitty/kitty.conf"

	git clone https://github.com/fuad-ibrahimzade/arch-scripts
	cp -av arch-scripts/i3-seperate-install-config/. "/home/$user_name/.config"
	rm -rf arch-scripts

	echo "root ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
	sudo chown -R "$user_name" "/home/$user_name/.config"
	head -n -1 /etc/sudoers > temp.txt ; mv temp.txt /etc/sudoers # delete NOPASSWD line
	
}

installZentile() {
	download_url=$( curl -s https://api.github.com/repos/blrsn/zentile/releases/latest | grep "browser_download_url.*zentile_linux_amd64" | cut -d : -f 2,3 | tr -d \" )
	wget $download_url
	mv zentile_linux_amd64 /usr/bin/zentile_linux_amd64

	# chmod a+x zentile_linux_amd64
	# ./zentile_linux_amd64

	cat > /etc/systemd/system/openbox-tiling.service << EOF
[Unit]
Description=Openbox tiling script
[Service]
Type=forking
ExecStart=/usr/bin/zentile_linux_amd64
KillMode=proces
TimeoutSec=infinity
[Install]
WantedBy=multi-user.target 
EOF
	sudo chmod 755 /usr/bin/zentile_linux_amd64
	#chmod u+x /usr/bin/temp-script.sh
	chmod a+x /usr/bin/zentile_linux_amd64
	sudo systemctl enable openbox-tiling.service;

	# Default Keybinding	Description
	# Ctrl+Shift+t	Tile current workspace
	# Ctrl+Shift+u	Untile current workspace
	# Ctrl+Shift+s	Cycle through layouts
	# Ctrl+Shift+n	Goto next window
	# Ctrl+Shift+p	Goto previous window
	# Ctrl+]	Increase size of master windows
	# Ctrl+[	Decrease size of master windows
	# Ctrl+Shift+i	Increment number of master windows
	# Ctrl+Shift+d	Decrement number of master windows
}

installDEkwin() {
	# sudo pacman -S plasma
	# pacman --noconfirm -S kwin konsole systemsettings
	pacman --noconfirm -S xorg xorg-xinit
	# pacman --noconfirm -S lightdm lightdm-gtk-greeter
	# systemctl enable lightdm.service
	installAURpackage lxqt-kwin-desktop-git
	#installAURpackage kwin-scripts-quarter-tiling-git
	installAURpackage kwin-scripts-tiling
	installAURpackage lxqt-less-theme-git
	# adwaita-icon-theme ttf-freefont 
	pacman --noconfirm -S kvantum-qt5 krusader
	# pacman --noconfirm -S breeze-icons
	# wget https://download.fman.io/fman.pkg.tar.xz

	# sudo pacman -S --needed xorg
	# sudo pacman -S --needed lxqt xdg-utils ttf-freefont sddm
	# sudo pacman -S --needed libpulse libstatgrab libsysstat lm_sensors network-manager-applet oxygen-icons pavucontrol-qt
	# sudo pacman -S --needed firefox vlc filezilla leafpad xscreensaver archlinux-wallpaper
	# systemctl enable sddm
	# systemctl enable NetworkManager

	pacman --noconfirm -S sddm
	git clone https://github.com/mikkeloscar/sddm-gracilis-theme.git
	mkdir -p /usr/share/sddm/themes
	cp -av sddm-gracilis-theme/. /usr/share/sddm/themes/
	sddm --example-config | tee /etc/sddm.conf
	echo "CurrentTheme=sddm-gracilis-theme" >> /etc/sddm.conf
	systemctl enable sddm.service
	# git clone https://github.com/kwin-scripts/kwin-tiling.git
	# cd kwin-tiling/
	# plasmapkg2 --type kwinscript -i .
	# kcmshell5 kwinscripts
}

installDEregolith() {
	user_name="$1"
	mkdir /tmp/regolithtmp
	cd /tmp/regolithtmp
	wget https://github.com/gardotd426/regolith-de/releases/latest/download/regolith-arch.zip
	pacman -S --noconfirm unzip
	unzip regolith-arch
	sudo pacman -U *.pkg.tar
	cd ..
	rm -rf /tmp/regolithtmp
	pacman -Sy xorg xorg-xinit
	installAURpackage ly-git
	systemctl enable ly.service
	#echo 'exec regolith-session' >> /${HOME}/.xinitrc
	#echo 'exec regolith-session' >> "/home/$user_name/.xinitrc"

}

installDEi3ecly() {
	user_name="$1"
	user_password="$2"
	installAURpackage "ly-git"
	# installAURpackage "trizen"
	# installAURpackage "paru"
	# installAURpackage "yay"
	sh -c 'systemctl enable ly.service'
	echo "$user_password" | sudo -S -u "$user_name" mkdir -p "/home/$user_name"
	echo "$user_password" | sudo -S -u "$user_name" git clone https://github.com/ecly/dotfiles.git
	echo "$user_password" | sudo -S -u "$user_name" cp -av dotfiles/. "/home/$user_name"

	installAURpackage zsh;
	installAURpackage zsh-completions ;
	installAURpackage zsh-syntax-highlighting ;
	installAURpackage zsh-autosuggestions ;
	installAURpackage python-pip ;
	installAURpackage python-jedi ;
	installAURpackage tmux ;
	installAURpackage i3-gaps ;
	installAURpackage polybar ;
	installAURpackage rofi ;
	installAURpackage neovim ;
	installAURpackage nodejs-neovim ;
	installAURpackage ruby-neovim ;
	installAURpackage python2-pynvim ;
	installAURpackage neovim-remote ;
	installAURpackage dunst ;
	installAURpackage ranger ;
	installAURpackage mpv ;
	installAURpackage neomutt ;
	installAURpackage i3lock ;
	installAURpackage xss-lock ;
	installAURpackage maim ;
	installAURpackage sxiv ;
	installAURpackage firefox ;
	installAURpackage pulseaudio ;
	installAURpackage pulseaudio-alsa ;
	installAURpackage pulsemixer ;
	installAURpackage gotop ;
	installAURpackage networkmanager ;
	installAURpackage w3m ;
	installAURpackage urlscan ;
	installAURpackage xclip ;
	installAURpackage imagemagick ;
	installAURpackage gnupg ;
	installAURpackage noto-fonts ;
	installAURpackage terminus-font-ttf ;
	installAURpackage nerd-fonts-terminus ;
	installAURpackage highlight ;
	installAURpackage ffmpegthumbnailer ;
	installAURpackage redshift ;
	installAURpackage fzf ;
	installAURpackage ripgrep ;
	installAURpackage tmuxinator ;
	installAURpackage xbanish ;
	installAURpackage xorg ;
	installAURpackage xorg-xinit ;
	installAURpackage openssh ;
	installAURpackage bitwarden-bin ;
	installAURpackage fd ;
	installAURpackage kbdlight ;
	installAURpackage elixir ;
	installAURpackage mullvad-vpn-bin ;
	installAURpackage ntp ;
	installAURpackage rxvt-unicode-truecolor ;
	installAURpackage alacritty ;
	installAURpackage fd ;
	installAURpackage zathura ;
	installAURpackage zathura-pdf-mupdf ;
	installAURpackage libreoffice ;
	installAURpackage wget ;
	installAURpackage zip ;
	installAURpackage unzip ;
	installAURpackage texlive-most ;
	installAURpackage biber ;
	installAURpackage texlive-lang ;
	installAURpackage npm ;
	installAURpackage yarn ;
	installAURpackage nm-connection-editor ;
	installAURpackage ctags ;
	installAURpackage oh-my-zsh-git ;
	installAURpackage git-delta-bin ;
	installAURpackage xdotool ;
	installAURpackage mons ;
	installAURpackage sc-im ;
	installAURpackage ctop-bin


	# Handle Python specific installs with pipx
	python -m pip install pipx --user
	python -m pipx install python-language-server
	python -m pipx install poetry
	python -m pipx install black
	python -m pipx install isort
	python -m pipx install pywal
	python -m pipx install vint
	python -m pipx install jupyterlab

	# Install npm specific packages
	npm install -g bash-language-server
	npm install -g vim-language-server
	npm install -g dockerfile-language-server-nodejs
	npm install -g yaml-language-server

	# apply theme
	wal --theme base16-gruvbox-hard

	# start network manager
	systemctl enable NetworkManager

	# ensure time is correct
	timedatectl set-ntp true

	# additional optional setup
	if [ -e "$1" ]; then
		# setup postgres for development
		installAURpackage 	postgresql ;
		installAURpackage 	spotify ;
		installAURpackage 	noto-fonts-cjk ;
		installAURpackage 	dbeaver

		runuser -l postgres -c 'initdb -D /var/lib/postgres/data'
		systemctl enable postgresql
	fi
}

installDEsway() {
	user_name="$1"
	user_password="$2"
	python -m pip install pywal
	yes | pacman -S kitty rofi zsh ttf-fira-code otf-font-awesome swaylock mako
	yes | pacman -S weston
	#python -m pikaur --noconfirm -S sway-git waybar-git nerd-fonts-fira-code
	yes '' | pacman -S sway waybar
	#python -m pikaur --noconfirm -S ly-git;
	#installAURpackage "sway-git"
	#installAURpackage "waybar-git"
	installAURpackage "ly-git"
	# installAURpackage "trizen"
	# installAURpackage "paru"
	# installAURpackage "yay"
	sh -c 'systemctl enable ly.service'
	echo "$user_password" | sudo -S -u "$user_name" mkdir -p "/home/$user_name"
	echo "$user_password" | sudo -S -u "$user_name" git clone https://github.com/coredotbin/dotfiles.git
	echo "$user_password" | sudo -S -u "$user_name" cp -av dotfiles/. "/home/$user_name"
	rm -rf dotfiles
}

installDEarchi3linux() {
	#yes | pacman -S zsh
	#echo "[archi3linux]" >> /etc/pacman.conf
	#echo "SigLevel = Optional TrustAll" >> /etc/pacman.conf
	#echo "Server = https://archi3linux.org/repo/x86_64" >> /etc/pacman.conf
	#useradd -mU -s /usr/bin/zsh -G wheel,uucp,sys,users user2
	#echo "user2:user2" | chpasswd
	#yes "'' y" | pacman -Sy archi3linux
	echo "installDEarchi3linux"
}

installFISH(){
	user_name="$1"
	user_password="$2"
	pacman --noconfirm -S pkgfile
	pkgfile -u
	pacman --noconfirm -S fish
	# echo "$user_name ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
	# echo "root ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
	# sudo chsh -s $(which fish)
	# sudo chsh -s /bin/fish
	# sudo -u "$user_name" chsh -s /bin/fish
	usermod --shell /usr/bin/fish root
	usermod --shell /usr/bin/fish user
	fish_update_completions
	# head -n -2 /etc/sudoers > temp.txt ; mv temp.txt /etc/sudoers # delete NOPASSWD lines
	cat > temp << EOF
set -g -x fish_greeting ''
### "vim" as manpager
set -x MANPAGER '/bin/bash -c "vim -MRn -c \"set buftype=nofile showtabline=0 ft=man ts=8 nomod nolist norelativenumber nonu noma\" -c \"normal L\" -c \"nmap q :qa<CR>\"</dev/tty <(col -b)"'

### "nvim" as manpager
# set -x MANPAGER "nvim -c 'set ft=man' -"
EOF
	mkdir -p "/home/$user_name/.config/fish/"
	cat temp >> "/home/$user_name/.config/fish/config.fish"
	rm temp

	# echo "$user_name ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
	# sudo -u "$user_name" python -m pip install powerline
	# head -n -1 /etc/sudoers > temp.txt ; mv temp.txt /etc/sudoers # delete NOPASSWD line
	# /usr/bin/fish set -U fish_user_paths $fish_user_paths "/home/$user_name/.local/bin" # for adding path
	# /usr/bin/fish echo $fish_user_paths | tr " " "\n" | nl # for gettint line number
	# /usr/bin/fish set --erase --universal fish_user_paths[5] # for removing sppecific path
	installAURpackageTrizen $user_name $user_password ttf-meslo-nerd-font-powerlevel10k
	installAURpackageTrizen $user_name $user_password fisher
	echo "$user_name ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
	sudo -u "$user_name" fisher install IlanCosman/tide
	sudo -u "$user_name" fisher install jorgebucaran/gitio.fish
	head -n -1 /etc/sudoers > temp.txt ; mv temp.txt /etc/sudoers # delete NOPASSWD line

	installAURpackageTrizen $user_name $user_password bass-fish
}

installZSH() {
	user_name="$1"
	user_password="$2"
	pacman --noconfirm -S zsh zsh-completions
	pacman --noconfirm --needed -S xorg-font-util fontconfig
	installAURpackageTrizen $user_name $user_password ttf-meslo-nerd-font-powerlevel10k;
	# installAURpackageTrizen $user_name $user_password oh-my-zsh-git;

	chsh -s $(which zsh)
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

	mkdir ~/.local/share/fonts
	cd  ~/.local/share/fonts
	wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
	wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf
	wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf
	wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf
	fc-cache -f -v

	git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
	sed -i 's/robbyrussell/powerlevel10k\/powerlevel10k/g' ~/.zshrc

	git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
	git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting


	# 	cat > temp << EOF
	# plugins=(
	# 	zsh-autosuggestions 
	# 	zsh-syntax-highlighting
	# )
	# EOF
	# 	cat temp >> $HOME/.zshrc
	# 	rm temp

	search="plugins=(git)"
	replace="plugins=(git zsh-autosuggestions zsh-syntax-highlighting)"
	sed -i "s|\$search|\$replace|g" $HOME/.zshrc

	echo "$user_name ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
	echo "$user_password" | sudo -S -u "$user_name" /bin/bash -c '
		sudo chsh -s $(which zsh)
		sudo sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

		sudo mkdir ~/.local/share/fonts
		cd  ~/.local/share/fonts
		sudo wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
		sudo wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf
		sudo wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf
		sudo wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf
		sudo fc-cache -f -v

		sudo git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
		sudo sed -i "s/robbyrussell/powerlevel10k\/powerlevel10k/g" ~/.zshrc

		sudo git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
		sudo git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
	
		search="plugins=(git)"
		replace="plugins=(git zsh-autosuggestions zsh-syntax-highlighting)"
		sudo sed -i "s|\\$search|\\$replace|g" $HOME/.zshrc
	'
	head -n -1 /etc/sudoers > temp.txt ; mv temp.txt /etc/sudoers # delete NOPASSWD line
	
	# ln -s /root/.oh-my-zsh "/home/$user_name/.oh-my-zsh"
	# ln -s /root/.zshrc "/home/$user_name/.zshrc"
}

installBlackArchRepositories() {
	# Run https://blackarch.org/strap.sh as root and follow the instructions.

	curl -O https://blackarch.org/strap.sh
	# Verify the SHA1 sum

	echo d062038042c5f141755ea39dbd615e6ff9e23121 strap.sh | sha1sum -c
	# Set execute bit

	chmod +x strap.sh
	# Run strap.sh

	sudo ./strap.sh
	# Enable multilib following https://wiki.archlinux.org/index.php/Official_repositories#Enabling_multilib and run:

	sed -z -i "s|\#\[multilib\]\n#Include = /etc/pacman.d/mirrorlist|\[multilib\]\nInclude = /etc/pacman.d/mirrorlist|g" /etc/pacman.conf;

	sudo pacman -Syyu

	################
	# USAGE:
	################
	# To list all of the available tools, run

	# sudo pacman -Sgg | grep blackarch | cut -d' ' -f2 | sort -u
	# # To install all of the tools, run

	# sudo pacman -S blackarch
	# # To install a category of tools, run

	# sudo pacman -S blackarch-<category>
	# # To see the blackarch categories, run

	# sudo pacman -Sg | grep blackarch
	# # Note - it maybe be necessary to overwrite certain packages when installing blackarch tools. If
	# # you experience "failed to commit transaction" errors, use the --needed and --overwrite switches
	# # For example:

	# sudo pacman -Syyu --needed blackarch --overwrite='*'

	################
	# alternative method:
	################
	# First, you must install blackman. If the BlackArch package repository is setup on your machine,
	# you can install blackman like:

	# sudo pacman -S blackman
	# # Download, compile and install package:

	# sudo blackman -i <package>
	# # Download, compile and install whole category

	# sudo blackman -g <group>
	# # Download, compile and install all BlackArch tools

	# sudo blackman -a
	# # To list blackarch categories

	# blackman -l
	# # To list category tools

	# blackman -p <category>
}

#pacman -Syy
#pacman --noconfirm -S git

getLatestYAY() {
	curl -s https://api.github.com/repos/Jguer/yay/releases/latest \
	| grep "browser_download_url.*deb" \
	| cut -d : -f 2,3 \
	| tr -d \" \
	| wget -qi -
}

installGitHubMakepackage() {
	#usermod --append --groups wheel nobody
	usermod -aG wheel nobody
	echo "root ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers

	packageName="$1"
	githubUrl="$2"
	echo "Packaga name is ${packageName}"
	cd /tmp
	sudo -u nobody git clone "${githubUrl}"

	chgrp nobody "/tmp/$packageName"
	chmod g+ws "/tmp/$packageName"
	setfacl -m u::rwx,g::rwx "/tmp/$packageName"
	setfacl -d --set u::rwx,g::rwx,o::- "/tmp/$packageName"

	cd "/tmp/$packageName"
	nobody_password=$( cat /etc/shadow | grep nobody | sed 's/[^a-zA-Z0-9]//g' | sed 's/[nobody]//g' )
	nobody_password=${nobody_password:-18628}

	echo "nobody:${nobody_password}" | chpasswd
	#yes | sudo -S -u nobody makepkg -scri
	yes | sudo -S -u root make install
	# yes | sudo -S -u nobody makepkg -sdfcri
	# yes | sudo -S -u nobody makepkg -sd
	# build_file=$( ls | grep ".tar." )
	# #pacman -U *.tar.xz
	# yes | pacman -U "$build_file"
	cd ..
	rm -rf "/tmp/${packageName}"

	head -n -1 /etc/sudoers > temp.txt ; mv temp.txt /etc/sudoers # delete NOPASSWD line
	gpasswd -d nobody wheel
}

installAURpackage() {
	#usermod --append --groups wheel nobody
	usermod -aG wheel nobody
	echo "nobody ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers

	packageName="$1"
	echo "Packaga name is ${packageName}"
	cd /tmp
	sudo -u nobody git clone "https://aur.archlinux.org/${packageName}.git"

	chgrp nobody "/tmp/$packageName"
	chmod g+ws "/tmp/$packageName"
	setfacl -m u::rwx,g::rwx "/tmp/$packageName"
	setfacl -d --set u::rwx,g::rwx,o::- "/tmp/$packageName"

	cd "/tmp/$packageName"
	nobody_password=$( cat /etc/shadow | grep nobody | sed 's/[^a-zA-Z0-9]//g' | sed 's/[nobody]//g' )
	nobody_password=${nobody_password:-18628}

	echo "nobody:${nobody_password}" | chpasswd
	#yes | sudo -S -u nobody makepkg -scri
	yes | sudo -S -u nobody makepkg -sdfcri
	# yes | sudo -S -u nobody makepkg -sd
	# build_file=$( ls | grep ".tar." )
	# #pacman -U *.tar.xz
	# yes | pacman -U "$build_file"
	cd ..
	rm -rf "/tmp/${packageName}"

	head -n -1 /etc/sudoers > temp.txt ; mv temp.txt /etc/sudoers # delete NOPASSWD line
	gpasswd -d nobody wheel
}

installAURpackageTrizen() {
	user_name="$1"
	user_password="$2"
	packageName="$3"
	

	sed -z -i "s|\#\[multilib\]\n#Include = /etc/pacman.d/mirrorlist|\[multilib\]\nInclude = /etc/pacman.d/mirrorlist|g" /etc/pacman.conf;
	sudo pacman -Syyu

	echo "$user_name ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
	rm -rf /tmp/*
	umount -l -R /tmp
	sudo -u "$user_name" trizen --noconfirm -S "$packageName"
	sudo -u "$user_name" trizen --noconfirm -Scc --aur
	# paccache -ruk0
	# sudo pacman -Rns --noconfirm $(pacman -Qdttq)
	
	# ye 'n' | sudo -S -u "$user_name" trizen -Rcuns $(pacman -Qqdt)
	# yes 'n' | sudo -S -u "$user_name" pacman -Rcuns $(pacman -Qqdt)
	head -n -1 /etc/sudoers > temp.txt ; mv temp.txt /etc/sudoers # delete NOPASSWD line
}

configureUsers() {
	root_password="$1"
	user_name="$2"
	user_password="$3"

	#uncomment wheel group in sudoers dont work here so it is before call

	userdel live
	rm -rf /home/live

	#useradd -m user
	groupadd "$user_name"
	useradd -m -g "$user_name" -G users,wheel,storage,power,network -s /bin/bash -c "Arch Qaqa" "$user_name"
	echo "${user_name}:${user_password}" | chpasswd;

	#echo "user:user" | chpasswd
	#echo "root:root" | chpasswd
	echo "root:${root_password}" | chpasswd
}

initCronScriptAtBootForWallpaper() {
	user_name="$1"
	user_password="$2"
	# @reboot  /home/user/test.sh
	
	# echo '~/.fehbg &' >> /${HOME}/.xinitrc
	# echo '~/.fehbg &' >> "/home/$user_name/.xinitrc"

	crontab -l > mycron
	#echo new cron into cron file
	echo "@reboot feh --bg-fill /usr/share/backgrounds/archlinux/1403423502665.png" >> mycron
	echo "@reboot xcompmgr -o 0.7 &" >> mycron
	#install new cron file
	crontab mycron
	rm mycron
}

initScriptAtBoot2() {

	cat > /usr/bin/temp-script.sh << EOF
#!/usr/bin/bash
# sleep 60 # one min
sleep 6
installAURpackage() {
	#usermod --append --groups wheel nobody
	usermod -aG wheel nobody

	nobody_password=\$( cat /etc/shadow | grep nobody | sed 's/[^a-zA-Z0-9]//g' | sed 's/[nobody]//g' )
	nobody_password=\${nobody_password:-18628}

	packageName="\$1"
	echo "Packaga name is \${packageName}"
	cd /tmp
	sudo -u nobody git clone "https://aur.archlinux.org/\${packageName}.git"

	chgrp nobody "/tmp/\$packageName"
	chmod g+ws "/tmp/\$packageName"
	setfacl -m u::rwx,g::rwx "/tmp/\$packageName"
	setfacl -d --set u::rwx,g::rwx,o::- "/tmp/\$packageName"

	cd "/tmp/\$packageName"

	#echo "nobody:\${nobody_password}" | chpasswd
	#yes | sudo -S -u nobody makepkg -scri
	yes | sudo -S -u nobody makepkg -sd
	build_file=\$( ls | grep ".tar." )
	#pacman -U *.tar.xz
	yes | pacman -U "\$build_file"
	cd ..
	rm -rf "/tmp/\${packageName}"

	gpasswd -d nobody wheel
}
#installAURpackage "ly-git";
#installAURpackage "sway-git";
#installAURpackage "waybar-git";
yes | pacman -Runs sway waybar;
python -m pikaur --noconfirm -S ly-git sway-git waybar-git;
#echo "user" | sudo -u user yay --noconfirm --sudoflags "-S" -S ly-git sway-git waybar-git; #working
systemctl enable ly.service;

# systemctl stop temp-script.service
# systemctl disable temp-script.service
# rm /etc/systemd/system/temp-script.service
# rm /etc/systemd/system/temp-script.service # and symlinks that might be related
# rm /usr/lib/systemd/system/temp-script.service 
# rm /usr/lib/systemd/system/temp-script.service # and symlinks that might be related
# systemctl daemon-reload
# systemctl reset-failed
# rm /usr/bin/temp-script.sh
reboot
EOF
	cat > /etc/systemd/system/temp-script.service << EOF
[Unit]
Description=My temp script
[Service]
Type=forking
ExecStart=/bin/bash /usr/bin/temp-script.sh
KillMode=proces
TimeoutSec=infinity
[Install]
WantedBy=multi-user.target 
EOF
	sudo chmod 755 /usr/bin/temp-script.sh
	#chmod u+x /usr/bin/temp-script.sh
	sudo systemctl enable temp-script.service
}

initScriptAtBoot() {
	user_name="$1"
	user_password="$2"
	cat > /usr/bin/temp-script.sh << EOF
#!/usr/bin/bash
sleep 60 # one min
echo "$user_password" | sudo -S -u "$user_name" /bin/bash -c '
		python -m pikaur --noconfirm -S ly-git;
		systemctl enable ly.service
		#mkdir -p ${HOME}/Downloads/build && cd $_
		# mkdir -p /home/"$user_name"/Downloads/build && cd $_
		python -m pikaur --noconfirm -S sway-git waybar-git
		
		# systemctl stop temp-script.service
		# systemctl disable temp-script.service
		# rm /etc/systemd/system/temp-script.service
		# rm /etc/systemd/system/temp-script.service # and symlinks that might be related
		# rm /usr/lib/systemd/system/temp-script.service 
		# rm /usr/lib/systemd/system/temp-script.service # and symlinks that might be related
		systemctl daemon-reload
		systemctl reset-failed
		# rm /usr/bin/temp-script.sh
		touch /tmp/bootrun_happened
		#rm ${HOME}/Downloads/build
		# rm -rf /home/"$user_name"/Downloads/build
	'
EOF
	cat > /etc/systemd/system/temp-script.service << EOF
[Unit]
Description=My temp script
[Service]
Type=forking
ExecStart=/bin/bash /usr/bin/temp-script.sh
KillMode=proces
[Install]
WantedBy=multi-user.target 
EOF
	sudo chmod 755 /usr/bin/temp-script.sh
	#chmod u+x /usr/bin/temp-script.sh
	sudo systemctl enable temp-script.service
}

copyWallpapers() {
	mkdir -p /mnt/usr/share/backgrounds/archlinux
	git clone https://github.com/fuad-ibrahimzade/arch-scripts-data
	cp -av arch-scripts-data/arch-wallpapers/. /mnt/usr/share/backgrounds/archlinux
	rm -rf arch-scripts-data
}


export -f initPacmanEntropy
export -f installTools
export -f installCacheCleanTools
export -f installBackupTools
export -f installDesktopEnvironment
export -f installGitHubMakepackage
export -f installAURpackage
export -f installAURpackageTrizen
export -f configureUsers
export -f initScriptAtBoot
export -f initScriptAtBoot2
export -f installDEi3ecly
export -f installDEkwin
export -f installDEmaterialshell
export -f installDEregolith
export -f installLxqtTiling
export -f installZentile
export -f installi3Only
export -f installi3Seperate
export -f initCronScriptAtBootForWallpaper
export -f writeArchIsoToSeperatePartition
export -f installFISH
export -f installZSH
export -f installBlackArchRepositories
export -f copyWallpapers
export -f createArchISO


#chroot /mnt /bin/bash -c "installAURpackage ly-git""

# end CHROOT functions

main "$@"; exit


# section OLD1
	# rsync -a --info=progress2 --no-i-r /run/archiso/bootmnt/arch/boot/. /mnt/boot	## grub alternative test
	##unsquashfs -f -d /mnt /run/archiso/bootmnt/arch/x86_64/airootfs.sfs	## not working
	#mkdir -p /tmp/sfs-mnt
	#mount -t squashfs /run/archiso/bootmnt/arch/x86_64/airootfs.sfs /tmp/sfs-mnt
	#rsync -a --info=progress2 --no-i-r /tmp/sfs-mnt/. /mnt
	##cp -av /tmp/sfs-mnt/. /mnt
	#umount /tmp/sfs-mnt
	#rm -rf /tmp/sfs-mnt

	#new
	# mount --bind squashfs-root squashfs-root
	# mount -t proc none squashfs-root/proc
	# mount -t sysfs none squashfs-root/sys
	# mount -o bind /dev squashfs-root/dev
	# mount -o bind /dev/pts squashfs-root/dev/pts  ## important for pacman (for signature check)
	# cp -L /etc/resolv.conf squashfs-root/etc  ## this is needed to use networking within the chroot
	#mount --bind /mnt /mnt
	#mount -t proc none /mnt/proc
	#mount -t sysfs none /mnt/sys
	#mount -o bind /dev /mnt/dev
	#mount -o bind /dev/pts /mnt/dev/pts  ## important for pacman (for signature check)
# end section OLD1

# section OLD2
	#pacman -S haveged
	#haveged -w 1024
	#pacman-key --init
	#pkill haveged
	#pacman -Rs haveged

	#pacman-key --keyserver hkps://keyserver.ubuntu.com --refresh
	#pacman-key --refresh-keys --keyserver hkp://keyserver.kjsl.com:80
	#pacman-key --refresh-keys --keyserver hkp://pgp.mit.edu:11371
	#pacman-key --refresh-keys --keyserver hkp://ipv4.pool.sks-keyservers.net:11371

	#yes '' | pacman -S xorg xorg-server
	#yes | pacman -S sddm
	#systemctl enable sddm
	#yes '' | pacman -S plasma-desktop konsole
	#sh larbs.sh
# end section OLD2

# section OLD3
	# FILE=/tmp/pacstrap_used
	# if [ -f "\$FILE" ]; then
	#     mkinitcpio -p linux;
	# else 
	#     mkinitcpio -g /boot/initramfs-linux.img
	# fi

	# systemctl get-default
	# #systemctl set-default graphical.target
	# #nano /etc/sddm.conf.d/autologin.conf
	# #remove live from there
	# #systemctl enable sddm
# end section OLD3

# section OLD4
	##bootctl --path=/boot install
	##blkid -s PARTUUID -o value "$efipart" > /boot/loader/entries/arch.conf
	##export SYSTEMD_RELAX_ESP_CHECKS=1 && test "yes" != "$(bootctl --esp-path=/boot is-installed)" && bootctl --esp-path=/boot install
	##half worked without entry with extendetd boot partition type 38 as for boot path nd then formatin 38 partition with mksfs.fat then bootctl --esp-path=/efi --boot-path=/boot install
	#bootctl --esp-path=/efi --boot-path=/boot install
# end section OLD4