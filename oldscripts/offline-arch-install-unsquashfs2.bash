# offline-arch-install-unsquashfs


#boot arhiso
#create gpt table
#create boot swap root partitions
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
sfdisk --delete "$Output_Device";
#wipefs --all "$Output_Device";
#dd if=/dev/zero of="$Output_Device" bs=512 count=1
partprobe;
(echo g; echo n; echo p; echo 1; echo ""; echo +512M; echo t; echo 1; echo n; echo p; echo 2; echo ""; echo ""; echo w; echo q) | fdisk $(echo $Output_Device);
#(echo g; echo n; echo p; echo 1; echo ""; echo +512M; echo t; echo 1; echo n; echo p; echo 2; echo ""; echo +512M; echo t; echo 2; echo 38; echo n; echo p; echo 3; echo ""; echo ""; echo w; echo q) | fdisk $(echo $Output_Device);
efipart=$(echo $Output_Device)1;
#extbootpart=$(echo $Output_Device)2;
rootpart=$(echo $Output_Device)2;
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

unsquashfs -force -dest /mnt /run/archiso/bootmnt/arch/x86_64/airootfs.sfs
lynx --source https://raw.githubusercontent.com/archlinux/mkinitcpio/master/mkinitcpio.conf | tr -d '\r' > /mnt/etc/mkinitcpio.conf
lynx --source larbs.xyz/larbs.sh | tr -d '\r' > /mnt/larbs.sh
# AREA section OLD1

cp -L /etc/resolv.conf /mnt/etc  ## this is needed to use networking within the chroot
#reflector --latest 5 --protocol http --protocol https --sort rate --save /mnt/etc/pacman.d/mirrorlist
#end new

#cp /run/archiso/bootmnt/arch/x86_64/vmlinuz /mnt/boot/vmlinuz-linux
cp /run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux /mnt/boot/vmlinuz-linux
genfstab -U -p /mnt >> /mnt/etc/fstab
arch-chroot /mnt << EOF
pacman -Sy
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
useradd -m archie
ln -s /usr/lib/security/pam_loginuid.so /usr/lib/pam_loginuid.so

# AREA section OLD2

yes '' | pacman -S base-devel
yes | pacman -S curl wget python python-pip pyalpm git;
python -m pip install pikaur pywal
yes | pacman -S kitty rofi zsh ttf-fira-code otf-font-awesome swaylock mako
yes | pacman -S weston
#python -m pikaur --noconfirm -S sway-git waybar-git nerd-fonts-fira-code
yes '' | pacman -S sway waybar
#python -m pikaur --noconfirm -S ly-git;
#sh -c 'systemctl enable ly.service'

EOF

pacman -Syy
pacman -S --noconfirm git;

function getAURpackage() {
	packageName="$1"
	echo "Packaga name is ${packageName}"
	sudo -u nobody mkdir /tmp/tmp-build
	cd /tmp/tmp-build
	git clone "https://aur.archlinux.org/${packageName}.git"
	sudo -u nobody mkdir -p "/mnt/tmp/tmp-build/${packageName}"
	sudo -u nobody rsync -a --info=progress2 --no-i-r "/tmp/tmp-build/${packageName}/." "/mnt/tmp/tmp-build/${packageName}"
	cd ..
	cd ..
}
getAURpackage "sway-git"
getAURpackage "waybar-git"
getAURpackage "ly-git"
function instllAURpackage() {
	cd /tmp/tmp-build
	chown -R nobody $packageName
	cd $packageName
	sudo -u nobody makepkg
	pacman -U *.tar.xz
	cd ..
	cd ..
	rm -rf "/tmp-build/${packageName}"
}
export -f instllAURpackage
chroot /mnt /bin/bash -c "instllAURpackage ly-git"
#instllAURpackage "sway-git"
#instllAURpackage "waybar-git"
#instllAURpackage "ly-git"

arch-chroot /mnt << EOF

#yes | pacman -S zsh
#echo "[archi3linux]" >> /etc/pacman.conf
#echo "SigLevel = Optional TrustAll" >> /etc/pacman.conf
#echo "Server = https://archi3linux.org/repo/x86_64" >> /etc/pacman.conf
#useradd -mU -s /usr/bin/zsh -G wheel,uucp,sys,users user2
#echo "user2:user2" | chpasswd
#yes "'' y" | pacman -Sy archi3linux

yes | pacman -S grub efibootmgr
#yes | pacman -S grub efibootmgr os-prober intel-ucode amd-ucode
userdel live
rm -rf /home/live

#useradd -m user
groupadd "$user_name"
useradd -m -g "$user_name" -G users,wheel,storage,power,network -s /bin/bash -c "Arch Qaqa" "$user_name"
echo "${user_name}:${user_password}" | chpasswd
search="# %wheel ALL=(ALL) ALL"
replace=" %wheel ALL=(ALL) ALL"
sed -i "s|\$search|\$replace|g" /etc/sudoers;

#echo "user:user" | chpasswd
#echo "root:root" | chpasswd
echo "root:${root_password}" | chpasswd
mkinitcpio -g /boot/initramfs-linux.img
systemctl get-default
#systemctl set-default graphical.target
#nano /etc/sddm.conf.d/autologin.conf
#remove live from there
#systemctl enable sddm
grub-install --target=x86_64-efi --efi-directory=/boot
#grub-install --target=x86_64-efi --efi-directory=/efi --boot-directory=/boot
grub-mkconfig -o /boot/grub/grub.cfg
##bootctl --path=/boot install
##blkid -s PARTUUID -o value "$efipart" > /boot/loader/entries/arch.conf
##export SYSTEMD_RELAX_ESP_CHECKS=1 && test "yes" != "$(bootctl --esp-path=/boot is-installed)" && bootctl --esp-path=/boot install
##half worked without entry with extendetd boot partition type 38 as for boot path nd then formatin 38 partition with mksfs.fat then bootctl --esp-path=/efi --boot-path=/boot install
#bootctl --esp-path=/efi --boot-path=/boot install

groupadd -r user
exit
EOF
#umount /mnt/boot
#umount /mnt -l
#umount -l -R /mnt
#umount -l -R /mnt
#reboot

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