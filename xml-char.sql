-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-char.sql', '$Id');

--	Wicci Project XML/HTML Encoding Schema

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * type xml_char_refs

-- TO DO: add to_xml operator!!!
-- what about xml_length operator???

SELECT create_ref_type('xml_char_refs');

-- * schema

-- xml_chars will eventually need to be associated
-- with a specific schema!!!
-- xml_chars may eventually need to distinguish
-- (1) those character entities which are allowed inside of xml text
-- (2) those character entities which must be used inside of xml text
-- (3/4) ditto for xml attribute values
-- or maybe if we properly re-encode xml text when we store it
-- that will suffice for both validation and normalization.
CREATE TABLE IF NOT EXISTS xml_chars (
	ref xml_char_refs,
	char_ integer PRIMARY KEY,
	name_ name_refs UNIQUE NOT NULL REFERENCES name_rows
);
COMMENT ON COLUMN xml_chars.char_ IS
'a character code in some character set';

SELECT declare_ref_class('xml_chars');

-- ** id management

CREATE OR REPLACE
FUNCTION unchecked_xml_char_from_id(ref_ids)
RETURNS xml_char_refs AS $$
	SELECT unchecked_ref(
	'xml_char_refs', 'xml_chars', $1
	)::xml_char_refs
$$ LANGUAGE SQL IMMUTABLE;

DROP SEQUENCE IF EXISTS xml_chars_id_seq CASCADE;

CREATE SEQUENCE xml_chars_id_seq
	OWNED BY xml_chars.ref
	MINVALUE 1000 MAXVALUE :RefIdMax CYCLE;

ALTER TABLE xml_chars ALTER COLUMN ref
	SET DEFAULT
	unchecked_xml_char_from_id( nextval('xml_chars_id_seq')::ref_ids );

-- * code - methods and other functions

-- improve dealing with non-ASCII and non-graphic chars ???
CREATE OR REPLACE
FUNCTION xml_char_declaration(xml_char_refs)
RETURNS text AS $$
	SELECT '<!ENTITY ' || name_::text || ' "' ||
	CASE
		WHEN char_ = ascii('"')	-- avoid quotes inside quotes
		OR char_ < 32			-- ASCII space, first "graphic" character
		OR char_ >= 127		-- ASCII DEL, past ASCII "graphic" chars
		THEN 'x' || to_hex(char_)
	ELSE
		chr(char_)
	END
	|| '">'
	FROM xml_chars WHERE ref = $1
$$ LANGUAGE SQL;
COMMENT ON FUNCTION xml_char_declaration(xml_char_refs) IS
'show a xml_char_refs as an xml entity declaration';

CREATE OR REPLACE
FUNCTION xml_char_text(xml_char_refs) RETURNS text AS $$
	SELECT '&' || name_::text || ';'
	FROM xml_chars WHERE ref = $1
$$ LANGUAGE SQL;
COMMENT ON FUNCTION xml_char_text(xml_char_refs) IS 'compute the text value';

CREATE OR REPLACE
FUNCTION xml_char_length(xml_char_refs) RETURNS integer AS $$
	SELECT name_length(name_) + 2
	FROM xml_chars WHERE ref = $1
$$ LANGUAGE SQL;
COMMENT ON FUNCTION xml_char_length(xml_char_refs) IS 'compute the length of the entity representation in bytes';

CREATE OR REPLACE
FUNCTION old_vchar_(integer, name_refs) RETURNS xml_char_refs AS $$
	SELECT ref FROM xml_chars WHERE char_ = $1 AND name_ = $2
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION new_vchar_(integer, name_refs) RETURNS xml_char_refs AS $$
	INSERT INTO xml_chars(char_, name_) VALUES( $1, $2 )
	RETURNING ref
$$ LANGUAGE sql;

-- +++ get_xml_char(integer, name) -> xml_char_refs
CREATE OR REPLACE
FUNCTION get_xml_char(integer, name_refs)
RETURNS xml_char_refs AS $$
	SELECT COALESCE( old_vchar_($1, $2), new_vchar_($1, $2) )
