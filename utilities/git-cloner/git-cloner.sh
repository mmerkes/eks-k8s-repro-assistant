#!/bin/bash

OUTPUT_FILE="git-cloner.log"
git clone https://github.com/aws/aws-sdk-go.git >> $OUTPUT_FILE 2>&1
echo "Compressing repo" >> $OUTPUT_FILE
tar zcvf sdk.tar.gz aws-sdk-go >> $OUTPUT_FILE 2>&1
mkdir git-cloner && cd git-cloner

while :
do
    echo "Decompressing repo" >> $OUTPUT_FILE
    tar zxvf ../sdk.tar.gz >> $OUTPUT_FILE 2>&1
    echo "Removing repo" >> $OUTPUT_FILE
    rm -rf aws-sdk-go >> $OUTPUT_FILE 2>&1
done
