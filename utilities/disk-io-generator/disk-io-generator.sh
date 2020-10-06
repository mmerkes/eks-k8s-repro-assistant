#!/bin/bash
while :
do
    LOG_FILE=log.txt
    FOO_FILE=foo
    touch $FOO_FILE
    echo "Starting to write foo file" >> $LOG_FILE
    # 1K
    head -c 1024 < /dev/urandom > $FOO_FILE

    echo "Starting to copy file" >> $LOG_FILE
    # Write 500MB
    for i in {1..62500}
    do
        cp $FOO_FILE $FOO_FILE$i 2>> $LOG_FILE
    done

    rm $FOO_FILE* 2>> $LOG_FILE
done
