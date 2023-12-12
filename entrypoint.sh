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

# Support Ctrl+C (SIGINT)
sigint_handler() {
  echo "Ctrl+C detected, exiting..."
  exit 1
}

trap 'sigint_handler' SIGINT

# Allow people to set a CLIENT_IP environment variable to skip the prompt
/usr/src/app/valid_ip.py
valid_ip_status=$?

while [[ ${valid_ip_status} -ne 0 ]]; do
  case $valid_ip_status in
    # A status of 3 is no IP was provided
    3) prompt="What does http://icanhazip.com/ipv4 show is your IP? " ;;
    # A status of 4 is an invalid IP
    4) prompt="The provided IP was invalid. What does http://icanhazip.com/ipv4 show? " ;;
    # A status of 5 is a private IP
    5) prompt="You provided a private IP; please use your public IP. What does http://icanhazip.com/ipv4 show? " ;;
    # A status of 6 is a Cloud9 IP address; they chose the wrong one
    6) prompt="You provided a Cloud9 public IP address, please provide your source computer's IP. What does http://icanhazip.com/ipv4 show? " ;;
  esac

  # CLIENT_IP is used by valid_ip.py
  read -r -p "${prompt}" CLIENT_IP
  export CLIENT_IP
  /usr/src/app/valid_ip.py
  valid_ip_status=$?
done

# Setup ansible prereqs
export KEY_FILE="${HOME}/.ssh/ansible_key"
export LOG_FILE="${HOME}/logs/entrypoint.log"
if [[ -s "${KEY_FILE}" ]]; then
  echo "${KEY_FILE} already exists! Skipping SSH key setup..."
  echo "See ${LOG_FILE} for previous configuration details"
else
  SSH_PASS=""
  export SSH_PASS
  echo "Generated passphrase: ${SSH_PASS:-empty}" >> "${LOG_FILE}"
  ssh-keygen -N "${SSH_PASS}" -C "Ansible key" -f "${KEY_FILE}" | tee -a "${LOG_FILE}"

  cat "${KEY_FILE}.pub" >> "${HOME}/.ssh/authorized_keys"
  echo "Updated ${HOME}/.ssh/authorized_keys" | tee -a "${LOG_FILE}"

  ssh-keyscan localhost 2>/dev/null >> "${HOME}/.ssh/known_hosts"
  echo "Updated ${HOME}/.ssh/known_hosts" | tee -a "${LOG_FILE}"
fi

# Don't take ~/.ssh/config into account, since we will change it as a part of the playbook
export ANSIBLE_SSH_ARGS="-F /dev/null"
ansible-playbook ${ANSIBLE_CUSTOM_ARGS:-} -e 'ansible_python_interpreter=/usr/bin/python3' --inventory localhost, --user "${HOST_USER:-ec2-user}" --private-key="${KEY_FILE}" /etc/app/policy-as-code.yml | tee -a "${LOG_FILE}"
