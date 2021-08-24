# nixos-install-zfs


main() {
	if [[ -f .env ]]; then
		# export "$(cat .env | xargs)"
		set -o allexport; source .env; set +o allexport
	fi

	passphrase=${passphrase:-mypassphrase}
	ssid=${ssid:-myssid}
	resetISOPasswords;
	connectToWIFI "$ssid" "$passphrase";

	default_Output_Device=${default_Output_Device:-/dev/sda}
	default_root_partitionsize=${default_root_partitionsize:-10}
	default_root_password=${default_root_password:-root}
	default_user_name=${default_user_name:-user}
	default_user_password=${default_user_password:-user}

	read -r -p "Accept Defaults default: y, [select y or n](Output Device: $default_Output_Device, root_partitionsize in GiB: $default_root_partitionsize, root_password: $default_root_password, user_name: $default_user_name, user_password: $default_user_password):" defaults_accepted
	defaults_accepted=${defaults_accepted:-y}
	echo "$defaults_accepted"

	Output_Device="$default_Output_Device"
	root_partitionsize="$default_root_partitionsize"
	root_password="$default_root_password"
	user_name="$default_user_name"
	user_password="$default_user_password"

	if [[ $defaults_accepted == "n" ]]; then
		initDefaultOptions;
	fi

	# echo "root ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers

	# initPackageManager;
	# initVirtualBoxGuestAdditions;
	# installDownloadAndEditTools;

	initAndMountPartitions "$Output_Device" "$root_partitionsize";
	
	# tee -a /etc/nixos/configuration.nix <<- EOF
	# security.sudo.extraRules= [
	# 	{  
	# 		users = [ \"$USER\" ];
	# 		commands = [
	# 		{ command = "ALL" ;
	# 			options= [ "NOPASSWD" ]; # "SETENV" # Adding the following could be a good idea
	# 		}
	# 		];
	# 	}
	# ];
	# EOF
	# sudo nixos-rebuild switch 
	# sudo nix-collect-garbage -d
	# zGenerationsInDaysToBeDeleted=22
	# nix-collect-garbage -d --delete-older-than ${zGenerationsInDaysToBeDeleted}
	# sudo nix-store --optimise

	# https://github.com/Fuuzetsu/nix-project-defaults/blob/master/nixos-config/configuration.nix
	# https://github.com/a-schaefers/themelios
	# https://github.com/bhougland18/nixos_config
	# https://gist.github.com/byrongibson/1578914d03a5c0a01a13f9ec53ee0b0a

	# http://toxicfrog.github.io/automounting-zfs-on-nixos/
	# https://nixos.wiki/wiki/Cheatsheet
	# https://www.reddit.com/r/archlinux/comments/b2jkrp/anyone_tried_nixos_what_are_your_thoughts/
	# https://nixos.wiki/wiki/NixOS_on_ZFS
	# https://nixos.wiki/wiki/User:2r/NixOS_on_ZFS
	# virtualbox guest editions:
	# https://gist.github.com/cleverca22/85f6d2cd680139f7c6c8b6c2844cb132
	# zsh config:
	# https://git.ingolf-wagner.de/palo/nixos-config/src/f7e1df5ad3c248f6a5d223fff08cac1fad3a6775/modules/programs/shell-zsh.nix
	
	nixosconfig="online-nixoszfs.nix"

	refactorCustomNixConfiguration "$user_name" "$user_password" "$nixosconfig" "$passphrase" "$ssid";
	install "$Output_Device" "$root_password" "$user_name" "$user_password" "$nixosconfig";


	# head -n -1 /etc/sudoers > temp.txt ; sudo -u root mv temp.txt /etc/sudoers # delete NOPASSWD line
	#reboot
}

install() {
	Output_Device="$1"
	root_password="$2"
	user_name="$3"
	user_password="$4"
	nixosconfig="$5"
	
	sudo nixos-generate-config --root /mnt
	sudo cp "$nixosconfig" /mnt/etc/nixos/configuration.nix

	sed -i "s|canTouchEfiVariables = true;|canTouchEfiVariables = false;|g" "$nixosconfig" #bug fix efi boot no space left

	# sudo nix-collect-garbage -d
	sudo nixos-install --show-trace

	efibootmgr -c -d "$Output_Device" -p 1 -L "SystemD" -l "\EFI\systemd\systemd-bootx64.efi" #bug fix efi boot no space left

	# boot.supportedFilesystems = ["zfs"];
	# boot.zfs.requestEncryptionCredentials = true;
	# sed -i "s|$search|$replace|g" /mnt/etc/nixos/configuration.nix

}

