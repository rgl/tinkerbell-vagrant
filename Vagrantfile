# configure the virtual machines network to use an already configured bridge.
# NB this must be used for connecting to the external switch.
$provisioner_bridge_name = 'br-rpi'
$provisioner_ip_address = '10.3.0.2'

# uncomment the next two lines to configure the virtual machines network
# to use a new private network that is only available inside the host.
# NB this must be used for NOT connecting to the external switch.
#$provisioner_bridge_name = nil
#$provisioner_ip_address = '10.11.12.2'

# to make sure the nodes are created sequentially, we
# have to force a --no-parallel execution.
ENV['VAGRANT_NO_PARALLEL'] = 'yes'

Vagrant.configure('2') do |config|
  config.vm.box = 'ubuntu-20.04-amd64'

  config.vm.provider :libvirt do |lv, config|
    lv.memory = 4*1024
    lv.cpus = 4
    lv.cpu_mode = 'host-passthrough'
    # lv.nested = true
    lv.keymap = 'pt'
    config.vm.synced_folder '.', '/vagrant', type: 'nfs', nfs_version: '4.2', nfs_udp: false
  end

  config.vm.define :provisioner do |config|
    config.vm.hostname = 'provisioner'
    if $provisioner_bridge_name
      config.vm.network :public_network,
        ip: $provisioner_ip_address,
        dev: $provisioner_bridge_name,
        mode: 'bridge',
        type: 'bridge'
  else
      config.vm.network :private_network,
        ip: $provisioner_ip_address,
        libvirt__dhcp_enabled: false,
        libvirt__forward_mode: 'none'
    end
    config.trigger.before :up do |trigger|
      trigger.run = {
        inline: '''bash -euc \'
file_paths=(
  ~/.ssh/id_rsa.pub
)
for file_path in "${file_paths[@]}"; do
  if [ -f $file_path ]; then
    mkdir -p tmp
    cp $file_path tmp
  fi
done
\'
'''
      }
    end
    config.vm.provision :shell, path: 'provision-base.sh'
    config.vm.provision :shell, path: 'provision-docker.sh'
    config.vm.provision :shell, path: 'provision-docker-compose.sh'
    config.vm.provision :shell, path: 'provision-portainer.sh'
    config.vm.provision :shell, path: 'provision-meshcommander.sh'
    config.vm.provision :shell, path: 'provision-tinkerbell.sh', args: [$provisioner_ip_address]
    config.vm.provision :shell, path: 'templates/provision.sh'
    config.vm.provision :shell, path: 'workers/provision.sh'
    config.vm.provision :shell, name: 'Summary', path: 'summary.sh', run: 'always'
  end

  ['bios', 'uefi'].each_with_index do |firmware, i|
    config.vm.define firmware do |config|
      config.vm.box = nil
      if $provisioner_bridge_name
        config.vm.network :public_network,
          dev: $provisioner_bridge_name,
          mac: "08002700000#{i+1}",
          mode: 'bridge',
          type: 'bridge',
          auto_config: false
      else
        config.vm.network :private_network,
          # NB this ip is not really used by the VM; its used by
          #    vagrant-libvirt to find the network to which it
          #    will attach this VM to.
          ip: $provisioner_ip_address,
          mac: "08002700000#{i+1}",
          auto_config: false
      end
      config.vm.provider :libvirt do |lv, config|
        lv.loader = '/usr/share/ovmf/OVMF.fd' if firmware == 'uefi'
        lv.memory = 4*1024
        # TODO when https://github.com/tinkerbell/hook/issues/84 is fixed, switch the bus to scsi.
        lv.storage :file, :size => '40G', :bus => 'virtio', :discard => 'unmap', :cache => 'unsafe'
        lv.boot 'hd'
        lv.boot 'network'
        lv.mgmt_attach = false
        lv.random :model => 'random'
        lv.graphics_type = 'spice'
        lv.video_type = 'virtio'
        # set some BIOS settings that will help us identify this particular machine.
        #
        #   QEMU                | Linux
        #   --------------------+----------------------------------------------
        #   type=1,manufacturer | /sys/devices/virtual/dmi/id/sys_vendor
        #   type=1,product      | /sys/devices/virtual/dmi/id/product_name
        #   type=1,version      | /sys/devices/virtual/dmi/id/product_version
        #   type=1,serial       | /sys/devices/virtual/dmi/id/product_serial
        #   type=1,sku          | dmidecode
        #   type=1,uuid         | /sys/devices/virtual/dmi/id/product_uuid
        #   type=3,manufacturer | /sys/devices/virtual/dmi/id/chassis_vendor
        #   type=3,family       | /sys/devices/virtual/dmi/id/chassis_type
        #   type=3,version      | /sys/devices/virtual/dmi/id/chassis_version
        #   type=3,serial       | /sys/devices/virtual/dmi/id/chassis_serial
        #   type=3,asset        | /sys/devices/virtual/dmi/id/chassis_asset_tag
        [
          'type=1,manufacturer=your vendor name here',
          'type=1,product=your product name here',
          'type=1,version=your product version here',
          'type=1,serial=your product serial number here',
          'type=1,sku=your product SKU here',
          "type=1,uuid=00000000-0000-4000-8000-00000000000#{i+1}",
          'type=3,manufacturer=your chassis vendor name here',
          #'type=3,family=1', # TODO why this does not work on qemu from ubuntu 18.04?
          'type=3,version=your chassis version here',
          'type=3,serial=your chassis serial number here',
          'type=3,asset=your chassis asset tag here',
        ].each do |value|
          lv.qemuargs :value => '-smbios'
          lv.qemuargs :value => value
        end
      end
    end
  end
end
