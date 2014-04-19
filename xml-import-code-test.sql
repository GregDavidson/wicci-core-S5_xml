-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-import-code-test.sql', '$Id');

--	Wicci Project code to import XML as a new document

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * TABLE xml_root_tag_default_lang_pairs (
-- 	tag_name xml_tag_name_refs PRIMARY KEY ...
-- 	lang_ doc_lang_name_refs ...
-- );

-- *  TYPE xml_id_node_pairs ( id text, node doc_node_refs );

-- * TYPE xml_prefix_uri_pairs ( prefix text, uri page_uri_refs );

SELECT show_xml_prefix_uri_pairs(
	ARRAY( SELECT xml_prefix_uri_data() )
);

-- * TYPE xml_kind_returns (
-- 	kind doc_node_kind_refs, ns_pair xml_prefix_uri_pairs
-- );

-- * TYPE xml_tree_returns (
-- 	node doc_node_refs,
-- 	ns_pairs xml_prefix_uri_pairs[],
-- 	id_pairs xml_id_node_pairs[]
-- );


SELECT xml_attr( '', 'id', 'main' );

SELECT test_func(
	'xml_attr(text, text, text)',
	xml_attr( '', 'id', 'main' ),
	xml_attr_return( find_xml_attr(_ns, _name, _val), _prefix, _ns )
) FROM
	xml_prefix_name_nil() _prefix,
	page_uri_nil() _ns,
	find_xml_attr_name('id') _name,
	find_text('main') _val;

SELECT xml_attr( 'http://www.w3.org/XML/1998/namespace', 'xml:space', 'preserve' );

SELECT test_func(
	'xml_attr(text, text, text)',
	xml_attr( 'http://www.w3.org/XML/1998/namespace', 'xml:space', 'preserve' ),
	xml_attr_return( find_xml_attr(_ns, _name, _val), _prefix, _ns )
) FROM
	find_xml_prefix_name('xml') _prefix,
	find_page_uri('http://www.w3.org/XML/1998/namespace') _ns,
	find_xml_attr_name('space') _name,
	find_text('preserve') _val;

SELECT xml_root_kind(
	xml_doctype('svg', 'svg'),
	'http://www.w3.org/2000/svg', 'rect',
  xml_attr( '', 'id', 'main' ),
	xml_attr(
		'http://www.w3.org/XML/1998/namespace', 'xml:space', 'preserve'
	)
);

SELECT test_func(
	'xml_root_kind(doc_lang_name_refs, text, text, xml_attr_returns[])',
	xml_root_kind(
		xml_doctype('svg', 'svg'),
		'http://www.w3.org/2000/svg', 'rect',
    xml_attr( '', 'id', 'main' ),
		xml_attr( 'http://www.w3.org/XML/1998/namespace', 'xml:space', 'preserve' )
	),
	xml_kind_return(
		non_null(
			try_xml_root_element_kind(_tag, ARRAY[_attr1, _attr2]),
			'try_xml_root_element_kind(xml_tag_refs, xml_attr_refs[])'
		),
		ARRAY[_pu1, _pu2 ], _tag
	)
) FROM
	xml_tag(
		find_page_uri('http://www.w3.org/2000/svg'),
		find_xml_tag_name('rect'),
		find_doc_lang_name('svg')
	) _tag,
	find_xml_attr(
		page_uri_nil(),
		find_xml_attr_name('id'),
		find_text('main')
	) _attr1,
	find_xml_attr(
		find_page_uri('http://www.w3.org/XML/1998/namespace'),
		find_xml_attr_name('space'), find_text('preserve')
	) _attr2,
	xml_prefix_uri_pair(
		xml_prefix_name_nil(),
		find_page_uri('http://www.w3.org/2000/svg')
	) _pu1,
	xml_prefix_uri_pair(
		find_xml_prefix_name('xml'),
		find_page_uri('http://www.w3.org/XML/1998/namespace')
	) _pu2
;


