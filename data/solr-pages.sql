-- Minimal frontend records used by the optional Solr development profile.
-- Named columns keep these inserts stable when TYPO3 adds or removes fields.

INSERT INTO pages (
    uid, pid, tstamp, crdate, deleted, hidden, sorting, perms_userid, perms_groupid, perms_user, perms_group, perms_everybody, title, slug, doktype, is_siteroot
) VALUES
    (1, 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 0, 128, 1, 0, 31, 27, 0, 'Presentation', '/', 1, 1),
    (7, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 0, 256, 1, 0, 31, 27, 0, 'Suche', '/suche', 1, 0),
    (8, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 0, 128, 1, 0, 31, 27, 0, 'Sammlungen', '/sammlungen', 1, 0);

INSERT INTO sys_template (
    uid, pid, tstamp, crdate, deleted, hidden, sorting, title, root, clear, include_static_file, constants, config
) VALUES (
    1, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 0, 128, 'Presentation', 1, 1,
    'EXT:fluid_styled_content/Configuration/TypoScript/,EXT:dlf/Configuration/TypoScript/',
    'plugin.tx_dlf.persistence.storagePid = 3\nplugin.tx_dlf.persistence.solrCoreUid = 1',
    'page = PAGE\npage.10 < styles.content.get'
);

INSERT INTO tt_content (
    uid, pid, tstamp, crdate, deleted, hidden, sorting, CType, header
) VALUES (
    11, 7, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 0, 256, 'header', 'Metadaten- und Volltextsuche'
);

INSERT INTO tt_content (
    uid, pid, tstamp, crdate, deleted, hidden, sorting, CType, list_type, pi_flexform
) VALUES (
    12, 7, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 0, 512, 'list', 'dlf_search',
    '<?xml version="1.0" encoding="utf-8" standalone="yes" ?>
<T3FlexForms><data><sheet index="sDEF"><language index="lDEF">
<field index="settings.fulltext"><value index="vDEF">1</value></field>
<field index="settings.fulltextPreselect"><value index="vDEF">0</value></field>
<field index="settings.datesearch"><value index="vDEF">1</value></field>
<field index="settings.solrcore"><value index="vDEF">1</value></field>
<field index="settings.extendedSlotCount"><value index="vDEF">1</value></field>
<field index="settings.limitFacets"><value index="vDEF">15</value></field>
<field index="settings.suggest"><value index="vDEF">1</value></field>
<field index="settings.targetPidPageView"><value index="vDEF">2</value></field>
</language></sheet></data></T3FlexForms>'
);

INSERT INTO tt_content (
    uid, pid, tstamp, crdate, deleted, hidden, sorting, CType, list_type, pi_flexform
) VALUES (
    13, 8, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 0, 256, 'list', 'dlf_collection',
    '<?xml version="1.0" encoding="utf-8" standalone="yes" ?>
<T3FlexForms><data><sheet index="sDEF"><language index="lDEF">
<field index="settings.solrcore"><value index="vDEF">1</value></field>
<field index="settings.show_userdefined"><value index="vDEF">-1</value></field>
<field index="settings.dont_show_single"><value index="vDEF">0</value></field>
<field index="settings.randomize"><value index="vDEF">0</value></field>
<field index="settings.targetPidPageView"><value index="vDEF">2</value></field>
</language></sheet></data></T3FlexForms>'
);