refactorCustomNixConfiguration() {
	user_name="$1"
	user_password="$2"
	nixosconfig="$3"
	passphrase="$4"
	ssid="$5"
	
	hased_user_password=$(echo user_password | mkpasswd -m sha-512)
	hostid=$(head -c 8 /etc/machine-id)
	sed -i "s|your_hostid|$hostid|g" "$nixosconfig"
	sed -i "s|your_hostname|$(hostname)|g" "$nixosconfig"
	sed -i "s|your_username|$user_name|g" "$nixosconfig"
	sed -i "s|your_virtualboxuser|$user_name|g" "$nixosconfig"
	sed -i "s|your_hashedpassword|$hased_user_password|g" "$nixosconfig"

	# # run `ip a` to find the values of these
	physical_interface=$(ls /sys/class/net | grep enp)
	wifi_interface=$(ls /sys/class/net | grep wl)

	sed -i "s|your_physicalinterface|$physical_interface|g" "$nixosconfig"
	sed -i "s|your_wifiinterface|$wifi_interface|g" "$nixosconfig"

	sudo bash -c "wpa_passphrase $ssid $passphrase >> temp"
	pskRaw_generated=$(cat temp);
	sudo rm temp
	sed -i "s|your_wifiname|myWifi|g" "$nixosconfig"
	sed -i "s|your_pskRaw_generated|$pskRaw_generated|g" "$nixosconfig"

	working_interface="$physical_interface";
	if [[ -z "$working_interface" ]]; then
		working_interface="$wifi_interface"
	fi
	sed -i "s|your_working_interface|$working_interface|g" "$nixosconfig"

	return
	tee -a "$nixosconfig" <<- EOF
	systemd.services.doUserdata = {
		script = ''
			echo hello
			flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
		'';
		wantedBy = ['multi-user.target'];
		serviceConfig = {
			Type = "oneshot";
			ExecStartPost=/bin/sh -c "touch /etc/nixos/do-userdata.nix"
			RemainAfterExit = false;
		};
		unitConfig = {
			ConditionPathExists = "!/etc/nixos/do-userdata.nix";
		};
	};
	EOF

}

