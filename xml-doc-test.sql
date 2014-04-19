-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-doc-test.sql', '$Id');

\set ECHO all

-- SELECT refs_debug_on(), text_refs_debug_on(), xml_debug_on();

-- show simple and fancy docs

\x

SELECT '***** ' || handle::text || '***** ' || E'\n' || key::text
FROM doc_keys_row_handles;
