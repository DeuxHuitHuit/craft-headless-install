#!/bin/bash

# bootsrap with
# /bin/bash -c "$(curl -fsSL https://github.com/DeuxHuitHuit/craft-headless-install/raw/main/install.sh)"

set -e -o pipefail

PROJECT_CODE=$(basename "$(pwd)");

echo "Welcome to Deux Huit Huit craft installer"
echo ""
echo "We are installing projet $PROJECT_CODE in $(pwd)";

read -r -p 'Continue? [Y/n] ';
if [[ "$REPLY" != "Y" ]]; then
	echo "Abort."
	exit;
fi;

echo "Backup web/.htaccess"
cp web/.htaccess "../$PROJECT_CODE.htaccess"

echo "Deleting files to make the pwd empty"
for F in ".htaccess" "web" ".well-known"; do
	if [[ -f "$F" ]]; then
		rm -f "./$F"
	elif [[ -d "$F" ]]; then
		rm -rf "./$F"
	fi
done

echo "Install craft"
composer create-project craftcms/craft .

echo "Restore htaccess infos"
echo "" >> web/.htaccess
cat "../$PROJECT_CODE.htaccess" >> web/.htaccess
rm -f "../$PROJECT_CODE.htaccess"

echo "Customize .htaccess file"
{
	cat << HTACCESS
#### SECURE APACHE
Options +SymLinksIfOwnerMatch -Indexes
<IfModule mod_negotiation.c>
    Options -MultiViews
</IfModule>

#### CUSTOM
<IfModule mod_rewrite.c>
    ## force TLS
    RewriteCond %{SERVER_PORT} !^443$
    RewriteRule .* https://%{HTTP_HOST}%{REQUEST_URI} [R=307,L]
</IfModule>

### CRAFT CMS
HTACCESS
	cat web/.htaccess
	cat ../authbypass.htaccess
	cat << HTACCESS

### Content-Types

AddType audio/mpeg mp3
AddType audio/mp4 m4a
AddType audio/ogg ogg
AddType audio/ogg oga
AddType audio/webm webma
AddType audio/webm weba
AddType audio/wav wav

AddType video/mp4 mp4
AddType video/mp4 m4v
AddType video/ogg ogv
AddType video/webm webm
AddType video/webm webmv

AddType image/vnd.microsoft.icon cur
AddType image/vnd.microsoft.icon ico
AddType application/x-navi-animation ani

AddType application/x-font-ttf ttf
AddType font/opentype otf
AddType application/x-font-woff woff
AddType application/font-woff2 woff2
AddType image/svg+xml svg
AddType application/vnd.ms-fontobject eot

AddType text/plain srt
AddType text/plain less

# No transform images
<IfModule mod_headers.c>
    <FilesMatch "\.(png|jpg|jpeg|gif|ico)$">
        Header append Cache-Control "public, no-transform"
    </FilesMatch>
</IfModule>

# ----------------------------------------------------------------------
# Expires headers (for better cache control)
# ----------------------------------------------------------------------

# These are pretty far-future expires headers.
# They assume you control versioning with filename-based cache busting
# Additionally, consider that outdated proxies may miscache
#   www.stevesouders.com/blog/2008/08/23/revving-filenames-dont-use-querystring/

# If you don't use filenames to version, lower the CSS  and JS to something like
#   "access plus 1 week" or so.

<IfModule mod_expires.c>
  ExpiresActive on

# Perhaps better to whitelist expires rules? Perhaps.
  ExpiresDefault                          "access plus 1 month"

# cache.appcache needs re-requests in FF 3.6 (thanks Remy ~Introducing HTML5)
  ExpiresByType text/cache-manifest       "access plus 0 seconds"

# Your document html
  ExpiresByType text/html                 "access plus 0 seconds"

# Data
  ExpiresByType text/xml                  "access plus 0 seconds"
  ExpiresByType application/xml           "access plus 0 seconds"
  ExpiresByType application/json          "access plus 0 seconds"

# Feed
  ExpiresByType application/rss+xml       "access plus 1 hour"
  ExpiresByType application/atom+xml      "access plus 1 hour"

# Favicon (cannot be renamed)
  ExpiresByType image/x-icon              "access plus 1 year"

# Media: images, video, audio
  ExpiresByType image/gif                 "access plus 1 year"
  ExpiresByType image/png                 "access plus 1 year"
  ExpiresByType image/jpeg                "access plus 1 year"
  ExpiresByType video/ogg                 "access plus 1 year"
  ExpiresByType audio/ogg                 "access plus 1 year"
  ExpiresByType video/mp4                 "access plus 1 year"
  ExpiresByType video/webm                "access plus 1 year"
  ExpiresByType video/ogg                 "access plus 1 year"

# HTC files  (css3pie)
  ExpiresByType text/x-component          "access plus 1 month"

# Webfonts
  ExpiresByType application/x-font-ttf    "access plus 1 year"
  ExpiresByType font/opentype             "access plus 1 year"
  ExpiresByType application/x-font-woff   "access plus 1 year"
  ExpiresByType application/font-woff2    "access plus 1 year"
  ExpiresByType image/svg+xml             "access plus 1 year"
  ExpiresByType application/vnd.ms-fontobject "access plus 1 year"

# CSS and JavaScript
  ExpiresByType text/css                  "access plus 1 year"
  ExpiresByType application/javascript    "access plus 1 year"

# Text
  ExpiresByType text/plain                "access plus 0 seconds"

</IfModule>

# ----------------------------------------------------------------------
# ETag removal
# ----------------------------------------------------------------------

# FileETag None is not enough for every server.
<IfModule mod_headers.c>
  Header unset ETag
</IfModule>

HTACCESS
} > web/.htaccess.tmp
mv -f web/.htaccess.tmp web/.htaccess

