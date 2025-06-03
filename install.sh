#!/bin/bash

# bootsrap with
# /bin/bash -c "$(curl -fsSL https://github.com/DeuxHuitHuit/craft-headless-install/raw/main/install.sh)"

set -e -o pipefail

PROJECT_CODE=$(basename "$(pwd)");
INSTALLER_PHP_EXEC="ea-php84"
DEV_SERVER="dev2.288dev.com"

echo "Welcome to Deux Huit Huit's Craft cms v5 installer"
echo ""
echo "We are installing projet $PROJECT_CODE in $(pwd)";

## Check if the project is already installed
if [[ -f "craft" ]]; then
	echo "Craft executable already exists, aborting."
	exit;
elif [[ -d "vendor" ]]; then
	echo "Vendor directory already exists, aborting."
	exit;
elif [[ -d "config" ]]; then
	echo "Config directory already exists, aborting."
	exit;
elif [[ -f "composer.json" ]]; then
	echo "composer.json file already exists, aborting."
	exit;
fi;

if [[ ! -f "$CRAFT_INSTALL_VERSION_FILE" ]]; then
	echo "$CRAFT_INSTALL_VERSION_FILE file not found, aborting."
	exit;
fi;

CRAFT_VERSION=$(jq -r '.require["craftcms/cms"]' < "$CRAFT_INSTALL_VERSION_FILE")
echo "Found Craft version $CRAFT_VERSION as the reference version."

read -r -p 'Continue? [Y/n] ';
if [[ "$REPLY" != "Y" ]]; then
	echo "Abort."
	exit;
fi;

if [[ -f "./web/.htaccess" ]]; then
	echo "Backup web/.htaccess"
	cp "./web/.htaccess" "../$PROJECT_CODE.htaccess"
fi;

if [[ ! -f "../$PROJECT_CODE.htaccess" ]]; then
	echo "Project .htaccess file not found, aborting."
	exit 1;
fi;

echo "Deleting files to make the pwd empty"
for F in ".htaccess" "web" ".well-known"; do
	if [[ -f "$F" ]]; then
		rm -f "./$F";
	elif [[ -d "$F" ]]; then
		rm -rf "./$F";
	fi;
done;

if [[ -f "./error_log" ]]; then
	echo "Found error_log, deleting it"
	rm -f "./error_log";
fi;

echo "Install craft project"
# Use composer from home dir for the first time
${INSTALLER_PHP_EXEC} ~/composer.phar create-project --no-install --no-scripts "craftcms/craft:^5.1" .

# Create env file
cp .env.example.dev .env

# Create proper composer.json
mv -f composer.json.default composer.json

echo "Set proper php version in composer.json"
sed -i 's/"php": "8\.2"/"php": "8.4"/g' composer.json

echo "Install craft"
# Require custom craft version
${INSTALLER_PHP_EXEC} ~/composer.phar require "craftcms/cms:$CRAFT_VERSION"

# Install craft
${INSTALLER_PHP_EXEC} -d max_execution_time=-1 ./craft install

# Fix broken permissions set by craft
chmod 755 web
chmod 644 web/index.php web/.htaccess

echo "Download latest phar version of composer"
wget https://getcomposer.org/download/latest-2.x/composer.phar

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

#### CORS
<IfModule mod_headers.c>
    Header always set Access-Control-Allow-Headers "X-Requested-With, Authorization, Content-Type, Request-Method, X-Craft-Token, Origin, Accept-Ranges"
    Header always set Access-Control-Allow-Methods "POST, GET, OPTIONS"
    Header always set Access-Control-Allow-Credentials "true"
    Header always unset Access-Control-Allow-Origin
    # List of allowed origins:
    # 1. localhost - ports 3000 to 5999
    # 2. Production domain
    # 3. Vercel deploys ($PROJECT_CODE-sveltekit.vercel.app or $PROJECT_CODE-sveltekit-commitish-deuxhuithuit.vercel.app)
    SetEnvIf Origin "^https?://(localhost(:[345][\d][\d][\d])?|((qa|www)\.)?$PROJECT_CODE\.com|$PROJECT_CODE-sveltekit(.+-deuxhuithuit)?\.vercel\.app)$" origin_is=\$0
    Header always set Access-Control-Allow-Origin "%{origin_is}e" env=origin_is
    Header always set vary "Accept-Encoding, Origin, Range"
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
    <FilesMatch "\.(js|css|txt|xml|html|json|woff|woff2|otf|svg|webp)$">
        Header append Cache-Control "public"
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

