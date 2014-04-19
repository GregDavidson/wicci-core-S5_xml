-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-types-code.sql', '$Id');

--	Wicci Project XML/HTML Encoding Schema
--	Support for all the XML types & classes

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * miscellaneous support

SELECT declare_name('xml-join-text');

SELECT create_env_name_type_func(
	'env_xml_kind_type', 'name_refs' -- really name_refs??
);

CREATE OR REPLACE
FUNCTION xml_nl(env_refs, crefs) RETURNS TEXT AS $$
	SELECT COALESCE(($1^'xml-join-text')::text, E'\n')
$$ LANGUAGE SQL;
COMMENT ON FUNCTION xml_nl(env_refs, crefs) IS '
	return an appropriate whitespace string to act as an
	end-of-element string - may include indentation for the next line.
	This really should be replaced by using the depth count
	in the crefs object!!!  And it really has nothing to do with
	XML per se, but rather any language which enjoys
	indentation to show hierarchy.
';

/* It is unclear whether it is beneficial to separate the
 * operation of producing XML text from the general
 * operation of producing text.  If we wish to do so,
 * here is some structure for it.
*/

CREATE OR REPLACE
FUNCTION ref_env_crefs_xml_op(refs, env_refs, crefs) RETURNS text
AS 'spx.so', 'ref_env_crefs_etc_text_op' LANGUAGE c;
COMMENT ON FUNCTION ref_env_crefs_xml_op(refs, env_refs, crefs)
IS 'This should produce valid xml when applied to any kind
of xml object';

CREATE OR REPLACE
FUNCTION xml_pure_text(refs, env_refs=env_nil(), crefs=crefs_nil())
RETURNS text AS $$
	SELECT xml_pure_text(ref_text_op($1), xml_nl($2, $3))
$$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION xml_pure_text(refs, env_refs, crefs)
IS 'This should produce valid xml text for any object which can
produce arbitrary text.';

SELECT declare_op_fallback(
	'ref_env_crefs_xml_op(refs, env_refs, crefs)',
	'xml_pure_text(refs, env_refs, crefs)'
);

-- * doc namespaces

CREATE OR REPLACE FUNCTION xml_ns_prefix_text(
	_ns page_uri_refs,
	_env env_refs = NULL,
	_cref crefs = NULL,
	_doc doc_refs = NULL,
	_prefix xml_prefix_name_refs = NULL
) RETURNS text AS $$
	SELECT CASE WHEN is_nil($1) THEN '' ELSE ( SELECT CASE
		WHEN _prefix IS NULL AND NOT is_nil(_doc) THEN
			( SELECT ''::text FROM
				raise_debug_note(this, page_uri_text($1), 'ERROR: no prefix!!!')
			)
		WHEN is_nil(_prefix) THEN ''
		ELSE _prefix::text || ':'
	END FROM
		COALESCE( $5, (
			SELECT prefix FROM doc_namespaces
			WHERE doc = _doc AND uri = $1
		) ) _prefix
	) END FROM
		COALESCE($4, try_crefs_doc($3), try_env_doc($2)) _doc,
		this('xml_ns_prefix_text(
			page_uri_refs, env_refs, crefs, doc_refs,
			xml_prefix_name_refs
		)')
$$ LANGUAGE SQL;

COMMENT ON FUNCTION xml_ns_prefix_text(
page_uri_refs, env_refs, crefs, doc_refs, xml_prefix_name_refs
) IS '
given a non-nil namespace with no matching prefix,
we will throw a notice and return an empty prefix!!
';

CREATE OR REPLACE
FUNCTION try_xml_doc_namespaces_text(doc_refs)
RETURNS text AS $$
	SELECT CASE
		WHEN _text IS NULL THEN ''
		WHEN _text = '' THEN ''
		ELSE _text
	END FROM array_to_string(ARRAY( 
		SELECT DISTINCT xml_unsafe_attr(
				'xmlns'::text || COALESCE(':'::text || prefix, ''),
				'http://'::text || page_uri_text(uri)
		) FROM doc_namespaces WHERE doc = $1
	), ' ') _text
$$ LANGUAGE SQL STRICT;

COMMENT ON FUNCTION 
try_xml_doc_namespaces_text(doc_refs)
IS 'Return all of the namespaces for this document with a preceeding space';

CREATE OR REPLACE
FUNCTION xml_split_prefix_name(text, OUT text, OUT text) AS $$
	SELECT
		CASE WHEN colon=0 THEN '' ELSE substr($1,1,colon-1) END,
		CASE WHEN colon=0 THEN $1 ELSE substr($1,colon+1) END 
	FROM strpos($1, ':') colon
$$ LANGUAGE SQL IMMUTABLE;