initAndMountPartitions() {
	# cari https://github.com/bhougland18/nixos_config
	# cari https://github.com/instantOS/instantNIX	
		 # https://raw.githubusercontent.com/instantOS/instantNIX/master/utils/configuration.nix
	# cari https://cheat.readthedocs.io/en/latest/nixos/zfs_install.html

	Output_Device="$1"
	root_partitionsize="$2"

	# sfdisk --delete "$Output_Device";
	sudo sgdisk --zap-all "$Output_Device"
	sudo wipefs --all "$Output_Device";

	sudo partprobe;

	starting_part_number=$(sudo partx -g /dev/sda | wc -l)
	is_efi="n"
	if [[ -d "/sys/firmware/efi/" && -n "$(ls -A /sys/firmware/efi/)" ]]; then
		is_efi="y"
	else
		starting_part_number=$((starting_part_number + 1));
	fi
	efipart_num=$((starting_part_number + 1))
	swappart_num=$((starting_part_number + 2))
	rootpart_num=$((starting_part_number + 3))
	efipart="${Output_Device}${efipart_num}";
	swappart="${Output_Device}${swappart_num}";
	rootpart="${Output_Device}${rootpart_num}";

	# partuuid=$(blkid -s PARTUUID -o value "$efipart")
	# SDA_ID="$(ls /dev/disk/by-id/ | grep '^[ata]')"
	SDA_UUID=$(blkid -s UUID -o value "$Output_Device")
	DISK="/dev/disk/by-uuid/$SDA_UUID"
	if [[ -z $(sudo lsblk -o PARTUUID /dev/sda | grep -v PARTUUID) ]]; then
		DISK="$Output_Device"
	fi

	if [[ $is_efi == "y" ]]; then
		sudo sgdisk -n 0:0:+1GiB -t 0:EF00 -c 0:boot "$DISK"
	else
		sudo sgdisk -n 0:0:+1MiB -t 0:ef02 -c 0:grub "$DISK"
		sudo sgdisk -n 0:0:+1GiB -t 0:ea00 -c 0:boot "$DISK"
	fi

	sudo partprobe;

	disk_size_float=$(sudo fdisk -l | grep Disk | grep Output_Device | awk -F"GiB" '{print $1}' | awk -F: '{print $2}'| tr '\n' ' ' | sed -e 's/^[[:space:]]*//')
	disk_size=$(("${disk_size_float%.*}" + 1 ))
	if [[ "$disk_size" -gt 16 ]]; then
		sudo sgdisk -n 0:0:+4GiB -t 0:8200 -c 0:swap "$DISK"
	else
		sudo sgdisk -n 0:0:+1GiB -t 0:8200 -c 0:swap "$DISK"
	fi

	sudo partprobe;

	remaining_free_disk_size_float=$(sudo parted "$DISK" unit GiB print free | grep "Free Space" | awk -F"Free Space" '{print $(NF-1)}' | awk '{print $NF}' | tail -n -1 | awk -F"GiB" '{print $1}' | tr '\n' ' ' | sed -e 's/^[[:space:]]*//');
	remaining_free_disk_size=$(("${remaining_free_disk_size_float%.*}" + 1 ))
	if [[ "$remaining_free_disk_size" -gt "$root_partitionsize" ]]; then
		sudo sgdisk -n 0:0:+"$root_partitionsize"GiB -t 0:BF01 -c 0:ZFS "$DISK"
	else
		sudo sgdisk -n 0:0:0 -t 0:BF01 -c 0:ZFS "$DISK"
	fi

	sudo partprobe;

	BOOT=$efipart
	SWAP=$swappart
	ZFS=$rootpart

	# import zfs pool if not from same session or destroy recreate (cari plus grub https://elis.nu/blog/2019/08/encrypted-zfs-mirror-with-mirrored-boot-on-nixos/)
	# zpool import zroot
	# zfs load-key zroot
	sudo zpool destroy -f rpool
	# sudo zpool create -f -o ashift=12 -o altroot="/mnt" -O mountpoint=none -O encryption=aes-256-gcm -O keyformat=passphrase rpool "$ZFS" #old 
	sudo zpool create -f -o ashift=12 -o altroot="/mnt" -O mountpoint=none -O encryption=aes-256-gcm -O keyformat=passphrase atime=off -O compression=lz4 -O xattr=sa -O acltype=posixacl -R /mnt rpool "$ZFS" #new
	# sudo zpool create -O mountpoint=none -O atime=off -O compression=lz4 -O xattr=sa -O acltype=posixacl -o ashift=12 -R /mnt rpool $DISK-part1

	sudo zfs create -o mountpoint=none rpool/root
	sudo zfs create -o mountpoint=legacy rpool/root/nixos
	sudo zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true rpool/home
	sudo zfs set compression=lz4 rpool/home
	sudo zfs create -o refreservation=10G -o mountpoint=none rpool/reserved

	# https://nixos.wiki/wiki/NixOS_on_ZFS
	# sudo zfs set com.sun:auto-snapshot=true rpool/root
	# services.zfs.autoSnapshot = {
	# 	enable = true;
	# 	frequent = 8; # keep the latest eight 15-minute snapshots (instead of four)
	# 	monthly = 1;  # keep only one monthly snapshot (instead of twelve)
	# };
	# zfs set com.sun:auto-snapshot:weekly=false rpool/root
	# services.zfs.trim.enable = true
	# zpool set autotrim=on rpool
	# zpool iostat -r

	# zpool trim tank
	# zpool status -t
	# zpool iostat -r
	# zpool iostat -w

	# https://www.kringles.org/linux/zfs/vmware/2015/02/10/linux-zfs-resize.html
	# zpool set autoexpand=on tank
	# zpool status # get diskname
	# parted /dev/sdb # resize
	# # (parted) resizepart                                                       
	# # Partition number? 1                                                       
	# # End?  [X.XGB]?                                                           
	# # (parted) quit   
	# zpool online -e tank sdb
	# df -h



	sudo mount -t zfs rpool/root/nixos /mnt
	sudo mkdir /mnt/home
	sudo mount -t zfs rpool/home /mnt/home

	sudo mkfs.vfat "$BOOT"
	sudo mkdir /mnt/boot
	sudo mount "$BOOT" /mnt/boot

	sudo mkswap -L swap "$SWAP"
	swapon "$SWAP"
}

