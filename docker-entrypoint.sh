#!/bin/sh

# Work in progress!

# Run main part of this script only one time (if /initFinished does not exists!):
if [ ! -f /initFinished ]; then
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
        --database-user-name=${DB_USER} \
        --database-user-password=${DB_PASSWORD} \
        --database-host-name='db' \
        --database-port=${DB_PORT} \
        --database-name=${DB_NAME} \
        --admin-user-name=${TYPO3_ADMIN_USER} \
        --admin-password=${TYPO3_ADMIN_PASSWORD} \
        --site-setup-type=no \
        --site-name presentation \
        --web-server-config=apache

    # Install Kitodo.Presentation and DFG-Viewer with OCR-On-Demand:
    echo '[MAIN] Install Presentation and DFG-Viewer with OCR-On-Demand:'
    composer config platform.php 7.4
    apt-get update
    apt-get install -y jq
    jq '.repositories += [{"type": "git", "url": "https://github.com/csidirop/dfg-viewer.git" }, {"type": "git", "url": "https://github.com/csidirop/kitodo-presentation.git"}, {"type": "git", "url": "https://github.com/csidirop/slub_digitalcollections.git" }] | .require += {"csidirop/dfgviewer": "dev-5.3-ocr"} | . += {"minimum-stability": "dev"}' composer.json > composer-edit.json
    mv composer.json composer.json.bak
    mv composer-edit.json composer.json
    composer update
    vendor/bin/typo3 extensionmanager:extension:install dlf
    vendor/bin/typo3 extensionmanager:extension:install dfgviewer
    chown -R www-data:www-data .
    # Activate other useful extensions: (only Typo3 v9)
    vendor/bin/typo3 extensionmanager:extension:install fluid_styled_content
    vendor/bin/typo3 extensionmanager:extension:install adminpanel
    vendor/bin/typo3 extensionmanager:extension:install belog 
    vendor/bin/typo3 extensionmanager:extension:install beuser
    vendor/bin/typo3 extensionmanager:extension:install form
    vendor/bin/typo3 extensionmanager:extension:install info
    vendor/bin/typo3 extensionmanager:extension:install redirects
    vendor/bin/typo3 extensionmanager:extension:install tstemplate
    vendor/bin/typo3 extensionmanager:extension:install viewpage

    # Setup DFG-Viewer: (https://github.com/UB-Mannheim/kitodo-presentation/wiki/Installation-Kitodo.Presentation-mit-DFG-Viewer-und-OCR-On-Demand-Testcode-als-Beispielanwendung#dfg-viewer-config)
    echo '[MAIN] Setup DFG-Viewer:'
    cd /var/www/typo3/
    vendor/bin/typo3cms configuration:set FE/pageNotFoundOnCHashError 0
    vendor/bin/typo3cms configuration:set FE/cacheHash/requireCacheHashPresenceParameters '["tx_dlf[id]", "set[mets]"]' --json
    ## OCR-On-Demand options:
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/fulltextFolder 'fileadmin/fulltextFolder'
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/fulltextTempFolder 'fileadmin/_temp_/fulltextTempFolder'
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/fulltextImagesFolder 'fileadmin/_temp_/imagesTempFolder'
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/ocrDebug 0 # 0 = off, 1 = on
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/ocrDelay '10'
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/ocrDummy 1
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/ocrLanguages 'frak2021_1.069' #TODO
    vendor/bin/typo3cms configuration:set EXTENSIONS/dlf/ocrLock 1
    mkdir public/fileadmin/fulltextFolder
    mkdir public/fileadmin/_temp_/fulltextTempFolder
    mkdir public/fileadmin/_temp_/imagesTempFolder
    chown -R www-data public/fileadmin/
    # Insert Typo3 content elements:
    echo '[MAIN] Setup DFG-Viewer: Update DB'
    dfgviewer_uid=$(mysql -h db -D ${DB_NAME} -e 'SELECT uid FROM pages WHERE title = "Viewer";' | sed '1d')
    mysql -h db -D ${DB_NAME} -e "UPDATE pages SET TSconfig = 'TCEMAIN.permissions.groupid = $dfgviewer_uid' WHERE title = 'Viewer';"
    mysql -h db -D ${DB_NAME} -e 'UPDATE pages SET tsconfig_includes = "EXT:dfgviewer/Configuration/TsConfig/Page.ts" WHERE title = "DFG Viewer";'
    mysql -h db -D ${DB_NAME} -e 'UPDATE pages SET tsconfig_includes = "EXT:dfgviewer/Configuration/TsConfig/Page.tsconfig" WHERE title = "Viewer";'
    mysql -h db -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, CType, header, bodytext) VALUES ('1', '1', 'text', 'DFG-Viewer Header', '<p><span style=\"color: #224466;\"><strong>DFG-Viewer OCR-On-Demand Testdocker</strong></span></p>');"
    mysql -h db -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, CType, header, bodytext) VALUES ('1', '1', 'text', 'DFG-Viewer Body', '<p>Nachfolgend finden Sie den Demonstator f&uuml;r OCR-On-Demand auf Basis des <a href=\"https://dfg-viewer.de/\" target=\"_blank\" rel=\"noopener\">DFG-Viewers</a> und <a href=\"https://www.kitodo.org/software/kitodopresentation\" target=\"_blank\" rel=\"noopener\">Kitodo.Presentation</a>, der im Rahmen des Projektes &bdquo;<em>OCR-D: Integration von Kitodo und OCR-D zur produktiven Massendigitalisierung\"</em> in einer Kooperation der <a href=\"https://www.bib.uni-mannheim.de/\" target=\"_blank\" rel=\"noopener\">UB Mannheim</a>, der <a href=\"https://www.tu-braunschweig.de/ub/\" target=\"_blank\" rel=\"noopener\">UB Braunschweig</a> und der <a href=\"https://www.slub-dresden.de/\" target=\"_blank\" rel=\"noopener\">SLUB Dresden</a> entwickelt wurde. Hier werden Ihnen Volltexte f&uuml;r Ihre Digitalisate auf Abruf automatisiert bereitgestellt.</p><p>Das Projekt wird gef&ouml;rdert durch die <a href=\"https://www.dfg.de/\" target=\"_blank\" rel=\"noopener\">Deutsche Forschungsgemeinschaft (DFG)</a>. Sie finden weiterf&uuml;hrende Informationen zum Projekt bei der <a href=\"https://www.bib.uni-mannheim.de/ihre-ub/projekte-der-ub/ocr-d-kitodo/\" target=\"_blank\" rel=\"noopener\">UB Mannheim</a> und der <a href=\"https://gepris.dfg.de/gepris/projekt/460478737\" target=\"_blank\" rel=\"noopener\">Deutschen Forschungsgemeinschaft</a> .</p>');"
    mysql -h db -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, CType, header, bodytext) VALUES ('1', '1', 'text', 'DFG-Viewer Examplebody', '<p>Nachfolgend befinden sich zwei Beispieldokumente zum Testen der OCR-On-Demand Funktionalit&auml;t. Alternativ kann man die URL zu einer beliebigen METS-Datei in das Suchfeld einf&uuml;gen.</p> <ul><li><a href=\"/index.php?id=2&amp;tx_dlf[id]=https%3A%2F%2Fdigi.bib.uni-mannheim.de%2Ffileadmin%2Fvl%2Fubmaosi%2F59087%2F59087.xml\">&Uuml;ber die Gesetze des geordneten Denkverlaufs [1913]</a></li><li><a href=\"/index.php?id=2&amp;tx_dlf[id]=https%3A%2F%2Fdigi.bib.uni-mannheim.de%2Ffileadmin%2Fvl%2Fubmaosi%2F59088%2F59088.xml\">Zur Psychologie des produktiven Denkens und des Irrtums [1922]</a></li></ul>');"
    mysql -h db -D ${DB_NAME} -e "INSERT INTO tt_content (pid, cruser_id, CType, header, bodytext) VALUES ('1', '1', 'html', 'Eingabefeld', '<div class=\"abstract\"> <form method=\"get\" action=\"index.php\">   <div> <label for=\"mets\">Fuegen Sie hier den Link zu Ihrer <acronym title=\"(engl.) metadata encoding and transmission standard; (dt.) Metadatenkodierungs- und -übertragungsstandard\">METS</acronym>-Datei bzw. <acronym title=\"(engl.) open archives initiative; (dt.) Initiative für freien Datenaustausch\">OAI</acronym>-Schnittstelle ein:</label> <br/> <input type=\"hidden\" name = \"id\" value = \"2\"> <input type=\"text\" class=\"url\" name=\"tx_dlf[id]\" value=\"\" required=\"true\" pattern=\"[0-9a-zA-Z].*\" placeholder=\"https://digi.bib.uni-mannheim.de/fileadmin/digi/1652998276/1652998276.xml\"/> <br/> <input type=\"hidden\" name=\"no_cache\" value=\"1\" /> <input type=\"reset\"> <input type=\"submit\" class=\"submit\" value=\"Demonstrator aufrufen\" />   </div> </form> </div>')"

    # AdditionalConfiguration (Fixes TYPO3-CORE-SA-2020-006: Same-Origin Request Forgery to Backend User Interface: https://typo3.org/security/advisory/typo3-core-sa-2020-006)
    # (Only if DMZ is set in .env)
    if [ ${AdditionalConfiguration} != 'false' ]; then
        echo -e "<?php\n['TYPO3_CONF_VARS']['SYS']['reverseProxySSL'] = '*';\n['TYPO3_CONF_VARS']['SYS']['reverseProxyIP'] = '*';\n['TYPO3_CONF_VARS']['SYS']['trustedHostsPattern'] = '${HOSTNAME}';\n['TYPO3_CONF_VARS']['SYS']['reverseProxyHeaderMultiValue'] = 'first';" >> AdditionalConfiguration.php
    fi

    # Install Tesseract v5: (https://notesalexp.org/tesseract-ocr/#tesseract_5.x)
    echo '[MAIN] Install Tesseract v5:'
    apt-get update
    apt-get install -y apt-transport-https lsb-release wget
    echo "deb https://notesalexp.org/tesseract-ocr5/$(lsb_release -cs)/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/notesalexp.list > /dev/null
    apt-get update -oAcquire::AllowInsecureRepositories=true
    apt-get install -y --allow-unauthenticated notesalexp-keyring -oAcquire::AllowInsecureRepositories=true
    apt-get update
    apt-get install -y tesseract-ocr
    cd /usr/share/tesseract-ocr/5/tessdata/
    wget https://ub-backup.bib.uni-mannheim.de/~stweil/tesstrain/frak2021/tessdata_fast/frak2021_1.069.traineddata
    cd /var/www/typo3/

    # Check languages:
    tesseract --list-langs

    # Cleanup:
    echo '[MAIN] cleanup:'
    apt-get purge -y jq apt-transport-https lsb-release
    apt-get autoremove -y
    apt-get clean
    rm -rf /var/lib/apt/lists/*

    # Check status:
    echo '[MAIN] Check apache status:'
    service apache2 status

    # Mark as finished:
    touch /initFinished
    echo '[MAIN] Finished setup '
fi

echo '[MAIN] Ready: http://localhost/typo3/ '
