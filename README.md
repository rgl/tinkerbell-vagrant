This is a [Vagrant](https://www.vagrantup.com/) Environment for playing with [Tinkerbell](https://tinkerbell.org/) for provisioning AMD64 and ARM64 (e.g. Raspberry Pi) machines.

# Usage

This `provisioner` environment is essentially running all the Tinkerbell [components](https://tinkerbell.org/components/) inside a single virtual machine.

In order for it to work you need to connect the `provisioner` virtual network to a physical network that reaches the physical machines.

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

Build and install the [Ubuntu Linux vagrant box](https://github.com/rgl/ubuntu-vagrant).

Build [Debian OSIE](https://github.com/rgl/tinkerbell-debian-osie) in `../tinkerbell-debian-osie`.

Optionally, build and install the following vagrant boxes (which must be using
the UEFI variant):

* [Debian](https://github.com/rgl/debian-vagrant)
* [Proxmox VE](https://github.com/rgl/proxmox-ve)
* [Ubuntu](https://github.com/rgl/ubuntu-vagrant)
* [Windows 2022](https://github.com/rgl/windows-vagrant)

Login into docker hub to have a [higher rate limits](https://www.docker.com/increase-rate-limits).

Launch the `provisioner` with:

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

You can see the worker and action logs from Grafana Explore (its address is displayed at the end of the provisioning).

From within the worker machine, you can query the metadata endpoint:

**NB** this endpoint returns the data set in the `TODO` field of the particular worker `hardware` document.

```bash
metadata_url="$(cat /proc/cmdline | tr ' ' '\n' | awk '/^tinkerbell=(.+)/{print "$1:50061/metadata"}')"
wget -qO- "$metadata_url"
```

Then repeat the process with the `uefi` worker machine.

To execute a more realistic workflow, you can install one of the following:

```bash
provision-workflow debian        uefi && watch-hardware-workflows uefi
provision-workflow flatcar-linux uefi && watch-hardware-workflows uefi
provision-workflow proxmox-ve    uefi && watch-hardware-workflows uefi
provision-workflow ubuntu        uefi && watch-hardware-workflows uefi
provision-workflow windows-2022  uefi && watch-hardware-workflows uefi
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

print(tabulate(sorted(info()), headers=('ContainerName', 'ImageName', 'ImageId')))
EOF
```

At the time of writing these were the containers running by default:

```plain
ContainerName                        ImageName                                 ImageId
-----------------------------------  ----------------------------------------  -----------------------------------------------------------------------
/compose-boots-1                     10.3.0.2/debian-boots                     sha256:397e3206222130ada624953220e8cb38c66365a4e31df7ce808f639c9a141599
/compose-db-1                        postgres:14-alpine                        sha256:eb82a397daaf176f244e990aa6f550422a764a88759f43e641c3a1323953deb7
/compose-hegel-1                     quay.io/tinkerbell/hegel:sha-89cb9dc8     sha256:23c22f0bb8779fb4b0fdab8384937c54afbbed6b45aefb3554f2d54cb2c7cffa
/compose-images-to-local-registry-1  quay.io/containers/skopeo:latest          sha256:9f5c670462ec0dc756fe52ec6c4d080f62c01a0003b982d48bb8218f877a456a
/compose-osie-bootloader-1           nginx:alpine                              sha256:b46db85084b80a87b94cc930a74105b74763d0175e14f5913ea5b07c312870f8
/compose-osie-work-1                 bash:4.4                                  sha256:bc8b0716d7386a05b5b3d04276cc7d8d608138be723fbefd834b5e75db6a6aeb
/compose-registry-1                  registry:2.7.1                            sha256:b8604a3fe8543c9e6afc29550de05b36cd162a97aa9b2833864ea8a5be11f3e2
/compose-registry-auth-1             httpd:2                                   sha256:ad17c88403e2cedd27963b98be7f04bd3f903dfa7490586de397d0404424936d
/compose-tink-cli-1                  quay.io/tinkerbell/tink-cli:sha-3743d31e  sha256:8c90de15e97362a708cde2c59d3a261f73e3a4242583a54222b5e18d4070acaf
/compose-tink-server-1               quay.io/tinkerbell/tink:sha-3743d31e      sha256:fb21c42c067588223b87a5c1f1d9b2892f863bfef29ce5fcd8ba755cfa0a990b
/compose-tink-server-migration-1     quay.io/tinkerbell/tink:sha-3743d31e      sha256:fb21c42c067588223b87a5c1f1d9b2892f863bfef29ce5fcd8ba755cfa0a990b
/compose-tls-gen-1                   cfssl/cfssl                               sha256:655abf144edde793a3ff1bc883cc82ca61411efb35d0d403a52f202c9c3cd377
/compose_tls-gen_run_67135735bbb3    cfssl/cfssl                               sha256:655abf144edde793a3ff1bc883cc82ca61411efb35d0d403a52f202c9c3cd377
/grafana                             grafana/grafana:8.2.5                     sha256:ddfae340d0681fe1a10582b06a2e8ae402196df9d429f0c1cefbe8dedca73cf0
/loki                                grafana/loki:2.4.1                        sha256:e3e722f23de3fdbb8608dcf1f8824dec62cba65bbfd5ab5ad095eed2d7c5872a
/meshcommander                       meshcommander                             sha256:aff2fc5004fb7f77b1a14a82c35af72e941fa33715e66c2eab5a5d253820d4bb
/portainer                           portainer/portainer-ce:2.9.2              sha256:a1c22f3d250fda6b357aa7d2148dd333a698805dd2878a08eb8f055ca8fb4e99
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

# Tinkerbell Debian OSIE

This vagrant environment uses the [Debian based OSIE](https://github.com/rgl/tinkerbell-debian-osie)
instead of the [LinuxKit (aka Hook) based OSIE](https://github.com/tinkerbell/hook).

You can login into it using the `osie` username and password.

# Raspberry Pi

Install the RPI4-UEFI-IPXE firmware into a sd-card as described at
https://github.com/rgl/rpi4-uefi-ipxe.

Insert an external disk (e.g. an USB flash drive or USB SSD) to use as target on
your Tinkerbell Action.

# Intel NUC

You can [use the Intel Integrator Toolkit ITK6.efi EFI application](https://downloadmirror.intel.com/29345/eng/Intel%20Integrator%20Toolkit%20User%20Guide.pdf) to set the SMBIOS properties.

# Troubleshooting

## Network Packet Capture

You can see all the network traffic from within the provisioner by running:

```bash
vagrant ssh-config provisioner >tmp/provisioner-ssh-config.conf
# NB this ignores the following ports:
#          22: SSH
#       16992: AMT HTTP
#       16994: AMT Redirection/TCP
#        4000: MeshCommander
wireshark -k -i <(ssh -F tmp/provisioner-ssh-config.conf provisioner 'sudo tcpdump -s 0 -U -n -i eth1 -w - not tcp port 22 and not port 16992 and not port 16994 and not port 4000')
```

You can also do it from the host by capturing traffic from the `br-rpi` or `vlan.rpi` interface.

## Database

Tinkerbell uses the [tinkerbell](https://github.com/tinkerbell/tink/tree/main/db/migration)
PostgreSQL database, you can access its console with, e.g.:

```bash
vagrant ssh provisioner
sudo -i
docker exec -i compose-db-1 psql -U tinkerbell -c '\dt'
docker exec -i compose-db-1 psql -U tinkerbell -c '\d hardware'
docker exec -i compose-db-1 psql -U tinkerbell -c 'select * from template'
docker exec -i compose-db-1 psql -U tinkerbell -c 'select * from workflow'
docker exec -i compose-db-1 psql -U tinkerbell -c 'select * from workflow_event order by created_at desc'
```

# Notes

* All workflow actions run as `--privileged` containers.

# Reference

* [IEEE 802.1Q VLAN Tutorial](http://www.microhowto.info/tutorials/802.1q.html)
* [ContainerSolutions/tinkerbell-rpi4-workflow](https://github.com/ContainerSolutions/tinkerbell-rpi4-workflow/tree/rpi4-tinkerbell-uefi)
