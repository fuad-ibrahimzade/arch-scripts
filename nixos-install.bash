# nixos-install-zfs


main() {
	if [[ -f .env ]]; then
		# export "$(cat .env | xargs)"
		set -o allexport; source .env; set +o allexport
	fi

	passphrase=${passphrase:-mypassphrase}
	ssid=${ssid:-myssid}
	connectToWIFI "$ssid" "$passphrase";

	default_Output_Device=${default_Output_Device:-/dev/sda}
	default_root_partitionsize=${default_root_partitionsize:-/dev/sda}
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

	initPartitionsAndMount "$Output_Device" "$root_partitionsize";

	install "$Output_Device" "$root_password" "$user_name" "$user_password";

	#reboot
}

install() {
	Output_Device="$1"
	root_password="$2"
	user_name="$3"
	user_password="$4"
	
	nixos-generate-config  --root /mnt

	hostid=$(head -c 8 /etc/machine-id)

	# boot.supportedFilesystems = ["zfs"];
	# boot.zfs.requestEncryptionCredentials = true;
	# sed -i "s|$search|$replace|g" /mnt/etc/nixos/configuration.nix

}

initPartitionsAndMount() {
	# https://github.com/bhougland18/nixos_config

	Output_Device="$1"
	root_partitionsize="$2"

	# sfdisk --delete "$Output_Device";
	sgdisk --zap-all "$Output_Device"
	wipefs --all "$Output_Device";

	partprobe;

	# starting_part_number=$(partx -g /dev/sda | wc -l)
	# efipart_num=$((starting_part_number + 1))
	# rootpart_num=$((starting_part_number + 2))
	# efipart="${Output_Device}${efipart_num}";
	# rootpart="${Output_Device}${rootpart_num}";

	is_efi="n"
	if [[ -d "/sys/firmware/efi/" && -n "$(ls -A /sys/firmware/efi/)" ]]; then
		is_efi="y"
	fi

	# partuuid=$(blkid -s PARTUUID -o value "$efipart")
	# SDA_ID="$(ls /dev/disk/by-id/ | grep '^[ata]')"
	SDA_UUID=$(blkid -s UUID -o value "$Output_Device")
	DISK="/dev/disk/by-uuid/$SDA_UUID"

	if [[ $is_efi == "y" ]]; then
		sgdisk -n 0:0:+1GiB -t 0:EF00 -c 0:boot "$DISK"
	else
		sgdisk -n 0:0:+1MiB -t 0:ef02 -c 0:grub "$DISK"
		sgdisk -n 0:0:+1GiB -t 0:ea00 -c 0:boot "$DISK"
	fi

	sgdisk -n 0:0:+4GiB -t 0:8200 -c 0:swap "$DISK"
	# sgdisk -n 0:0:0 -t 0:BF01 -c 0:ZFS "$DISK"
	sgdisk -n 0:0:+"$root_partitionsize"GiB -t 0:BF01 -c 0:ZFS "$DISK"

	BOOT=""
	SWAP=""
	ZFS=""
	if [[ $is_efi == "y" ]]; then
		BOOT=$DISK-part1
		SWAP=$DISK-part2
		ZFS=$DISK-part3
	else
		BOOT=$DISK-part2
		SWAP=$DISK-part3
		ZFS=$DISK-part4
	fi

	zpool create -o ashift=12 -o altroot="/mnt" -O mountpoint=none -O encryption=aes-256-gcm -O keyformat=passphrase rpool "$ZFS"
	zfs create -o mountpoint=none rpool/root
	zfs create -o mountpoint=legacy rpool/root/nixos
	zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true rpool/home
	zfs set compression=lz4 rpool/home

	mount -t zfs rpool/root/nixos /mnt
	mkdir /mnt/home
	mount -t zfs rpool/home /mnt/home

	mkfs.vfat "$BOOT"
	mkdir /mnt/boot
	mount "$BOOT" /mnt/boot

	mkswap -L swap "$SWAP"
}

connectToWIFI() {
	ssid="$1"
	passphrase="$2"
	if which iwctl >/dev/null; then
		iwctl --passphrase "$passphrase" station wlan0 connect-hidden "$ssid"
	else
		wifi_interface=$(ls /sys/class/net | grep wl)
		mkdir /etc/wpa_supplicant
		touch "/etc/wpa_supplicant/wpa_supplicant-${wifi_interface}.conf"
		tee "/etc/wpa_supplicant/wpa_supplicant-${wifi_interface}.conf" <<- EOF
		ctrl_interface=/var/run/wpa_supplicant
		update_config=1
		EOF
		wpa_passphrase "$ssid" "$passphrase" >> "/etc/wpa_supplicant/wpa_supplicant-${wifi_interface}.conf"
		sed -i "s|network={|network={\n\tmode=0\n\tscan_ssid=1|g" "/etc/wpa_supplicant/wpa_supplicant-${wifi_interface}.conf";
		wpa_supplicant -B -i "$wifi_interface" -c "/etc/wpa_supplicant/wpa_supplicant-${wifi_interface}.conf"
		systemctl restart wpa_supplicant.service
	fi
}

initDefaultOptions() {
	read -r -p "Output Device (default: /dev/sda):" Output_Device
	Output_Device=${Output_Device:-/dev/sda}
	echo "$Output_Device"
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

export -f install
export -f connectToWIFI
export -f initDefaultOptions
export -f initPartitionsAndMount

main "$@"; exit

