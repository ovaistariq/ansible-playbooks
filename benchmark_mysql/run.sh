#!/bin/bash

export PYTHONUNBUFFERED=1

script_root=$(dirname $(readlink -f $0))
ansible-playbook -i ${script_root}/hosts ${script_root}/main.yml
