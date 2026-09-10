#!/bin/bash

source /docker-entrypoint-aux.sh

# check if solr is running:
wait-for-it -t 10 solr:8983
if [[ $? == 0 ]]; then solr=1; else solr=0; fi

set -euo pipefail # exit on: error, undefined variable, pipefail

# Run main part of this script only one time (if /initFinished does not exists!):
if [ ! -f /initFinished ]; then
    printHeadline "Running Startup Script:"

    # Wait for db to be ready: (https://docs.docker.com/compose/startup-order/)
    wait-for-it -t 0 ${DB_ADDR}:${DB_PORT}

    # Setup TYPO3 with typo3console (https://docs.typo3.org/p/helhum/typo3-console/main/en-us/CommandReference/InstallSetup.html):
    cd /var/www/typo3/
    printHeadline "Starting TYPO3 auto setup:"

    # Refresh the complete dependency set before adding extensions. Base images may
    # contain an older TYPO3 lock file whose packages are blocked by newer security
    # advisories. Updating only the requested extension cannot unlock every TYPO3
    # package, even with --with-all-dependencies.
    composer update --with-all-dependencies --no-interaction
    composer require helhum/typo3-console
    vendor/bin/typo3 install:setup \
        --no-interaction \
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

    # Install Kitodo.Presentation:
    printHeadline "Install Presentation:"
    composer config platform.php 8.2
    # Presentation 7 requires 0.3.2, but upstream has not published that tag. 
    #TODO: remove the commit hash when upstream has published 0.3.2
    composer require --with-all-dependencies \
        "ubl/php-iiif-prezi-reader:dev-master#57d3471cd1210cf78388e1d2b3e4c0ba1ef2688f as 0.3.2" \
        "kitodo/presentation"
    vendor/bin/typo3 extension:setup

    chown -R www-data:www-data .
    ## Activate other useful extensions:
    ### .... INSERT HERE ....
    vendor/bin/typo3 extension:list

    # Setup Kitodo.Presentation: (https://github.com/UB-Mannheim/kitodo-presentation/wiki/Installation-Kitodo.Presentation)
    printHeadline "Setup Kitodo.Presentation:"
    cd /var/www/typo3/
    ## Configure TYPO3 and Kitodo.Presentation:
    vendor/bin/typo3 configuration:set FE/pageNotFoundOnCHashError 0
    vendor/bin/typo3 configuration:set FE/cacheHash/requireCacheHashPresenceParameters '["tx_dlf[id]"]' --json
    vendor/bin/typo3 configuration:set SYS/fileCreateMask 0660
    vendor/bin/typo3 configuration:set SYS/folderCreateMask 2770
    vendor/bin/typo3 configuration:set SYS/systemLocale en_US.UTF-8
    vendor/bin/typo3 configuration:set SYS/trustedHostsPattern "^(www\.)?${HOST}(:${PORT})?$"
    ## Set right permissions for existing folders:
    # chmod 2770 public/typo3conf/ext/                                    # set permissions for ext folder: owner and group can read, write and execute + inherit permissions
    # find .       -name ext\* -prune -o -name \* -exec chmod 2770 {} \;  # set permissions for all other: owner and group can read, write and execute + inherit permissions
    find .       -name .htaccess  -exec chmod -v 0660 {} \;             # set permissions for .htaccess: owner and group can read and write
    find public/ -name index.html -exec chmod -v 0660 {} \;             # set permissions for index.html: owner and group can read and write
    ## Solr options:
    [[ $solr == 1 ]] && vendor/bin/typo3 configuration:set EXTENSIONS/dlf/solr/host "solr" # Inside the container solr is reacheble under 'solr'

    # Insert TYPO3 site content:

    ## Setup and update pages:
    printHeadline "Setup Kitodo.Presentation: Update DB:"

    ## Add solr related pages and settings:
    printInfoLine "Setup Kitodo.Presentation: Add solr related pages and settings:"
    if [ $solr == 1 ]; then
        # MariaDB clients 11.4+ enable TLS by default, while the development database in this Compose stack does not provide TLS.
        mysql() { command mysql --disable-ssl "$@"; }

        #### New Tenant & set core in List -> Solr Cores
        printInfoLine "Setup Kitodo.Presentation: Update DB: New Tenant & set core in List -> Solr Cores"
        mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO tx_dlf_solrcores (pid, cruser_id, label, index_name) VALUES (3, 1, 'Solr Core (PID 1)','dlf');"
        #### Create Tenant Structures:
        printInfoLine "Setup Kitodo.Presentation: Update DB: Create Tenant Structures"
        # TODO: remove when data init is finished (https://github.com/slub/dfg-viewer/pull/284)
        # mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} < /data/tx_dlf_metadata.sql
        # mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} < /data/tx_dlf_metadataformat.sql
        # mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} < /data/tx_dlf_structures.sql

        #### Pages and content elements:
        mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} < /data/solr-pages.sql
    fi

    # Insert TYPO3 site content translations:
    ## Create Site configuration with two languages (en & de):
    printHeadline "Setup Kitodo.Presentation: Write site configuration for ${HOST}"
    mkdir -p config/sites/presentation/
    ### Take config.yaml from /data, substitute the variables and pipe it to the TYPO3 dir:
    envsubst '${HOST}' < /data/config.yaml >> /var/www/typo3/config/sites/presentation/config.yaml
    if [ ${HOST} = 'localhost' ]; then
        ### Replace localhost with / :
        sed -i 's/localhost/\//g' /var/www/typo3/config/sites/presentation/config.yaml
    fi
    cp -v /data/routes-*.yaml /var/www/typo3/config/sites/presentation/
    chown -R www-data:www-data config
    
    # AdditionalConfiguration (Fixes TYPO3-CORE-SA-2020-006: Same-Origin Request Forgery to Backend User Interface: https://typo3.org/security/advisory/typo3-core-sa-2020-006)
    # (Only if DMZ is set in .env)
    if [ ${TYPO3_ADDITIONAL_CONFIGURATION} != 'false' ]; then
        printHeadline "Write AdditionalConfiguration.php:"
        ### Take AdditionalConfiguration from /data, substitute the variables except for $GLOBALS (which isnt one) and pipe it to the TYPO3 dir
        envsubst '${HOST}' < /data/AdditionalConfiguration.php >> /var/www/typo3/public/typo3conf/AdditionalConfiguration.php
    fi

    vendor/bin/typo3 cache:warmup

    # Cleanup:
    printHeadline "Cleanup:"
    apt-get purge -y jq gettext
    apt-get autoremove -y
    apt-get clean
    rm -rf /var/lib/apt/lists/*

    # Run further scripts:
    printHeadline "Running further scripts:"
    chmod +x /data/scripts/*
    run-parts --regex '.*sh$' /data/scripts/

    # Mark as finished:
    touch /initFinished
    printSuccessLine "Finished setup!"
fi

if [ $PORT == 80 ]; then # default PORT
    printSuccessLine "Site:    http://${HOST}"
    printSuccessLine "Backend: http://${HOST}/typo3/"
else # Non default PORT
    printSuccessLine "Site:    http://${HOST}:${PORT}"
    printSuccessLine "Backend: http://${HOST}:${PORT}/typo3/"
fi
[[ $solr == 1 ]] && printSuccessLine "Solr:    http://${HOST}:8983"
