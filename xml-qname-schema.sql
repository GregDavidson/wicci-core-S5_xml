-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-qname-schema.sql', '$Id');

--	Wicci Project Virtual Text Schema
--	xml_qname: an xml subtype representing namespace qualified names

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- The datatypes here are awaiting the right time to be used in a
-- refactoring of the xml_attr and xml_tag abstractions

-- * schema

SELECT create_name_ref_schema('xml_qname_name');

SELECT create_ref_type('xml_qname_refs');

-- ** TABLE xml_qname_rows

CREATE TABLE IF NOT EXISTS xml_qname_rows (
	ref xml_qname_refs PRIMARY KEY,
	ns_ page_uri_refs DEFAULT page_uri_nil()
		NOT NULL REFERENCES page_uri_rows,
	name_  xml_qname_name_refs
		NOT NULL REFERENCES xml_qname_name_rows,
	UNIQUE(ns_, name_)
);
COMMENT ON TABLE xml_qname_rows IS
'XML namespace qualified names';
COMMENT ON COLUMN xml_qname_rows.ns_ IS
'The uri of the namespace, if any';

SELECT declare_ref_class_with_funcs('xml_qname_rows');

SELECT create_simple_serial('xml_qname_rows');

CREATE OR REPLACE
FUNCTION xml_qname_uri(xml_qname_refs)
RETURNS page_uri_refs AS $$
	SELECT ns_ FROM xml_qname_rows WHERE ref = $1
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION xml_qname_name(xml_qname_refs)
RETURNS xml_qname_name_refs AS $$
	SELECT name_ FROM xml_qname_rows WHERE ref = $1
$$ LANGUAGE sql;
