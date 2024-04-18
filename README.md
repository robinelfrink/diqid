# Docker-in-QEMU-in-Docker

Run docker containers in a virtual machine, using QEMU. This makes it possible
possible to run privileged containers within unpivileged containers.

## Example

```shell
$ docker run --interactive --tty --rm --name diqid --user 1000:1000 \
      ghcr.io/robinelfrink/diqid \
      docker run --interactive --tty --rm --privileged --name debian \
          debian debian:bookworm-slim

Waiting for QEMU... [OK]
Waiting for dockerd........................................................... [OK]
Unable to find image 'debian:bookworm-slim' locally
bookworm-slim: Pulling from library/debian
13808c22b207: Pull complete 
Digest: sha256:3d5df92588469a4c503adbead0e4129ef3f88e223954011c2169073897547cac
Status: Downloaded newer image for debian:bookworm-slim
root@4c903fbe03a0:/#
```

## Configuration

### Memory size

The virtual machine's memory can be changed from the default 1GB by setting the
variable `MEMORY` to, for example, 4GB.

### Docker volume

The inner docker daemon may need a lot of room for it's overlay images. The
default configuration is to create a disk image in memory (via tmpfs). If you
need more space you may set values to write it to local storage. You may even
provide your own qcow2 image and prevent it from being removed.

Example:

```shell
$ docker run --interactive --tty --volume $(pwd):/scratch \
      --env DOCKER_VOLUME_SIZE=6G \
      --env DOCKER_VOLUME_FILE=/scratch/docker.qcow2 \
      --env DOCKER_VOLUME_REMOVE=false \
      ghcr.io/robinelfrink/diqid \
      docker run --interactive --tty alpine
  Waiting for QEMU... [OK]
  Waiting for dockerd.......................................................... [OK]
  Unable to find image 'alpine:latest' locally
  latest: Pulling from library/alpine
  4abcf2066143: Pull complete 
  Digest: sha256:c5b1261d6d3e43071626931fc004f70149baeba2c8ec672bd4f27761f8e1ad6b
  Status: Downloaded newer image for alpine:latest
  / #
```

## Console

If needed, the QEMU console is available through a socket in the main
container. When the virtual machine is fully booted, it will show a login
prompt where you can login with user `root` and no password:

```shell
$ docker exec --interactive --tty diqid \
      socat STDIO,cfmakeraw,rawer,escape=0x1d UNIX:/tmp/console.sock
[... kernel boot messages ...]
diqid login: root
Welcome to Alpine!

The Alpine Wiki contains a large amount of how-to guides and general
information about administrating Alpine systems.
See <https://wiki.alpinelinux.org/>.

You can setup the system with the command: setup-alpine

You may change this message by editing /etc/motd.

diqid:~# 
```

The flag `escape=0x1d` makes it possible to disconnect from the socket using
`^]`.

## Credits

DiQiD is inspired by [diuid](https://github.com/weber-software/diuid) and
[dinv](https://github.com/Pusnow/dinv).
