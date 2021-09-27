#!/bin/bash
set -euxo pipefail
source /vagrant/tink-helpers.source.sh

cd "$(dirname "${BASH_SOURCE[0]}")"

export provisioner_ip_address="$TINKERBELL_HOST_IP"
worker_ip_address_prefix="$(echo $provisioner_ip_address | cut -d "." -f 1).$(echo $provisioner_ip_address | cut -d "." -f 2).$(echo $provisioner_ip_address | cut -d "." -f 3)"

# provision the example x86_64 image.
docker pull debian:bullseye-slim
docker tag debian:bullseye-slim $provisioner_ip_address/debian:bullseye-slim
docker push $provisioner_ip_address/debian:bullseye-slim

# provision an example hello-world workflow template.
delete-template hello-world
template_output="$(tink template create <<EOF
version: '0.1'
name: hello-world
global_timeout: 600
tasks:
  - name: hello-world
    worker: '{{.device_1}}'
    actions:
      - name: hello-world
        image: debian:bullseye-slim
        timeout: 60
        command:
          - bash
          - -c
          - |
            echo 'hello-world'
            echo 'Hello World!'
      - name: info
        image: debian:bullseye-slim
        timeout: 60
        volumes:
          # NB the root directory is inside the dind container. to access it at
          #    the osie console you have to execute:
          #      ctr -n services.linuxkit tasks exec --tty --exec-id shell docker sh
          #      ls -laF /tmp/*.log
          - /:/osie
        command:
          - bash
          - -c
          - |
            exec >>/osie/tmp/hello-world-info.log 2>&1
            set -x
            date
            mount
            env
            # NB this json file contains the workflow ephemeral-data.
            # NB this data is shared between the workers that participate in the same workflow.
            # NB if you want to share data between actions in the same worker, you should use the
            #    /workflow directory instead.
            # NB tink-worker will sync it with hegel before/after an action is executed.
            # see https://github.com/tinkerbell/tink/blob/master/docs/concepts.md#ephemeral-data
            # see https://github.com/tinkerbell/tink/blob/8e7e17042fbbe3cf92fc7e37983c9943fb3c76ee/cmd/tink-worker/worker.go#L150
            # see https://github.com/tinkerbell/tink/blob/8e7e17042fbbe3cf92fc7e37983c9943fb3c76ee/cmd/tink-worker/worker.go#L192
            cat /workflow/data
            ls -laF /
            #find / ! -path '/osie/**'
      # - name: reboot
      #   image: reboot
      #   volumes:
      #     - /worker:/worker
EOF
)"
template_id="$(tink template get --format json | jq -r '.data[] | select(.name=="hello-world") | .id')"
tink template get "$template_id"
