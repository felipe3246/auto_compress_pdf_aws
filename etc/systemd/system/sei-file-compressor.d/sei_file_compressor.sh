#!/bin/bash

inotifywait -m $SEI_WATCH_DIR -e create -e moved_to

while read dir action file; do
    echo "The file '$file' appeared in directory '$dir' via '$action'"  | tee -a $SEI_LOGFILE
    
    # push a message to SNS TOPIC
    aws sns publish --topic-arn $SEI_SNS_ARN --message '{"full_file_name": "'"$file"'"}' 
done