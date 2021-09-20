#!/bin/bash

# bootsrap with
# /bin/bash -c "$(curl -fsSL https://github.com/DeuxHuitHuit/craft-headless-install/raw/main/install.sh)"

set -e -o pipefail

PROJECT_CODE=$(basename $(pwd));

echo "Welcome to Deux Huit Huit craft installer"
echo ""
echo "We are installing projet $PROJECT_CODE in $(pwd)";

read -p 'Continue? [Y/n] ' '-d ';
if [[ "$REPLY" != "Y" ]]; then
    echo "Abort."
    exit;
fi;

echo "Backup web/.htaccess"
cp web/.htaccess "../$PROJECT_CODE.htaccess"

echo "Deleting files to make the pwd empty"
for F in ".htaccess" "web" ".well-known"; do
	if [[ -f "$F" ]]; then
		rm -rf "./$F"
	fi
done

echo "Install craft"
composer create-project craftcms/craft .

echo "Restore htaccess infos"
echo "" >> web/.htaccess
cat "../$PROJECT_CODE.htaccess" >> web/.htaccess
rm -f "../$PROJECT_CODE.htaccess"

echo "Make the cli executable"
chmod u+x ./craft

echo "Install cp-field-inspect and redactor"
ea-php74 ./craft plugin/install cp-field-inspect
ea-php74 ./craft plugin/install redactor

echo "Add /storage to .gitignore"
echo "/storage" >> .gitignore
echo "/web/cpressources" >> .gitignore

echo "Update .env file"
echo "" >> .env
echo "ASSETS_FILE_SYSTEM_PATH=$(pwd)/web/uploads" >> .env 
echo "" >> .env
echo "UPLOADS_URL=https://$PROJECT_CODE.288dev.com/uploads" >> .env
echo "" >> .env

echo "Add config file for agency-auth"
cat > config/agency-auth.php << EOF
<?php

return [
    '*' => [
        'client_id' => '',
        'client_secret' => '',
    ]
];

EOF

echo "Add headless config for craft"
cat > config/general.tmp << EOF
<?php
/**
 * General Configuration
 *
 * All of your system's general configuration settings go in here. You can see a
 * list of the available settings in vendor/craftcms/cms/src/config/GeneralConfig.php.
 *
 * @see \craft\config\GeneralConfig
 */

use craft\helpers\App;

return [
    // Global settings
    '*' => [
        // Default Week Start Day (0 = Sunday, 1 = Monday...)
        'defaultWeekStartDay' => 1,

        // Whether generated URLs should omit "index.php"
        'omitScriptNameInUrls' => true,

        // Control Panel trigger word
        'cpTrigger' => 'craft',

        // The secure key Craft will use for hashing and encrypting data
        'securityKey' => App::env('SECURITY_KEY'),

        // Enable headless mode: https://craftcms.com/docs/3.x/config/config-settings.html#headlessmode
        'headlessMode' => true,

        'addTrailingSlashesToUrls' => true,

        'limitAutoSlugsToAscii' => true,

        'useEmailAsUsername' => true,

        'errorTemplatePrefix' => '_pages/errors/',

        'upscaleImages' => false,

        'transformGifs' => false,

        'sendPoweredByHeader' => false,

        'cacheTTL' => 14400, // 12 hours

        'generateTransformsBeforePageLoad' => true,
    ],

    // Dev environment settings
    'dev' => [
        // Dev Mode (see https://craftcms.com/guides/what-dev-mode-does)
        'devMode' => true,
        // No indexing
        'disallowRobots' => true,
        // Aliases
        'aliases' => [
            '@previewBaseUrl' => 'https://.vercel.app/api/preview',
        ]
    ],

    // Staging environment settings
    'staging' => [
        // Set this to `false` to prevent administrative changes from being made on staging
        'allowAdminChanges' => false,
        // Disable updates in prod
        'allowUpdates' => false,
        // No indexing
        'disallowRobots' => true,
        // Aliases
        'aliases' => [
            '@previewBaseUrl' => 'https://.vercel.app/api/preview',
        ]
    ],

    // Production environment settings
    'production' => [
        // Set this to `false` to prevent administrative changes from being made on production
        'allowAdminChanges' => false,
        // Disable updates in prod
        'allowUpdates' => false,
        // Aliases
        'aliases' => [
            '@previewBaseUrl' => 'https://.vercel.app/api/preview',
        ]
    ],
];

EOF

echo "We are done, please login at https://$PROJECT_CODE.288dev.com/craft"
