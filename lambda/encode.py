
"""
these are my comments
"""

from __future__ import print_function
from pprint import pprint

import json
import subprocess
import shlex
import os
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
    request['tmp_location'] = '/tmp/' + request['key']

    print(request)

    try:
        print("Using waiter to wait for object to persist thru s3 service")
        waiter = s3.get_waiter('object_exists')
        waiter.wait(Bucket=request['bucket'], Key=request['key'])

        # Download the file from S3
        s3.download_file(request['bucket'], request['key'], request['tmp_location'])
        filename, file_extension = os.path.splitext(request['tmp_location'])
        request['file_extension'] = file_extension

        if get_rotation(request) == 0:
            print('No rotation needed')
        else:
            print("Rotation needed.  Rotation value was")
            print(request['rotation'])
            rotate(request)


        get_dimensions(request)
        print(request['dimensions']['width'])
        print(request['dimensions']['height'])



        s3.upload_file('/tmp/rotated.' + request['file_extension'], 'mahryboutte.com-processed', request['key'])
        s3.delete_object(Bucket=request['bucket'], Key=request['key'])

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



def rotate(request):
    """
    Function to rotation the input video file.

    0 = 90CounterCLockwise and Vertical Flip (default)
    1 = 90Clockwise
    2 = 90CounterClockwise
    3 = 90Clockwise and Vertical Flip

    Returns a new video file in /tmp/ directory
    """

    unique_filename = '/tmp/rotated.' + request['file_extension']

    # ffmpeg -i in.mov -vf "transpose=1" out.mov
    cmd = "bin/ffmpeg -i " + request['tmp_location'] + " -vf transpose='" + str(request['rotation']) + "' " + unique_filename
    print(cmd)
    args = shlex.split(cmd)
    print(args)

    ffmpeg_output = subprocess.check_output(args).decode('utf-8')


def get_rotation(request):
    """
    Function to get the rotation of the input video file.
    Adapted from gist.github.com/oldo/dc7ee7f28851922cca09/revisions using the ffprobe comamand by Lord Neckbeard from
    stackoverflow.com/questions/5287603/how-to-extract-orientation-information-from-videos?noredirect=1&lq=1

    Returns a rotation None, 90, 180 or 270
    """
    cmd = "bin/ffprobe -loglevel error -select_streams v:0 -show_entries stream_tags=rotate -of default=nw=1:nk=1"
    args = shlex.split(cmd)
    args.append(request['tmp_location'])
    # run the ffprobe process, decode stdout into utf-8 & convert to JSON
    ffprobe_output = subprocess.check_output(args).decode('utf-8')
    if len(ffprobe_output) > 0:  # Output of cmd is None if it should be 0
        ffprobe_output = json.loads(ffprobe_output)
        request['rotation'] = ffprobe_output
    else:
        request['rotation'] = 0

def get_dimensions(request):
    """
    Function to get the orientation of the input video file.

    Returns a rotation None, 90, 180 or 270
    """
    request['dimensions'] = {}
    cmd = "bin/ffprobe -v error -print_format json -select_streams v:0 -show_entries stream=height,width"
    args = shlex.split(cmd)
    args.append(request['tmp_location'])
    # run the ffprobe process, decode stdout into utf-8 & convert to JSON
    ffprobe_output = json.loads(subprocess.check_output(args).decode('utf-8'))
    request['dimensions']['width'] = ffprobe_output['streams'][0]['width']
    request['dimensions']['height'] = ffprobe_output['streams'][0]['height']
