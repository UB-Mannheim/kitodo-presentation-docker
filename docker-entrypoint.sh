#!/bin/sh

# Work in progress!

echo '[MAIN] Running startup script:'

# Get waiting script
echo '[MAIN] get waiting script:'
apt-get update
apt-get install -y wget
wget -q https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh 

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
    --database-name='typo3-dfgviewer-v5-ocr' \
    --admin-user-name='test' \
    --admin-password='test1234' \
    --site-setup-type=no \
    --site-name presentation \
    --web-server-config=apache

# Install Kitodo.Presentation and DFG-Viewer with OCR-On-Demand:
echo '[MAIN] Install Presentation and DFG-Viewer with OCR-On-Demand:'
composer config platform.php 7.4
apt-get install -y jq
jq '.repositories += [{"type": "git", "url": "https://github.com/csidirop/dfg-viewer.git" }, {"type": "git", "url": "https://github.com/csidirop/kitodo-presentation.git"}, {"type": "git", "url": "https://github.com/csidirop/slub_digitalcollections.git" }] | .require += {"csidirop/dfgviewer": "dev-5.3-ocr-test"} | . += {"minimum-stability": "dev"}' composer.json > composer-edit.json
mv composer.json composer.json.bak
mv composer-edit.json composer.json
composer update
vendor/bin/typo3 extensionmanager:extension:install dlf
vendor/bin/typo3 extensionmanager:extension:install dfgviewer
chown -R www-data:www-data .

# Setup DFG-Viewer:
##TODO

# Install Tesseract v5:
apt-get install -y tesseract
cd /usr/share/tesseract-ocr/5/tessdata/
wget https://ub-backup.bib.uni-mannheim.de/~stweil/tesstrain/frak2021/tessdata_fast/frak2021_1.069.traineddata
cd /var/www/typo3/

# Check languages:
tesseract --list-langs

# Cleanup:
echo '[MAIN] cleanup:'
apt-get purge -y wget jq
apt-get autoremove -y
apt-get clean 
rm -rf /var/lib/apt/lists/*

# Check status:
echo '[MAIN] Check apache status:'
service apache2 status

echo '[MAIN] Finished setup: http://localhost/typo3/ '