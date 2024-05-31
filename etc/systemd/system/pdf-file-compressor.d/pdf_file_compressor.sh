#!/bin/bash

inotifywait -m $PDF_WATCH_DIR -e create -e moved_to

while read dir action file; do
    echo "The file '$file' appeared in directory '$dir' via '$action'"  | tee -a $PDF_LOGFILE
    
    extension="${file##*.}"
    extension="${extension,,}"
    
    #validate if file extension is pdf and it is not a compressed file
    if [[ "$file" != *"_compressed"*  && "$extension" == "pdf"  ]]; then
        # push a message to SNS TOPIC
        aws sns publish --topic-arn $PDF_SNS_ARN --message '{"full_file_name": "'"$file"'"}' 
    
done