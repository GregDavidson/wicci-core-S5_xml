-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-doc-schema.sql', '$Id');

--	Wicci Project XML/HTML Encoding Schema

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * doc_id_nodes

SELECT create_name_ref_schema('xml_id_name');
			-- add regexp check for valid xml id!!

CREATE TABLE IF NOT EXISTS xml_id_node_pairs (
	id xml_id_name_refs NOT NULL REFERENCES xml_id_name_rows
		CHECK(NOT is_nil(id)),
	node doc_node_refs NOT NULL
		REFERENCES tree_doc_node_rows
		CHECK(NOT is_nil(node))
);

SELECT declare_abstract('xml_id_node_pairs');

COMMENT ON TABLE xml_id_node_pairs IS
'A type to hold pairs which will eventually be added to
TABLE doc_id_nodes but declared as a table
so it can be used as an abstract base';

CREATE TABLE IF NOT EXISTS doc_id_nodes (
	doc doc_refs NOT NULL,
		CONSTRAINT doc_id_nodes__doc
		FOREIGN KEY(doc) REFERENCES tree_doc_rows
		ON DELETE CASCADE,
	UNIQUE(doc, id),
	UNIQUE(doc, node)
) INHERITS(xml_id_node_pairs);

COMMENT ON TABLE doc_id_nodes IS
'Records nodes in documents by their id and i attributes,
in order to
	(1) ensure uniqueness,
	(2) provide a handle-like mechanism for nodes in documents.
We cannot allow i/id attributes in graft nodes!!
Graft nodes must be considered to have the same i/id
attribute as their original node.
What about being able to add an i/id attribute through a graft??
Ans: Require the original to not have an i/id and add it there!!
Can we allow an i to become an id??
Ans: Why not??
';

-- * xml_lang_doctypes

/*

Obsoleted by wicci_lang_responses(lang, '_doctype', )

CREATE TABLE IF NOT EXISTS xml_lang_doctypes (
	lang doc_lang_name_refs
		PRIMARY KEY REFERENCES doc_lang_name_rows,
	type_ doc_node_kind_refs
		NOT NULL REFERENCES xml_literal_kind_rows
);

COMMENT ON TABLE xml_lang_doctypes IS
'When returning  a document of this language to a browser,
indicate that it is of this doctype';

COMMENT ON COLUMN xml_lang_doctypes.type_ IS
'A kind which renders into a legal value for an
http_response';

*/
