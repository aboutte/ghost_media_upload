
"""
these are my comments
"""

from __future__ import print_function

import json
import boto3
import urllib
import logging
print('Loading function')

s3 = boto3.client('s3')



logger = logging.getLogger()
logger.setLevel(logging.INFO)

#-------------------------------------------------------------------------------
# CONFIGURABLE SETTINGS
#-------------------------------------------------------------------------------

# path to ffmpeg bin
FFMPEG = './bin/ffmpeg'


#-------------------------------------------------------------------------------
# encoding script
#-------------------------------------------------------------------------------

def handler(event, context):
    event = event['Records'][0]
    request = {}
    request['key'] = urllib.unquote_plus(event['s3']['object']['key'])
    request['bucket'] = event['s3']['bucket']['name']
    request['bucket_region'] = event['awsRegion']
    print(request)

    try:
        print("Using waiter to wait for object to persist thru s3 service")
        waiter = s3.get_waiter('object_exists')
        waiter.wait(Bucket=request['bucket'], Key=request['key'])

        # Download the file from S3
        s3.download_file(request['bucket'], request['key'], '/tmp/' + request['key'])
        s3.upload_file('/tmp/' + request['key'], 'mahryboutte.com-processed', request['key'])

        # s3.delete_object(Bucket=bucket, Key=key)

    except Exception as e:
        print(e)
        print('Error getting object {} from bucket {}.'.format(request['key'], request['bucket']))
        raise e



def encode(file):
    name = ''.join(file.split('.')[:-1])
    subtitles = 'temp.ass'.format(name)
    output = '{}.mp4'.format(name)

    try:
        command = [
            FFMPEG_PATH, '-i', file,
            '-c:v', 'libx264', '-tune', 'animation', '-preset', PRESET, '-profile:v', PROFILE, '-crf', CRF_VALUE,
        ]

        subprocess.call(command)                # encode the video!

    finally:
        # always cleanup even if there are errors
        subprocess.call(['rm', '-fr', 'attachments'])
        subprocess.call(['rm', '-f', FONT_DIR])
        subprocess.call(['rm', '-f', subtitles])
