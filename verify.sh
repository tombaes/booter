#!/bin/bash

# Variables
disk="/dev/sda"

# Vérification de la présence du disque et des partitions
echo "🔍 Vérification des partitions sur $disk..."
lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT $disk

echo "\n🔍 Vérification de la table de partition GPT..."
if ! parted $disk print | grep -q "gpt"; then
    echo "❌ Erreur: Le disque $disk n'a pas de table de partition GPT."
    exit 1
fi

echo "\n🔍 Vérification des partitions EFI et système..."
if ! lsblk -o NAME,FSTYPE $disk | grep -q "vfat"; then
    echo "❌ Erreur: Aucune partition EFI (vfat) détectée sur $disk1."
    exit 1
fi
if ! lsblk -o NAME,FSTYPE $disk | grep -q "ext4"; then
    echo "❌ Erreur: Aucune partition root (ext4) détectée sur $disk."
    exit 1
fi

# Vérification du montage
echo "\n🔍 Vérification du montage des partitions..."
if mountpoint -q /mnt; then
    echo "✅ La partition root est déjà montée."
else
    echo "❌ Erreur: La partition root n'est pas montée."
fi
if mountpoint -q /mnt/boot/efi; then
    echo "✅ La partition EFI est déjà montée."
else
    echo "❌ Erreur: La partition EFI n'est pas montée."
fi

# Vérification de l'installation de GRUB
echo "\n🔍 Vérification de l'installation de GRUB..."
if [ -d /mnt/boot/efi/EFI/GRUB ]; then
    echo "✅ GRUB est présent dans la partition EFI."
else
    echo "❌ Erreur: GRUB n'est pas installé correctement."
fi

# Vérification des entrées UEFI
echo "\n🔍 Vérification des entrées UEFI..."
efibootmgr
if ! efibootmgr | grep -q "GRUB"; then
    echo "❌ Erreur: Aucune entrée UEFI GRUB trouvée. Vous devrez peut-être exécuter efibootmgr manuellement."
fi

# Vérification du contenu de la partition EFI
echo "\n🔍 Contenu de la partition EFI :"
ls -R /mnt/boot/efi
