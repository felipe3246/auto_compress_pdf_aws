#!/usr/bin/python3

import json
import os
import boto3
import botocore
from pypdf import PdfWriter, PdfReader

def lambda_handler(event, context):
    try:
        # read message received from SNS Topic
        message = json.dumps(event['Records'][0]['Sns']['Message'])
        file_object = json.loads(message)

        # Compress the PDF file
        pdf_file_to_compress = file_object['full_file_name']
        path_pdf_to_compress = "/mnt/lambda/" + pdf_file_to_compress
        file_result = compress_pdf(path_pdf_to_compress, pdf_file_to_compress)
        compressed_file_size = file_result[0]
        original_file_size = file_result[1]

        # Return the response
        return {
            'statusCode': 200,
            'body': json.dumps(f'PDF File Successfully Compressed. File Size Before Compression: {original_file_size} Bytes. File Size After Compression: {compressed_file_size} Bytes.')
        }
    except (botocore.exceptions.ClientError, json.JSONDecodeError, Exception) as e:
        # Handle any other exceptions
        return {
            'statusCode': 500,
            'body': json.dumps(f'An unexpected error occurred: {str(e)}')
        }

def compress_pdf(path_pdf_to_compress, original_filename):
    try:
        file_size_before = 0
        with open(path_pdf_to_compress, "rb") as f:
            file_size_before = len(f.read())
            print("File size before compression:", file_size_before)

        reader = PdfReader(path_pdf_to_compress)
        writer = PdfWriter()
            
        for page in reader.pages:
            writer.add_page(page)

        for page in writer.pages:
            for img in page.images:
                img.replace(img.image, quality=10)

        compressed_filename = original_filename.replace(".pdf", "_compressed.pdf")
        compressed_full_path = "/mnt/lambda/" + compressed_filename
        with open(compressed_full_path, "wb") as f:
            writer.write(f)

        with open(compressed_full_path, "rb") as f:
            file_size_after = len(f.read())
            print("File size after compression:", file_size_after)

        return file_size_after, file_size_before
    except (IOError, Exception) as e:
        # Handle exceptions in the compress_pdf function
        raise Exception(f'Error compressing the PDF file: {str(e)}')
