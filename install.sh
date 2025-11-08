#!/bin/bash
set -euo pipefail

# タイムゾーンやホスト名などの変数
HOSTNAME="frankve"
TIMEZONE="Asia/Tokyo"
ROOT_PASSWORD="root"

# ディスクの初期化 (警告: 既存データは消えます)
parted /dev/nvme0n1 --script mklabel gpt
parted /dev/nvme0n1 --script mkpart ESP fat32 1MiB 512MiB
parted /dev/nvme0n1 --script set 1 boot on
parted /dev/nvme0n1 --script mkpart primary ext4 512MiB 100%

# フォーマット
mkfs.fat -F32 /dev/nvme0n1p1
mkfs.ext4 /dev/nvme0n1p2

# マウント
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot

# ベースシステムのインストール
pacstrap /mnt base linux linux-firmware nano qemu virt-manager libvirt dnsmasq bridge-utils iptables lxc lxd cockpit cockpit-machines networkmanager

# fstab生成
genfstab -U /mnt >> /mnt/etc/fstab

# chroot環境での設定
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

echo "root:$ROOT_PASSWORD" | chpasswd

# ブートローダー (systemd-boot)
bootctl install
EOF
arch-chroot /mnt systemctl enable libvirtd
arch-chroot /mnt systemctl enable cockpit.socket
arch-chroot /mnt systemctl enable NetworkManager

echo "インストール完了！再起動してください。"
