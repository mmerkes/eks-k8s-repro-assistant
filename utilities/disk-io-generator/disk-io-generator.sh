#!/bin/bash
while :
do
    FOO_FILE=foo
    BAR_FILE=bar
    touch $FOO_FILE
    for i in {1..5000}
    do
       echo "Uneasy lies the head that wears the crown." >> $FOO_FILE
    done

    for i in {1..5000}
    do
        cp $FOO_FILE $BAR_FILE
        rm $BAR_FILE
    done

    rm $FOO_FILE
done
