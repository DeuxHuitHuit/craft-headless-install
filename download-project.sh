#!/bin/bash

set -e -o pipefail

HOST="dev2@mo7.288dev.com"
PORT="1023"
PROJECT="$1"
PHP_EXEC="ea-php83"

if [[ -z "$PROJECT" ]]; then
	echo "ERROR! Please specify a project name.";
	echo "This should be the name of the folder that contains your Craft project";
	echo "on the remote (dev) server";
	exit;
fi

echo "1. Generating project files"
ssh -p "$PORT" "$HOST" "cd ~/www/$PROJECT/ && rm -rf config/project && $PHP_EXEC ./craft project-config/write"

echo "2. Downloading project files"
git rm -r ./project
rsync -Phavz -e "ssh -p $PORT" "$HOST":"~/www/$PROJECT/config/project" "./"

echo "3. Edit project files to remove license key and other sensitive data"
sed "s/licenseKey:.*/licenseKey: /g" project/project.yaml > project/project.yaml.tmp
mv -f project/project.yaml.tmp project/project.yaml

echo "4. Adding new files to git"
git add "./project"

echo "Done 👍"
echo "Please commit the result"
echo ""