$$ LANGUAGE sql;

-- ** type xml_char_refs recognizers and converters

-- CREATE OR REPLACE
-- FUNCTION isa_xml_char(refs) RETURNS boolean AS $$
--   SELECT xml_char_tag() = ref_tag($1)
-- $$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION xml_char_char(xml_char_refs) RETURNS integer AS $$
	SELECT char_ FROM xml_chars WHERE ref = $1
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION xml_char_name(xml_char_refs) RETURNS name_refs AS $$
	SELECT name_ FROM xml_chars WHERE ref = $1
$$ LANGUAGE sql;

-- ** Checked Downcasts

-- CREATE OR REPLACE
-- FUNCTION xml_char_from_ref(refs) RETURNS xml_char_refs AS $$
--   SELECT unchecked_xml_char_from_id( ref_id($1) )
--   WHERE isa_xml_char($1)
-- $$ LANGUAGE sql;

-- * get_xml_char

-- ++ get_xml_char(integer, text) -> xml_char_refs
CREATE OR REPLACE
FUNCTION get_xml_char(integer, text) RETURNS xml_char_refs AS $$
	SELECT get_xml_char($1, $2::name_refs)
$$ LANGUAGE SQL;

-- ++ get_xml_char(char, text) -> xml_char_refs -- for convenience
CREATE OR REPLACE
FUNCTION get_xml_char(char, text) RETURNS xml_char_refs AS $$
	SELECT get_xml_char( ascii($1), $2 )
$$ LANGUAGE SQL;

-- what about specifying something to be a space???
-- what about supporting entity declaration syntax???
CREATE OR REPLACE
FUNCTION try_xml_char_var_val_(text)  RETURNS text[] AS $$
	SELECT COALESCE(
		try_str_match(str, E'^(\\d+)=([[:lower:]]+)$'),
		try_str_match(str, E'^(.)=([[:lower:]]+)$')
	) FROM str_trim_deep($1) str
$$ LANGUAGE SQL IMMUTABLE STRICT;

CREATE OR REPLACE
FUNCTION xml_char_var_val_(text) RETURNS text[] AS $$
	SELECT non_null(
		try_xml_char_var_val_($1),
		'xml_char_var_val_(text)'
	)
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION get_xml_char_(text) RETURNS xml_char_refs AS $$
	SELECT get_xml_char(
		CASE WHEN x[1] ~ E'^\\d+$'
	THEN x[1]::integer ELSE ascii(x[1]) END,
	x[2]::name_refs
	) FROM xml_char_var_val_($1) x
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION try_get_xml_char(text) RETURNS xml_char_refs AS $$
	SELECT CASE
		WHEN $1 ~ E'^\\d+$' THEN
			(SELECT ref FROM xml_chars WHERE char_ = $1::integer)
		WHEN $1 ~ '^&?([[lower]]+);?$' THEN (
			SELECT ref FROM xml_chars
			WHERE name_text(name_)
				= regexp_replace($1, '^&?([[lower]]+);?$', E'\1', '')
		)
		ELSE get_xml_char_($1)
	END
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION get_xml_char(text) RETURNS xml_char_refs AS $$
	SELECT non_null(
		try_get_xml_char($1), 'get_xml_char(text)'
	)
$$ LANGUAGE SQL;


-- ** register type xml_char_refs class xml_chars

-- SELECT type_class_io(
-- 	'xml_char_refs', 'xml_chars',
-- 	'get_xml_char(text)', 'xml_char_text(xml_char_refs)'
-- );

SELECT type_class_op_method(
	'xml_char_refs', 'xml_chars',
	'ref_text_op(refs)',  'xml_char_text(xml_char_refs)'
);

SELECT type_class_op_method(
	'xml_char_refs', 'xml_chars',
	'ref_length_op(refs)', 'xml_char_length(xml_char_refs)'
);

