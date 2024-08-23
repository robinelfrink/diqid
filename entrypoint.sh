#!/bin/sh

# Create image to be mounted at /var/lib/docker
DOCKER_VOLUME_FILE=${DOCKER_VOLUME_FILE:-/tmp/var-lib-docker-${RANDOM}.qcow2}
if [ ! -f ${DOCKER_VOLUME_FILE} ]; then
    qemu-img create -q -f qcow2 ${DOCKER_VOLUME_FILE} ${DOCKER_VOLUME_SIZE}
fi

# Abuse the /dev tmpfs mount for temporary files
mkdir -p /tmp

# Start QEMU, using this container's root filesystem
qemu-system-x86_64 -smp 1 -m ${MEMORY} -nodefaults \
    -no-reboot -no-user-config -nographic -display none \
    -kernel /boot/vmlinuz-virt -initrd /boot/initramfs-virt \
    -append "root=rootfs ro rootfstype=9p rootflags=trans=virtio console=ttyS0 nomodeset" \
    `# Console` \
    -chardev socket,path=/tmp/console.sock,server=on,wait=off,logfile=/tmp/qemu.log,id=console \
    -serial chardev:console \
    `# PID` \
    -pidfile /tmp/qemu.pid \
    `# Root filesystem, from the main container` \
    -virtfs local,path=/,mount_tag=rootfs,security_model=none,multidevs=remap \
    `# Docker disk` \
    -drive file=${DOCKER_VOLUME_FILE},format=qcow2,if=virtio,cache=writeback \
    `# Network interface` \
    -nic user,model=virtio-net-pci,hostfwd=tcp::2375-:2375 \
    `# Guest agent socket` \
    -device virtio-serial \
    -chardev socket,path=/tmp/qga.sock,server=on,wait=off,id=qga0 \
    -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
    `# Daemonize on startup` \
    -daemonize

# Wait for QEMU
echo -n "Waiting for QEMU..."
TIMEOUT=${QEMU_TIMEOUT_START}
while [ "${TIMEOUT}" -gt 0 -a ! -f /tmp/qemu.pid ]; do
    TIMEOUT=$((${TIMEOUT}-1))
    echo -n "."
    sleep 1
done
if [ ${TIMEOUT} -le 0 ]; then
    echo " [TIMEOUT]"
    exit 1
fi
echo " [OK]"

# Wait for docker
echo -n "Waiting for dockerd..."
TIMEOUT=${DOCKER_TIMEOUT_START}
while [ "${TIMEOUT}" -gt 0 -a "$(wget --timeout 1 --quiet --output-document - http://127.0.0.1:2375/_ping 2>/dev/null)" != "OK" ]; do
    TIMEOUT=$((${TIMEOUT}-1))
    echo -n "."
    sleep 1
done
if [ ${TIMEOUT} -le 0 ]; then
    echo " [TIMEOUT]"
    exit 1
fi
echo " [OK]"

# Run command
if [ "$#" -gt 0 ]; then
    $@
else
    sh
fi

# Stop QEMU
echo -n "Waiting for QEMU to shutdown..."
echo '{ "execute": "guest-shutdown" }' | nc local:/tmp/qga.sock
PID=$(cat /tmp/qemu.pid)
TIMEOUT=${QEMU_TIMEOUT_STOP}
while [ "${TIMEOUT}" -gt 0 -a -d /proc/${PID} ]; do
    TIMEOUT=$((${TIMEOUT}-1))
    echo -n "."
    sleep 1
done
if [ "${TIMEOUT}" -le 0 ]; then
    echo " timeout, ignoring [OK]"
else
    echo " [OK]"
fi

# Remove docker volume image
DOCKER_VOLUME_REMOVE=${DOCKER_VOLUME_REMOVE:-true}
if [ ${DOCKER_VOLUME_REMOVE} != "false" ]; then
    rm -f ${DOCKER_VOLUME_FILE}
fi
