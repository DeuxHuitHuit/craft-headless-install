#!/bin/bash

set -e -o pipefail

rm -rf project
cd ../sveltekit-cms/
git checkout main
git pull origin main
cd -
cp -R ../sveltekit-cms/config/project .
