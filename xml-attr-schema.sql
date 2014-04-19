-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-attr-schema.sql', '$Id');

--	Wicci Project Virtual Text Schema
--	attr: an xml subtype representing xml attributes

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * type xml_attr_name

--		CHECK(is_xml_name(xml_attr_name_text(name_))),
SELECT create_name_ref_schema('xml_attr_name');

SELECT create_const_ref_func('xml_attr_name_refs', '_id', -1);

INSERT INTO xml_attr_name_rows(ref, name_)
VALUES ( xml_attr_name_id(), '_id' );

-- * type xml_attr_refs

SELECT create_ref_type('xml_attr_refs');

-- * schema

-- ** TABLE xml_attr_rows

CREATE TABLE IF NOT EXISTS xml_attr_rows (
	ref xml_attr_refs PRIMARY KEY,
	ns_ page_uri_refs DEFAULT page_uri_nil()
		NOT NULL REFERENCES page_uri_rows,
	name_  xml_attr_name_refs
		NOT NULL REFERENCES xml_attr_name_rows,
	value_ refs NOT NULL
		CHECK( NOT is_nil(value_) AND refs_op_tag_to_method(
			'ref_env_crefs_text_op(refs, env_refs, crefs)', ref_tag(value_)
		) IS NOT NULL),
	UNIQUE(ns_, name_, value_)
);
COMMENT ON TABLE xml_attr_rows IS
'XML attribute-value pairs';
COMMENT ON COLUMN xml_attr_rows.ns_ IS
'The uri of any namespace associated with this
attribute or page_uri_nil() if none..';
COMMENT ON COLUMN xml_attr_rows.name_ IS
'when xml_attr_name_nil() then real attr_name= prefixes the value
otherwise: need to be sure the name_ is valid!!';
COMMENT ON COLUMN xml_attr_rows.value_ IS
'A texty ref will be xml_encoded by the to_xml_text function;
would adding a distinct xml_text type help??';

SELECT declare_ref_class_with_funcs('xml_attr_rows');

SELECT create_simple_serial('xml_attr_rows');

CREATE OR REPLACE
FUNCTION xml_attr_uri(xml_attr_refs)
RETURNS page_uri_refs AS $$
	SELECT ns_ FROM xml_attr_rows WHERE ref = $1
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION xml_attr_name(xml_attr_refs)
RETURNS xml_attr_name_refs AS $$
	SELECT name_ FROM xml_attr_rows WHERE ref = $1
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION xml_attr_value(xml_attr_refs) RETURNS refs AS $$
	SELECT value_ FROM xml_attr_rows WHERE ref = $1
$$ LANGUAGE sql;

