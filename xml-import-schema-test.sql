-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-import-schema-test.sql', '$Id');

--	Wicci Project code to import XML as a new document

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * TABLE xml_root_tag_default_lang_pairs (
-- 	tag_name xml_tag_name_refs PRIMARY KEY ...
-- 	lang doc_lang_name_refs ...
-- );

-- *  TYPE xml_id_node_pairs ( id text, node doc_node_refs );

/*
CREATE OR REPLACE
FUNCTION xml_id_node_data()
RETURNS SETOF xml_id_node_pairs AS $$
	SELECT xml_id_node_pair(get_handle::text, key)
	FROM doc_node_keys_row_handles
$$ LANGUAGE sql;

SELECT id, key FROM xml_id_node_data() AS foo(id, key);
*/

-- * TYPE xml_prefix_uri_pairs ( prefix text, uri page_uri_refs );

CREATE OR REPLACE
FUNCTION xml_prefix_uri_data()
RETURNS SETOF xml_prefix_uri_pairs AS $$
	SELECT xml_prefix_uri_pair(''::text, 'puuhonua.org') UNION
	SELECT xml_prefix_uri_pair('puu'::text, 'puuhonua.org') UNION
	SELECT xml_prefix_uri_pair('foo'::text,'/foo/bar') UNION
	SELECT xml_prefix_uri_pair('bar'::text,'/foo/bar') UNION
	SELECT xml_prefix_uri_pair(
		'touch'::text, 'touch@puuhonua.org'
	) UNION SELECT xml_prefix_uri_pair(
		''::text, 'user:touch@puuhonua.org'
	) UNION SELECT xml_prefix_uri_pair(
		'index'::text, 'user:touch@puuhonua.org/index.html'
	)
$$ LANGUAGE sql;

SELECT prefix, uri
FROM xml_prefix_uri_data() AS foo(prefix, uri);

SELECT _prefix, _uri FROM
	xml_prefix_uri_data() AS foo(_prefix, _uri),
	xml_prefix_name_rows
WHERE _prefix = ref
ORDER BY _uri, length(name_) DESC;
