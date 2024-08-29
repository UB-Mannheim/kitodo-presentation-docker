#!/bin/bash

source /docker-entrypoint-aux.sh

# check if solr is running:
wait-for-it -t 10 solr:8983
if [[ $? == 0 ]]; then solr=1; else solr=0; fi

set -euo pipefail # exit on: error, undefined variable, pipefail

# Run main part of this script only one time (if /initFinished does not exists!):
if [ ! -f /initFinished ]; then
    printHeadline "Running Startup Script:"
    SECONDS=0 #measure time

    # Wait for db to be ready: (https://docs.docker.com/compose/startup-order/)
    wait-for-it -t 0 ${DB_ADDR}:${DB_PORT}

    # Setup TYPO3 with typo3console (https://docs.typo3.org/p/helhum/typo3-console/main/en-us/CommandReference/InstallSetup.html):
    cd /var/www/typo3/
    docker-php-ext-install -j$(nproc) mysqli #TODO: remove -> why its not already installed
    printHeadline "Starting TYPO3 auto setup:"
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

    # Install Kitodo.Presentation and DFG-Viewer with OCR-On-Demand:
    printHeadline "Install Presentation and DFG-Viewer with OCR-On-Demand:"
    composer config platform.php 8.2
    ## Add the custom repositories to the composer file:
    jq '  .repositories += [
            {"type": "git", "url": "https://github.com/UB-Mannheim/dfg-viewer.git" },
            {"type": "git", "url": "https://github.com/UB-Mannheim/kitodo-presentation.git"},
            {"type": "git", "url": "https://github.com/UB-Mannheim/ubma_digitalcollections.git" }]
        | .require += {"ub-mannheim/dfgviewer": "dev-6.x-ocr-devel"}
        | . += {"minimum-stability": "dev"}' composer.json > composer-edit.json
    # TODO: remove fixed commit hash after updating to presentation v5 and dfgviewer v6 (official)
    mv composer.json composer.json.bak
    mv composer-edit.json composer.json
    composer update
    # vendor/bin/typo3 extension:activate dlf
    # vendor/bin/typo3 extension:activate dfgviewer
    chown -R www-data:www-data .
    chmod +x public/typo3conf/ext/dlf/Classes/Plugin/Tools/FullTextGenerationScripts/*.sh
    ## Activate other useful extensions:
    ### .... INSERT HERE ....
    # vendor/bin/typo3 extension:activate info # (activating info (or any other) is a workaround so the site config is red correctly)
    vendor/bin/typo3 extension:list

    # Setup Kitodo.Presentation and DFG-Viewer: (https://github.com/UB-Mannheim/kitodo-presentation/wiki/Installation-Kitodo.Presentation-mit-DFG-Viewer-und-OCR-On-Demand-Testcode-als-Beispielanwendung#dfg-viewer-config)
    printHeadline "Setup Kitodo.Presentation and DFG-Viewer:"
    cd /var/www/typo3/
    ## Configure TYPO3 and Kitodo.Presentation:
    vendor/bin/typo3cms configuration:set FE/pageNotFoundOnCHashError 0
    vendor/bin/typo3cms configuration:set FE/cacheHash/requireCacheHashPresenceParameters '["tx_dlf[id]", "set[mets]"]' --json
    vendor/bin/typo3cms configuration:set SYS/systemLocale en_US.UTF-8
    vendor/bin/typo3cms configuration:set SYS/fileCreateMask 0660
    vendor/bin/typo3cms configuration:set SYS/folderCreateMask 2770
    vendor/bin/typo3cms configuration:set SYS/trustedHostsPattern "(https?:\/\/)?(www\.)?${HOST}"
    ## Set right permissions for existing folders:
    chmod 2770 public/typo3conf/ext/                                    # set permissions for ext folder: owner and group can read, write and execute + inherit permissions
    find .       -name ext\* -prune -o -name \* -exec chmod 2770 {} \;  # set permissions for all other: owner and group can read, write and execute + inherit permissions
    find .       -name .htaccess  -exec chmod -v 0660 {} \;             # set permissions for .htaccess: owner and group can read and write
    find public/ -name index.html -exec chmod -v 0660 {} \;             # set permissions for index.html: owner and group can read and write
    ## Presentation options:
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/fileGrpImages 'DEFAULT,DEFAULTPLUS,MASTER,MAX,ORIGINAL' # Add additional fileGrps: ORIGINAL (SLUB), MASTER (TU Braunschweig), DEFAULTPLUS (UB HD)
    ## OCR-On-Demand options:
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/fulltextFolder 'fileadmin/fulltextFolder'
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/fulltextTempFolder 'fileadmin/_temp_/ocrTempFolder/fulltext'
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/fulltextImagesFolder 'fileadmin/_temp_/ocrTempFolder/images'
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/fulltextLockFolder 'fileadmin/_temp_/ocrTempFolder/lock'
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/ocrDebug 0 # 0 = off, 1 = on
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/ocrDelay '0' # time in seconds
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/ocrPlaceholder 1
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/ocrLock 1
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/ocrUpdateMets 0
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/ocrIndexMets 0
    ## Solr options:
    if [ $solr == 1 ]; then
        vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/solrHost "solr" # Inside the container solr is reacheble under 'solr'
        vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/ocrUpdateMets 1
        vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/ocrIndexMets 1
    fi
    mkdir -v -p public/fileadmin/fulltextFolder
    mkdir -v -p public/fileadmin/_temp_/ocrTempFolder/fulltext
    mkdir -v -p public/fileadmin/_temp_/ocrTempFolder/images
    mkdir -v -p public/fileadmin/_temp_/ocrTempFolder/lock
    chown -R www-data public/fileadmin/

    # Insert TYPO3 site content:
    ## Setup and update pages:
    printHeadline "Setup Kitodo.Presentation: Update DB:"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO be_dashboards VALUES (1,0,0,0,1,0,0,0,0,'3b40de016dfd4ba9c78a77acae795b67c5ae6dee','My dashboard','{\"58e0b3ef88b5520d21317f6f12c962e4f6336019\":{\"identifier\":\"t3information\"},\"b64400e7b9bc9da61c66dd05b90173ef8a0f4d73\":{\"identifier\":\"t3news\"},\"8827c68f64868f01727a2c3a1cfdc9785ef01846\":{\"identifier\":\"sysLogErrors\"},\"5f62783836befcbb19ce903265794e26152705c3\":{\"identifier\":\"t3securityAdvisories\"},\"202988d35cdc05eb4d810430930c3452e4ae936d\":{\"identifier\":\"failedLogins\"},\"ee4b3965195d8b863885499fa9780576d079748d\":{\"identifier\":\"typeOfUsers\"}}');"
    printInfoLine "Setup Kitodo.Presentation: Update DB: Insert sites and properties:"
    dfgviewer_uid=$(mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e 'SELECT uid FROM pages WHERE title = "Viewer";' | sed '1d')
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "UPDATE pages SET TSconfig = 'TCEMAIN.permissions.groupid = $dfgviewer_uid' WHERE title = 'Viewer';"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e 'UPDATE pages SET tsconfig_includes = "EXT:dfgviewer/Configuration/TsConfig/Page.ts" WHERE title = "DFG Viewer";'
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e 'UPDATE pages SET tsconfig_includes = "EXT:dfgviewer/Configuration/TsConfig/Page.tsconfig" WHERE title = "Viewer";'
    ### Hide viewer tab from root page menu:
    printInfoLine "Setup Kitodo.Presentation: Update DB: Hide viewer tab from root page menu:"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "UPDATE pages SET nav_hide = 1 WHERE title = 'Viewer';"
    ### Take typo3 content element data from /data/typo3ContentElementData.json and insert it to the DB:
    printInfoLine "Setup Kitodo.Presentation: Update DB: Take typo3 content element data from /data/typo3ContentElementData.json and insert it to the DB:"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, CType, header, bodytext) VALUES ('1', '1', 'text', 'DFG-Viewer Header',       '$(jq -r '."DFG-Viewer-Main".german."DFG-Viewer-Header"' /data/typo3ContentElementData.json)');"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, CType, header, bodytext) VALUES ('1', '1', 'html', 'Eingabefeld',             '$(jq -r '."DFG-Viewer-Main".german."Eingabefeld"'       /data/typo3ContentElementData.json)');"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, CType, header, bodytext) VALUES ('1', '1', 'text', 'DFG-Viewer Examplebody',  '$(jq -r '."DFG-Viewer-Main".german."DFG-Viewer-Examplebody"' /data/typo3ContentElementData.json)');"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, CType, header, bodytext) VALUES ('1', '1', 'text', 'DFG-Viewer Body',         '$(jq -r '."DFG-Viewer-Main".german."DFG-Viewer-Body"'   /data/typo3ContentElementData.json)');"
    ## Create external links:
    printInfoLine "Setup Kitodo.Presentation: Update DB: Create external links:"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO pages (pid, cruser_id, perms_userid, title, slug, doktype, url) VALUES ('1', '1', '1', 'Datenschutzerklärung', '/datenschutzerklaerung', 3, '$(jq -r '."DFG-Viewer-Main".nolang.datenschutzerklaerung' /data/typo3ContentElementData.json)');"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO pages (pid, cruser_id, perms_userid, title, slug, doktype, url) VALUES ('1', '1', '1', 'Impressum',           '/impressum', '3',            '$(jq -r '."DFG-Viewer-Main".nolang.impressum'             /data/typo3ContentElementData.json)');"
    ### Embed external links: 1 viewer dropdown menu
    printInfoLine "Setup Kitodo.Presentation: Update DB: Embed external links: 1 viewer dropdown menu"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "UPDATE sys_template SET constants = 'config.storagePid = 3\n config.rootPid = 1\n config.headNavPid = 0\n config.viewerNavPids = 1, 4, 5\n config.kitodoPageView = 2\n' WHERE sitetitle = 'DFG-Viewer';"
    ### Embed external links: 2 main site header or footer
    printInfoLine "Setup Kitodo.Presentation: Update DB: Embed external links: 2 main site header or footer"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, CType, header) VALUES ('1', '1', 'div', 'Divider');"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, CType, pages) VALUES ('1', '1', 'menu_section_pages', '2');" # Unterseiten von viewer: Datenschutzerklärung, Impressum
    ### Add solr related pages and settings:
    printInfoLine "Setup Kitodo.Presentation: Update DB: Add solr related pages and settings:"
    if [ $solr == 1 ]; then
        #### New Tenant & set core in List -> Solr Cores
        printInfoLine "Setup Kitodo.Presentation: Update DB: New Tenant & set core in List -> Solr Cores"
        printInfoLine "Setup Kitodo.Presentation: Update DB: New Tenant & set core in List -> Solr Cores"
        mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO tx_dlf_solrcores (pid, cruser_id, label, index_name) VALUES (3, 1, 'Solr Core (PID 1)','dlf');"
        #### Create Tenant Structures:
        printInfoLine "Setup Kitodo.Presentation: Update DB: Create Tenant Structures"
        mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} < /data/tx_dlf_metadata.sql
        mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} < /data/tx_dlf_metadataformat.sql
        mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} < /data/tx_dlf_structures.sql

        #### Pages and contentelements #TODO cleanup!
        ##### SearchView:
        printInfoLine "Setup Kitodo.Presentation: Update DB: Add pages and contentelements: SearchView"
        mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO pages VALUES (7,1,0,0,1,0,0,0,0,'',256,'',0,0,0,0,NULL,0,'',0,0,0,0,0,0,0,1,0,31,27,0,'Suche','/suche',1,'',0,0,'',0,0,'',0,'',0,0,'',0,'',0,'',0,1676470444,'','',0,'','','',0,0,0,0,0,0,'','','',0,0,'',0,0,'','',0,'','',0,'summary','',0.5,'',0);"
        mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO tt_content VALUES (11,'',7,0,0,1,0,0,0,0,'',256,0,0,0,0,NULL,0,'',0,0,0,0,0,0,0,'list','','',NULL,0,0,0,0,0,0,0,2,0,0,0,'default',0,'','',NULL,NULL,0,'','',0,'0','dlf_search',1,0,NULL,0,'','','',0,0,0,'<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"yes\" ?>\n<T3FlexForms>\n    <data>\n        <sheet index=\"sDEF\">\n            <language index=\"lDEF\">\n                <field index=\"settings.fulltext\">\n                    <value index=\"vDEF\">1</value>\n                </field>\n                <field index=\"settings.datesearch\">\n                    <value index=\"vDEF\">1</value>\n                </field>\n                <field index=\"settings.solrcore\">\n                    <value index=\"vDEF\">1</value>\n                </field>\n                <field index=\"settings.extendedSlotCount\">\n                    <value index=\"vDEF\">1</value>\n                </field>\n                <field index=\"settings.extendedFields\">\n                    <value index=\"vDEF\">author,title,volume,repository,year,place</value>\n                </field>\n                <field index=\"settings.searchIn\">\n                    <value index=\"vDEF\">none</value>\n                </field>\n                <field index=\"settings.collections\">\n                    <value index=\"vDEF\"></value>\n                </field>\n                <field index=\"settings.facets\">\n                    <value index=\"vDEF\"></value>\n                </field>\n                <field index=\"settings.facetCollections\">\n                    <value index=\"vDEF\"></value>\n                </field>\n                <field index=\"settings.limitFacets\">\n                    <value index=\"vDEF\">15</value>\n                </field>\n                <field index=\"settings.resetFacets\">\n                    <value index=\"vDEF\">0</value>\n                </field>\n                <field index=\"settings.sortingFacets\">\n                    <value index=\"vDEF\">count</value>\n                </field>\n                <field index=\"settings.suggest\">\n                    <value index=\"vDEF\">1</value>\n                </field>\n                <field index=\"settings.showLogicalPageField\">\n                    <value index=\"vDEF\">0</value>\n                </field>\n                <field index=\"settings.showSingleResult\">\n                    <value index=\"vDEF\">0</value>\n                </field>\n                <field index=\"settings.targetPid\">\n                    <value index=\"vDEF\"></value>\n                </field>\n                <field index=\"settings.targetPidPageView\">\n                    <value index=\"vDEF\">2</value>\n                </field>\n            </language>\n        </sheet>\n    </data>\n</T3FlexForms>','',0,'',NULL,'','',NULL,124,0,0,0,0,0);"
        mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO tt_content VALUES (12,'',7,0,0,1,0,0,0,0,'',128,0,0,0,0,NULL,0,'',0,0,0,0,0,0,0,'text','Metadaten- und Volltextsuche','',NULL,0,0,0,0,0,0,0,2,0,0,0,'default',0,'','',NULL,NULL,0,'','',0,'3','',1,0,NULL,0,'','','',0,0,0,NULL,'',0,'',NULL,'','',NULL,124,0,0,0,0,0);"
        ##### CollectionView:
        printInfoLine "Setup Kitodo.Presentation: Update DB: Add pages and contentelements: CollectionView"
        mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO pages VALUES (9,1,0,0,1,0,0,0,0,'',256,'',0,0,0,0,NULL,0,'',0,0,0,0,0,0,0,1,0,31,27,0,'Sammlungen','/sammlungen',1,'',0,0,'',0,0,'',0,'',0,0,'',0,'',0,'',0,1677164542,'','',0,'','','',0,0,0,0,0,0,'','','',0,0,'',0,0,'','',0,'','',0,'summary','',0.5,'',0);"
        mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO tt_content VALUES (17,'',9,0,0,1,0,0,0,0,'',256,0,0,0,0,NULL,0,'',0,0,0,0,0,0,0,'list','','',NULL,0,0,0,0,0,0,0,2,0,0,0,'default',0,'','',NULL,NULL,0,'','',0,'0','dlf_collection',1,0,NULL,0,'','','',0,0,0,'<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"yes\" ?>\n<T3FlexForms>\n    <data>\n        <sheet index=\"sDEF\">\n            <language index=\"lDEF\">\n                <field index=\"settings.collections\">\n                    <value index=\"vDEF\"></value>\n                </field>\n                <field index=\"settings.solrcore\">\n                    <value index=\"vDEF\">1</value>\n                </field>\n                <field index=\"settings.show_userdefined\">\n                    <value index=\"vDEF\">-1</value>\n                </field>\n                <field index=\"settings.dont_show_single\">\n                    <value index=\"vDEF\">0</value>\n                </field>\n                <field index=\"settings.randomize\">\n                    <value index=\"vDEF\">0</value>\n                </field>\n                <field index=\"settings.targetPid\">\n                    <value index=\"vDEF\"></value>\n                </field>\n                <field index=\"settings.targetPidPageView\">\n                    <value index=\"vDEF\">2</value>\n                </field>\n                <field index=\"settings.targetFeed\">\n                    <value index=\"vDEF\"></value>\n                </field>\n            </language>\n        </sheet>\n    </data>\n</T3FlexForms>','',0,'',NULL,'','',NULL,124,0,0,0,0,0);"
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
    ## Insert translated pages and content elements as translations:
    ### Take typo3 content element data from /data/typo3ContentElementData.json and insert it to the DB:
    printHeadline "Setup Kitodo.Presentation: Update DB: Translations:"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO pages (pid, cruser_id, sys_language_uid, l10n_parent, l10n_source, perms_userid, title, slug, doktype, is_siteroot, tsconfig_includes, tx_impexp_origuid) VALUES ('0', '1', '1', '1', '1', '2', 'DFG Viewer', '/', '1', '1', 'EXT:dfgviewer/Configuration/TsConfig/Page.ts', '0');"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, sys_language_uid, l18n_parent, l10n_source, t3_origuid, CType, header, bodytext) VALUES ('1', '1', '1', '1', '1', '1', 'text', 'DFG-Viewer Header',       '$(jq -r '."DFG-Viewer-Main".english."DFG-Viewer-Header"' /data/typo3ContentElementData.json)');"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, sys_language_uid, l18n_parent, l10n_source, t3_origuid, CType, header, bodytext) VALUES ('1', '1', '1', '2', '2', '2', 'html', 'Eingabefeld',             '$(jq -r '."DFG-Viewer-Main".english."Eingabefeld"'       /data/typo3ContentElementData.json)');"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, sys_language_uid, l18n_parent, l10n_source, t3_origuid, CType, header, bodytext) VALUES ('1', '1', '1', '3', '3', '3', 'text', 'DFG-Viewer Examplebody',  '$(jq -r '."DFG-Viewer-Main".english."DFG-Viewer-Examplebody"' /data/typo3ContentElementData.json)');"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -v -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, sys_language_uid, l18n_parent, l10n_source, t3_origuid, CType, header, bodytext) VALUES ('1', '1', '1', '4', '4', '4', 'text', 'DFG-Viewer Body',         '$(jq -r '."DFG-Viewer-Main".english."DFG-Viewer-Body"'   /data/typo3ContentElementData.json)');"
    
    # AdditionalConfiguration (Fixes TYPO3-CORE-SA-2020-006: Same-Origin Request Forgery to Backend User Interface: https://typo3.org/security/advisory/typo3-core-sa-2020-006)
    # (Only if DMZ is set in .env)
    if [ ${TYPO3_ADDITIONAL_CONFIGURATION} != 'false' ]; then
        printHeadline "Write AdditionalConfiguration.php:"
        ### Take AdditionalConfiguration from /data, substitute the variables except for $GLOBALS (which isnt one) and pipe it to the TYPO3 dir
        envsubst '${HOST}' < /data/AdditionalConfiguration.php >> /var/www/typo3/public/typo3conf/AdditionalConfiguration.php
    fi

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
    printInfoLine "Completed in $SECONDS seconds"
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
