#!/bin/sh

# Work in progress!

echo '[MAIN] Running startup script:'

# Wait for db to be ready:
wait-for-it -t 0 ${DB_ADDR}:${DB_PORT}

# Setup Typo3 with typo3console (https://docs.typo3.org/p/helhum/typo3-console/main/en-us/CommandReference/InstallSetup.html):
cd /var/www/typo3/
docker-php-ext-install -j$(nproc) mysqli
echo '[MAIN] Auto setup typo3:'
vendor/bin/typo3cms install:setup \
    --use-existing-database \
    --database-driver='mysqli' \
    --database-user-name='typo3' \
    --database-user-password='password' \
    --database-host-name='db' \
    --database-port=3306 \
    --database-name='typo3-dfgviewer-v5' \
    --admin-user-name='test' \
    --admin-password='test1234' \
    --site-setup-type=no \
    --site-name presentation \
    --web-server-config=apache

# Install Kitodo.Presentation and DFG-Viewer:
echo '[MAIN] Install Presentation and DFG-Viewer:'
composer config platform.php 7.4
composer require slub/dfgviewer
vendor/bin/typo3 extensionmanager:extension:install dlf
vendor/bin/typo3 extensionmanager:extension:install dfgviewer
chown -R www-data:www-data .

# Check status:
echo '[MAIN] Check apache status:'
service apache2 status

echo '[MAIN] Finished setup: http://localhost/typo3/ '