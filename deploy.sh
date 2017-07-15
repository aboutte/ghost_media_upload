#!/usr/bin/env bash

set -e

ORIGINAL_DIR="$(pwd)"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR

rm -rf /home/aboutte/ghost_media_upload
git clone --depth 1 --branch master https://github.com/aboutte/ghost_media_upload.git