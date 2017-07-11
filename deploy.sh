#!/usr/bin/env bash

set -e

rm -rf /home/aboutte/ghost_media_upload
git clone --depth 1 --branch master https://github.com/aboutte/ghost_media_upload.git