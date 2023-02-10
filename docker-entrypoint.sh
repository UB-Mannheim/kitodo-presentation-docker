#!/bin/bash

# Some color variables:
CLR_B='\e[1;34m' # Bold Blue
CLR_G='\e[32m' # Green
CLR_R='\e[31m' # Red
NC='\e[0m' # No Color

set -euo pipefail # exit on: error, undefined variable, pipefail

# check if solr is running: # TODO: found a nicer way
ping -c 1 solr > /dev/null 2>&1
[[ $? == 0 ]] && solr=1

# Run main part of this script only one time (if /initFinished does not exists!):
if [ ! -f /initFinished ]; then
    echo -e "${CLR_B}[MAIN] Running startup script:${NC}"
    SECONDS=0 #messure time

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

    # Install Kitodo.Presentation and DFG-Viewer with OCR-On-Demand:
    echo -e "${CLR_B}[MAIN] Install Presentation and DFG-Viewer with OCR-On-Demand:${NC}"
    composer config platform.php 7.4
    ## Add the custom repositories to the composer file:
    jq '  .repositories += [
            {"type": "git", "url": "https://github.com/ub-mannheim/dfg-viewer.git" },
            {"type": "git", "url": "https://github.com/ub-mannheim/kitodo-presentation.git"},
            {"type": "git", "url": "https://github.com/ub-mannheim/ubma_digitalcollections.git" }]
        | .require += {"ub-mannheim/dfgviewer": "dev-5.3-ocr"}
        | . += {"minimum-stability": "dev"}' composer.json > composer-edit.json
    mv composer.json composer.json.bak
    mv composer-edit.json composer.json
    composer update
    vendor/bin/typo3 extensionmanager:extension:install dlf
    vendor/bin/typo3 extensionmanager:extension:install dfgviewer
    chown -R www-data:www-data .
    chmod +x public/typo3conf/ext/dlf/Classes/Plugin/Tools/FullTextGenerationScripts/*.sh
    ## Activate other useful extensions: (only TYPO3 v9)
    vendor/bin/typo3 extensionmanager:extension:install fluid_styled_content
    vendor/bin/typo3 extensionmanager:extension:install adminpanel
    vendor/bin/typo3 extensionmanager:extension:install belog
    vendor/bin/typo3 extensionmanager:extension:install beuser
    vendor/bin/typo3 extensionmanager:extension:install form
    vendor/bin/typo3 extensionmanager:extension:install info
    vendor/bin/typo3 extensionmanager:extension:install redirects
    vendor/bin/typo3 extensionmanager:extension:install rte_ckeditor
    vendor/bin/typo3 extensionmanager:extension:install tstemplate
    vendor/bin/typo3 extensionmanager:extension:install viewpage

    # Setup Kitodo.Presentation and DFG-Viewer: (https://github.com/UB-Mannheim/kitodo-presentation/wiki/Installation-Kitodo.Presentation-mit-DFG-Viewer-und-OCR-On-Demand-Testcode-als-Beispielanwendung#dfg-viewer-config)
    echo -e "${CLR_B}[MAIN] Setup Kitodo.Presentation and DFG-Viewer:${NC}"
    cd /var/www/typo3/
    ## Configure TYPO3 and Kitodo.Presentation:
    vendor/bin/typo3cms configuration:set FE/pageNotFoundOnCHashError 0
    vendor/bin/typo3cms configuration:set FE/cacheHash/requireCacheHashPresenceParameters '["tx_dlf[id]", "set[mets]"]' --json
    vendor/bin/typo3cms configuration:set SYS/systemLocale en_US.UTF-8
    vendor/bin/typo3cms configuration:set SYS/fileCreateMask 0660
    vendor/bin/typo3cms configuration:set SYS/folderCreateMask 2770
    ## Set right permissions for existing folders:
    chmod 2770 public/typo3conf/ext/                                    # set permissions for ext folder: owner and group can read, write and execute + inherit permissions
    find .       -name ext\* -prune -o -name \* -exec chmod 2770 {} \;  # set permissions for all other: owner and group can read, write and execute + inherit permissions
    find .       -name .htaccess  -exec chmod -v 0660 {} \;             # set permissions for .htaccess: owner and group can read and write
    find public/ -name index.html -exec chmod -v 0660 {} \;             # set permissions for index.html: owner and group can read and write
    ## Presentation options:
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/fileGrpImages 'DEFAULT,DEFAULTPLUS,MASTER,MAX,ORIGINAL' # Add additional fileGrps: ORIGINAL (SLUB), MASTER (TU Braunschweig), DEFAULTPLUS (UB HD)
    ## Solr options:
    [[ $solr == 1 ]] && vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/solrHost "solr" # Inside the container solr is reacheble under 'solr'
    ## OCR-On-Demand options:
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/fulltextFolder 'fileadmin/fulltextFolder'
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/fulltextTempFolder 'fileadmin/_temp_/ocrTempFolder/fulltext'
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/fulltextImagesFolder 'fileadmin/_temp_/ocrTempFolder/images'
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/fulltextLockFolder 'fileadmin/_temp_/ocrTempFolder/lock'
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/ocrDebug 0 # 0 = off, 1 = on
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/ocrDelay '0' # time in seconds
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/ocrPlaceholder 1
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/ocrLanguages 'frak2021_1.069' #TODO
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/ocrLock 1
    mkdir -v -p public/fileadmin/fulltextFolder
    mkdir -v -p public/fileadmin/_temp_/ocrTempFolder/fulltext
    mkdir -v -p public/fileadmin/_temp_/ocrTempFolder/images
    mkdir -v -p public/fileadmin/_temp_/ocrTempFolder/lock
    chown -R www-data public/fileadmin/

    # Insert TYPO3 site content:
    ## Setup and update pages:
    echo -e "${CLR_B}[MAIN] Setup DFG-Viewer: Update DB${NC}"
    echo -e "${CLR_B}[MAIN] Setup DFG-Viewer: Update DB: Insert sites and properties${NC}"
    dfgviewer_uid=$(mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e 'SELECT uid FROM pages WHERE title = "Viewer";' | sed '1d')
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "UPDATE pages SET TSconfig = 'TCEMAIN.permissions.groupid = $dfgviewer_uid' WHERE title = 'Viewer';"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e 'UPDATE pages SET tsconfig_includes = "EXT:dfgviewer/Configuration/TsConfig/Page.ts" WHERE title = "DFG Viewer";'
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e 'UPDATE pages SET tsconfig_includes = "EXT:dfgviewer/Configuration/TsConfig/Page.tsconfig" WHERE title = "Viewer";'
    ### Hide viewer tab from root page menu:
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "UPDATE pages SET nav_hide = 1 WHERE title = 'Viewer';"
    ### Take typo3 content element data from /data/typo3ContentElementData.json and insert it to the DB:
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, CType, header, bodytext) VALUES ('1', '1', 'text', 'DFG-Viewer Header',       '$(jq -r '."DFG-Viewer-Main".german."DFG-Viewer-Header"' /data/typo3ContentElementData.json)');"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, CType, header, bodytext) VALUES ('1', '1', 'html', 'Eingabefeld',             '$(jq -r '."DFG-Viewer-Main".german."Eingabefeld"'       /data/typo3ContentElementData.json)');"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, CType, header, bodytext) VALUES ('1', '1', 'text', 'DFG-Viewer Examplebody',  '$(jq -r '."DFG-Viewer-Main".german."DFG-Viewer-Examplebody"' /data/typo3ContentElementData.json)');"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, CType, header, bodytext) VALUES ('1', '1', 'text', 'DFG-Viewer Body',         '$(jq -r '."DFG-Viewer-Main".german."DFG-Viewer-Body"'   /data/typo3ContentElementData.json)');"
    ## Create external links:
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO pages (pid, cruser_id, perms_userid, title, slug, doktype, url) VALUES ('1', '1', '1', 'Datenschutzerklärung', '/datenschutzerklaerung', 3, '$(jq -r '."DFG-Viewer-Main".nolang.datenschutzerklaerung' /data/typo3ContentElementData.json)');"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO pages (pid, cruser_id, perms_userid, title, slug, doktype, url) VALUES ('1', '1', '1', 'Impressum',           '/impressum', '3',            '$(jq -r '."DFG-Viewer-Main".nolang.impressum'             /data/typo3ContentElementData.json)');"
    ### Embed external links: 1 viewer dropdown menu
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "UPDATE sys_template SET constants = 'config.storagePid = 3\n config.rootPid = 1\n config.headNavPid = 0\n config.viewerNavPids = 1, 4, 5\n config.kitodoPageView = 2\n' WHERE sitetitle = 'DFG-Viewer';"
    ### Embed external links: 2 main site header or footer
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, CType, header) VALUES ('1', '1', 'div', 'Divider');"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, CType, pages) VALUES ('1', '1', 'menu_section_pages', '2');" # Unterseiten von viewer: Datenschutzerklärung, Impressum
    ### Add solr related pages and settings:
    if [ $solr == 1 ]; then
        #### New Tenant & set core in List -> Solr Cores
        mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO tx_dlf_solrcores (pid, cruser_id, label, index_name) VALUES (3, 1, 'Solr Core (PID 1)','dlf');"
        #### Pages and contentelements #TODO cleanup!
        #### PageView: (not needed with DFG-Viewer)
        # mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO pages VALUES (7,1,0,0,1,0,0,0,0,'',64,'',0,0,0,0,NULL,0,'',0,0,'',0,0,0,0,0,0,1,0,31,27,0,'Seitenansicht','/seitenansicht',1,'',0,0,'',0,0,'',0,'',0,0,'',0,'',0,'',0,1674036059,'','',0,'','','',1,0,0,0,'',0,0,'','','',0,0,'',0,0,'','',0,'','',0,'',0)"
        # mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO tt_content VALUES (11,'',7,0,0,1,0,0,0,0,'',256,0,0,0,0,NULL,0,'',0,0,'',0,0,0,0,0,0,'list','','',NULL,0,0,0,0,0,0,0,2,0,0,0,'default',0,0,0,'','',NULL,NULL,0,'','',0,'0','dlf_pageview',1,0,NULL,0,'','','',0,0,0,'<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"yes\" ?>\n<T3FlexForms>\n    <data>\n        <sheet index=\"sDEF\">\n            <language index=\"lDEF\">\n                <field index=\"pages\">\n                    <value index=\"vDEF\">3</value>\n                </field>\n                <field index=\"excludeOther\">\n                    <value index=\"vDEF\">1</value>\n                </field>\n                <field index=\"features\">\n                    <value index=\"vDEF\"></value>\n                </field>\n                <field index=\"elementId\">\n                    <value index=\"vDEF\">tx-dlf-map</value>\n                </field>\n                <field index=\"crop\">\n                    <value index=\"vDEF\">0</value>\n                </field>\n                <field index=\"useInternalProxy\">\n                    <value index=\"vDEF\">0</value>\n                </field>\n                <field index=\"magnifier\">\n                    <value index=\"vDEF\">0</value>\n                </field>\n                <field index=\"basketButton\">\n                    <value index=\"vDEF\">0</value>\n                </field>\n                <field index=\"targetBasket\">\n                    <value index=\"vDEF\"></value>\n                </field>\n                <field index=\"templateFile\">\n                    <value index=\"vDEF\"></value>\n                </field>\n            </language>\n        </sheet>\n    </data>\n</T3FlexForms>','',0,'',NULL,'','',NULL,124,0,0,0,0,0)"
        #### ListView:
        mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO pages VALUES (8,1,1675264343,0,1,0,0,0,0,'',288,'',0,0,0,0,NULL,0,'',0,0,'',0,0,0,0,0,0,1,0,31,27,0,'Suchergebnisse','/suchergebnisse',1,'',0,0,'',0,0,'',0,'',0,0,'',0,'',0,'',0,1674036774,'','',0,'','','',1,0,0,0,'',0,0,'','','',0,0,'',0,0,'','',0,'','',0,'',0)"
        mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO tt_content VALUES (12,'',8,0,0,1,0,0,0,0,'',256,0,0,0,0,NULL,0,'',0,0,'',0,0,0,0,0,0,'list','','',NULL,0,0,0,0,0,0,0,2,0,0,0,'default',0,0,0,'','',NULL,NULL,0,'','',0,'0','dlf_listview',1,0,NULL,0,'','','',0,0,0,'<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"yes\" ?>\n<T3FlexForms>\n    <data>\n        <sheet index=\"sDEF\">\n            <language index=\"lDEF\">\n                <field index=\"pages\">\n                    <value index=\"vDEF\">3</value>\n                </field>\n                <field index=\"limit\">\n                    <value index=\"vDEF\">25</value>\n                </field>\n                <field index=\"targetPid\">\n                    <value index=\"vDEF\">2</value>\n                </field>\n                <field index=\"getTitle\">\n                    <value index=\"vDEF\">0</value>\n                </field>\n                <field index=\"basketButton\">\n                    <value index=\"vDEF\">0</value>\n                </field>\n                <field index=\"targetBasket\">\n                    <value index=\"vDEF\"></value>\n                </field>\n                <field index=\"templateFile\">\n                    <value index=\"vDEF\"></value>\n                </field>\n            </language>\n        </sheet>\n    </data>\n</T3FlexForms>','',0,'',NULL,'','',NULL,124,0,0,0,0,0)"
        #### Search:
        mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO pages VALUES (9,1,0,0,1,0,0,0,0,'',400,'',0,0,0,0,NULL,0,'',0,0,'',0,0,0,0,0,0,1,0,31,27,0,'Suche','/suche',1,'',0,0,'',0,0,'',0,'',0,0,'',0,'',0,'',0,0,'','',0,'','','',0,0,0,0,'',0,0,'','','',0,0,'',0,0,'','',0,'','',0,'',0)"
        mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO tt_content VALUES (13,'',9,0,0,1,0,0,0,0,'',256,0,0,0,0,NULL,0,'',0,0,'',0,0,0,0,0,0,'list','','',NULL,0,0,0,0,0,0,0,2,0,0,0,'default',0,0,0,'','',NULL,NULL,0,'','',0,'0','dlf_search',1,0,NULL,0,'','','',0,0,0,'<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"yes\" ?>\n<T3FlexForms>\n    <data>\n        <sheet index=\"sDEF\">\n            <language index=\"lDEF\">\n                <field index=\"pages\">\n                    <value index=\"vDEF\">3</value>\n                </field>\n                <field index=\"fulltext\">\n                    <value index=\"vDEF\">1</value>\n                </field>\n                <field index=\"searchIn\">\n                    <value index=\"vDEF\">none</value>\n                </field>\n                <field index=\"resetFacets\">\n                    <value index=\"vDEF\">0</value>\n                </field>\n                <field index=\"sortingFacets\">\n                    <value index=\"vDEF\">count</value>\n                </field>\n                <field index=\"suggest\">\n                    <value index=\"vDEF\">1</value>\n                </field>\n                <field index=\"showLogicalPageField\">\n                    <value index=\"vDEF\">0</value>\n                </field>\n                <field index=\"showSingleResult\">\n                    <value index=\"vDEF\">0</value>\n                </field>\n                <field index=\"targetPid\">\n                    <value index=\"vDEF\">8</value>\n                </field>\n                <field index=\"templateFile\">\n                    <value index=\"vDEF\"></value>\n                </field>\n                <field index=\"solrcore\">\n                    <value index=\"vDEF\">1</value>\n                </field>\n                <field index=\"extendedSlotCount\">\n                    <value index=\"vDEF\">1</value>\n                </field>\n                <field index=\"extendedFields\">\n                    <value index=\"vDEF\">title,author,repository,shelfmark,issue,place,year</value>\n                </field>\n                <field index=\"collections\">\n                    <value index=\"vDEF\"></value>\n                </field>\n                <field index=\"facets\">\n                    <value index=\"vDEF\"></value>\n                </field>\n                <field index=\"facetCollections\">\n                    <value index=\"vDEF\"></value>\n                </field>\n                <field index=\"limitFacets\">\n                    <value index=\"vDEF\">15</value>\n                </field>\n            </language>\n        </sheet>\n    </data>\n</T3FlexForms>','',0,'',NULL,'','',NULL,124,0,0,0,0,0)"
    fi

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
    ## Insert translated pages and content elements as translations:
    ### Take typo3 content element data from /data/typo3ContentElementData.json and insert it to the DB:
    echo -e "${CLR_B}[MAIN] Setup DFG-Viewer: Update DB: Translations${NC}"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO pages (pid, cruser_id, sys_language_uid, l10n_parent, l10n_source, perms_userid, title, slug, doktype, is_siteroot, tsconfig_includes, tx_impexp_origuid) VALUES ('0', '1', '1', '1', '1', '2', 'DFG Viewer', '/', '1', '1', 'EXT:dfgviewer/Configuration/TsConfig/Page.ts', '0');"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, sys_language_uid, l18n_parent, l10n_source, t3_origuid, CType, header, bodytext) VALUES ('1', '1', '1', '1', '1', '1', 'text', 'DFG-Viewer Header',       '$(jq -r '."DFG-Viewer-Main".english."DFG-Viewer-Header"' /data/typo3ContentElementData.json)');"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, sys_language_uid, l18n_parent, l10n_source, t3_origuid, CType, header, bodytext) VALUES ('1', '1', '1', '2', '2', '2', 'html', 'Eingabefeld',             '$(jq -r '."DFG-Viewer-Main".english."Eingabefeld"'       /data/typo3ContentElementData.json)');"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, sys_language_uid, l18n_parent, l10n_source, t3_origuid, CType, header, bodytext) VALUES ('1', '1', '1', '3', '3', '3', 'text', 'DFG-Viewer Examplebody',  '$(jq -r '."DFG-Viewer-Main".english."DFG-Viewer-Examplebody"' /data/typo3ContentElementData.json)');"
    mysql -h db --user=$DB_USER --password=$DB_PASSWORD -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, sys_language_uid, l18n_parent, l10n_source, t3_origuid, CType, header, bodytext) VALUES ('1', '1', '1', '4', '4', '4', 'text', 'DFG-Viewer Body',         '$(jq -r '."DFG-Viewer-Main".english."DFG-Viewer-Body"'   /data/typo3ContentElementData.json)');"
    
    # AdditionalConfiguration (Fixes TYPO3-CORE-SA-2020-006: Same-Origin Request Forgery to Backend User Interface: https://typo3.org/security/advisory/typo3-core-sa-2020-006)
    # (Only if DMZ is set in .env)
    if [ ${TYPO3_ADDITIONAL_CONFIGURATION} != 'false' ]; then
        echo -e "${CLR_B}[MAIN] Write AdditionalConfiguration.php:${NC}"
        ### Take AdditionalConfiguration from /data, substitute the variables except for $GLOBALS (which isn't one) and pipe it to the TYPO3 dir
        envsubst '${HOST}' < /data/AdditionalConfiguration.php >> /var/www/typo3/public/typo3conf/AdditionalConfiguration.php
    fi

    # Check tesseract languages:
    echo -e "${CLR_B}[MAIN] Install Tesseract v5:${NC}"
    tesseract --list-langs

    # Cleanup:
    echo -e "${CLR_B}[MAIN] cleanup:${NC}"
    apt-get purge -y jq gettext
    apt-get autoremove -y
    apt-get clean
    rm -rf /var/lib/apt/lists/*

    # Run further scripts:
    echo -e "${CLR_B}[MAIN] run further scripts:${NC}"
    chmod +x /data/scripts/*
    run-parts --regex '.*sh$' /data/scripts/

    # Mark as finished:
    touch /initFinished
    echo -e "Completed in $SECONDS seconds"
    echo -e "${CLR_B}[MAIN]${CLR_G} Finished setup!${NC}"
fi

echo -e "${CLR_B}[MAIN]${CLR_G} Site:    http://${HOST} ${NC}"
echo -e "${CLR_B}[MAIN]${CLR_G} Backend: http://${HOST}/typo3/ ${NC}"
[[ $solr == 1 ]] && echo -e "${CLR_B}[MAIN]${CLR_G} Solr:    http://${HOST}:8983 ${NC}"
