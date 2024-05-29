# AutoCompress SEI PDF files

This project is an automation tool based on AWS Services to compress SEI (Sistema Eletrônico de Informação desenvolvido pelo TRF4) PDF files uploaded by users into an EFS filesystem.

## Overview

The tool consists of watching a specific folder in a mounted EFS filesystem and notifying an AWS Lambda function using Amazon SNS service to compress any PDF file added to that folder. The compressed file is then saved in the same directory with a different filename.

## Architecture

The solution utilizes the following components:

- **Terraform**: Used as the Infrastructure as Code (IaC) tool to provision and manage AWS resources.
- **Python 3.12**: The backend language used for the AWS Lambda function responsible for compressing PDF files.
- **Shell Script**: A Linux watch service that monitors the target folder and triggers the Lambda function when new PDF files are added.
- **Amazon SNS**: As the notification service to receive communication from servers and trigger the lambda function.
- **AWS Lambda**: The serverless compute service that runs the Python function to compress PDF files.
- **AWS EFS (Elastic File System)**: A scalable and fully managed NFS file system used to store the PDF files.

## Prerequisites

Before running the project, ensure you have the following prerequisites:

- AWS account with appropriate permissions to create and manage the required resources.
- Terraform installed on your local machine.
- Python 3.12 installed on your local machine (if you need to make changes to the Lambda function).

## Getting Started

1. Clone the repository to your local machine.
2. Navigate to the project directory.
3. Navigate into the folder `infrastructure`.
4. Run `terraform plan` to check what are the resources that are going to be created at your account.
5. Run `terraform apply` to create the necessary AWS resources.
6. After successful deployment, Terraform will output the EFS mount point and other relevant information.
7. Mount the EFS file system on your local machine or an EC2 instance.
8. Copy the `watch_folder.sh` script to the mounted EFS file system.
9. Run the `watch_folder.sh` script to start monitoring the target folder for new PDF files.

## Usage

1. Upload PDF files to the monitored folder on the EFS file system.
2. The `watch_folder.sh` script will detect new PDF files and trigger the Lambda function to compress them.
3. The compressed PDF files will be saved in the same directory with a different filename (e.g., `original_file_compressed.pdf`).

## Cleaning Up

To remove all AWS resources created by this project, run `terraform destroy` from the `infrastructure` directory.

## License

This project is licensed under the [MIT License](LICENSE).