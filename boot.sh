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

# Partitionnement avec gdisk
echo "Partitionnement du disque..."
echo -e "o\nn\n1\n\n+515M\nef00\nn\n2\n\n\n8e00\nw\ny" | gdisk $disk

# Formatage des partitions
echo "🔍 Formatage des partitions..."
mkfs.vfat -F32 ${disk}1
mkfs.ext4 ${disk}2

# Montage des partitions
echo "Montage des partitions..."
mount ${disk}2 /mnt
mkdir -p /mnt/boot
mount ${disk}1 /mnt/boot

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

# GRUB avec EFI et VirtualBox
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch_grub
grub-mkconfig -o /boot/grub/grub.cfg

# SSH configuration (Port 42, Key-based only)
sed -i 's/#Port 22/Port 42/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Activer les services
systemctl enable NetworkManager
systemctl enable sddm

# Créer les utilisateurs et groupes
useradd -m -G asso,Hogwarts -s /bin/bash $username_turban
useradd -m -G managers,Hogwarts -s /bin/bash $username_dumbledore

# Parrot OS /home auto-mount
mkdir -p /mnt/parrot_home
echo "/dev/sdb2 /home ext4 defaults 0 2" >> /etc/fstab

EOF

# Fin
umount -R /mnt
echo "🔍 Vérification finale des partitions montées..."
lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT $disk
echo "Installation terminée. Redémarrage dans 5 secondes..."
sleep 5
reboot