installDownloadAndEditTools() {
	packages=$(nix-env -qA --installed "*")
	# packages=$(nix-env -qa --installed "*")
	# nix-env -iA nixos.git
	# nix-env -iA nixos.curl
	# nix-env -iA nixos.wget
	# nix-env -iA nixos.vim
	# nix-env -iA nixos.rsync
	echo 'with import <nixpkgs>{}; [ git curl wget vim rsync nix-index ]' > /tmp/tmp.nix
	nix-env -if /tmp/tmp.nix
}


initVirtualBoxGuestAdditions() {
	nix-env -iA nixos.linuxPackages.virtualboxGuestAdditions
	current_user="$USER"
	current_group=$(id -g -n)
	systemctl enable --now vboxservice.service
	usermod -a -G vboxsf "$current_user"
	
	echo "root ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
	sudo chown -R "$current_user":"$current_group" /media/sf_Public/ #create shared Public folder inside virtualbox
	sudo cp /usr/bin/VBoxClient-all sudo cp /usr/local/bin/VBoxClient-all #needed for sharing clipboard inside virtualbox
	sudo chown -R "$current_user":"$current_group" /usr/local/bin/VBoxClient-all
}

resetISOPasswords() {
	echo root:root | sudo chpasswd
	echo "$USER":"$USER" | sudo chpasswd
}

initPackageManager() {
	nix-channel --add https://nixos.org/channels/nixos-21.05 nixos
	nix-channel --add https://nixos.org/channels/nixos-unstable unstable
	nix-channel --update
}

initDefaultOptions() {
	read -r -p "Output Device (default: /dev/sda):" Output_Device
	Output_Device=${Output_Device:-/dev/sda}
	echo "$Output_Device"
	read -r -p "Root partition size in GiB (default: 10Gib):" root_partitionsize;
	root_partitionsize=${root_partitionsize:-10}
	echo "$root_partitionsize"
	read -r -p "Root Password (default: root):" root_password;
	root_password=${root_password:-root}
	echo "$root_password"
	read -r -p "User Name (default: user):" user_name;
	user_name=${user_name:-user}
	echo "$user_name"
	read -r -p "User Password (default: user):" user_password;
	user_password=${user_password:-user}
	echo "$user_password"
}

connectToWIFI() {
	ssid="$1"
	passphrase="$2"
	# nmcli device wifi connect "$ssid" password "$passphrase"
	sudo nmcli dev wifi connect "$ssid" password "$passphrase" hidden yes
	# nmcli c add type wifi con-name "con-$ssid" ifname wlan0 ssid "$ssid"
	# nmcli con modify "con-$ssid" wifi-sec.key-mgmt wpa-psk
	# nmcli con modify "con-$ssid" wifi-sec.psk <password>
	# nmcli con up "con-$ssid"
	# nmcli c delete "con-$ssid"

	if which iwctl >/dev/null; then
		sudo iwctl --passphrase "$passphrase" station wlan0 connect-hidden "$ssid"
	else
		wifi_interface=$(ls /sys/class/net | grep wl)
		sudo mkdir /etc/wpa_supplicant
		sudo touch "/etc/wpa_supplicant/wpa_supplicant-${wifi_interface}.conf"
		sudo tee "/etc/wpa_supplicant/wpa_supplicant-${wifi_interface}.conf" <<- EOF
		ctrl_interface=/var/run/wpa_supplicant
		update_config=1
		EOF
		sudo bash -c "wpa_passphrase $ssid $passphrase >> /etc/wpa_supplicant/wpa_supplicant-${wifi_interface}.conf"
		sudo sed -i "s|network={|network={\n\tmode=0\n\tscan_ssid=1|g" "/etc/wpa_supplicant/wpa_supplicant-${wifi_interface}.conf";
		sudo wpa_supplicant -B -i "$wifi_interface" -c "/etc/wpa_supplicant/wpa_supplicant-${wifi_interface}.conf"
		# sudo wpa_supplicant -B -i "$wifi_interface" -D nl80211 -c "/etc/wpa_supplicant/wpa_supplicant-${wifi_interface}.conf"
		sudo systemctl restart wpa_supplicant.service
	fi
}

export -f connectToWIFI
export -f initDefaultOptions
export -f resetISOPasswords
export -f initPackageManager
export -f initVirtualBoxGuestAdditions
export -f installDownloadAndEditTools
export -f initAndMountPartitions
export -f refactorCustomNixConfiguration
export -f install

main "$@"; exit

