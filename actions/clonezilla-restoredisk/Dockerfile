FROM debian:bullseye-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        efibootmgr \
        nfs-common \
        httpdirfs \
        clonezilla \
        partclone \
        parted \
        procps \
        udev \
        lvm2 \
        zstd && \
    rm -rf /var/lib/apt/lists/*

COPY --chmod=755 entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]