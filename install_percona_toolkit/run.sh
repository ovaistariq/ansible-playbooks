#!/bin/bash

export PYTHONUNBUFFERED=1

script_root=$(dirname $(readlink -f $0))

ansible-playbook ${script_root}/main.yml --list-hosts

ret_code=$?
(( ${ret_code} != 0 )) && exit ${ret_code}

proceed_with_play=
echo -n 1>&2 "Would you like to proceed with running the playbook [yes/no]: "
read proceed_with_play
if [[ "${proceed_with_play}" == "yes" ]]
then
    ansible-playbook ${script_root}/main.yml
fi
