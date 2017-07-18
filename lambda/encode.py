from __future__ import print_function
from pprint import pprint

import json
import subprocess
import shlex
import os
import boto3
import urllib
import logging
import shutil

s3 = boto3.client('s3')
FFMPEG = './bin/ffmpeg'

def handler(event, context):
    event = event['Records'][0]
    request = {}
    request['key'] = urllib.unquote_plus(event['s3']['object']['key'])
    request['bucket'] = event['s3']['bucket']['name']
    request['bucket_region'] = event['awsRegion']
    request['tmp_location'] = '/tmp/' + request['key']

    # TODO: this assumes the object will always be at the root level
    filename, file_extension = os.path.splitext(request['key'])
    request['source_file_extension'] = file_extension
    request['source_file_name'] = filename
    request['source_file_name_with_extension'] = request['source_file_name'] + '.' + request['source_file_extension']

    request['target_file_extension'] = 'mp4'
    request['target_file_name'] = request['source_file_name']
    request['target_file_name_with_extension'] = request['source_file_name'] + '.' + request['target_file_extension']

    try:
        waiter = s3.get_waiter('object_exists')
        waiter.wait(Bucket=request['bucket'], Key=request['key'])

        # Download the file from S3
        s3.download_file(request['bucket'], request['key'], request['tmp_location'])
        request['tags'] = s3.get_object_tagging(Bucket=request['bucket'], Key=request['key'])
        print("the s3 object tags are", request['tags'])
        filename, file_extension = os.path.splitext(request['tmp_location'])
        request['file_extension'] = file_extension
    except Exception as e:
        print(e)
        print('Error getting object {} from bucket {}.'.format(request['key'], request['bucket']))
        raise e

    # get_rotation will update the metadata in request
    get_rotation(request)

    if request['rotation'] != 0:
        print("Rotation needed.  Rotation value was:", request['rotation'])
        #rotate(request)


    get_dimensions(request)
    print(request['dimensions']['width'])
    print(request['dimensions']['height'])

    encode(request)

    # TODO: update upload to include tags. no need to make two API calls and there is a race condition when we go to fetch the object from S3
    tags = {}
    tags['TagSet'] = request['tags']['TagSet']
    s3.upload_file('/tmp/output.mp4', 'mahryboutte.com-processed', request['target_file_name_with_extension'])
    s3.put_object_tagging(Bucket='mahryboutte.com-processed', Key=request['target_file_name_with_extension'], Tagging=tags)
    s3.delete_object(Bucket=request['bucket'], Key=request['key'])

def encode(request):
    print("Starting encoding process...")

    try:
        command = [
            FFMPEG,
            '-i',
            request['tmp_location'],
            '-s',
            '640x480',
            '-c:v',
            'libx264',
            '-crf',
            '25',
            '-c:a',
            'aac',
            '-movflags',
            'faststart',
            '/tmp/output.mp4'
        ]

        subprocess.call(['rm', '-rf', '/tmp/output.mp4'])

        subprocess.call(command)                # encode the video!
        print("Encoding process complete.")

    finally:
        # always cleanup even if there are errors
        subprocess.call(['rm', '-rf', 'attachments'])

def rotate(request):
    """
    Function to rotation the input video file.

    0 = 90CounterCLockwise and Vertical Flip (default)
    1 = 90Clockwise
    2 = 90CounterClockwise
    3 = 90Clockwise and Vertical Flip

    Returns a new video file in /tmp/ directory
    """

    rotated_filename = '/tmp/rotated' + request['file_extension']

    try:
        os.remove(rotated_filename)
    except OSError:
        pass

    # ffmpeg -i in.mov -vf "transpose=1" out.mov
    cmd = "bin/ffmpeg -i " + request['tmp_location'] + " -vf transpose='" + str(request['rotation']) + "' " + rotated_filename
    print(cmd)
    args = shlex.split(cmd)
    ffmpeg_output = subprocess.check_output(args).decode('utf-8')

    shutil.move(rotated_filename, request['tmp_location'])


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
