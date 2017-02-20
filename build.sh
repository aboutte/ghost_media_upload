#!/usr/bin/env bash

mkdir -p build/bin

# download the latest version of ffmpeg


cd build/
zip -r aws-lambda-ffmpeg.zip *

aws --region us-west-2 s3 cp aws-lambda-ffmpeg.zip s3://aboutte-lambda/aws-lambda-ffmpeg.zip
