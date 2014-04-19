-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-node-schema.sql', '$Id');

--	Wicci Project XML/HTML Encoding Schema
--	XML Document Nodes

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

SELECT create_key_delete_trigger_for(
	'tree_doc_node_rows', 'doc_node_keys'
);

SELECT create_key_delete_trigger_for(
 'graft_doc_node_rows', 'doc_node_keys'
);
