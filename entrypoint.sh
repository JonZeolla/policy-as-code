#!/usr/bin/env bash

if [ "$#" -ne 0 ]; then
  "$@" # Ensures that we always have a shell. exec "$@" works when we are passed `/bin/bash -c "example"`, but not just `example`; the latter will
       # bypass the easy_infra shims because it doesn't have a BASH_ENV equivalent
  exit $?
fi

set -o nounset
set -o pipefail
# Don't turn on errexit to ensure we see the logs from failed ansible-playbooks attempts
#set -o errexit

if [[ -z "${CLIENT_IP:-}" ]]; then
  echo "CLIENT_IP is required but was not set"
  exit 1
fi

# Setup ansible prereqs
export KEY_FILE="${HOME}/.ssh/ansible_key"
export LOG_FILE="${HOME}/logs/entrypoint.log"
if [[ -s "${KEY_FILE}" ]]; then
  echo "${KEY_FILE} already exists! Skipping SSH key setup..."
  echo "See ${LOG_FILE} for previous configuration details"
else
  #SSH_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9!#$%&\()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 50)
  SSH_PASS=""
  export SSH_PASS
  echo "Generated passphrase: ${SSH_PASS:-empty}" >> "${LOG_FILE}"
  ssh-keygen -N "${SSH_PASS}" -C "Ansible key" -f "${KEY_FILE}" | tee -a "${LOG_FILE}"
  #eval "$(ssh-agent -s)" | tee -a "${LOG_FILE}"
  #DISPLAY=1 SSH_ASKPASS=/usr/local/bin/askpass.sh ssh-add "${KEY_FILE}" < /dev/null | tee -a "${LOG_FILE}"

  cat "${KEY_FILE}.pub" >> "${HOME}/.ssh/authorized_keys"
  echo "Updated ${HOME}/.ssh/authorized_keys" | tee -a "${LOG_FILE}"

  ssh-keyscan localhost 2>/dev/null >> "${HOME}/.ssh/known_hosts"
  echo "Updated ${HOME}/.ssh/known_hosts" | tee -a "${LOG_FILE}"
fi

# Don't take ~/.ssh/config into account, since we will change it as a part of the playbook
export ANSIBLE_SSH_ARGS="-F /dev/null"
ansible-playbook ${ANSIBLE_CUSTOM_ARGS:-} -e 'ansible_python_interpreter=/usr/bin/python3' --inventory localhost, --user "${HOST_USER:-ec2-user}" --private-key="${KEY_FILE}" /etc/app/policy-as-code.yml | tee -a "${LOG_FILE}"
