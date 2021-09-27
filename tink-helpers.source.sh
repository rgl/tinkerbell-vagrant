source ~/tinkerbell-sandbox/deploy/compose/.env

TINKERBELL_STATE_WEBROOT_PATH="$HOME/tinkerbell-sandbox/deploy/compose/state/webroot"

function tink {
  # NB its unfortunate that this will output the following to stderr:
  #       Flag based client configuration failed with err: fetch cert: Get "http://127.0.0.1:42114/cert"
  #    but there is no universal workaround for it... we have to wait
  #    for an upstream fix.
  # see https://github.com/tinkerbell/tink/issues/524
  docker exec -i compose_tink-cli_1 tink "$@"
}

# recreate the given template and workflow.
# e.g. provision-workflow hello-world bios
function provision-workflow {
  local template_name="$1"; shift
  local hardware_hostname="$1"; shift || true
  bash "/vagrant/templates/$template_name/provision.sh" \
    && bash "/vagrant/templates/$template_name/provision-workflow.sh" "$hardware_hostname" "$@"
}

function delete-template {
  local template_name="$1"
  tink template get --format json | jq -r --arg name "$template_name" '.data[] | select(.name==$name) | .id' | while read template_id; do
    tink template delete "$template_id"
  done
}

function get-hardware-workflows {
  docker exec -i compose_db_1 psql -U tinkerbell -A -t <<EOF
select
  w.workflow_id, h.hardware_id, h.hostname, h.mac
from
  (
    select
      id as workflow_id,
      devices->>'device_1' as mac
    from
      workflow
    where
      deleted_at is null
  ) as w
inner join
  (
    select
      id as hardware_id,
      jsonb_array_elements(data->'network'->'interfaces')->'dhcp'->>'mac' as mac,
      jsonb_array_elements(data->'network'->'interfaces')->'dhcp'->>'hostname' as hostname
    from
      hardware
  ) as h
on
  w.mac=h.mac
where
  h.hostname='$1'
EOF
}

# delete the workflows associated with the hardware.
# NB we do not need to really delete the existing workflows. they are only
#    applied once. but deleting them makes things easier to follow.
# NB workflows are not really deleted from the database, they are only
#    marked as deleted.
function delete-hardware-workflows {
  local hardware_hostname="$1"
  get-hardware-workflows "$hardware_hostname" | awk -F '|' '{print $1}' | while read workflow_id; do
    tink workflow delete "$workflow_id"
  done
}

function watch-hardware-workflows {
  local hardware_hostname="$1"
  workflow_ids="$(get-hardware-workflows "$hardware_hostname" | awk -F '|' '{print $1}')"
  [ -z "$workflow_ids" ] && echo "the $hardware_hostname hardware does not have any workflow" && return
  watch "
echo \"$workflow_ids\" | while read workflow_id; do
  docker exec -i compose_tink-cli_1 tink workflow state \$workflow_id
  docker exec -i compose_tink-cli_1 tink workflow events \$workflow_id
done
"
}

function install-vagrant-box-clonezilla-image {
  local VAGRANT_BOX_IMAGE_PATH=/vagrant-boxes/$1/0/libvirt/box.img
  local CLONEZILLA_IMAGE_NAME=$2
  local CLONEZILLA_IMAGE_PATH=/vagrant/tmp/$CLONEZILLA_IMAGE_NAME

  if [ ! -f "$VAGRANT_BOX_IMAGE_PATH" ]; then
    echo "WARNING: $VAGRANT_BOX_IMAGE_PATH does not exist. skipping creating the $CLONEZILLA_IMAGE_NAME image."
    exit 0
  fi

  # convert the vagrant box to a clonezilla image.
  if [ ! -f "$CLONEZILLA_IMAGE_PATH/SHA1SUMS" ] || [ "$VAGRANT_BOX_IMAGE_PATH" -nt "$CLONEZILLA_IMAGE_PATH/SHA1SUMS" ]; then
    qemu-img info $VAGRANT_BOX_IMAGE_PATH
    qemu-nbd --read-only --connect /dev/nbd0 $VAGRANT_BOX_IMAGE_PATH
    parted --script /dev/nbd0 print
    rm -rf $CLONEZILLA_IMAGE_PATH
    ocs-sr \
      --batch \
      --nogui \
      --ocsroot /vagrant/tmp \
      --use-partclone \
      --clone-hidden-data \
      --pzstd-compress \
      --skip-check-restorable \
      --gen-sha1sum \
      savedisk \
      $CLONEZILLA_IMAGE_NAME \
      nbd0
    qemu-nbd --disconnect /dev/nbd0
    du -h $CLONEZILLA_IMAGE_PATH
  fi

  # you can restore the image with:
  # qemu-img create -f qcow2 $CLONEZILLA_IMAGE_PATH-test.qcow2 60G
  # qemu-img info $CLONEZILLA_IMAGE_PATH-test.qcow2
  # qemu-nbd --connect /dev/nbd1 $CLONEZILLA_IMAGE_PATH-test.qcow2
  # ocs-sr \
  #   --batch \
  #   --nogui \
  #   --ocsroot /vagrant/tmp \
  #   --skip-check-restorable-r \
  #   --check-sha1sum \
  #   restoredisk \
  #   $CLONEZILLA_IMAGE_NAME \
  #   nbd1
  # parted --script /dev/nbd1 print
  # qemu-nbd --disconnect /dev/nbd1

  # copy the clonezilla image to the tinkerbell webroot.
  install -d "$TINKERBELL_STATE_WEBROOT_PATH/images"
  rsync \
    --archive \
    --no-owner \
    --no-group \
    --chmod Du=rwx,Dg=rx,Do=rx,Fu=rw,Fg=r,Fo=r \
    --delete \
    $CLONEZILLA_IMAGE_PATH \
    "$TINKERBELL_STATE_WEBROOT_PATH/images"
}
