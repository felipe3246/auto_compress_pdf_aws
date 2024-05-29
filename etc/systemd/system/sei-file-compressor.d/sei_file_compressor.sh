#!/bin/bash

inotifywait -m $SEI_WATCH_DIR -e create -e moved_to

while read dir action file; do
    echo "The file '$file' appeared in directory '$dir' via '$action'"  | tee -a $SEI_LOGFILE
    
    # push a message to SQS QUEUE 
    aws sqs send-message --queue-url $SEI_SQS_QUEUE_URL --message-body "$file"
done