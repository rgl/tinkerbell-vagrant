FROM ubuntu:20.04

# install dependencies and parted for troubleshooting purposes.
# see toolset at https://github.com/flatcar-linux/init/blob/flatcar-master/bin/flatcar-install#L20
RUN apt-get update && \
    apt-get install -y \
        btrfs-progs \
        gawk \
        gpg \
        udev \
        wget \
        parted && \
    rm -rf /var/lib/apt/lists/*

# TODO have everything inside this container and do not go to the internet when installing flatcar?
#      NOPE instead we should mirror everything because the container will be
#      downloaded to the memory of the worker, which might not be enough. instead,
#      it should be streamed from the nginx server (like osie) to the disk.
#      flatcar-install -f file should do the trick to install.
#      where file is downloaded from https://${CHANNEL_ID}.release.flatcar-linux.net/${BOARD}
#      e.g. https://stable.release.flatcar-linux.net/amd64-usr/current/version.txt
#      e.g. https://stable.release.flatcar-linux.net/amd64-usr/current/flatcar_production_image.bin.bz2
# TODO https://github.com/flatcar-linux/init/issues/20
# see https://docs.flatcar-linux.org/os/installing-to-disk/
# see https://github.com/flatcar-linux/docs/blob/master/os/installing-to-disk.md
# see https://github.com/flatcar-linux/init/blob/flatcar-master/bin/flatcar-install
RUN wget \
        -qO /usr/local/bin/flatcar-install \
        https://raw.githubusercontent.com/flatcar-linux/init/flatcar-master/bin/flatcar-install && \
    chmod +x /usr/local/bin/flatcar-install
