-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-attr-code.sql', '$Id');

--	Wicci Project Virtual Text Schema
--	attr: an xml subtype representing xml attributes

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * code - methods and other functions

-- +++ xml_attr_text(xml_attr_refs, env_refs, crefs) -> TEXT
CREATE OR REPLACE FUNCTION xml_attr_text(
	xml_attr_refs, env_refs = env_nil(), crefs = crefs_nil()
) RETURNS text AS $$
	SELECT xml_unsafe_attr(
		xml_ns_prefix_text(ns_, $2, $3) || xml_attr_name_text(name_),
		ref_env_crefs_text_op(value_, $2, $3)
	) FROM xml_attr_rows WHERE ref = $1
$$ LANGUAGE SQL;
COMMENT ON FUNCTION xml_attr_text(xml_attr_refs, env_refs, crefs)
IS 'compute the text value';

CREATE OR REPLACE
FUNCTION old_xml_attr(page_uri_refs, xml_attr_name_refs, refs) 
RETURNS xml_attr_refs AS $$
	SELECT ref FROM xml_attr_rows
	WHERE ns_ = $1 AND name_ = $2 AND value_ = $3
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_xml_attr(page_uri_refs, xml_attr_name_refs, refs)
RETURNS xml_attr_refs AS $$
	SELECT non_null(
		old_xml_attr($1,$2,$3),
		'find_xml_attr(page_uri_refs,xml_attr_name_refs,refs)'
	)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION new_xml_attr(page_uri_refs, xml_attr_name_refs, refs)
 RETURNS xml_attr_refs AS $$
	INSERT INTO xml_attr_rows(ns_, name_, value_) VALUES( $1,$2,$3 )
	RETURNING ref
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION get_xml_attr(page_uri_refs, xml_attr_name_refs, refs)
RETURNS xml_attr_refs AS $$
	SELECT COALESCE( old_xml_attr($1,$2,$3), new_xml_attr($1,$2,$3) )
$$ LANGUAGE sql;

-- * get_xml_attr

CREATE OR REPLACE
FUNCTION get_xml_attr(page_uri_refs, xml_attr_name_refs, text)
RETURNS xml_attr_refs AS $$
	SELECT get_xml_attr($1, $2, get_text($3)::refs)
$$ LANGUAGE SQL;
COMMENT ON FUNCTION
get_xml_attr(page_uri_refs, xml_attr_name_refs, text) IS
'This is only creating text_refs values!!!
Consider passing in an environment from which
we can determine what the datatype associated
with this attribute name is supposed to be!
Note: xml id attribute values are assumed to be text,
so be sure not to break that!!';

CREATE OR REPLACE
FUNCTION get_xml_attr(page_uri_refs, xml_attr_name_refs, integer)
RETURNS xml_attr_refs AS $$
	SELECT get_xml_attr($1, $2, get_int_ref($3)::refs)
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION get_xml_attr(
	page_uri_refs, xml_attr_name_refs, double precision
) RETURNS xml_attr_refs AS $$
	SELECT get_xml_attr($1, $2, get_float_ref($3)::refs)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION get_xml_attr(text, text, integer)
RETURNS xml_attr_refs AS $$
	SELECT get_xml_attr(
		get_page_uri($1), get_xml_attr_name($2),
		get_int_ref($3)::refs
	)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION get_xml_attr(text, text, double precision)
RETURNS xml_attr_refs AS $$
	SELECT get_xml_attr(
		get_page_uri($1), get_xml_attr_name($2),
		get_float_ref($3)::refs
	)
$$ LANGUAGE SQL;

-- ** pattern matching

/*
-- This code is old, crude and redundant;
-- please give it some love when possible!!

-- illegal possibilities???, missing possibilities???
-- what about encoded values in quotes???
-- what about escaped quotes in quotes???
CREATE OR REPLACE
FUNCTION try_xml_attr_var_val_(text)  RETURNS text[] AS $$
	SELECT COALESCE(
		try_str_match(str, E'^([^=]+)="([^"]*)"$'),
		try_str_match(str, E'^([^=]+)=''([^'']*)''$'),
		try_str_match(str, E'^([^=]+)=(.*)$')
	) FROM str_trim($1) str
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION xml_attr_var_val_(text) RETURNS text[] AS $$
	SELECT non_null(
		try_xml_attr_var_val_($1),
		'xml_attr_var_val_(text)'
	)
$$ LANGUAGE SQL IMMUTABLE;

-- should we allow single quotes???
CREATE OR REPLACE
FUNCTION is_xml_attr_array(text) RETURNS boolean AS $$
	SELECT $1 ~ E'^\\s*([A-Za-z]\\w*="[^"]*"(\\s+[A-Za-z]\\w*="[^"]*")*)?\\s*$'
$$ LANGUAGE sql;

-- should we allow single quotes???
CREATE OR REPLACE
FUNCTION parse_attrs_(text) RETURNS SETOF text[] AS $$
	SELECT regexp_matches($1, E'([A-Za-z]\\w*)="([^"]*)"', 'g')
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION xml_attr_var_val_(text, OUT text, OUT text) AS $$
	SELECT CASE
		WHEN $1 ~ E'^[^=]*=\\s*"[^"]*"$'
			THEN substring_pair(str, '^([^=]*)=', E'^[^=]*=\\s*"([^"]*)"$')
		WHEN $1 ~ '^[A-Za-z_:][a-zA-Z0-9_.:-]*=[^]<>"'']*$'
			THEN substring_pair(str, '^([^=]*)=', E'^[^=]*=\\s*(.*)')
	END
	FROM str_trim($1) str
$$ LANGUAGE SQL IMMUTABLE;
*/