echo "Create uploads directory"
mkdir -p "./web/uploads"
mkdir -p "./web/stream"

echo "Nuke and recreate an empty module folder"
rm -rf ./modules
mkdir ./modules
touch ./modules/.gitkeep

echo "Delete IIS web.config file"
rm -f "./web/web.config"

echo "Install mvp plugins"
${INSTALLER_PHP_EXEC} ./composer.phar require putyourlightson/craft-sendgrid
${INSTALLER_PHP_EXEC} ./craft plugin/install sendgrid
${INSTALLER_PHP_EXEC} ./composer.phar require verbb/vizy
${INSTALLER_PHP_EXEC} ./craft plugin/install vizy
${INSTALLER_PHP_EXEC} ./composer.phar require verbb/hyper
${INSTALLER_PHP_EXEC} ./craft plugin/install hyper
${INSTALLER_PHP_EXEC} ./composer.phar require dodecastudio/craft-blurhash
${INSTALLER_PHP_EXEC} ./craft plugin/install blur-hash
${INSTALLER_PHP_EXEC} ./composer.phar require mmikkel/cp-field-inspect
${INSTALLER_PHP_EXEC} ./craft plugin/install cp-field-inspect
${INSTALLER_PHP_EXEC} ./composer.phar require craftpulse/craft-colour-swatches
${INSTALLER_PHP_EXEC} ./craft plugin/install colour-swatches
${INSTALLER_PHP_EXEC} ./composer.phar require deuxhuithuit/craft-cloudflare-stream
${INSTALLER_PHP_EXEC} ./craft plugin/install cloudflare-stream
${INSTALLER_PHP_EXEC} ./composer.phar require deuxhuithuit/craft-admin-panel-controllers
${INSTALLER_PHP_EXEC} ./craft plugin/install admin-panel-controllers
${INSTALLER_PHP_EXEC} ./composer.phar require deuxhuithuit/craft-agency-auth
${INSTALLER_PHP_EXEC} ./craft plugin/install agency-auth
${INSTALLER_PHP_EXEC} ./composer.phar require deuxhuithuit/craft-routes-api
${INSTALLER_PHP_EXEC} ./craft plugin/install routes-api
${INSTALLER_PHP_EXEC} ./composer.phar require deuxhuithuit/craft-fonts-api
${INSTALLER_PHP_EXEC} ./craft plugin/install fonts-api
${INSTALLER_PHP_EXEC} ./composer.phar require craftcms/webhooks
${INSTALLER_PHP_EXEC} ./craft plugin/install webhooks

echo "Install dev packages"
${INSTALLER_PHP_EXEC} ./composer.phar require friendsofphp/php-cs-fixer --dev

echo "Create custom htmlpurifier config (overwrites default)"
mkdir -p ./config/htmlpurifier
cat > ./config/htmlpurifier/Default.json << HTMLPURIFIER
{
  "Attr.AllowedFrameTargets": [
    "_blank"
  ],
  "Attr.EnableID": true,
  "HTML.AllowedComments": [
    "pagebreak"
  ],
  "HTML.SafeIframe": true,
  "URI.SafeIframeRegexp": "%^(https?:)?//(www.youtube.com/embed/|player.vimeo.com/video/|www.loom.com/embed/)%"
}

HTMLPURIFIER

echo "Remove .env from .gitignore"
sed '/\/\.env/d' .gitignore >> .gitignore.tmp
mv -f .gitignore.tmp .gitignore
echo "Add /storage to .gitignore"
echo "/storage" >> .gitignore
echo "Add /web/cpressources to .gitignore"
echo "/web/cpressources" >> .gitignore
echo "Add .php-cs-fixer.cache to .gitignore"
echo ".php-cs-fixer.cache" >> .gitignore
echo "Add /web/uploads to .gitignore"
echo "/web/uploads" >> .gitignore
echo "Add /web/stream to .gitignore"
echo "/web/stream" >> .gitignore

echo "Create .gitattributes file"
cat > .gitattributes << GITATTR
# Set fonts to be binary
*.eot binary
*.otf binary
*.ttf binary
*.woff binary
*.woff2 binary
# Set images to be binary
*.png binary
*.jpeg binary
*.jpg binary
*.gif binary
# Set phar to be binary
*.phar binary

