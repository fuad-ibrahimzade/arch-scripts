#!/bin/bash
#TODO
#
#read -p "User Name:" user_name;
#read -p "User Password:" user_password;
#search="bindsym $mod+d exec --no-startup-id i3-dmenu-desktop"
#replace="bindsym $mod+Shift+d exec --no-startup-id i3-dmenu-desktop"
#echo "$user_password" | sudo -S sed -i "s|\$search|\$replace|g" /home/"$user_name"/.config/i3/config;
#echo "$user_password" | sudo -S python -m pikaur --noconfirm -S pikaur;
#echo "$user_password" | sudo -S python -m pikaur --noconfirm -S ly-git;
#echo "$user_password" | sudo -S sh -c 'systemctl enable ly.service'
#echo "$user_password" | sudo -S python -m pikaur --noconfirm -S cava gotop-bin rtorrent-ps tty-clock;
##echo "$user_password" | sudo -S python -m pikaur --noconfirm -S urxvtconfig themix-full-git
#
#ENDTODO

read -p "Output Device (example: /dev/sdb):" Output_Device
read -p "Root Password:" root_password;
read -p "User Name:" user_name;
read -p "User Password:" user_password;
sfdisk --delete "$Output_Device";
(echo o; echo n; echo p; echo 1; echo ""; echo +512M; echo n; echo p; echo 2; echo ""; echo ""; echo w; echo q) | fdisk $(echo $Output_Device);
partprobe;
efipart=$(echo $Output_Device)1;
rootpart=$(echo $Output_Device)2;
mkfs.fat -F32 -n EFI "$efipart";
mkfs.ext4 -L root "$rootpart";
mount "$rootpart" /mnt;
cd /mnt;
mkdir -p boot;
mount "$efipart" /mnt/boot;

yes '' | pacstrap -i /mnt base base-devel linux;
yes | pacstrap -i /mnt efibootmgr grub vim nano lynx flameshot xdiskusage;
genfstab -U /mnt >> /mnt/etc/fstab;
arch-chroot /mnt << EOF
#!/usr/bin/bash
ln -s /usr/share/zoneinfo/Asia/Baku /etc/localtime;
hwclock --systohc;
sed  -i 's/\#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen;
locale-gen;
echo "LANG=en_US.UTF-8" >> /etc/locale.conf;
yes | pacman -S networkmanager;
echo "localhost" >> /etc/hostname;# Replace your-hostname with your value;
echo "127.0.0.1 localhost" >> /etc/hosts;
echo "::1 localhost" >> /etc/hosts;
systemctl enable NetworkManager.service;

yes | pacman -S i3-gaps i3status;
yes | pacman -S ttf-dejavu dmenu xautolock i3lock;
yes | pacman -S pcurses neofetch ranger mc cmus calcurse dunst;
yes | pacman -S curl wget python-pip pyalpm git;
pip install pikaur
yes | pacman -S rxvt-unicode;
#deluge  pulseaudio pavucontrol vlc
#continue at TODO

#https://github.com/unix121/i3wm-themer
#pacman -S ttf-dejavu polybar nitrogen rofi python-pip ttf-font-awesome adobe-source-code-pro-fonts binutils gcc make pkg-config fakeroot python-yaml ttf-nerd-fonts-symbols git --noconfirm
##yes '' | pacman -S nvidia nvidia-utils    # NVIDIA 
##yes | pacman -S xf86-video-amdgpu mesa   # AMD
##yes | pacman -S xf86-video-intel mesa    # Intel
#yes | pacman -S alsa-utils    # Sound
#pacman --noconfirm -S notepadqq
#apponame=curl --silent "https://api.github.com/repos/app-outlet/app-outlet/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
#appname="https://github.com/app-outlet/app-outlet/releases/download/app-outlet-$app-outlet"
#lynx --source "$appname" > app-outlet.tar.gz
#tar -xvf app-outlet.tar.gz
#cd app-outlet
#makepkg -si
#cd ..
#rm -rf app-outlet

yes '' | pacman -S xorg-server xorg-xinit xterm
sed -i "s|twm \&|\#twm \&|g" /etc/X11/xinit/xinitrc;
sed -i "s|xclock -geometry 50x50-1+1 \&|\#xclock -geometry 50x50-1+1 \&|g" /etc/X11/xinit/xinitrc;
sed -i "s|xterm -geometry 80x50+494+51 \&|\#xterm -geometry 80x50+494+51 \&|g" /etc/X11/xinit/xinitrc;
sed -i "s|xterm -geometry 80x20+494-0 \&|\#xterm -geometry 80x20+494-0 \&|g" /etc/X11/xinit/xinitrc;
sed -i "s|exec xterm -geometry 80x66+0+0 -name login|\#exec xterm -geometry 80x66+0+0 -name login\nexec i3|g" /etc/X11/xinit/xinitrc;
#sed -i "s|exec xterm -geometry 80x66+0+0 -name login|\#exec xterm -geometry 80x66+0+0 -name login\ndunst \&\nurxvtd -q -f -o \&\nexec i3|g" /etc/X11/xinit/xinitrc;