echo "Make the cli executable"
chmod u+x ./craft

echo "Create storage directory"
mkdir -p "./storage"

echo "Create upload directory"
mkdir -p "./web/upload"

echo "Nuke and recreate the module folder"
rm -rf ./modules
mkdir ./modules

echo "Install custom modules"
cd ./modules
git clone https://github.com/DeuxHuitHuit/craft-agency-auth.git
mv ./craft-agency-auth ./agency-auth
rm -rf ./agency-auth/.git
rm -f ./agency-auth/.gitignore
cd ..
sed 's/modules\\\\"\: "modules\/"/modules\\\\agencyauth\\\\"\: "modules\/agency-auth\/src\/"/g' composer.json > composer.tmp
mv -f composer.tmp composer.json
composer dump-autoload -a

echo "Delete IIS web.config file"
rm -f "./web/web.config"

echo "Install cp-field-inspect, redactor, snitch, ..."
composer require mmikkel/cp-field-inspect
ea-php74 ./craft plugin/install cp-field-inspect
composer require craftcms/redactor
ea-php74 ./craft plugin/install redactor
composer require marionnewlevant/snitch
ea-php74 ./craft plugin/install snitch

echo "Remove .env from .gitignore"
sed '/\/\.env/d' .gitignore >> .gitignore.tmp
mv -f .gitignore.tmp .gitignore
echo "Add /storage to .gitignore"
echo "/storage" >> .gitignore
echo "Add /web/cpressources to .gitignore"
echo "/web/cpressources" >> .gitignore

echo "Update .env file"
{
echo ""
echo "ASSETS_FILE_SYSTEM_PATH=$(pwd)/web/uploads"
echo ""
echo "UPLOADS_URL=https://$PROJECT_CODE.288dev.com/uploads"
echo ""
} >> .env

echo "Add config file for agency-auth"
cat > config/agency-auth.php << PHP
<?php

return [
    '*' => [
        'client_id' => '',
        'client_secret' => '',
    ]
];

PHP

echo "Add modules files"
cat > config/app.php << PHP
<?php
/**
 * Yii Application Config
 *
 * Edit this file at your own risk!
 *
 * The array returned by this file will get merged with
 * vendor/craftcms/cms/src/config/app.php and app.[web|console].php, when
 * Craft's bootstrap script is defining the configuration for the entire
 * application.
 *
 * You can define custom modules and system components, and even override the
 * built-in system components.
 *
 * If you want to modify the application config for *only* web requests or
 * *only* console requests, create an app.web.php or app.console.php file in
 * your config/ folder, alongside this one.
 */

use craft\helpers\App;

return [
    'id' => App::env('APP_ID') ?: 'CraftCMS Headless',
    'modules' => [
        'agency-auth' => \modules\agencyauth\AgencyAuth::class,
    ],
    'bootstrap' => [
        'agency-auth',
    ],
];

PHP

echo "Add headless config for craft"
cat > config/general.php << PHP
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
        // Set this value only if really required. Should always be false.
        'allowAdminChanges' => false,
        // Disable updates in staging
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
        // Set this value only if really required. Should always be false.
        'allowAdminChanges' => false,
        // Disable updates in prod
        'allowUpdates' => false,
        // Aliases
        'aliases' => [
            '@previewBaseUrl' => 'https://.vercel.app/api/preview',
        ]
    ],
];

PHP

cat > config/routes.php << PHP
<?php
/**
 * Site URL Rules
 *
 * You can define custom site URL rules here, which Craft will check in addition
 * to any routes you’ve defined in Settings → Routes.
 *
 * See http://www.yiiframework.com/doc-2.0/guide-runtime-routing.html for more
 * info about URL rules.
 *
 * In addition to Yii’s supported syntaxes, Craft supports a shortcut syntax for
 * defining template routes:
 *
 *     'blog/archive/<year:\d{4}>' => ['template' => 'blog/_archive'],
 *
 * That example would match URIs such as '/blog/archive/2012', and pass the
 * request along to the 'blog/_archive' template, providing it a 'year' variable
 * set to the value '2012'.
 */

return [
    'api' => 'graphql/api'
];

PHP

echo "Delete .env.example if still lingering around"
if [[ -f ".env.example" ]]; then
	rm -f ".env.example"
fi

echo "Setup dev project downloader"
cat > download-project.sh <<BASH
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
ssh -p "$PORT" "$HOST" "cd ~/www/$PROJECT/ && rm -rf config/project && ea-php74 ./craft project-config/write"

echo "2. Downloading project files"
git rm -r config/project
scp -r -P "$PORT" "$HOST":"~/www/$PROJECT/config/project" "./config"

echo "3. Adding new files to git"
git add "./config/project"

echo "Done 👍"
echo "Please commit the result"
echo ""

BASH

echo "Install project files"
rm -rf config/project
wget https://github.com/DeuxHuitHuit/craft-headless-install/raw/main/project.tar.gz
tar -xvf project.tar.gz -C config/
rm -f project.tar.gz
sed "s/__PROJECT__/${PROJECT_CODE}/g" config/project/project.yaml > config/project/project.yaml.tmp
mv -f config/project/project.yaml.tmp config/project/project.yaml
ea-php74 ./craft project-config/apply

echo "We are done, please login at https://$PROJECT_CODE.288dev.com/craft"
