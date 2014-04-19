-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-types.sql', '$Id');

--	Wicci Project XML/HTML Encoding Schema
--	Support for all the XML types & classes

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * doc namespaces

SELECT create_name_ref_schema('xml_prefix_name');
COMMENT ON TYPE xml_prefix_name_refs IS '
	overkill??
	add regexp check for valid xml prefix!!
';

SELECT create_env_name_type_func( -- unused!!!
	'env_namespace_prefix', 'xml_prefix_name_refs'
);

SELECT create_env_name_type_func(
	'env_namespace_uri', 'page_uri_refs'
);

CREATE TABLE IF NOT EXISTS xml_prefix_uri_pairs (
	prefix xml_prefix_name_refs NOT NULL
		REFERENCES xml_prefix_name_rows,
	uri page_uri_refs NOT NULL REFERENCES page_uri_rows
		CHECK(NOT is_nil(uri))
);
SELECT declare_abstract('xml_prefix_uri_pairs');

COMMENT ON TABLE xml_prefix_uri_pairs IS
'A type to hold pairs which will eventually be added to
TABLE doc_namespaces but declared as a table
so it can be used as an abstract base';

CREATE TABLE IF NOT EXISTS doc_namespaces (
	doc doc_refs NOT NULL REFERENCES tree_doc_rows
		ON DELETE CASCADE,
	UNIQUE(doc, uri),							-- where do I ensure this???
	UNIQUE(doc, prefix)						-- xml standard requires!
) INHERITS(xml_prefix_uri_pairs);

COMMENT ON TABLE doc_namespaces IS
'Records namespaces associated with a specific document.
I will simplify things by:
- making up a unique real prefix for any default namespaces.
	(except maybe 1 for the root element - code suggestion!)
- ensuring all prefixes unique in the document (xml requirement)
- putting all namespaces on the root node at output time
';
