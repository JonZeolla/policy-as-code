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
  exit 1
}

trap 'sigint_handler' SIGINT

# Allow people to set a CLIENT_IP environment variable to skip the prompt
/usr/src/app/valid_ip.py
valid_ip_status=$?

# [ -t 0 ] checks to see if fd 0 (stdin) is a TTY
if [ ! -t 0 ] && [[ ${valid_ip_status} -ne 0 ]]; then
  if [[ "${CLIENT_IP:-empty}" == "empty" ]]; then
    echo "No TTY and no CLIENT_IP provided; unable to prompt for IP address" >&2
  else
    echo "No TTY and an invalid CLIENT_IP was provided; unable to prompt for IP address" >&2
  fi
  exit 1
fi

while [[ ${valid_ip_status} -ne 0 ]]; do
  case $valid_ip_status in
    # A status of 3 is no IP was provided
    3) prompt="What does http://icanhazip.com/ipv4 show is your IP? " ;;
    # A status of 4 is an invalid IP
    4) prompt="The provided IP was invalid. What does http://icanhazip.com/ipv4 show? " ;;
    # A status of 5 is a private IP
    5) prompt="You provided a private IP; please use your public IP. What does http://icanhazip.com/ipv4 show? " ;;
    # A status of 6 is a Cloud9 IP address
    6) prompt="You provided a Cloud9 public IP address, please provide your source computer's IP. What does http://icanhazip.com/ipv4 show? " ;;
  esac

  # CLIENT_IP is used by valid_ip.py
  read -r -p "${prompt}" CLIENT_IP
  export CLIENT_IP
  /usr/src/app/valid_ip.py
  valid_ip_status=$?
done

# Setup ansible prereqs
DEFAULT_USER="$(awk -F: '$3 == 1000 {print $1}' < /host/etc/passwd)"
if [ -z "${HOST_USER:-}" ]; then
  HOST_USER="${DEFAULT_USER:-ec2-user}"
fi
HOST_HOME_DIR="/host/home/${HOST_USER}"
KEY_FILE="${HOST_HOME_DIR}/.ssh/ansible_key"
LOG_DIR="${HOST_HOME_DIR}/logs"
LOG_FILE="${LOG_DIR}/entrypoint.log"
mkdir -p "${LOG_DIR}"
touch "${LOG_FILE}"
# This is the desired UID/GID on the host
chown -R 1000:1000 "${LOG_DIR}"
KNOWN_HOSTS="${HOST_HOME_DIR}/.ssh/known_hosts"

if [[ -s "${KEY_FILE}" ]]; then
  echo "${KEY_FILE} already exists! Skipping SSH key setup..."
  echo "See ${LOG_FILE} for previous configuration details"
else
  SSH_PASS=""
  echo "Generated passphrase: ${SSH_PASS:-empty}" >> "${LOG_FILE}"
  ssh-keygen -N "${SSH_PASS}" -C "Ansible key" -f "${KEY_FILE}" | tee -a "${LOG_FILE}"

  AUTHORIZED_KEYS="${HOST_HOME_DIR}/.ssh/authorized_keys"
  cat "${KEY_FILE}.pub" >> "${AUTHORIZED_KEYS}"
  echo "Updated ${AUTHORIZED_KEYS}" | tee -a "${LOG_FILE}"

  ssh-keyscan localhost 2>/dev/null >> "${KNOWN_HOSTS}"
  echo "Updated ${KNOWN_HOSTS}" | tee -a "${LOG_FILE}"
fi

# Don't take the host's ~/.ssh/config into account, since we will change it as a part of the playbook
# Also, use a custom location for the known_hosts file based on how we've mounted the host filesystem
export ANSIBLE_SSH_ARGS="-F /dev/null -o UserKnownHostsFile=${KNOWN_HOSTS}"
ansible-playbook ${ANSIBLE_CUSTOM_ARGS:-} -e 'ansible_python_interpreter=/usr/bin/python3' --inventory localhost, --user "${HOST_USER}" --private-key="${KEY_FILE}" /etc/app/policy-as-code.yml | tee -a "${LOG_FILE}"
