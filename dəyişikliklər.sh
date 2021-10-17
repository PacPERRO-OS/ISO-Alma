#!/usr/bin/bash

# Deponu güncəlləyək
apt-get update

# 17g Linux Installer quraşdırma
dpkg -i debian-paketləri/17g_1.0_all.deb
apt-get install -f -y

# ISO alma tool'larını yükləmək
apt install grub-pc-bin grub-efi squashfs-tools xorriso mtools curl -y

# Yükləmək istədiyiniz paketlər 
apt-get install gjs