GITATTR

echo "Update .env file"
{
echo ""
echo "# Env setup"
echo "SITE_NAME=\"$PROJECT_CODE DEV\""
echo ""
echo "VERCEL_SITE_URL=http://localhost:3000"
echo "PRIMARY_SITE_URL=https://$PROJECT_CODE.$DEV_SERVER"
echo ""
echo "CRAFT_HOME=$(pwd)"
echo "CRAFT_WEBROOT=\${CRAFT_HOME}/web"
echo ""
echo "# Assets"
echo "ASSETS_FILE_SYSTEM_PATH=\${CRAFT_WEBROOT}/uploads"
echo "UPLOADS_URL=\${PRIMARY_SITE_URL}/uploads"
echo "STREAM_FILE_SYSTEM_PATH=\${CRAFT_WEBROOT}/stream"
echo "STREAM_URL=\${PRIMARY_SITE_URL}/stream"
echo ""
echo "# Emails"
echo "SENDGRID_API=\"\""
echo "EMAIL_FROM=noreply@$PROJECT_CODE.$DEV_SERVER"
echo ""
echo "# Cloudflare Stream"
echo "CF_STREAM_ACCOUNT_ID=\"\""
echo "CF_STREAM_API_TOKEN=\"\""
echo ""
} >> .env

echo "Add config file for agency-auth"
cat > config/agency-auth.php << PHP
<?php

