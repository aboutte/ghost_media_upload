#!/usr/bin/env bash

set -e

ORIGINAL_DIR="$(pwd)"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR

rm -rf lambda/aws-lambda-ffmpeg.zip
mkdir -p lambda/bin

# download the latest version of ffmpeg

cd lambda/
zip -r aws-lambda-ffmpeg.zip *

aws --region us-west-2 s3 cp aws-lambda-ffmpeg.zip s3://aboutte-lambda/aws-lambda-ffmpeg.zip

cd $ORIGINAL_DIR