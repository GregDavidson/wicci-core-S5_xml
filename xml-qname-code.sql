 -- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-qname-code.sql', '$Id');

--	Wicci Project Virtual Text Schema
--	xml_qname: an xml subtype representing xml namespace qualified names

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * code - methods and other functions

-- +++ xml_qname_text(xml_qname_refs, env_refs, crefs) -> TEXT
CREATE OR REPLACE FUNCTION xml_qname_text(
	xml_qname_refs, env_refs = env_nil(), crefs = crefs_nil()
) RETURNS text AS $$
	SELECT xml_unsafe_qname(
xml_ns_prefix_text(ns_, $2, $3), xml_qname_name_text(name_)
	) FROM xml_qname_rows WHERE ref = $1
$$ LANGUAGE SQL;
COMMENT ON FUNCTION xml_qname_text(xml_qname_refs, env_refs, crefs)
IS 'compute the text value';

CREATE OR REPLACE
FUNCTION old_xml_qname(page_uri_refs, xml_qname_name_refs)
RETURNS xml_qname_refs AS $$
	SELECT ref FROM xml_qname_rows
	WHERE ns_ = $1 AND name_ = $2
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION new_xml_qname(page_uri_refs, xml_qname_name_refs)
 RETURNS xml_qname_refs AS $$
	INSERT INTO xml_qname_rows(ns_, name_) VALUES( $1,$2 )
	RETURNING ref
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION get_xml_qname(page_uri_refs, xml_qname_name_refs)
RETURNS xml_qname_refs AS $$
	SELECT COALESCE( old_xml_qname($1,$2), new_xml_qname($1,$2) )
$$ LANGUAGE sql;

-- * get_xml_qname

CREATE OR REPLACE
FUNCTION get_xml_qname(page_uri_refs, xml_qname_name_refs)
RETURNS xml_qname_refs AS $$
	SELECT get_xml_qname($1, $2)
$$ LANGUAGE SQL;

-- ** pattern matching

-- we should have some functions for validating tags and qname_names
-- with regexps!

CREATE OR REPLACE
FUNCTION try_xml_qname(page_uri_refs, xml_qname_name_refs)
RETURNS xml_qname_refs AS $$
	SELECT ref FROM xml_qname_rows
	WHERE ns_ = $1 AND name_ = $2
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION try_get_xml_qname(text, text) 
RETURNS xml_qname_refs AS $$
	SELECT get_xml_qname( _ns, _name ) FROM
		try_page_uri($1) _ns,
		try_xml_qname_name($2) _name
	WHERE NOT is_nil(_name) AND _ns IS NOT NULL
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION get_xml_qname(text, text)
RETURNS xml_qname_refs AS $$
	SELECT get_xml_qname( _ns, _name ) FROM
		get_page_uri($1) _ns,
		get_xml_qname_name($2) _name
$$ LANGUAGE SQL;


-- How can this be inferred by the fallbacks mechanism?
SELECT type_class_op_method(
	'xml_qname_refs', 'xml_qname_rows',
	'ref_text_op(refs)',
	'xml_qname_text(xml_qname_refs, env_refs, crefs)'
);

SELECT type_class_op_method(
	'xml_qname_refs', 'xml_qname_rows',
	'ref_env_crefs_text_op(refs, env_refs, crefs)',
	'xml_qname_text(xml_qname_refs, env_refs, crefs)'
);

SELECT declare_xml_qname_name('kind', 'xmlns');
