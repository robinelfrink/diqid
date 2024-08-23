FROM alpine:3.19

# Install base system
RUN apk add --no-cache alpine-base coreutils docker e2fsprogs linux-virt \
    qemu-guest-agent qemu-img qemu-system-x86_64 socat util-linux virtiofsd

# Configure the machine
RUN printf "auto lo\niface lo inet loopback\n\nauto eth0\niface eth0 inet dhcp\n" \
        > /etc/network/interfaces && \
    printf "DOCKER_OPTS=\"-H unix:///var/run/docker.sock -H tcp://0.0.0.0:2375\"\n" \
        >> /etc/conf.d/docker && \
    mkdir -p /diqid && \
    printf "tmpfs /tmp tmpfs rw,nosuid,nodev 0 1\n" > /etc/fstab && \
    printf "tmpfs /var/log tmpfs rw,nosuid,nodev 0 1\n" >> /etc/fstab && \
    ln -s /etc/init.d/agetty /etc/init.d/agetty.ttyS0 && \
    mkinitfs -F "9p base ext4 keymap kms mmc nvme raid scsi virtio" $(ls /lib/modules/) && \
    chmod 664 /boot/initramfs-virt && \
    passwd -d root && chmod 644 /etc/shadow

# Copy scripts
COPY init/diqid-prepare /etc/init.d/
COPY init/diqid-run /etc/init.d/
COPY entrypoint.sh /

# Set up runlevels
RUN rc-update add agetty.ttyS0 default && \
    rc-update add docker default && \
    rc-update add diqid-prepare default && \
    rc-update add diqid-run default && \
    rc-update add qemu-guest-agent default && \
    rc-update add modules boot && \
    rc-update add sysctl boot && \
    rc-update add syslog boot && \
    rc-update add mount-ro shutdown && \
    rc-update add killprocs shutdown && \
    rc-update add savecache shutdown

# Make sure /var/lib/docker exists
RUN mkdir /var/lib/docker

# Configurable settings
ENV MEMORY 1G
ENV DOCKER_VOLUME_SIZE 1G
ENV DOCKER_VOLUME_FILE ""
ENV DOCKER_VOLUME_REMOVE "true"
ENV DOCKER_TIMEOUT_START=300
ENV QEMU_TIMEOUT_START=60
ENV QEMU_TIMEOUT_STOP=30

# Run
ENV DOCKER_HOST="tcp://127.0.0.1:2375"
WORKDIR /workdir
ENTRYPOINT ["/entrypoint.sh"]