mkinitcpio -p linux;
echo "root:${root_password}" | chpasswd
groupadd "$user_name"
useradd -m -g "$user_name" -G users,wheel,storage,power,network -s /bin/bash -c "Arch Qaqa" "$user_name"
echo "${user_name}:${user_password}" | chpasswd
search="# %wheel ALL=(ALL) ALL"
replace=" %wheel ALL=(ALL) ALL"
sed -i "s|\$search|\$replace|g" /etc/sudoers;
grub-install --target=x86_64-efi --efi-directory=/boot
grub-mkconfig -o /boot/grub/grub.cfg;
echo "$user_password" | sudo -S -u "$user_name" mkdir /home/"$user_name";
echo "$user_password" | sudo -S -u "$user_name" cat > /home/"$user_name"/reload_bash_shell.sh << EOF2
#!/usr/bin/bash
if [ ! -f /home/"$user_name"/resume-after-reboot ]; then
  # scripts

  # Preparation for reboot
  script="bash /home/$user_name/reload_bash_shell.sh"
  echo "$script" >> /home/"$user_name"/.bashrc 
  sudo touch /home/"$user_name"/resume-after-reboot
  echo "rebooting.."
else 
  echo "resuming script after reboot.."
  # Remove the line that we added in bashrc
  sed -i '/bash/d' /home/"$user_name"/.bashrc 
  sudo rm -f /home/"$user_name"/resume-after-reboot
  
  # continue script
  #read -p "User Name:" user_name;
  #read -p "User Password:" user_password;
  echo "$user_password" | sudo -S -s -- <<EOF3
	  mkdir -p /home/"$user_name"/.config/i3
	  lynx --source https://gist.githubusercontent.com/fuad-ibrahimzade/266441c50e94ba9c8cecbfbdabcf0595/raw | tr -d '\r' > /home/"$user_name"/.config/i3/config
	  echo "client.focused #4c7899 #285577 #ffffff #2e9ef4 #285577" >> /home/"$user_name"/.config/i3/config
	  mkdir -p /home/"$user_name"/.config/i3status
	  cp /etc/i3status.conf /home/"$user_name"/.config/i3status/config
	  touch /home/"$user_name"/.Xresources
	  cat > /home/"$user_name"/.Xresources << EOF4
		#https://terminal.sexy/		default
		! special
		*.foreground:   #c5c8c6
		*.background:   #000000
		*.cursorColor:  #c5c8c6

		! black
		*.color0:       #282a2e
		*.color8:       #373b41

		! red
		*.color1:       #a54242
		*.color9:       #cc6666

		! green
		*.color2:       #8c9440
		*.color10:      #b5bd68

		! yellow
		*.color3:       #de935f
		*.color11:      #f0c674

		! blue
		*.color4:       #5f819d
		*.color12:      #81a2be

		! magenta
		*.color5:       #85678f
		*.color13:      #b294bb

		! cyan
		*.color6:       #5e8d87
		*.color14:      #8abeb7

		! white
		*.color7:       #707880
		*.color15:      #c5c8c6
EOF4
	  #lynx --source https://gist.githubusercontent.com/fuad-ibrahimzade/9f9d199a116dffcaa7db31d5f47957bb/raw | tr -d '\r' > /home/"$user_name"/.Xresources
	  #https://gist.github.com/fuad-ibrahimzade/9f7af6904c911440d5b3ae8e8a7c4e13
	  lynx --source https://raw.githubusercontent.com/felixr/urxvt-color-themes/master/tango | tr -d '\r' > /home/"$user_name"/.Xresources
	  echo "xterm*background: black" >> /home/"$user_name"/.Xresources
	  echo "xterm*foreground: lightgray" >> /home/"$user_name"/.Xresources
	  echo "urxvt*scrollBar_right: false" >> /home/"$user_name"/.Xresources
	  echo "urxvt*font: xft:dejavusansmono:size=11" >> /home/"$user_name"/.Xresources
	  xrdb ~/.Xresources
	  
	  search="bindsym $mod+d exec --no-startup-id i3-dmenu-desktop"
	  replace="bindsym $mod+Shift+d exec --no-startup-id i3-dmenu-desktop"
	  sed -i "s|\$search|\$replace|g" /home/"$user_name"/.config/i3/config;
	  search="bindsym $mod+Return exec i3-sensible-terminal"
	  replace="bindsym $mod+Return exec urxvt"
	  sed -i "s|\$search|\$replace|g" /home/"$user_name"/.config/i3/config;
	  
	  git clone https://github.com/fuad-ibrahimzade/polybar-themes;
	  mkdir -p ~/home/"$user_name"/.local/share/fonts
	  cp -r polybar-themes/polybar-5/fonts/* /home/"$user_name"/.local/share/fonts
	  fc-cache -v
	  rm /etc/fonts/conf.d/70-no-bitmaps.conf
	  mkdir -p /home/"$user_name"/.config/polybar
	  #rsync -a polybar-themes/polybar-5/ /home/"$user_name"/.config/polybar/;
	  cp -a polybar-themes/polybar-5/* /home/"$user_name"/.config/polybar/;
	  rm -rf polybar-themes
	  
	  echo "exec_always --no-startup-id /home/$user_name/.config/polybar/launch.sh" >> /home/"$user_name"/.config/i3/config;
	  #python -m pikaur --noconfirm -S pikaur;
	  python -m pikaur --noconfirm -S ly-git polybar;
	  sh -c 'systemctl enable ly.service'
	  #for fixing broken packages
	  python -m pikaur --noconfirm -S downgrade;
	  #python -m pikaur --noconfirm -S cava gotop-bin tty-clock;
	  #python -m pikaur --noconfirm -S urxvtconfig themix-full-git
	  # rtorrent-ps
EOF3
fi
EOF2

sh /home/"$user_name"/reload_bash_shell.sh;

exec bash
EOF
umount /mnt/boot
umount /mnt/home
umount -l /mnt
reboot
exec bash
