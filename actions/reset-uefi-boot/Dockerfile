FROM ubuntu:20.04

RUN apt-get update && \
    apt-get install -y \
        efibootmgr && \
    rm -rf /var/lib/apt/lists/*

COPY --chmod=755 entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]