-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-kind-schema.sql', '$Id');

--	Wicci Project XML/HTML Encoding Schema
--	type xml_kind schema

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * types

-- for rendering XML
-- should we (1) use the existing *_text_op operations??
-- or (2) create XML-specific *_to_xml_op operations ??
-- Machinery for (2) is in xml-types.sql, but is it reasonable
-- to separate xml languages from other languages??

SELECT declare_doc_lang_family('xml', 'text');
SELECT declare_doc_lang_family('svg', 'xml');
SELECT declare_doc_lang_family('ajax', 'xml');
SELECT declare_doc_lang_family('html', 'xml');
SELECT declare_doc_lang_family('xhtml', 'html');
SELECT declare_doc_lang_family('xhtml-strict', 'xhtml');
SELECT declare_doc_lang_family('html4', 'html');
SELECT declare_doc_lang_family('html4-strict', 'html4');
SELECT declare_doc_lang_family('png', 'binary');
SELECT declare_doc_lang_family('gif', 'binary');
SELECT declare_doc_lang_family('jpeg', 'binary');

CREATE OR REPLACE
FUNCTION isa_xml_kind(refs) RETURNS BOOLEAN AS $$
	-- SELECT type_ = 'xml_kind_refs'::regtype
	-- FROM typed_object_classes WHERE tag_ = ref_tag($1)
	SELECT true										-- 	-- ???? finish !!!
$$ LANGUAGE SQL;
COMMENT ON FUNCTION isa_xml_kind(refs)
IS 'How should this work???';

-- * schema

-- do we want to: ???
-- derive from abstract ref kinds --> current code
-- or roll our own --> commented out

-- * abstract base class

 CREATE TABLE IF NOT EXISTS abstract_xml_leaf_kind_rows (
   ref doc_node_kind_refs --  PRIMARY KEY
);
COMMENT ON TABLE abstract_xml_leaf_kind_rows IS
'How can we refactor the code so that leaf nodes
and only leaf nodes use leaf kinds??';
SELECT declare_abstract('abstract_xml_leaf_kind_rows');

-- ** concrete tables

-- *** TABLE xml_literal_kind_rows

-- need better justification for the existence of
-- this hack!!!

CREATE TABLE IF NOT EXISTS xml_literal_kind_rows (
	PRIMARY KEY (ref),
--	FOREIGN KEY(ref) REFERENCES xml_kind_keys,
	literal refs
) INHERITS(abstract_doc_node_kind_rows);
COMMENT ON TABLE xml_literal_kind_rows IS
'Allows for specially-built xml text
- children will be rendered normally
- children will appear AFTER the literal.
Separating the literal from regular children:
- allows them to be of ref types that are NOT xml_kind_refs
- prevents any wicci mechanism from replacing them.
Great for doctypes and processing directives!';

SELECT create_handles_for('xml_literal_kind_rows');
SELECT declare_ref_class('xml_literal_kind_rows');
SELECT declare_doc_kind_lang_type('xml_literal_kind_rows', 'xml');

ALTER TABLE xml_literal_kind_rows ALTER COLUMN ref
	SET DEFAULT next_doc_node_kind( 'xml_literal_kind_rows' );

SELECT create_key_triggers_for(
	'xml_literal_kind_rows', 'doc_node_kind_keys'
);

-- *** TABLE xml_element_kind_rows

CREATE TABLE IF NOT EXISTS xml_element_kind_rows (
	PRIMARY KEY (ref),		-- DO NOT DEFAULT THIS!
--	FOREIGN KEY(ref) REFERENCES xml_kind_keys, -- !!
	tag xml_tag_refs NOT NULL,
	attrs xml_attr_refs[] NOT NULL
) INHERITS(abstract_doc_node_kind_rows);
COMMENT ON TABLE xml_element_kind_rows IS 'XML elements';
SELECT declare_ref_class('xml_element_kind_rows');
SELECT declare_doc_kind_lang_type('xml_element_kind_rows', 'xml');

SELECT create_key_triggers_for(
	'xml_element_kind_rows', 'doc_node_kind_keys'
);

-- *** TABLE xml_root_element_kind_rows

