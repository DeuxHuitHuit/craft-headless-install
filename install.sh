#!/bin/bash

# bootsrap with
# /bin/bash -c "$(curl -fsSL https://github.com/DeuxHuitHuit/craft-headless-install/raw/main/install.sh)"

set -e -o pipefail

PROJECT_CODE=$(basename "$(pwd)");
INSTALLER_PHP_EXEC="ea-php82"

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
# Use composer from home dir for the first time
${INSTALLER_PHP_EXEC} ~/composer.phar create-project craftcms/craft .

echo "Download latest phar version of composer"
wget https://getcomposer.org/download/latest-2.x/composer.phar

echo "Set proper php version in composer.json"
sed -i 's/"php": "8\.0\.2"/"php": "8.2"/g' composer.json

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
mkdir -p "./web/uploads/stream"

echo "Nuke and recreate an empty module folder"
rm -rf ./modules
mkdir ./modules
touch ./modules/.gitkeep

echo "Delete IIS web.config file"
rm -f "./web/web.config"

echo "Install cp-field-inspect, redactor, snitch, ..."
${INSTALLER_PHP_EXEC} ./composer.phar require mmikkel/cp-field-inspect
${INSTALLER_PHP_EXEC} ./craft plugin/install cp-field-inspect
${INSTALLER_PHP_EXEC} ./composer.phar require craftcms/redactor
${INSTALLER_PHP_EXEC} ./craft plugin/install redactor
${INSTALLER_PHP_EXEC} ./composer.phar require putyourlightson/craft-sendgrid
${INSTALLER_PHP_EXEC} ./craft plugin/install sendgrid
${INSTALLER_PHP_EXEC} ./composer.phar require carlcs/craft-redactorcustomstyles
${INSTALLER_PHP_EXEC} ./craft plugin/install redactor-custom-styles
${INSTALLER_PHP_EXEC} ./composer.phar require spicyweb/craft-neo
${INSTALLER_PHP_EXEC} ./craft plugin/install neo
${INSTALLER_PHP_EXEC} ./composer.phar require dodecastudio/craft-blurhash
${INSTALLER_PHP_EXEC} ./craft plugin/install blur-hash
${INSTALLER_PHP_EXEC} ./composer.phar require verbb/field-manager
${INSTALLER_PHP_EXEC} ./craft plugin/install field-manager
${INSTALLER_PHP_EXEC} ./composer.phar require deuxhuithuit/craft-cloudflare-stream
${INSTALLER_PHP_EXEC} ./craft plugin/install cloudflare-stream
${INSTALLER_PHP_EXEC} ./composer.phar require deuxhuithuit/craft-admin-panel-controllers
${INSTALLER_PHP_EXEC} ./craft plugin/install admin-panel-controllers
${INSTALLER_PHP_EXEC} ./composer.phar require deuxhuithuit/craft-agency-auth
${INSTALLER_PHP_EXEC} ./craft plugin/install agency-auth
${INSTALLER_PHP_EXEC} ./composer.phar require deuxhuithuit/craft-routes-api
${INSTALLER_PHP_EXEC} ./craft plugin/install routes-api

echo "Install dev packages"
${INSTALLER_PHP_EXEC} ./composer.phar require friendsofphp/php-cs-fixer --dev

echo "Create default redactor config"
mkdir -p ./config/redactor
cat > ./config/redactor/Default.json << REDACTORDEFAULT
{
	"buttons": ["html", "formatting", "unorderedlist", "orderedlist", "bold", "italic", "link"],
	"formatting": [],
	"formattingAdd": {
		"heading-2": {
			"title": "Titre",
			"api": "module.block.format",
			"args": {
				"tag": "h2"
			}
		},
		"heading-3": {
			"title": "Sous-titre",
			"api": "module.block.format",
			"args": {
				"tag": "h3"
			}
		},
		"paragraph": {
			"title": "Paragraphe",
			"api": "module.block.format",
			"args": {
				"tag": "p"
			}
		},
		"quote": {
			"title": "Citation",
			"api": "module.block.format",
			"args": {
				"tag": "blockquote"
			}
		}
	},
	"linkNewTab": true
}
REDACTORDEFAULT

