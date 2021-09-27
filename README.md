This is a [Vagrant](https://www.vagrantup.com/) Environment for playing with [Tinkerbell](https://tinkerbell.org/) for provisioning Raspberry Pis.

# Usage

This `provisioner` environment is essentially running all the Tinkerbell [components](https://tinkerbell.org/components/) inside a single virtual machine.

In order for it to work you need to connect the `provisioner` virtual network to a physical network that reaches the Raspberry Pis.

I'm using Ubuntu 20.04 as the host, qemu/kvm/libvirt has the hypervisor, and a [tp-link tl-sg108e](https://www.tp-link.com/en/business-networking/easy-smart-switch/tl-sg108e/) switch.

**NB** You can also use this vagrant environment without the switch (see the [Vagrantfile](Vagrantfile)).

The network is connected as:

![](network.png)

The tp-link tl-sg108e switch is configured with [rgl/ansible-collection-tp-link-easy-smart-switch](https://github.com/rgl/ansible-collection-tp-link-easy-smart-switch) as:

![](tp-link-sg108e-802-1q-vlan-configuration.png)
![](tp-link-sg108e-802-1q-vlan-pvid-configuration.png)

**NB** this line of switches is somewhat insecure as, at least, its configuration protocol (UDP port 29808 and TCP port 80) uses clear text messages. For more information see [How I can gain control of your TP-LINK home switch](https://www.pentestpartners.com/security-blog/how-i-can-gain-control-of-your-tp-link-home-switch/) and [Information disclosure vulnerability in TP-Link Easy Smart switches](https://www.chrisdcmoore.co.uk/post/tplink-easy-smart-switch-vulnerabilities/).

The host network is configured by netplan with `/etc/netplan/config.yaml` as:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp3s0:
      link-local: []
      addresses:
        - 10.1.0.1/24
        - 192.168.0.254/24
  bridges:
    # NB this is equivalent of executing:
    #       ip link add name br-rpi type bridge
    #       ip addr flush dev br-rpi
    #       ip addr add dev br-rpi 10.3.0.1/24
    #       ip link set dev br-rpi up
    #       ip addr ls dev br-rpi
    #       ip -d link show dev br-rpi
    #       ip route
    # NB later, you can remove with:
    #       ip link set dev br-rpi down
    #       ip link delete dev br-rpi
    br-rpi:
      link-local: []
      addresses:
        - 10.3.0.1/24
      interfaces:
        - vlan.rpi
  vlans:
    vlan.wan:
      id: 2
      link: enp3s0
      link-local: []
      addresses:
        - 192.168.1.1/24
      gateway4: 192.168.1.254
      nameservers:
        addresses:
          # cloudflare+apnic public dns resolvers.
          # see https://en.wikipedia.org/wiki/1.1.1.1
          - "1.1.1.1"
          - "1.0.0.1"
          # google public dns resolvers.
          # see https://en.wikipedia.org/wiki/8.8.8.8
          #- "8.8.8.8"
          #- "8.8.4.4"
    # NB this is equivalent of executing:
    #       ip link add link enp3s0 vlan.rpi type vlan proto 802.1q id 2
    #       ip link set dev vlan.rpi up
    #       ip -d link show dev vlan.rpi
    # NB later, you can remove with:
    #       ip link set dev vlan.rpi down
    #       ip link delete dev vlan.rpi
    vlan.rpi:
      id: 3
      link: enp3s0
      link-local: []
```

**NB** For more information about VLANs see the [IEEE 802.1Q VLAN Tutorial](http://www.microhowto.info/tutorials/802.1q.html).

Build and install the [Ubuntu Linux base box](https://github.com/rgl/ubuntu-vagrant).

After the above is in place, launch the `provisioner` with:

```bash
# NB this takes about 30m in my machine. YMMV.
vagrant up --no-destroy-on-error --no-tty provisioner
```

Enter the `provisioner` machine, and tail the relevant logs with:

```bash
vagrant ssh provisioner
sudo -i
cd ~/tinkerbell-sandbox/deploy/compose
docker compose logs --follow tink-server boots nginx
```

In another terminal, launch the `uefi` worker machine with:

```bash
vagrant up --no-destroy-on-error --no-tty uefi
```

**NB** Alpine Linux OSIE: If the machine boots and nothing seems to happen, [workflow-helper](https://github.com/tinkerbell/osie/blob/master/apps/workflow-helper.sh) might have crashed. Login into the worker as `root` (no password needed) and check the [Alpine Linux Init System](https://wiki.alpinelinux.org/wiki/Alpine_Linux_Init_System) status with `rc-status`. If it appears as `crashed`, try to manually execute `workflow-helper` and go from there. You might also want to execute `docker images -a` and `docker ps -a`.

In another terminal, watch the workflow progress with:

```bash
vagrant ssh provisioner
sudo -i
watch-hardware-workflows uefi
```

You should eventually see something alike:

```
+----------------------+--------------------------------------+
| FIELD NAME           | VALUES                               |
+----------------------+--------------------------------------+
| Workflow ID          | dc2ff4c3-13b1-11ec-a4c5-0242ac1a0004 |
| Workflow Progress    | 100%                                 |
| Current Task         | hello-world                          |
| Current Action       | info                                 |
| Current Worker       | 00000000-0000-4000-8000-080027000001 |
| Current Action State | STATE_SUCCESS                        |
+----------------------+--------------------------------------+
+--------------------------------------+-------------+-------------+----------------+---------------------------------+---------------+
| WORKER ID                            | TASK NAME   | ACTION NAME | EXECUTION TIME | MESSAGE                         | ACTION STATUS |
+--------------------------------------+-------------+-------------+----------------+---------------------------------+---------------+
| 00000000-0000-4000-8000-080027000001 | hello-world | hello-world |              0 | Started execution               | STATE_RUNNING |
| 00000000-0000-4000-8000-080027000001 | hello-world | hello-world |              3 | finished execution successfully | STATE_SUCCESS |
| 00000000-0000-4000-8000-080027000001 | hello-world | info        |              0 | Started execution               | STATE_RUNNING |
| 00000000-0000-4000-8000-080027000001 | hello-world | info        |              0 | finished execution successfully | STATE_SUCCESS |
+--------------------------------------+-------------+-------------+----------------+---------------------------------+---------------+
```

**NB** After a workflow action is executed, `tink-worker` will not re-execute it, even if you reboot the worker. You must create a new workflow, e.g. `provision-workflow hello-world uefi && watch-hardware-workflows uefi`.

From within the worker machine, you can query the metadata endpoint:

**NB** this endpoint returns the data set in the `TODO` field of the partilar worker `hardware` document.

```bash
metadata_url="$(cat /proc/cmdline | tr ' ' '\n' | awk '/^tinkerbell=(.+)/{print "$1:50061/metadata"}')"
wget -qO- "$metadata_url"
```

Then repeat the process with the `uefi` worker machine.

To execute a more realistic workflow, you can install one of the following:

```bash
provision-workflow flatcar-linux uefi && watch-hardware-workflows uefi
```

See which containers are running in the `provisioner` machine:

```bash
vagrant ssh provisioner
sudo -i
# see https://docs.docker.com/engine/reference/commandline/ps/#formatting
python3 <<'EOF'
import io
import json
import subprocess
from tabulate import tabulate

def info():
  p = subprocess.Popen(
    ('docker', 'ps', '-a', '--no-trunc', '--format', '{{.ID}}'),
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT)
  for id in (l.rstrip("\r\n") for l in io.TextIOWrapper(p.stdout)):
    p = subprocess.Popen(
      ('docker', 'inspect', id),
      stdout=subprocess.PIPE,
      stderr=subprocess.STDOUT)
    for c in json.load(p.stdout):
      yield (c['Name'], c['Config']['Image'], c['Image'])

print(tabulate(info(), headers=('ContainerName', 'ImageName', 'ImageId')))
EOF
```

At the time of writing these were the containers running by default:

```plain
ContainerName                        ImageName                                 ImageId
-----------------------------------  ----------------------------------------  -----------------------------------------------------------------------
/compose_osie-bootloader_1           nginx:alpine                              sha256:513f9a9d8748b25cdb0ec6f16b4523af7bba216a6bf0f43f70af75b4cf7cb780
/compose_registry-ca-crt-download_1  alpine                                    sha256:14119a10abf4669e8cdbdff324a9f9605d99697215a0d21c360fe8dfa8471bab
/compose_hegel_1                     quay.io/tinkerbell/hegel:sha-9f5da0a8     sha256:1e32a53ea16153ac9c7b6f0eea4aa8956f748ed710d8b926b9257221e794c3b8
/compose_tink-cli_1                  quay.io/tinkerbell/tink-cli:sha-8ea8a0e5  sha256:c67d5bdf2f1dc5a7eebe1e31a73abe46c28bdafc11ead079688d94253c836ceb
/compose_boots_1                     quay.io/tinkerbell/boots:sha-94f43947     sha256:dbebee7b9680a291045eec5c38106bed47d68434b3f9486911af7c5f3011dcde
/compose_images-to-local-registry_1  quay.io/containers/skopeo:latest          sha256:4044537125418d051209b3f38c4a157cd77b6d0b39d7678f67110a76f991032b
/compose_tink-server_1               quay.io/tinkerbell/tink:sha-8ea8a0e5      sha256:7231517852e13257353e65ebe58d66eb949ecad5890188b7e050188e7ea05a7d
/compose_registry_1                  registry:2.7.1                            sha256:b2cb11db9d3d60af38d9d6841d3b8b053e5972c0b7e4e6351e9ea4374ed37d8c
/compose_tls-gen_1                   cfssl/cfssl                               sha256:655abf144edde793a3ff1bc883cc82ca61411efb35d0d403a52f202c9c3cd377
/compose_tink-server-migration_1     quay.io/tinkerbell/tink:sha-8ea8a0e5      sha256:7231517852e13257353e65ebe58d66eb949ecad5890188b7e050188e7ea05a7d
/compose_registry-auth_1             httpd:2                                   sha256:f34528d8e714f1b877711deafec0d957394a86987cbba54d924bc0a6e517a7ac
/compose_db_1                        postgres:10-alpine                        sha256:17ec9988ae216f69d9e6528aae17a9fce29a2b7951313de9a34802528116f2eb
/compose_osie-work_1                 bash:4.4                                  sha256:e9ae8cfa6bbca7b9790ab5ea66d619e3cf9df5d037f8969980d96193eef0a198
```

Those containers were started with docker compose and you can use it to
inspect the tinkerbell containers:

```bash
vagrant ssh provisioner
sudo -i
cd ~/tinkerbell-sandbox/deploy/compose
docker compose ps
docker compose logs -f
```

You can also use the [Portainer](https://github.com/portainer/portainer)
application at the address that is displayed after the vagrant environment
is launched (e.g. at `http://10.3.0.2:9000`).

# Tinkerbell Hook

This vagrant environment uses the [linuxkit based hook osie](https://github.com/tinkerbell/hook)
instead of the [alpine linux based osie](https://github.com/tinkerbell/osie).

In the osie you can execute the following troubleshooting commands:

```bash
alias l='ls -lF'
alias ll='l -a'
alias ctr='ctr -n services.linuxkit'
alias docker='ctr tasks exec --tty --exec-id shell docker docker'

# list the containers.
ctr containers ls

# list the tasks that are actually running in the containers.
ctr tasks ls

# list the processes running in the (tink-)docker container.
ctr task ps docker

# list the downloaded images and docker containers.
# NB to troubleshoot check the containers logs with docker logs.
docker images -a
docker ps -a
```

# Raspberry Pi

Tinkerbell boots and the rpi PXE client are not compatible with each-other and
as such we will not use the rpi PXE client at all, instead we will use
iPXE/UEFI.

Create a [iPXE/UEFI](https://github.com/rgl/raspberrypi-uefi-edk2-vagrant)
sd-card with [balenaEtcher](https://www.balena.io/etcher/), put it in your pi
and power it on.

Press `ESC` to enter the UEFI setup, then:

1. Select `Device Manager`.
2. Select `Raspberry Pi Configuration`.
3. Select `Advanced Configuration`.
4. Select `System Table Selection`.
5. Select `Devicetree`.
6. Press `F10`.
7. Press `ESC` until you reach the main menu.
8. Select `Continue` to boot to the iPXE prompt.

At the iPXE boot prompt type the following command to boot tinkerbell osie:

```
chain --autofree http://${next-server}/auto.ipxe
```

The `auto.ipxe` script is handled by tinkerbell boots in:

* [job/http.go#Job.ServeFile](https://github.com/tinkerbell/boots/blob/10b79956134ae3badae65a668614b3e6b332ca3b/job/http.go#L15-L25)
* [job/ipxe.go#Job.serveBootScript](https://github.com/tinkerbell/boots/blob/a776430e1230851a873d9c5a945a8b5c8506f09f/job/ipxe.go#L47-L68)
* [installers/osie/main.go#install](https://github.com/tinkerbell/boots/blob/139cc4cdb1f9537acd3eaeac536e0d86f6df3624/installers/osie/main.go#L23-L36)

# Intel NUC

You can [use the Intel Integrator Toolkit ITK6.efi EFI application](https://downloadmirror.intel.com/29345/eng/Intel%20Integrator%20Toolkit%20User%20Guide.pdf) to set the SMBIOS properties.

# Troubleshooting

## Network Packet Capture

You can see all the network traffic from within the provisioner by running:

```bash
vagrant ssh-config provisioner >tmp/provisioner-ssh-config.conf
wireshark -k -i <(ssh -F tmp/provisioner-ssh-config.conf provisioner 'sudo tcpdump -s 0 -U -n -i eth1 -w - not tcp port 22')
```

You can also do it from the host by capturing traffic from the `br-rpi` or `vlan.rpi` interface.

## Database

Tinkerbell uses the [tinkerbell](https://github.com/tinkerbell/tink/blob/master/deploy/db/tinkerbell-init.sql)
PostgreSQL database, you can access its console with, e.g.:

```bash
vagrant ssh provisioner
sudo -i
docker exec -i compose_db_1 psql -U tinkerbell -c '\dt'
docker exec -i compose_db_1 psql -U tinkerbell -c '\d hardware'
docker exec -i compose_db_1 psql -U tinkerbell -c 'select * from template'
docker exec -i compose_db_1 psql -U tinkerbell -c 'select * from workflow'
docker exec -i compose_db_1 psql -U tinkerbell -c 'select * from workflow_event order by created_at desc'
```

# Notes

* All workflow actions run as `--privileged` containers.

# Reference

* [IEEE 802.1Q VLAN Tutorial](http://www.microhowto.info/tutorials/802.1q.html)
* [ContainerSolutions/tinkerbell-rpi4-workflow](https://github.com/ContainerSolutions/tinkerbell-rpi4-workflow/tree/rpi4-tinkerbell-uefi)
