#!/bin/bash
set -euxo pipefail

# show the current mounts.
mount

# show the current uefi boot status (before modifying it).
efibootmgr -v

# delete all the boot options.
# NB if we do not set any boot option, the firmware will recover/discover them
#    at the next boot. unfortunately, in my test HP EliteDesk 800 35W G2
#    Desktop Mini, this requires an extra reboot, which messes with the
#    ethernet speed by switching it to 10 Mbps. so, we also execute grub to
#    install the boot option.
efibootmgr \
    | perl -n -e '/^Boot([0-9A-F]{4})/ && print "$1\n"' \
    | xargs -I% efibootmgr --quiet --delete-bootnum --bootnum %

# install grub (using the target os grub-install binary).
if [ -v BOOT_DEVICE ] && [ -v UEFI_DEVICE ] && [ -v ROOT_DEVICE ]; then
    # mount the root and uefi devices.
    target='/mnt/target'
    mkdir -p $target
    mount $ROOT_DEVICE $target
    mount $UEFI_DEVICE $target/boot/efi

    # bind mount the required mount points.
    required_mount_points=(dev proc sys sys/firmware/efi/efivars)
    for p in ${required_mount_points[@]}; do
        mount --bind "/$p" "$target/$p"
    done

    # install grub.
    chroot $target /usr/sbin/grub-install $BOOT_DEVICE

    # umount the required mount points (in reverse order).
    for (( i=${#required_mount_points[@]}-1; i>=0; i-- )); do
        p="${required_mount_points[i]}"
        umount "$target/$p"
    done

    # umount the root and uefi devices (in reverse order).
    umount $target/boot/efi
    umount $target
fi

# show the current uefi boot status.
efibootmgr -v