echo "Create inline redactor config"
cat > ./config/redactor/Inline.json << REDACTORINLINE
{
	"buttons": ["html", "bold", "italic", "link"],
	"formatting": [],
	"breakline": true,
	"linkNewTab": true
}
REDACTORINLINE

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
echo "ASSETS_FILE_SYSTEM_PATH=$(pwd)/web/uploads"
echo "UPLOADS_URL=https://$PROJECT_CODE.288dev.com/uploads"
echo "STREAM_FILE_SYSTEM_PATH=$(pwd)/web/uploads/stream"
echo "STREAM_URL=https://$PROJECT_CODE.288dev.com/uploads/stream"
echo ""
echo "SITE_NAME=$PROJECT_CODE"
echo ""
echo "SENDGRID_API=\"\""
echo "EMAIL_FROM=noreply@$PROJECT_CODE.288dev.com"
echo ""
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
        // Enable headless mode: https://craftcms.com/docs/3.x/config/config-settings.html#headlessmode
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
        'sameSiteCookieValue' => 'None'
    ],

    // Dev environment settings
    'dev' => [
        // Dev Mode (see https://craftcms.com/guides/what-dev-mode-does)
        'devMode' => true,
        // No indexing
        'disallowRobots' => true,
        // Always disable queue server in dev
        'runQueueAutomatically' => true,
        // Aliases
        'aliases' => [
            '@host' => 'http://localhost:3000',
            '@web' => 'https://$PROJECT_CODE.288dev.com',
        ]
    ],

    // Production environment settings
    'production' => [
        // Set this value only if really required. Should always be false.
        'allowAdminChanges' => false,
        // Disable updates in prod
        'allowUpdates' => false,
        // No indexing
        'disallowRobots' => true,
        // Aliases
        'aliases' => [
            '@host' => 'https://',
            '@web' => 'https://',
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

HOST="dev@hg2.288dev.com"
PORT="1023"
PROJECT="$1"
PHP_EXEC="ea-php82"

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

CRAFT_HOME="${HOME}"
PHP_EXEC="ea-php82"
CMD="$1"
GITHUB_RUN_ID="$2"

echo "Hi from host $HOSTNAME for run $GITHUB_RUN_ID and command $CMD"
cd "${CRAFT_HOME}"
pwd

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
    mkdir -p ./web/uploads/stream

    echo "Setup done"

elif [ "$CMD" = "apply" ]; then

    echo "Install composer deps"
    "${PHP_EXEC}" composer.phar install --no-scripts --no-dev --prefer-dist --no-progress

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

    echo "Create .prod file symlinks"
    ln -s .env.prod .env || true
    rm -rf ./web/.htaccess || true
    ln -s .htaccess.prod ./web/.htaccess || true

    echo "Install composer deps"
    "${PHP_EXEC}" composer.phar install --no-scripts --no-dev --prefer-dist --no-progress

    echo "Restore db"
    "${PHP_EXEC}" ./craft db/restore ./storage/restore/*.sql

    echo "Clear temp files"
    "${PHP_EXEC}" ./craft clear-caches/temp-files

    echo "Make sure craft runs"
    "${PHP_EXEC}" ./craft

    echo "gg;wp 👍"

else
    echo "ERROR, $CMD is not a valid command";
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
    steps:
      - uses: actions/checkout@master

      - name: Predeploy notification
        uses: rtCamp/action-slack-notify@master
        env:
          SLACK_COLOR: ${{ job.status }}
          SLACK_TITLE: ":rocket: Nouveau déploiement du CMS en cours"

      - name: ssh setup
        run: echo "${{ secrets.SSH_KNOWN_HOSTS }}" > ~/.ssh/known_hosts

      - name: Detect run type (install/deploy)
        run: if [[ "${{ vars.SETUP_DONE }}" -eq "1" ]]; then echo "IS_INSTALL=0" >> $GITHUB_OUTPUT; else echo "IS_INSTALL=1" >> $GITHUB_OUTPUT; fi;
        id: runtype

      - name: Set CRAFT_HOME
        run: echo "CRAFT_HOME=/home/${{ secrets.SSH_USERNAME }}" >> $GITHUB_OUTPUT;
        id: path

      - name: Remote setup
        if: steps.runtype.outputs.IS_INSTALL == '1'
        run: ssh -p ${{ secrets.SSH_PORT }} ${{ secrets.SSH_USERNAME }}@${{ secrets.SSH_HOST }} 'bash -s -- setup ${{ github.run_id }}' < deploy.sh

      - name: Backup
        if: steps.runtype.outputs.IS_INSTALL == '0'
        run: ssh -p ${{ secrets.SSH_PORT }} ${{ secrets.SSH_USERNAME }}@${{ secrets.SSH_HOST }} 'bash -s -- backup ${{ github.run_id }}' < deploy.sh

      - name: Upload config
        run: rsync -Phavz -e "ssh -p ${{ secrets.SSH_PORT }}" ./config ${{ secrets.SSH_USERNAME }}@${{ secrets.SSH_HOST }}:${{ steps.path.outputs.CRAFT_HOME }}/

      - name: Upload modules
        run: rsync -Phavz -e "ssh -p ${{ secrets.SSH_PORT }}" ./modules ${{ secrets.SSH_USERNAME }}@${{ secrets.SSH_HOST }}:${{ steps.path.outputs.CRAFT_HOME }}/

      - name: Upload migrations
        run: '[ -d "./migrations" ] && rsync -Phavz -e "ssh -p ${{ secrets.SSH_PORT }}" ./migrations ${{ secrets.SSH_USERNAME }}@${{ secrets.SSH_HOST }}:${{ steps.path.outputs.CRAFT_HOME }}/ || true'

      - name: Upload Rebrand
        run: '[ -d "./storage/rebrand" ] && rsync -Phavz -e "ssh -p ${{ secrets.SSH_PORT }}" ./storage/rebrand ${{ secrets.SSH_USERNAME }}@${{ secrets.SSH_HOST }}:${{ steps.path.outputs.CRAFT_HOME }}/storage/ || true'

      - name: Upload Restore
        if: steps.runtype.outputs.IS_INSTALL == '1'
        run: '[ -d "./storage/restore" ] && rsync -Phavz -e "ssh -p ${{ secrets.SSH_PORT }}" ./storage/restore ${{ secrets.SSH_USERNAME }}@${{ secrets.SSH_HOST }}:${{ steps.path.outputs.CRAFT_HOME }}/storage/ || true'

      - name: Upload .htaccess.prod
        run: rsync -Phavz -e "ssh -p ${{ secrets.SSH_PORT }}" ./web/.htaccess.prod ${{ secrets.SSH_USERNAME }}@${{ secrets.SSH_HOST }}:${{ steps.path.outputs.CRAFT_HOME }}/web/

      - name: Upload .env.prod
        run: rsync -Phavz -e "ssh -p ${{ secrets.SSH_PORT }}" ./.env.prod ${{ secrets.SSH_USERNAME }}@${{ secrets.SSH_HOST }}:${{ steps.path.outputs.CRAFT_HOME }}/

      - name: Upload composer files
        run: rsync -Phavz -e "ssh -p ${{ secrets.SSH_PORT }}" ./composer.* ${{ secrets.SSH_USERNAME }}@${{ secrets.SSH_HOST }}:${{ steps.path.outputs.CRAFT_HOME }}/

      - name: Upload craft cli
        run: rsync -Phavz -e "ssh -p ${{ secrets.SSH_PORT }}" ./craft ${{ secrets.SSH_USERNAME }}@${{ secrets.SSH_HOST }}:${{ steps.path.outputs.CRAFT_HOME }}/

      - name: Upload service file
        run: '[ -f ./*.service ] && rsync -Phavz -e "ssh -p ${{ secrets.SSH_PORT }}" ./*.service ${{ secrets.SSH_USERNAME }}@${{ secrets.SSH_HOST }}:{{ steps.path.outputs.CRAFT_HOME }} || true'

      - name: Upload bootstrap.php
        if: steps.runtype.outputs.IS_INSTALL == '1'
        run: rsync -Phavz -e "ssh -p ${{ secrets.SSH_PORT }}" ./bootstrap.php ${{ secrets.SSH_USERNAME }}@${{ secrets.SSH_HOST }}:${{ steps.path.outputs.CRAFT_HOME }}/

      - name: Upload index.php
        if: steps.runtype.outputs.IS_INSTALL == '1'
        run: rsync -Phavz -e "ssh -p ${{ secrets.SSH_PORT }}" ./web/index.php ${{ secrets.SSH_USERNAME }}@${{ secrets.SSH_HOST }}:${{ steps.path.outputs.CRAFT_HOME }}/web

      - name: First install
        if: steps.runtype.outputs.IS_INSTALL == '1'
        run: ssh -p ${{ secrets.SSH_PORT }} ${{ secrets.SSH_USERNAME }}@${{ secrets.SSH_HOST }} 'bash -s -- install ${{ github.run_id }}' < deploy.sh

      - name: Install and apply
        if: steps.runtype.outputs.IS_INSTALL == '0'
        run: ssh -p ${{ secrets.SSH_PORT }} ${{ secrets.SSH_USERNAME }}@${{ secrets.SSH_HOST }} 'bash -s -- apply ${{ github.run_id }}' < deploy.sh

      - name: Postdeploy failure notification
        uses: rtCamp/action-slack-notify@master
        if: failure()
        env:
          SLACK_COLOR: ${{ job.status }}
          SLACK_TITLE: ":alert::alert::alert: Échec du déploiement :alert::alert::alert:"

      - name: Postdeploy success notification
        uses: rtCamp/action-slack-notify@master
        if: success()
        env:
          SLACK_COLOR: ${{ job.status }}
          SLACK_TITLE: ":moon: Le CMS a atterrit avec succès :sparkles:"

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
                php-version: '8.2'
                coverage: none
                tools: composer

            - name: composer install
              run: composer install --no-scripts --prefer-dist --no-suggest --no-progress

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
          SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
          SLACK_CHANNEL: ${{ secrets.SLACK_CHANNEL }}
          SLACK_COLOR: ${{ job.status }}
          SLACK_USERNAME: CMS
          SLACK_ICON: ${{ secrets.SLACK_ICON }}
          SLACK_TITLE: "Le PR pour le sync du CMS est prêt !"
          SLACK_MESSAGE: |
            Vous devez maintenant faire le code review!
            <${{ github.server_url }}/${{ github.repository }}/pull/${{ steps.pr.outputs.pull-request-number }}>

      - name: No PR notification
        uses: rtCamp/action-slack-notify@master
        if: failure() || steps.pr.outputs.pull-request-number == ''
        env:
          SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
          SLACK_CHANNEL: ${{ secrets.SLACK_CHANNEL }}
          SLACK_COLOR: ${{ job.status }}
          SLACK_USERNAME: CMS
          SLACK_ICON: ${{ secrets.SLACK_ICON }}
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

echo "We are done 🐔🐔🐔"
echo "To use deuxhuithuit.co login, configure config/agency-auth.php"
echo "Please login at https://$PROJECT_CODE.288dev.com/craft"
