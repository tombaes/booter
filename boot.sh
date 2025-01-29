#!/bin/bash

# Variables
disk="/dev/sda" # Disque principal
hostname="client_${USER}"
username_turban="turban"
username_dumbledore="dumbledore"
locale="en_US.UTF-8"
keymap="fr"
timezone="Europe/Paris"

# Mise à jour de l'heure
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc

# Partitionnement avec LVM
echo "Partitionnement du disque..."
parted $disk -- mklabel msdos
parted $disk -- mkpart primary ext4 1MiB 35GiB
pvcreate ${disk}1
vgcreate vg_arch ${disk}1
lvcreate -L 500M -n lv_boot vg_arch
lvcreate -L 30G -n lv_root vg_arch
lvcreate -L 4G -n lv_swap vg_arch
lvcreate -l 100%FREE -n lv_home vg_arch

# Formatage des partitions
mkfs.ext4 /dev/vg_arch/lv_root
mkfs.ext4 /dev/vg_arch/lv_home
mkfs.ext4 /dev/vg_arch/lv_boot
mkswap /dev/vg_arch/lv_swap
swapon /dev/vg_arch/lv_swap

# Montage des partitions
echo "Montage des partitions..."
mount /dev/vg_arch/lv_root /mnt
mkdir -p /mnt/boot
mount /dev/vg_arch/lv_boot /mnt/boot
mkdir -p /mnt/home
mount /dev/vg_arch/lv_home /mnt/home

# Installation de base
echo "Installation de base..."
pacstrap /mnt base linux linux-firmware lvm2

echo "Génération du fichier fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Configuration du système
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc

# Locales
echo "$locale UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$locale" > /etc/locale.conf
echo "KEYMAP=$keymap" > /etc/vconsole.conf

# Hostname et hosts
echo "$hostname" > /etc/hostname
cat <<EOT >> /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain $hostname
EOT

# Installation de base supplémentaire
pacman -S grub efibootmgr networkmanager network-manager-applet dialog wpa_supplicant mtools dosfstools base-devel linux-headers avahi xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bash-completion openssh rsync reflector plasma-meta sddm lvm2

# GRUB avec LVM
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P
mkdir -p /boot/efi
grub-install --target=i386-pc --recheck $disk
grub-mkconfig -o /boot/grub/grub.cfg

# Vérification et ajout avec efibootmgr
if ! efibootmgr | grep -q "GRUB"; then
    echo "Ajout de GRUB à la liste de démarrage UEFI..."
    efibootmgr --create --disk $disk --part 1 --label "Arch Linux" --loader \EFI\GRUB\grubx64.efi
fi

# Activer les services
systemctl enable NetworkManager
systemctl enable sddm

# Créer les utilisateurs et groupes
useradd -m -G asso,Hogwarts -s /bin/bash $username_turban
useradd -m -G managers,Hogwarts -s /bin/bash $username_dumbledore
echo "Mot de passe pour $username_turban :"
passwd $username_turban
echo "Mot de passe pour $username_dumbledore :"
passwd $username_dumbledore

EOF

# Fin
umount -R /mnt