CREATE TABLE IF NOT EXISTS xml_root_element_kind_rows (
	PRIMARY KEY (ref),		-- DO NOT DEFAULT THIS!
--	FOREIGN KEY(ref) REFERENCES xml_kind_keys, -- !!
	tag xml_tag_refs NOT NULL,
	attrs xml_attr_refs[] NOT NULL
) INHERITS(abstract_doc_node_kind_rows);
COMMENT ON TABLE xml_root_element_kind_rows IS '
XML root element - responsible for rendering document
namespaces on output.
';
-- COMMENT ON COLUMN xml_root_element_kind_rows.attrs IS
-- 'xml_attr_array_null(attrs) when no attributes';

SELECT declare_ref_class('xml_root_element_kind_rows');
SELECT declare_doc_kind_lang_type('xml_root_element_kind_rows', 'xml');

SELECT create_key_triggers_for(
	'xml_root_element_kind_rows', 'doc_node_kind_keys'
);

-- *** TABLE xml_text_kind_rows

CREATE TABLE IF NOT EXISTS xml_text_kind_rows (
	PRIMARY KEY (ref),
--	FOREIGN KEY(ref) REFERENCES xml_kind_keys,
	xml_text refs NOT NULL
) INHERITS(abstract_xml_leaf_kind_rows);
COMMENT ON TABLE xml_text_kind_rows IS
'XML text - from an XML viewpoint this is a text leaf.
The associated node must have NO children.
The xml_text should render as xml text.';

SELECT declare_ref_class('xml_text_kind_rows');
SELECT declare_doc_kind_lang_type('xml_text_kind_rows', 'xml');

ALTER TABLE xml_text_kind_rows ALTER COLUMN ref
	SET DEFAULT next_doc_node_kind( 'xml_text_kind_rows' );

SELECT create_key_triggers_for(
	'xml_text_kind_rows', 'doc_node_kind_keys'
);

-- *** TABLE xml_to_xml_text_kind_rows

CREATE TABLE IF NOT EXISTS xml_to_xml_text_kind_rows (
	PRIMARY KEY (ref),
--	FOREIGN KEY(ref) REFERENCES xml_kind_keys,
	to_xml_text refs NOT NULL
) INHERITS(abstract_xml_leaf_kind_rows);
COMMENT ON TABLE xml_to_xml_text_kind_rows IS
'XML text - from an XML viewpoint this is an xml text node leaf.
The associated node must have NO children.
The text must be converted to xml text.';

SELECT declare_ref_class('xml_to_xml_text_kind_rows');
SELECT declare_doc_kind_lang_type('xml_to_xml_text_kind_rows', 'xml');

ALTER TABLE xml_to_xml_text_kind_rows ALTER COLUMN ref
	SET DEFAULT next_doc_node_kind( 'xml_to_xml_text_kind_rows' );

SELECT create_key_triggers_for(
	'xml_to_xml_text_kind_rows', 'doc_node_kind_keys'
);

-- *** TABLE xml_proc_kind_rows

-- ** Two provisions for dynamic objects:

-- if we want this at all, we may need more than one
-- of them to indicate how we're going to pass any children!!

-- the function can only get information about the current context
-- through the env_ref and crefs arguments.

/*
-- How can we use method calls to automagically
-- call the specific proc_ through a ref?

CREATE TABLE IF NOT EXISTS xml_proc_kind_rows (
	PRIMARY KEY (ref),
	proc_ regprocedure NOT NULL UNIQUE
) INHERITS(abstract_xml_kind_rows);
COMMENT ON TABLE xml_proc_kind_rows IS
'the children are processed by proc_ to yield XML';
COMMENT ON COLUMN xml_proc_kind_rows.proc_ IS
'TEXT <proc>( ???, env_refs, crefs, ???)';

SELECT declare_ref_class('xml_proc_kind_rows');

ALTER TABLE xml_proc_kind_rows ALTER COLUMN ref
	SET DEFAULT next_doc_node_kind( 'xml_proc_kind_rows' );

SELECT create_key_triggers_for(
	'xml_proc_kind_rows', 'xml_kind_keys'
);
*/
