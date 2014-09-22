#!/bin/bash

export PYTHONUNBUFFERED=1

script_root=$(dirname $(readlink -f $0))
ansible-playbook -i ${script_root}/hosts ${script_root}/main.yml --list-hosts

proceed_with_play=
echo 1>&2 "Would you like to proceed with running the playbook: [yes/no]"
read proceed_with_play
if [[ "${proceed_with_play}" == "yes" ]]
then
    ansible-playbook -i ${script_root}/hosts ${script_root}/main.yml
fi
