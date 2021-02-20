#read -p "Output Device (example: /dev/sdb):" Output_Device
Output_Device="/dev/sda"
sfdisk --delete "$Output_Device";
partprobe;
(echo o; echo n; echo p; echo 1; echo ""; echo +512M; echo n; echo p; echo 2; echo ""; echo ""; echo w; echo q) | fdisk $(echo $Output_Device);
efipart=$(echo $Output_Device)1;
rootpart=$(echo $Output_Device)2;
#mkfs.fat -F32 -n EFI "$efipart";
# after ls -l /dev/disk/by-label	found ARCH_202011 on mount of /dev/sr0 at /run/archiso/bootmnt/arch/boot/syslinux/archiso_sys-linux.cfg
mkfs.fat -F32 -n ARCH_202012 "$efipart";
mkfs.ext4 -L root "$rootpart";
mount "$rootpart" /mnt
mkdir -p /mnt/boot
mount "$efipart" /mnt/boot

# new
lynx --source https://archmirror.it/iso/2020.12.01/archlinux-bootstrap-2020.12.01-x86_64.tar.gz > /tmp/archlinux-bootstrap-2020.12.01-x86_64.tar.gz
tar xzf /tmp/archlinux-bootstrap-*-x86_64.tar.gz -C /tmp
#mount --bind /tmp/root.x86_64 /tmp/root.x86_64
#cd /tmp/root.x86_64
mount --bind /tmp/root.x86_64 /mnt
lynx --source https://raw.githubusercontent.com/archlinux/mkinitcpio/master/mkinitcpio.conf | tr -d '\r' > /mnt/etc/mkinitcpio.conf
cd /mnt
cp /etc/resolv.conf etc
mount -t proc /proc proc
mount --make-rslave --rbind /sys sys
mount --make-rslave --rbind /dev dev
mount --make-rslave --rbind /run run    # (assuming /run exists on the system)

#chroot /tmp/root.x86_64 /bin/bash
# end new (3 lines after this commented)


#cp -ax / /mnt
#cp -vaT /run/archiso/bootmnt/arch/boot/$(uname -m)/vmlinuz-linux /mnt/boot/vmlinuz-linux
#genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt << EOF
sed -i 's/Storage=volatile/#Storage=auto/' /etc/systemd/journald.conf
rm /etc/udev/rules.d/81-dhcpcd.rules
systemctl disable pacman-init.service choose-mirror.service
rm -r /etc/systemd/system/{choose-mirror.service,pacman-init.service,etc-pacman.d-gnupg.mount,getty@tty1.service.d}
rm /etc/systemd/scripts/choose-mirror
rm /root/{.automated_script.sh,.zlogin}
rm /etc/mkinitcpio-archiso.conf
rm -r /etc/initcpio
rm /root/{.automated_script.sh,.zlogin}
rm /etc/mkinitcpio-archiso.conf
rm -r /etc/initcpio
pacman -Sy
pacman -S --noconfirm archlinux-keyring
echo "keyserver hkp://ipv4.pool.sks-keyservers.net:11371" >> /etc/pacman.d/gnupg/gpg.conf
pacman-key --init
pacman-key --populate archlinux
pacman-key --refresh-keys
# echo "keyserver hkp://ipv4.pool.sks-keyservers.net:11371" >> /etc/pacman.d/gnupg/gpg.conf
# #rm -r /etc/pacman.d/gnupg
# pacman-key --init
# pacman -S --noconfirm archlinux-keyring
# pacman-key --populate archlinux
ln -sf /usr/share/zoneinfo/Asia/Baku /etc/localtime
hwclock --systohc
sed  -i 's/\#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen;
locale-gen;
echo "LANG=en_US.UTF-8" >> /etc/locale.conf;
echo "localhost" >> /etc/hostname;# Replace your-hostname with your value;
echo "127.0.0.1 localhost" >> /etc/hosts;
echo "::1 localhost" >> /etc/hosts;
yes | pacman -S grub efibootmgr os-prober intel-ucode amd-ucode
userdel live
rm -rf /home/live
useradd -m user
echo "user:user" | chpasswd
echo "root:root" | chpasswd
#mkinitcpio -p linux
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
#grub-install $(echo $Output_Device)
#grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
mkinitcpio -p linux
#or
#bootctl --path=/boot install
#blkid -s PARTUUID -o value /dev/sda1 > /boot/loader/entries/arch.conf
exit
EOF
umount /mnt/boot
umount /mnt -l
reboot