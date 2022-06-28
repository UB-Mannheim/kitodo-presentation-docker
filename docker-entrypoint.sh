#!/bin/sh

# Work in progress!

echo '[MAIN] Running startup script:'

# Get waiting script
echo '[MAIN] get waiting script:'
apt-get update
apt-get install -y wget
wget -q https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh 
# Cleanup:
echo '[MAIN] cleanup:'
apt-get purge -y wget
apt-get autoremove -y
apt-get clean 
rm -rf /var/lib/apt/lists/*
# Wait for database container:
chmod +x wait-for-it.sh
./wait-for-it.sh -t 0 ${DB_ADDR}:${DB_PORT}

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
    --database-name='typo3-presentation-v3' \
    --admin-user-name='test' \
    --admin-password='test1234' \
    --site-setup-type=no \
    --site-name presentation \
    --web-server-config=apache

# Install Kitodo.Presentation v3.3:
echo '[MAIN] Install presentation 3.3:'
composer config platform.php 7.4 
composer require kitodo/presentation:^3.3 
vendor/bin/typo3 extensionmanager:extension:install dlf
chown -R www-data:www-data .

# Check status:
echo '[MAIN] Check apache status:'
service apache2 status

echo '[MAIN] Finished setup: http://localhost/typo3/ '