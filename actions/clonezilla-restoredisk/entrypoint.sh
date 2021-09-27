#!/bin/bash
set -euxo pipefail

function die {
    echo -- "ERROR: $@"
    exit 1
}

if [ ! -v IMG_URL ]; then
    die 'The IMG_URL environment variable is not defined'
fi

if [ ! -v DEST_DEVICE ]; then
    die 'The DEST_DEVICE environment variable is not defined'
fi

CLONEZILLA_OCSROOT=/ocs
CLONEZILLA_IMAGE_NAME="$(basename "$IMG_URL")"
CLONEZILLA_IMAGE_MOUNT_POINT="$CLONEZILLA_OCSROOT/$CLONEZILLA_IMAGE_NAME"

# mount the image.
install -d $CLONEZILLA_IMAGE_MOUNT_POINT
case "$IMG_URL" in
    http:*)
        # NB clonezilla over httpdirfs is very slow.
        httpdirfs -o ro $IMG_URL $CLONEZILLA_IMAGE_MOUNT_POINT
        ;;
    nfs:*)
        mount \
            -t nfs4 \
            -o ro,noatime,nolock \
            "$(echo "$IMG_URL" | perl -n -e '/^nfs:\/\/(.+?)(\/.+)/ && print "$1:$2"')" \
            $CLONEZILLA_IMAGE_MOUNT_POINT
        ;;
    *)
        die 'Unsupported IMG_URL scheme'
        ;;
esac
find $CLONEZILLA_IMAGE_MOUNT_POINT

# show the mounts.
mount

# restore the image.
# NB we do not use --check-sha1sum because its too time consuming.
# TODO trim the free space.
ocs-sr \
    --batch \
    --nogui \
    --ocsroot $CLONEZILLA_OCSROOT \
    --skip-check-restorable-r \
    restoredisk \
    $CLONEZILLA_IMAGE_NAME \
    $(basename $DEST_DEVICE)

# umount the image.
umount $CLONEZILLA_IMAGE_MOUNT_POINT
