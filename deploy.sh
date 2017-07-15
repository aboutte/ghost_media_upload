#!/usr/bin/env bash

set -e

ORIGINAL_DIR="$(pwd)"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR

DEPLOYMENT_LOCATION="/home/aboutte"
DEPLOYMENT_DIR="ghost_media_upload"

rm -rf "$DEPLOYMENT_LOCATION/$DEPLOYMENT_DIR"
cd $DEPLOYMENT_LOCATION
git clone --depth 1 --branch master https://github.com/aboutte/ghost_media_upload.git