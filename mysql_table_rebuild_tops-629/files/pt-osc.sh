#!/bin/bash -u

# Configuration options
concurrency=6

script_root=$(dirname $(readlink -f $0))
current_datetime=$(date +%Y_%m_%d_%H_%M_%S)

pt_plugin_dir="/etc/percona-toolkit/plugins"
osc_plugin="${pt_plugin_dir}/pt-osc-stop-slave-fk-drop-swap.pl"

if [[ ! -e ${osc_plugin} ]]
then
    osc_plugin="${script_root}/pt-osc-stop-slave-fk-drop-swap.pl"
fi

osc_config="/root/.pt-online-schema-change.conf"

tmp_dir="/tmp/pt-osc-run-${current_datetime}"
log_file="${tmp_dir}/pt-osc.log"
concurrency_control_file="${tmp_dir}/pt-osc.concurrency"

mysql_username=$(awk -F= '/user/ {print $2}' ${osc_config})
mysql_password=$(awk -F= '/password/ {print $2}' ${osc_config})

# Setup tool
mysqladmin_bin="/usr/bin/mysqladmin"
mysql_bin="/usr/bin/mysql"
pt_osc_bin="/usr/bin/pt-online-schema-change"

sql_to_fetch_tables="select c.table_schema, c.table_name, 
                        sum(data_length+index_length)/1024/1024/1024 as table_size_gb 
                from columns as c inner join tables as t using (table_schema, table_name) 
                where (data_type like '%text%' or data_type like '%blob%' 
                        or (data_type = 'varchar' and character_maximum_length > 256)) 
                        and c.table_schema not in ('information_schema', 'mysql', 'performance_schema') and 
                        t.engine='innodb' 
                group by c.table_schema, c.table_name 
                order by table_size_gb asc limit 5"

# Function definitions
function vlog() {
    datetime=$(date "+%Y-%m-%d %H:%M:%S")
    msg="[${datetime}] $1"

    echo ${msg} | tee -a ${log_file}
}

function test_mysql_access() {
#    set -x
    local mysqladmin_args=

    mysqladmin_args="--user=${mysql_username} --password=${mysql_password}"

    if (( $(${mysqladmin_bin} ${mysqladmin_args} ping &> /dev/null; echo $?) != 0 ))
    then
        echo "Could not connect to MySQL on $(hostname)"
        exit 2003
    fi

    return 0

#    set +x
}

function increment_alter_threads_count() {
    # We increment the running counter that shows number of ALTER running
    local num_running_alters=$(cat ${concurrency_control_file})
    let num_running_alters=num_running_alters+1
    echo -n "${num_running_alters}" > ${concurrency_control_file}
}

function decrement_alter_threads_count() {
    # We now decrement the counter that shows number of ALTERs running
    local num_running_alters=$(cat ${concurrency_control_file})
    let num_running_alters=num_running_alters-1
    echo -n "${num_running_alters}" > ${concurrency_control_file}
}

function get_alter_threads_count() {
    local num_running_alters=$(cat ${concurrency_control_file})
    echo ${num_running_alters}
}

function do_online_alter() {
    local db=$1
    local table=$2
    local table_size=$3
    local table_rebuild_log="${tmp_dir}/rebuild-${db}.${table}.log"

    increment_alter_threads_count

    vlog "Rebuilding ${db}.${table} - size: ${table_size} - log: ${table_rebuild_log}"
    
    ${pt_osc_bin} h=localhost,D=${db},t=${table} \
        --alter "engine=innodb" --alter-foreign-keys-method drop_swap \
        --critical-load Threads_running=5000 --recursion-method none \
        --set-vars sql_log_bin=0 --plugin ${osc_plugin} \
        --progress percentage,1 --execute &> ${table_rebuild_log}

    ret_code=${PIPESTATUS[0]}
    if (( ${ret_code} != 0 ))
    then
        vlog "FAILED to rebuild table ${db}.${table}"
    else
        vlog "SUCCESSFULLY rebuilt table ${db}.${table}"
    fi

    decrement_alter_threads_count
}

# Test that all tools are available
for tool_bin in ${mysqladmin_bin} ${mysql_bin} ${pt_osc_bin}
do
    if (( $(which $tool_bin &> /dev/null; echo $?) != 0 ))
    then
        echo "Can't find $tool_bin on $(hostname)"
        exit 22 # OS error code  22:  Invalid argument
    fi
done

# Test if MySQL access works
test_mysql_access


# Do the actual stuff

# Setup the directory needed to store temporary files
mkdir -p ${tmp_dir}
touch ${log_file}
echo -n "0" > ${concurrency_control_file}

vlog "Created temporary directory ${tmp_dir} and logging to ${log_file}"

# Now we loop through the list of tables that need to be rebuilt
mysql_bin="${mysql_bin} --user=${mysql_username} --password=${mysql_password}"

${mysql_bin} -NB information_schema -e "${sql_to_fetch_tables}" | while read line
do
    db=$(echo $line | awk '{print $1}')
    table=$(echo $line | awk '{print $2}')
    table_size=$(echo $line | awk '{ 
                                        size=$3;multiplier=1;prefix="GB"; 
                                        while(size < 1) {
                                            size=size*1024;multiplier=multiplier*1000; 
                                            if(multiplier == 1000) {
                                                prefix="MB";
                                            } else {
                                                prefix="KB"
                                            } 
                                        } 
                                        printf "%.2f%s\n", size,prefix; 
                                    }')

    # We run the alter as a background process to enable parallelization
    do_online_alter ${db} ${table} ${table_size} &

    sleep 1

    # If we are already running the allowed number of parallel alters
    # then we wait for one of them to finish
    while (( $(get_alter_threads_count) >= ${concurrency}  ))
    do
        sleep 1
    done
done

# We wait for all child processes to finish
while [[ "$(get_alter_threads_count)" != "0" ]]
do
    sleep 1
done