return [
    '*' => [
        'client_id' => '',
        'client_secret' => '',
        'domain' => 'deuxhuithuit.co',
        'default_password' => '$AGENCY_AUTH_DEFAULT_PASSWORD',
        'photo_volume_handle' => 'assets',
        'photo_folder_name' => 'user-profile',
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
    ],
    'bootstrap' => [
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
        // Enable headless mode: https://craftcms.com/docs/4.x/config/config-settings.html#headlessmode
        'headlessMode' => true,
        'addTrailingSlashesToUrls' => false,
        'limitAutoSlugsToAscii' => true,
        'useEmailAsUsername' => true,
        'errorTemplatePrefix' => '_pages/errors/',
        'upscaleImages' => false,
        'transformGifs' => false,
        'sendPoweredByHeader' => false,
        'generateTransformsBeforePageLoad' => true,
        'verificationCodeDuration' => 259200, // 72 hours
        'userSessionDuration' => 604800, // 1 week
        'maxUploadFileSize' => '100M',
        // Disable re-encoding of files:
        // This can be dangerous and should be disabled with caution
        // but since it makes images enormous, we can not use it.
        'sanitizeCpImageUploads' => false,
        'sanitizeSvgUploads' => false,
        // If the project has the queue server on, we need to disable this
        'runQueueAutomatically' => true,
        // Since we are in headless mode, we need cookies to be available across sites so we can check authentication
        'sameSiteCookieValue' => 'None',
        // Aliases
        'aliases' => [
            '@host' => App::env('VERCEL_SITE_URL'),
            '@web' => App::env('PRIMARY_SITE_URL'),
            '@webroot' => App::env('CRAFT_WEBROOT'),
        ],
    ],

    // Dev environment settings
    'dev' => [
        // Dev Mode (see https://craftcms.com/guides/what-dev-mode-does)
        'devMode' => true,
        // No indexing
        'disallowRobots' => true,
        // Always disable queue server in dev
        'runQueueAutomatically' => true,
    ],

    // Production environment settings
    'production' => [
        // Set this value only if really required. Should always be false.
        'allowAdminChanges' => false,
        // Disable updates in prod
        'allowUpdates' => false,
        // No indexing
        'disallowRobots' => true,
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

echo "Delete .env.example files if they're still lingering around"
for E in .env.example*; do
	rm -f "${E}";
done

echo "Delete twig files"
rm -f "./templates/*.twig"

echo "Setup dev project downloader"
cat > download-project.sh << 'BASH'
#!/bin/bash

set -e -o pipefail

HOST="dev2@mo7.288dev.com"
PORT="1023"
PROJECT="$1"
PHP_EXEC="ea-php84"

if [[ -z "$PROJECT" ]]; then
	echo "ERROR! Please specify a project name.";
	echo "This should be the name of the folder that contains your Craft project";
	echo "on the remote (dev) server";
	exit;
fi

echo "1. Generating project files"
ssh -p "$PORT" "$HOST" "cd ~/www/$PROJECT/ && rm -rf config/project && $PHP_EXEC ./craft project-config/write"

echo "2. Downloading project files"
# make sure it exists so git won't complain
mkdir -p storage/rebrand
touch storage/rebrand/.gitkeep || true
# remove files from git
git rm -rf config/project || true
git rm -f craft || true
git rm -f web/index.php || true
git rm -f bootstrap.php || true
git rm -rf storage/rebrand || true
# make sure the folder exits, git will have deleted it
mkdir -p storage/rebrand
touch storage/rebrand/.gitkeep
# download the files
rsync -Phavz -e "ssh -p $PORT" "$HOST":"~/www/$PROJECT/config/*" "./config/"
rsync -Phavz -e "ssh -p $PORT" "$HOST":"~/www/$PROJECT/storage/rebrand" "./storage/"
rsync -Phavz -e "ssh -p $PORT" "$HOST":"~/www/$PROJECT/composer.json" "./composer.json"
rsync -Phavz -e "ssh -p $PORT" "$HOST":"~/www/$PROJECT/composer.lock" "./composer.lock"
rsync -Phavz -e "ssh -p $PORT" "$HOST":"~/www/$PROJECT/composer.phar" "./composer.phar"
rsync -Phavz -e "ssh -p $PORT" "$HOST":"~/www/$PROJECT/craft" "./craft"
rsync -Phavz -e "ssh -p $PORT" "$HOST":"~/www/$PROJECT/web/index.php" "./web/index.php"
rsync -Phavz -e "ssh -p $PORT" "$HOST":"~/www/$PROJECT/bootstrap.php" "./bootstrap.php"

echo "3. Adding new files to git"
git add "./storage/rebrand" -f || true
git add "./config"
git add "composer.*"
git add "./craft"
git add "./web/index.php"
git add "./bootstrap.php"

echo "Done 👍"
echo "Please commit the result"
echo ""

BASH

echo "Create deploy script"
cat > deploy.sh << 'BASH'
#!/bin/bash
### Deploy script run by github action
###
### To revert a broken deploy you can
### 1) Restore the backup created by the previous run
### 2) Get the old project files from config/project.$GITHUB_RUN_ID

set -e -o pipefail

PHP_EXEC="ea-php84"
CMD="$1"
GITHUB_RUN_ID="$2"
CRAFT_HOME="${3:-HOME}"
TARGET="${4:-prod}"

echo "👋 Hi from host $HOSTNAME!"
echo "Target is '$TARGET'"
echo "This is run id '$GITHUB_RUN_ID' and command '$CMD'"
cd "${CRAFT_HOME}"

if [ "$CMD" = "backup" ]; then

    echo "Make sure required folder exists"
    mkdir -p ./config
    mkdir -p ./config/project
    mkdir -p ./storage
    mkdir -p ./storage/rebrand
    mkdir -p ./storage/backups

    echo "Backup database"
    "${PHP_EXEC}" ./craft db/backup

    echo "Rename project folder"
    mv ./config/project "./config/project.$GITHUB_RUN_ID"

    echo "Backup done"

elif [ "$CMD" = "setup" ]; then

    echo "Make sure we are NOT overwriting a previously done setup"
    if [ -f "./.setup_done" ]; then
        echo "🛑✋ ABORTING: Setup seems to already exists";
        exit 66;
    fi

    echo "Make sure required folder exists"
    mkdir -p ./config
    mkdir -p ./config/project
    mkdir -p ./migrations
    mkdir -p ./modules
    mkdir -p ./templates
    mkdir -p ./storage
    mkdir -p ./storage/rebrand
    mkdir -p ./storage/backups
    mkdir -p ./storage/restore
    mkdir -p ./web/uploads
    mkdir -p ./web/stream

    echo "Setup done"

elif [ "$CMD" = "apply" ]; then

    echo "Install composer deps"
    "${PHP_EXEC}" composer.phar install --no-scripts --no-dev --prefer-dist --no-progress
    
    echo "Request for a restart of PHP-FPM"
    touch "./restart-${PHP_EXEC}-php-fpm"

    echo "Apply changes and run migrations"
    "${PHP_EXEC}" ./craft up

    echo "Clear temp files"
    "${PHP_EXEC}" ./craft clear-caches/temp-files

    echo "Remove old project files"
    rm -rf "./config/project.$GITHUB_RUN_ID"

    echo "Remove old backups"
    find ./storage/backups -mtime +7 -name '*.sql' -exec rm -f {} \;

    echo "gg;wp 👍"

elif [ "$CMD" = "install" ]; then

    echo "Create .${TARGET} file symlinks"
    ln -s ".env.${TARGET}" .env || true
    rm -rf ./web/.htaccess || true
    ln -s ".htaccess.${TARGET}" ./web/.htaccess || true

    echo "Install composer deps"
    "${PHP_EXEC}" composer.phar install --no-scripts --no-dev --prefer-dist --no-progress

    echo "Try to backup db in case there is a previous one"
    "${PHP_EXEC}" ./craft db/backup --silent-exit-on-exception=1

    echo "Restore db"
    "${PHP_EXEC}" ./craft db/restore ./storage/restore/*.sql

    echo "Clear temp files"
    "${PHP_EXEC}" ./craft clear-caches/temp-files

    echo "Make sure craft runs"
    "${PHP_EXEC}" ./craft

    echo "Mark setup as done"
    echo "done: $GITHUB_RUN_ID" > ./.setup_done
    chmod 444 ./.setup_done || true

    echo "gg;wp 👍"

else
    echo "🛑✋ ERROR, ${CMD} is not a valid command";
    exit 1;
fi

BASH

echo "Create github actions"
mkdir -p .github/workflows
cat > .github/workflows/deploy.yaml << 'YAML'
name: Deploy
on:
  push:
    branches:
      - main
jobs:
  deploy:
    runs-on: self-hosted
    name: Deploy
    env:
      SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
      SLACK_CHANNEL: ${{ secrets.SLACK_CHANNEL }}
      SLACK_USERNAME: POUUUUUUCHE
      SLACK_ICON: ${{ secrets.SLACK_ICON }}
    strategy:
      fail-fast: false
      matrix:
        include:
          # CMS PROD
          - target: prod
            enabled: ${{ github.ref_name == 'main' }}
            host: SSH_HOST
            username: SSH_USERNAME
            port: SSH_PORT
            known_hosts: SSH_KNOWN_HOSTS
            path: ''
    steps:
      - uses: actions/checkout@master
        if: matrix.enabled

      - name: Predeploy notification
        if: matrix.enabled
        uses: rtCamp/action-slack-notify@master
        env:
          SLACK_COLOR: ${{ job.status }}
          SLACK_TITLE: ":rocket: Nouveau déploiement du CMS de ${{ matrix.target }} en cours"

      - name: ssh setup
        if: matrix.enabled
        run: echo "${{ secrets[matrix.known_hosts] }}" > ~/.ssh/known_hosts

      - name: Set CRAFT_HOME
        if: matrix.enabled
        run: echo "CRAFT_HOME=/home/${{ secrets[matrix.username] }}${{ matrix.path }}" >> $GITHUB_OUTPUT;
        id: path

      - name: Remote setup
        if: matrix.enabled && vars.SETUP_DONE == '0'
        run: ssh -p ${{ secrets[matrix.port] }} ${{ secrets[matrix.username] }}@${{ secrets[matrix.host] }} 'bash -s -- setup ${{ github.run_id }} ${{ steps.path.outputs.CRAFT_HOME }} ${{ matrix.target }}' < deploy.sh

      - name: Backup
        if: matrix.enabled && vars.SETUP_DONE  == '1'
        run: ssh -p ${{ secrets[matrix.port] }} ${{ secrets[matrix.username] }}@${{ secrets[matrix.host] }} 'bash -s -- backup ${{ github.run_id }} ${{ steps.path.outputs.CRAFT_HOME }} ${{ matrix.target }}' < deploy.sh

      - name: Upload config
        if: matrix.enabled
        run: rsync -Phavz -e "ssh -p ${{ secrets[matrix.port] }}" ./config ${{ secrets[matrix.username] }}@${{ secrets[matrix.host] }}:${{ steps.path.outputs.CRAFT_HOME }}/

      - name: Upload modules
        if: matrix.enabled
        run: rsync -Phavz -e "ssh -p ${{ secrets[matrix.port] }}" ./modules ${{ secrets[matrix.username] }}@${{ secrets[matrix.host] }}:${{ steps.path.outputs.CRAFT_HOME }}/

      - name: Upload migrations
        if: matrix.enabled
        run: '[ -d "./migrations" ] && rsync -Phavz -e "ssh -p ${{ secrets[matrix.port] }}" ./migrations ${{ secrets[matrix.username] }}@${{ secrets[matrix.host] }}:${{ steps.path.outputs.CRAFT_HOME }}/ || true'

      - name: Upload Rebrand
        if: matrix.enabled
        run: '[ -d "./storage/rebrand" ] && rsync -Phavz -e "ssh -p ${{ secrets[matrix.port] }}" ./storage/rebrand ${{ secrets[matrix.username] }}@${{ secrets[matrix.host] }}:${{ steps.path.outputs.CRAFT_HOME }}/storage/ || true'

      - name: Upload Restore
        if: matrix.enabled && vars.SETUP_DONE == '0'
        run: '[ -d "./storage/restore" ] && rsync -Phavz -e "ssh -p ${{ secrets[matrix.port] }}" ./storage/restore ${{ secrets[matrix.username] }}@${{ secrets[matrix.host] }}:${{ steps.path.outputs.CRAFT_HOME }}/storage/ || true'

      - name: Upload .htaccess.${{ matrix.target }}
        if: matrix.enabled
        run: rsync -Phavz -e "ssh -p ${{ secrets[matrix.port] }}" ./web/.htaccess.${{ matrix.target }} ${{ secrets[matrix.username] }}@${{ secrets[matrix.host] }}:${{ steps.path.outputs.CRAFT_HOME }}/web/

      - name: Upload .env.${{ matrix.target }}
        if: matrix.enabled
        run: rsync -Phavz -e "ssh -p ${{ secrets[matrix.port] }}" ./.env.${{ matrix.target }} ${{ secrets[matrix.username] }}@${{ secrets[matrix.host] }}:${{ steps.path.outputs.CRAFT_HOME }}/

      - name: Upload fonts
        if: matrix.enabled
        run: '[ -d "./web/fonts" ] && rsync -Phavz -e "ssh -p ${{ secrets[matrix.port] }}" ./web/fonts ${{ secrets[matrix.username] }}@${{ secrets[matrix.host] }}:${{ steps.path.outputs.CRAFT_HOME }}/web/ || true'

      - name: Upload composer files
        if: matrix.enabled
        run: rsync -Phavz -e "ssh -p ${{ secrets[matrix.port] }}" ./composer.* ${{ secrets[matrix.username] }}@${{ secrets[matrix.host] }}:${{ steps.path.outputs.CRAFT_HOME }}/

      - name: Upload craft cli
        if: matrix.enabled
        run: rsync -Phavz -e "ssh -p ${{ secrets[matrix.port] }}" ./craft ${{ secrets[matrix.username] }}@${{ secrets[matrix.host] }}:${{ steps.path.outputs.CRAFT_HOME }}/

      - name: Upload service file
        if: matrix.enabled
        run: '[ -f ./*.service ] && rsync -Phavz -e "ssh -p ${{ secrets[matrix.port] }}" ./*.service ${{ secrets[matrix.username] }}@${{ secrets[matrix.host] }}:${{ steps.path.outputs.CRAFT_HOME }}/ || true'

      - name: Upload bootstrap.php
        if: matrix.enabled && vars.SETUP_DONE == '0'
        run: rsync -Phavz -e "ssh -p ${{ secrets[matrix.port] }}" ./bootstrap.php ${{ secrets[matrix.username] }}@${{ secrets[matrix.host] }}:${{ steps.path.outputs.CRAFT_HOME }}/

      - name: Upload index.php
        if: matrix.enabled && vars.SETUP_DONE == '0'
        run: rsync -Phavz -e "ssh -p ${{ secrets[matrix.port] }}" ./web/index.php ${{ secrets[matrix.username] }}@${{ secrets[matrix.host] }}:${{ steps.path.outputs.CRAFT_HOME }}/web

      - name: First install
        if: matrix.enabled && vars.SETUP_DONE == '0'
        run: ssh -p ${{ secrets[matrix.port] }} ${{ secrets[matrix.username] }}@${{ secrets[matrix.host] }} 'bash -s -- install ${{ github.run_id }} ${{ steps.path.outputs.CRAFT_HOME }} ${{ matrix.target }}' < deploy.sh

      - name: Install and apply
        if: matrix.enabled && vars.SETUP_DONE == '1'
        run: ssh -p ${{ secrets[matrix.port] }} ${{ secrets[matrix.username] }}@${{ secrets[matrix.host] }} 'bash -s -- apply ${{ github.run_id }} ${{ steps.path.outputs.CRAFT_HOME }} ${{ matrix.target }}' < deploy.sh

      - name: Postdeploy failure notification
        uses: rtCamp/action-slack-notify@master
        if: matrix.enabled && failure()
        env:
          SLACK_COLOR: ${{ job.status }}
          SLACK_TITLE: ":alert::alert::alert: Échec du déploiement de ${{ matrix.target }} :alert::alert::alert:"

      - name: Postdeploy success notification
        uses: rtCamp/action-slack-notify@master
        if: matrix.enabled && success()
        env:
          SLACK_COLOR: ${{ job.status }}
          SLACK_TITLE: ":moon: Le CMS de ${{ matrix.target }} a atterrit avec succès :sparkles:"

YAML

cat > .github/workflows/format.yaml << 'YAML'
name: Format code

on:
    pull_request:

jobs:
    format:
        runs-on: ubuntu-latest

        steps:
            - uses: actions/checkout@master
              with:
                  ref: ${{ github.head_ref }}

            - name: Setup PHP
              uses: shivammathur/setup-php@master
              with:
                php-version: '8.4'
                coverage: none
                tools: composer

            - name: composer install
              run: composer install --no-scripts --prefer-dist --no-progress

            - name: format
              run: ./vendor/bin/php-cs-fixer fix modules --rules=@PhpCsFixer,-yoda_style,-concat_space

            - uses: stefanzweifel/git-auto-commit-action@master
              with:
                  commit_message: Format code

YAML

cat > .github/workflows/cms-sync.yaml << 'YAML'
name: "CMS Sync"
on:
  workflow_dispatch:

jobs:
  sync:
    runs-on: self-hosted
    name: Sync
    steps:
      - uses: actions/checkout@master

      - name: Setup
        run: echo "${{ secrets.DEV_SSH_KNOWN_HOSTS }}" > ~/.ssh/known_hosts

      - name: Sync
        run: ./download-project.sh ${{ secrets.DEV_PROJECT_NAME }}

      - name: Status
        run: git status

      - name: Create Pull Request
        id: pr
        uses: peter-evans/create-pull-request@main
        with:
          commit-message: CMS Sync
          title: New CMS Sync
          branch: cms-sync/${{ github.run_id }}
          delete-branch: true
          reviewers: ${{ github.actor }}
          assignees: ${{ github.triggering_actor }}

      - name: Post PR notification
        uses: rtCamp/action-slack-notify@master
        if: success() && steps.pr.outputs.pull-request-number != ''
        env:
          SLACK_COLOR: ${{ job.status }}
          SLACK_USERNAME: CMS
          SLACK_TITLE: "Le PR pour le sync du CMS est prêt !"
          SLACK_MESSAGE: |
            Vous devez maintenant faire le code review!
            <${{ github.server_url }}/${{ github.repository }}/pull/${{ steps.pr.outputs.pull-request-number }}>

      - name: No PR notification
        uses: rtCamp/action-slack-notify@master
        if: failure() || steps.pr.outputs.pull-request-number == ''
        env:
          SLACK_COLOR: ${{ job.status }}
          SLACK_USERNAME: CMS
          SLACK_TITLE: "Pas de diff!"
          SLACK_MESSAGE: |
            Il n'y a pas de différence entre le CMS et le projet.

YAML

echo "Install project files"
rm -rf config/project
wget https://github.com/DeuxHuitHuit/craft-headless-install/raw/main/project.tar.gz
tar -xvf project.tar.gz -C config/
rm -f project.tar.gz
sed "s/__PROJECT__/${PROJECT_CODE}/g" config/project/project.yaml > config/project/project.yaml.tmp
mv -f config/project/project.yaml.tmp config/project/project.yaml
${INSTALLER_PHP_EXEC} ./craft up

echo "Creating symlinks for .env and .htaccess files"
cd web
mv .htaccess .htaccess.dev
ln -s .htaccess.dev .htaccess
cd -
mv .env .env.dev
ln -s .env.dev .env

echo "Initialize git repository"
git init
git add .gitignore .gitattributes
git add .
git add .env.*
git commit -a -m "Initial commit, on dev server"

echo "We are done 🐔🐔🐔"
echo "To use deuxhuithuit.co login, configure config/agency-auth.php"
echo "Please login at https://$PROJECT_CODE.$DEV_SERVER/craft"
