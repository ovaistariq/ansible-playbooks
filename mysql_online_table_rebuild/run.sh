#!/bin/bash

export PYTHONUNBUFFERED=1

script_root=$(dirname $(readlink -f $0))

podname=$1
if [[ -z ${podname} ]] || [[ ! -e ${script_root}/hosts.${podname} ]]
then
    echo "Podname was not provided, could not load the inventory"
    exit 22
fi

ansible-playbook -i ${script_root}/hosts.${podname} ${script_root}/main.yml --list-hosts

proceed_with_play=
echo -n 1>&2 "Would you like to proceed with running the playbook [yes/no]: "
read proceed_with_play
if [[ "${proceed_with_play}" == "yes" ]]
then
    ansible-playbook -i ${script_root}/hosts.${podname} ${script_root}/main.yml
fi
