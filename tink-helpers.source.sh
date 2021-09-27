source ~/tinkerbell-sandbox/deploy/compose/.env

function tink {
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
