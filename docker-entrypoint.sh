#!/bin/bash

# Some color variables:
CLR_B='\033[1;34m' # Bold Blue
CLR_G='\e[32m' # Green
NC='\033[0m' # No Color

# Run main part of this script only one time (if /initFinished does not exists!):
if [ ! -f /initFinished ]; then
    echo -e "${CLR_B}[MAIN] Running startup script:${NC}"

    # Wait for db to be ready: (https://docs.docker.com/compose/startup-order/)
    wait-for-it -t 0 ${DB_ADDR}:${DB_PORT}

    # Setup TYPO3 with typo3console (https://docs.typo3.org/p/helhum/typo3-console/main/en-us/CommandReference/InstallSetup.html):
    cd /var/www/typo3/
    docker-php-ext-install -j$(nproc) mysqli
    echo -e "${CLR_B}[MAIN] Auto setup typo3:${NC}"
    vendor/bin/typo3cms install:setup \
        --use-existing-database \
        --database-driver='mysqli' \
        --database-user-name="${DB_USER}" \
        --database-user-password="${DB_PASSWORD}" \
        --database-host-name='db' \
        --database-port=${DB_PORT} \
        --database-name=${DB_NAME} \
        --admin-user-name="${TYPO3_ADMIN_USER}" \
        --admin-password="${TYPO3_ADMIN_PASSWORD}" \
        --site-setup-type=no \
        --site-name presentation \
        --web-server-config=apache

    # Install Kitodo.Presentation v4.x and DFG-Viewer main-branch:
    echo -e "${CLR_B}[MAIN] Install Kitodo.Presentation 4.x and DFG-Viewer:${NC}"
    composer config platform.php 7.4
    composer require kitodo/presentation:dev-master
    composer require slub/dfgviewer:dev-master
    vendor/bin/typo3 extensionmanager:extension:install dlf
    vendor/bin/typo3 extensionmanager:extension:install dfgviewer
    chown -R www-data:www-data .

    # Setup Kitodo.Presentation and DFG-Viewer: (https://github.com/UB-Mannheim/kitodo-presentation/wiki/Installation-Kitodo.Presentation-mit-DFG-Viewer-als-Beispielanwendung)
    echo -e "${CLR_B}[MAIN] Setup Kitodo.Presentation and DFG-Viewer:${NC}"
    cd /var/www/typo3/
    ## Configure TYPO3 and Kitodo.Presentation:
    vendor/bin/typo3cms configuration:set FE/pageNotFoundOnCHashError 0
    vendor/bin/typo3cms configuration:set FE/cacheHash/requireCacheHashPresenceParameters '["tx_dlf[id]", "set[mets]"]' --json
    vendor/bin/typo3cms configuration:set SYS/fileCreateMask 0660
    vendor/bin/typo3cms configuration:set SYS/folderCreateMask 2770
    vendor/bin/typo3cms configuration:set SYS/systemLocale en_US.UTF-8
    vendor/bin/typo3cms configuration:set SYS/trustedHostsPattern '.*\.?localhost\.?.*' #TODO: get $HOST and refactor + use usefull regex
    ## Set right permissions for existing folders:
    chmod 2770 public/typo3conf/ext/                                    # set permissions for ext folder: owner and group can read, write and execute + inherit permissions
    find .       -name ext\* -prune -o -name \* -exec chmod 2770 {} \;  # set permissions for all other: owner and group can read, write and execute + inherit permissions
    find .       -name .htaccess  -exec chmod -v 0660 {} \;             # set permissions for .htaccess: owner and group can read and write
    find public/ -name index.html -exec chmod -v 0660 {} \;             # set permissions for index.html: owner and group can read and write

    # Insert TYPO3 site content:
    ## Main site content elements:
    ### .... INSERT HERE ....

    # Insert TYPO3 site content translations:
    ## Create Site configuration with two languages (en & de):
    echo -e "${CLR_B}[MAIN] Setup Kitodo.Presentation: Write site configuration for ${HOST} ${NC}"
    mkdir -p config/sites/presentation/
    ### Take config.yaml from /data, substitute the variables and pipe it to the TYPO3 dir:
    envsubst '${HOST}' < /data/config.yaml >> /var/www/typo3/config/sites/presentation/config.yaml
    if [ ${HOST} = 'localhost' ]; then
        ### Replace localhost with / :
        sed -i 's/localhost/\//g' /var/www/typo3/config/sites/presentation/config.yaml
    fi
    chown -R www-data:www-data config
    
    # AdditionalConfiguration (Fixes TYPO3-CORE-SA-2020-006: Same-Origin Request Forgery to Backend User Interface: https://typo3.org/security/advisory/typo3-core-sa-2020-006)
    # (Only if DMZ is set in .env)
    if [ ${TYPO3_ADDITIONAL_CONFIGURATION} != 'false' ]; then
        echo -e "${CLR_B}[MAIN] Write AdditionalConfiguration.php:${NC}"
        ### Take AdditionalConfiguration from /data, substitute the variables except for $GLOBALS (which isnt one) and pipe it to the TYPO3 dir
        envsubst '${HOST}' < /data/AdditionalConfiguration.php >> /var/www/typo3/public/typo3conf/AdditionalConfiguration.php
    fi

    # Cleanup:
    echo -e "${CLR_B}[MAIN] cleanup:${NC}"
    apt-get purge -y jq gettext
    apt-get autoremove -y
    apt-get clean
    rm -rf /var/lib/apt/lists/*

    # Check status:
    echo -e "${CLR_B}[MAIN] Check apache status:${NC}"
    service apache2 status

    # Mark as finished:
    touch /initFinished
    echo -e "${CLR_B}[MAIN]${CLR_G} Finished setup!${NC}"
fi

echo -e "${CLR_B}[MAIN]${CLR_G} Site http://${HOST} ${NC}"
echo -e "${CLR_B}[MAIN]${CLR_G} Backend: http://${HOST}/typo3/ ${NC}"
