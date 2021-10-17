#!/usr/bin/bash

if [[ ! $UID -eq 0 ]] ; then
    echo -e "\033[31;1m Xahiş edirik root ilə açın ! \033[:0m"
    exit 1
fi

echo """


  _____  _____  ____             _      __  __          
 |_   _|/ ____|/ __ \      /\   | |    |  \/  |   /\    
   | | | (___ | |  | |    /  \  | |    | \  / |  /  \   
   | |  \___ \| |  | |   / /\ \ | |    | |\/| | / /\ \  
  _| |_ ____) | |__| |  / ____ \| |____| |  | |/ ____ \ 
 |_____|_____/ \____/  /_/    \_\______|_|  |_/_/    \_\
                                                        
                                                        

        PacPERRO OS tərəfindən hazırlanmış
                iso alma programı

Saytımız: https://pacperro-os.github.io
"""

echo """ Scriptləri avtomatik çalışdırmaq üçün:
          1) ./avtomatik-çalışdır.sh

"""

read -s -p "'./dəyişikliklər.sh' faylı çalışdırılacaqdır. Davam etmək üçün ENTER düyməsinə basın"
chmod +x dəyişikliklər.sh
if ! bash dəyişikliklər.sh;
then
  echo "dəyişikliklərin qeyd olunduğu fayl tapılmadı"
else
  echo ""
fi

read -s -p "ISO alınmağa başlanacaqdır. Davam etməzdən əvvəl sistemdə istədiyiniz dəyişiklikləri edib sonra davam edə bilərsiniz"
read -p "İstifadəçi Adınız: " user_ad
cp -prf /home/$user_ad/.config /etc/skel
cp -prf /home/$user_ad/.bash_logout /etc/skel
cp -prf /home/$user_ad/.bashrc /etc/skel
cp -prf /home/$user_ad/.profile /etc/skel

read -p "Sistemizin Adı: " s_ad
read -p "Sisteminizin şifrəsi: " sifre
# ISO Alma prosesi
set -ex

#overlayfs mount
mount -t tmpfs tmpfs /tmp || true
mkdir -p /tmp/work/source /tmp/work/a /tmp/work/b /tmp/work/target /tmp/work/empty \
         iso/live/ iso/boot/grub/|| true
touch /tmp/work/empty-file
umount -v -lf -R /tmp/work/* || true
mount --bind / /tmp/work/source
mount -t overlay -o lowerdir=/tmp/work/source,upperdir=/tmp/work/a,workdir=/tmp/work/b overlay /tmp/work/target

#resolv.conf fix
export rootfs=/tmp/work/target
rm -f $rootfs/etc/resolv.conf || true
echo "nameserver 1.1.1.1" > $rootfs/etc/resolv.conf

#live-boot quraşdırma
chroot $rootfs apt install live-config live-boot -y
chroot $rootfs apt autoremove -y
echo -e "$sifre\n$sifre\n" | chroot $rootfs passwd

#mount empty file and directories
for i in dev sys proc run tmp root media mnt; do
    mount -v --bind /tmp/work/empty $rootfs/$i
done

#istifadəçi silinməsi
for u in $(ls /home/) ; do
    chroot $rootfs userdel -fr $u || true
done

mount --bind /tmp/work/empty-file $rootfs/etc/fstab

#rootfs təmizləmə
find $rootfs/var/log -type f | xargs rm -f
chroot $rootfs apt clean -y

#squashfs yaratma
if [[ ! -f iso/live/filesystem.squashfs ]] ; then
    mksquashfs $rootfs iso/live/filesystem.squashfs -comp gzip -wildcards
fi

#grub faylı yazdırma
grub=iso/boot/grub/grub.cfg
echo "insmod all_video" > $grub
echo "set timeout=3" >> $grub
echo "set timeout_style=menu" >> $grub
dist=$(cat /etc/os-release | grep ^PRETTY_NAME | cut -f 2 -d '=' | head -n 1 | sed 's/\"//g')
for k in $(ls /boot/vmlinuz-*) ; do
    ver=$(echo $k | sed "s/.*vmlinuz-//g")
    if [[ -f /boot/initrd.img-$ver ]] ; then
        cp -f $rootfs/boot/vmlinuz-$ver iso/boot
        cp -f $rootfs/boot/initrd.img-$ver iso/boot
        if [[ -f $rootfs/install ]] ; then
            echo "menuentry \"Install $dist ($ver)\" {" >> $grub
            echo "    linux /boot/vmlinuz-$ver boot=live init=/install" >> $grub
            echo "    initrd /boot/initrd.img-$ver" >> $grub
            echo "}" >> $grub
        fi
        echo "menuentry "$dist run live" {" >> $grub
        echo "    linux /boot/vmlinuz-$ver boot=live live-config quiet splash" >> $grub
        echo "    initrd /boot/initrd.img-$ver" >> $grub
        echo "}" >> $grub
    fi
done

#umount all
umount -v -lf -R /tmp/work/* || true

# iso yaratma
grub-mkrescue iso/ -o PacPERRO-OS.iso