CREATE OR REPLACE
FUNCTION xml_attr_other_value(text, text) RETURNS refs AS $$
	SELECT get_text($1 || '="' || $2 || '"')::refs
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION find_xml_attr_value(text) RETURNS refs AS $$
	SELECT COALESCE(
		try_int_ref($1)::refs,
		try_float_ref($1)::refs,
		try_bool_ref($1)::refs,
		try_page_uri($1)::refs,
		find_text($1)::refs
	)
$$ LANGUAGE SQL;
COMMENT ON FUNCTION find_xml_attr_value(text) IS
'Analyze $1 to see if it is a ref_scalar or a vtext_ref
and return the first ref you find;
As we move to a richer representation for
attribute values, this will get interesting!!!
Consider passing in an environment from which
we can determine what the datatype associated
with this attribute name is supposed to be!';

CREATE OR REPLACE
FUNCTION try_xml_attr(page_uri_refs, xml_attr_name_refs, refs)
RETURNS xml_attr_refs AS $$
	SELECT ref FROM xml_attr_rows
	WHERE ns_ = $1 AND name_ = $2 AND value_ = $3
$$ LANGUAGE SQL STRICT;

/*
CREATE OR REPLACE
FUNCTION try_xml_attr(text) RETURNS xml_attr_refs AS $$
	SELECT COALESCE(
		( SELECT try_xml_attr(
				try_xml_attr_name(x[1]), find_xml_attr_value(x[2])
		) ),
		( SELECT try_xml_attr(
				xml_attr_name_nil(), xml_attr_other_value(x[1], x[2])
		) )
	) FROM xml_attr_var_val_($1) AS x
$$ LANGUAGE SQL STRICT;
*/

/*
CREATE OR REPLACE
FUNCTION find_xml_attr(text) RETURNS xml_attr_refs AS $$
	SELECT non_null( try_xml_attr($1), 'find_xml_attr(text)' )
$$ LANGUAGE SQL;
*/

CREATE OR REPLACE
FUNCTION get_xml_attr_value(text) RETURNS refs AS $$
	SELECT CASE
		WHEN is_int_ref_text($1) THEN
			get_int_ref($1::int)::refs
		WHEN is_float_ref_text($1) THEN
			get_float_ref(CAST($1 AS double precision))::refs
		ELSE
			get_text($1)::refs
	END
$$ LANGUAGE SQL;
COMMENT ON FUNCTION get_xml_attr_value(text) IS
'Analyze $1 to see if it is a number with a unit and if so,
generate a int_refs or float_refs with an appropriate env!!!
The code to do that should be in int_refs and/or float_refs!!';

CREATE OR REPLACE
FUNCTION try_get_xml_attr(text, text, text) 
RETURNS xml_attr_refs AS $$
	SELECT get_xml_attr(
		_ns, _name, get_xml_attr_value($3)
	) FROM
		try_page_uri($1) _ns,
		try_xml_attr_name($2) _name
	WHERE NOT is_nil(_name) AND _ns IS NOT NULL
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION get_xml_attr(text, text, text)
RETURNS xml_attr_refs AS $$
	SELECT get_xml_attr(
		_ns, _name, 	get_xml_attr_value($3)
	) FROM
		get_page_uri($1) _ns,
		get_xml_attr_name($2) _name
$$ LANGUAGE SQL;

/*
CREATE OR REPLACE
FUNCTION try_get_xml_attr(text) RETURNS xml_attr_refs AS $$
	SELECT try_get_xml_attr(page_uri_nil(), x[1], x[2])
	FROM xml_attr_var_val_($1) AS x
$$ LANGUAGE SQL STRICT;
*/

/*
CREATE OR REPLACE
FUNCTION get_xml_attr(text) RETURNS xml_attr_refs AS $$
	SELECT non_null( try_get_xml_attr($1), 'get_xml_attr(text)' )
$$ LANGUAGE SQL;
*/

-- ** register type xml_attr_refs class xml_attr_rows

-- SELECT type_class_io(
-- 	'xml_attr_refs', 'xml_attr_rows',
-- 	'get_xml_attr(text)', 'xml_attr_text(xml_attr_refs, env_refs, crefs)'
-- );

