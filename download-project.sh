#!/bin/bash

set -e -o pipefail

HOST="dev@hg2.288dev.com"
PORT="1023"
PROJECT="$1"

if [[ -z "$PROJECT" ]]; then
	echo "ERROR! Please specify a project name.";
	echo "This should be the name of the folder that contains your Craft project";
	echo "on the remote (dev) server";
	exit;
fi

echo "1. Generating project files"
ssh -p "$PORT" "$HOST" "cd ~/www/$PROJECT/ && rm -rf config/project && ea-php81 ./craft project-config/write"

echo "2. Downloading project files"
git rm -r ./project
scp -r -P "$PORT" "$HOST":"~/www/$PROJECT/config/project" "./"

echo "3. Adding new files to git"
git add "./project"

echo "Done 👍"
echo "Please commit the result"
echo ""
