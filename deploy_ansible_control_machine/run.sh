#!/bin/bash

export PYTHONUNBUFFERED=1

script_root=$(dirname $(readlink -f $0))
ansible_control_machine_hostname=sv5putil03

ansible-playbook -i "${ansible_control_machine_hostname}," ${script_root}/setup_ansible.yml
ansible-playbook ${script_root}/setup_authorized_keys.yml
ansible-playbook -i "${ansible_control_machine_hostname}," ${script_root}/setup_git_remote_repo.yml