SELECT xml_tag(
	find_page_uri('http://www.w3.org/2000/svg'),
	find_xml_tag_name('rect'),
	find_doc_lang_name('svg')
);

SELECT '"' || xml_ns_prefix_text( _uri, env_nil(), crefs_nil() ) || '"'
FROM find_page_uri('http://www.w3.org/2000/svg') _uri;

SELECT xml_tag_text( _tag ) FROM xml_tag(
	find_page_uri('http://www.w3.org/2000/svg'),
	find_xml_tag_name('rect'),
	find_doc_lang_name('svg')
) _tag;


SELECT xml_root_kind(xml_doctype('svg', 'svg'), 'http://www.w3.org/2000/svg', 'rect',
     xml_attr( '', 'id', 'main' ), xml_attr( 'http://www.w3.org/XML/1998/namespace', 'xml:space', 'preserve' ));

SELECT u, t FROM
	get_page_uri('fubar.svg') u,
	xml_doctype('svg', 'svg') t;

SELECT xml_tree(
	'',
  xml_kind(t, 'http://www.w3.org/2000/svg', 'svg' )
) FROM
	get_page_uri('fubar.svg') u,
	xml_doctype('svg', 'svg') t;


SELECT show_ref( (
	xml_root_kind(xml_doctype('svg', 'svg'), 'http://www.w3.org/2000/svg', 'rect',
     xml_attr( '', 'id', 'main' ), xml_attr( 'http://www.w3.org/XML/1998/namespace', 'xml:space', 'preserve' ))
).kind );

SELECT xml_tree(
	'',
  xml_root_kind( t, 'http://www.w3.org/2000/svg', 'svg' )
) FROM
	get_page_uri('fubar.svg') u,
	xml_doctype('svg', 'svg') t;

DELETE FROM doc_keys WHERE
key IS NOT DISTINCT FROM
try_doc_page_doc(try_doc_page('fubar.svg'));

SELECT doc_page_from_uri_lang_root(u, t,
  xml_tree( '',
   xml_root_kind(t, 'http://www.w3.org/2000/svg', 'svg' ) ) )
FROM get_page_uri('fubar.svg') u, xml_doctype('svg', 'svg') t;

SELECT test_func(
	'try_xml_doc_namespaces_text(doc_refs)',
	try_xml_doc_namespaces_text(_doc),
	' xmlns:_1="http://www.w3.org/2000/svg"'
) FROM doc_page_doc(find_doc_page('fubar.svg')) _doc;

/*

psql:xml-import-code-test.sql:167: ERROR:  P0001: FUNCTION xml_root_element_kind_text(doc_node_kind_refs,env_refs,crefs,doc_node_refs[]) RETURNED:
"<svg>
" ! "<svg />
"
LOCATION:  exec_stmt_raise, pl_exec.c:2795
make[1]: *** [xml-import-code-test.sql-out] Error 3
make[1]: Leaving directory `/home/greg/Projects/Wicci/Core/S5_xml'
make: *** [rebuild-all] Error 1

SELECT test_func(
	'xml_root_element_kind_text(doc_node_kind_refs, env_refs, crefs, doc_node_refs[])',
	tree_doc_text(_doc),
	E'<svg />\n'
) FROM doc_page_doc(find_doc_page('fubar.svg')) _doc;
*/

CREATE OR REPLACE
FUNCTION doc_uri_text(page_uri_refs) RETURNS text AS $$
	SELECT ( SELECT drop_env_give_value(
		_env, tree_doc_text(_doc, _env)
	) FROM COALESCE( ( env_doc( make_user_env(), _doc) ).env ) _env
	) FROM find_page_doc($1) _doc
$$ LANGUAGE SQL;

SELECT test_func_tokens(
	'xml_root_element_kind_text(
		doc_node_kind_refs, env_refs, crefs, doc_node_refs[]
	)',
	doc_uri_text('fubar.svg'),
	E'<_1:svg xmlns:_1="http://www.w3.org/2000/svg" />\n'
);
