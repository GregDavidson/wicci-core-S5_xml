-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('css-kind-schema.sql', '$Id');

--	Wicci Project CSS Encoding Schema

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * css property names

SELECT create_name_ref_schema('css_name', name_type := 'citext');

CREATE TABLE IF NOT EXISTS css_name_types (
	name_ css_name_refs NOT NULL
		REFERENCES css_name_rows,
	type_ env_refs NOT NULL
		REFERENCES env_rows
);

COMMENT ON TABLE css_name_types IS
'css_name_types are for constraining possible values
of named properties in the same or similar manner
as environments associated with xml tag atrributes
constrain their possible values.';

-- * css_doc_kind

CREATE TABLE IF NOT EXISTS css_root_kind_rows (
	PRIMARY KEY (ref)
) INHERITS(abstract_doc_node_kind_rows);

COMMENT ON TABLE css_root_kind_rows IS
'	A singleton class representing the root of
	a css document.
	Eventually use doc_kind_lang_types to
	ensure children are css_set nodes!!
';

SELECT declare_ref_class('css_root_kind_rows');
SELECT declare_doc_kind_lang_type('css_root_kind_rows', 'css');

DO $$
DECLARE
	_ref doc_node_kind_refs;
BEGIN
	SELECT ref INTO _ref FROM css_root_kind_rows;
	IF NOT FOUND THEN
		_ref := next_doc_node_kind( 'css_root_kind_rows' );
		INSERT INTO css_root_kind_rows(ref) VALUES (_ref);
		INSERT INTO doc_node_kind_keys(key) VALUES (_ref);
	END IF;
END $$;

-- * css_set_kind

CREATE TABLE IF NOT EXISTS css_set_kind_rows (
	PRIMARY KEY (ref),
	path_ text UNIQUE NOT NULL
) INHERITS(abstract_doc_node_kind_rows);

COMMENT ON TABLE css_set_kind_rows IS
'	somewhere, somehow, require that the children
	all be css_property nodes!!
';

COMMENT ON COLUMN css_set_kind_rows.path_ IS
'	eventually this could become a structured expression;
	otherwise it should at least be parsed & checked!!
';

SELECT declare_ref_class('css_set_kind_rows');
SELECT declare_doc_kind_lang_type('css_set_kind_rows', 'css');

ALTER TABLE css_set_kind_rows ALTER COLUMN ref
	SET DEFAULT next_doc_node_kind( 'css_set_kind_rows' );

SELECT create_key_triggers_for(
	'css_set_kind_rows', 'doc_node_kind_keys'
);

-- * css_property_kind

CREATE TABLE IF NOT EXISTS css_property_kind_rows (
	PRIMARY KEY (ref),
	name_ css_name_refs NOT NULL
		REFERENCES css_name_rows,
	val_ refs NOT NULL,
	UNIQUE(name_, val_)
) INHERITS(abstract_doc_node_kind_rows);

COMMENT ON COLUMN css_property_kind_rows.val_ IS
'	constrained by the css_name_types.type_
	associated with the css_property_kind_rows.name_
	associated with this field!!
';

SELECT declare_ref_class('css_property_kind_rows');
SELECT declare_doc_kind_lang_type('css_property_kind_rows', 'css');

ALTER TABLE css_property_kind_rows ALTER COLUMN ref
	SET DEFAULT next_doc_node_kind( 'css_property_kind_rows' );

SELECT create_key_triggers_for(
	'css_property_kind_rows', 'doc_node_kind_keys'
);
