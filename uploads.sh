#!/bin/bash

set -e -o pipefail

# Usage example:
# ./uploads.sh user example.com 22

USER="$1"
HOST="$2"
PORT="$3"

rsync -Phavz -e "ssh -p $PORT" "./web/uploads $USER@$HOST:/home/$USER/web"
