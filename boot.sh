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

# Partitionnement
echo "Partitionnement du disque..."
parted $disk -- mklabel gpt
parted $disk -- mkpart ESP fat32 1MiB 401MiB
parted $disk -- set 1 esp on
parted $disk -- mkpart primary ext4 401MiB 15.401GiB
parted $disk -- mkpart primary ext4 15.401GiB 20.401GiB
parted $disk -- mkpart primary linux-swap 20.401GiB 20.901GiB
mkfs.fat -F32 ${disk}1
mkfs.ext4 ${disk}2
mkfs.ext4 ${disk}3
mkswap ${disk}4
swapon ${disk}4

# Montage
echo "Montage des partitions..."
mount ${disk}2 /mnt
mkdir -p /mnt/boot/efi
mount ${disk}1 /mnt/boot/efi
mkdir -p /mnt/home
mount ${disk}3 /mnt/home

# Installation de base
echo "Installation de base..."
pacstrap /mnt base linux linux-firmware

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
pacman -S grub efibootmgr networkmanager network-manager-applet dialog wpa_supplicant mtools dosfstools base-devel linux-headers avahi xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bash-completion openssh rsync reflector plasma-meta sddm

# GRUB
mkdir -p /boot/efi
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# Vérification et ajout avec efibootmgr
if ! efibootmgr | grep -q "GRUB"; then
    echo "Ajout de GRUB à la liste de démarrage UEFI..."
    efibootmgr --create --disk $disk --part 1 --label "Arch Linux" --loader \EFI\GRUB\grubx64.efi
fi

# Création du chargeur par défaut pour UEFI
mkdir -p /boot/efi/EFI/Boot
cp /boot/efi/EFI/GRUB/grubx64.efi /boot/efi/EFI/Boot/bootx64.efi

# Diagnostic UEFI
echo "Diagnostic des entrées UEFI :"
efibootmgr

echo "Contenu de la partition EFI :"
ls -R /boot/efi

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
echo "Installation terminée. Redémarrage dans 5 secondes..."