-- How can this be inferred by the fallbacks mechanism?
SELECT type_class_op_method(
	'xml_attr_refs', 'xml_attr_rows',
	'ref_text_op(refs)',
	'xml_attr_text(xml_attr_refs, env_refs, crefs)'
);

SELECT type_class_op_method(
	'xml_attr_refs', 'xml_attr_rows',
	'ref_env_crefs_text_op(refs, env_refs, crefs)',
	'xml_attr_text(xml_attr_refs, env_refs, crefs)'
);

-- * ref function postponed until xml gnosis ???

-- ** ref_to_xml_text(refs, env_refs, crefs) -> text
-- does not seem to be in use currently!
CREATE OR REPLACE
FUNCTION ref_to_xml_text(refs, env_refs, crefs) RETURNS text AS $$
	SELECT
	xml_encode_special_chars(ref_env_crefs_text_op($1, $2, $3))
$$ LANGUAGE sql;
COMMENT ON FUNCTION ref_to_xml_text(refs, env_refs, crefs) IS
'xml_encoded text rendering of a ref entity in given context;
suitable for use as a text node or as attribute data';


-- * xml_attr_refs[]

CREATE OR REPLACE FUNCTION xml_attrs_text(
	xml_attr_refs[], env_refs=env_nil(), crefs=crefs_nil()
) RETURNS TEXT AS $$
	SELECT CASE
		WHEN array_is_empty($1) THEN ''
		ELSE array_join( ARRAY(
			 SELECT xml_attr_text(attr, $2, $3)
			 FROM unnest($1) attr
		), '' )
	END
$$ LANGUAGE SQL IMMUTABLE;

/*
CREATE OR REPLACE
FUNCTION get_xml_attrs(text) RETURNS xml_attr_refs[] AS $$
	SELECT ARRAY(
		SELECT try_get_xml_attr( page_uri_nil(), attr[1], attr[2] )
		FROM parse_attrs_($1) attr WHERE is_xml_attr_array($1)
	)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION get_xml_attrs(text[]) RETURNS xml_attr_refs[] AS $$
	SELECT ARRAY(
		SELECT get_xml_attr(x) FROM unnest($1) x
	)
$$ LANGUAGE sql;
*/

-- * search

CREATE OR REPLACE FUNCTION try_xml_attrs_name_attr(
	xml_attr_refs[], xml_attr_name_refs
) RETURNS xml_attr_refs AS $$
	SELECT ref FROM xml_attr_rows, unnest($1) x
	WHERE ref = x AND name_ = $2 LIMIT 1
$$ LANGUAGE sql STABLE STRICT;

-- +++ xml_attrs_search(xml_attr_refs[], name_) -> refs?
CREATE OR REPLACE
FUNCTION xml_attrs_search(xml_attr_refs[], xml_attr_name_refs)
RETURNS refs AS $$
	SELECT value_ FROM xml_attr_rows
		WHERE ref = ANY($1) AND name_ = $2 LIMIT 1
$$ LANGUAGE sql STABLE;
COMMENT ON FUNCTION xml_attrs_search(
	xml_attr_refs[], xml_attr_name_refs
) IS '1st value in xml_attr_refs[] matching given name_  or NULL;
this looks VERY inefficient!!';


DROP OPERATOR IF EXISTS ^ (xml_attr_refs[] , xml_attr_name_refs)
CASCADE;

CREATE OPERATOR ^ (
		leftarg = xml_attr_refs[],
		rightarg = xml_attr_name_refs,
		procedure = xml_attrs_search
);

SELECT declare_xml_attr_name('class');

CREATE OR REPLACE FUNCTION xml_attrs_class_match(
	xml_attr_refs[], _regexp text
) RETURNS SETOF refs AS $$
	SELECT ref FROM xml_attr_rows
	WHERE ref = ANY($1)
	AND name_ = 'class' AND ns_ = page_uri_nil()
	AND ref_text_op(value_) ~ $2
	LIMIT 1
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION xml_attrs_class_match(
	xml_attr_refs[], _regexp text
) IS '
	Returns SETOF class attributes matching given regexp;
	this looks VERY inefficient!!
	Consider
	(1) having an op for regexp matching string types
	(2) having a set value type for classes
';

-- * xml_namespace(s) as xml_attr_refs([])

SELECT declare_xml_attr_name('kind', 'xmlns');

-- a custom data structure for namespaces would be
-- much, much more efficient than what we have here!!
-- but for now, we're going to use xml_attr_refs through
-- a thin layer of functions

CREATE OR REPLACE
FUNCTION xml_namespace_drop_xmlns(text)
RETURNS text AS $$
	SELECT CASE WHEN $1 = 'xmlns' THEN ''
	ELSE substring($1 FROM position(':' IN $1) + 1)
	END
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE
FUNCTION xml_namespace_add_xmlns(text)
RETURNS text AS $$
	SELECT CASE WHEN COALESCE($1 = '', true) THEN 'xmlns'
	ELSE 'xmlns:' || $1
	END
$$ LANGUAGE sql IMMUTABLE;
