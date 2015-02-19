#!/bin/bash
NUM=0
QUEUE=""
MAX_NPROC=2 # default
 
function queue {
    QUEUE="$QUEUE $1"
    NUM=$(($NUM+1))
}
 
function regeneratequeue {
    OLDREQUEUE=$QUEUE
    QUEUE=""
    NUM=0
    for PID in $OLDREQUEUE
    do
        if [ -d /proc/$PID  ] ; then
            QUEUE="$QUEUE $PID"
            NUM=$(($NUM+1))
        fi
    done
}
 
function checkqueue {
    OLDCHQUEUE=$QUEUE
    for PID in $OLDCHQUEUE
    do
        if [ ! -d /proc/$PID ] ; then
            regeneratequeue # at least one PID has finished
            break
        fi
    done
}
 
# Main program
echo Using $MAX_NPROC parallel threads
COMMAND=$1
 
for INS in $* # for the rest of the arguments
do
    # DEFINE COMMAND
    echo "Running $CMD"
 
    $CMD &
    # DEFINE COMMAND END
 
    PID=$!
    queue $PID
 
    while [[ $NUM >= $MAX_NPROC ]]
    do
        checkqueue
        sleep 0.4
    done
done

wait # wait for all processes to finish before exit
