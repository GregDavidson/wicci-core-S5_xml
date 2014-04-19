-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-node-code.sql', '$Id');

--	Wicci Project XML/HTML Encoding Schema
--	type ref_xml support code

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * xml_trees and xml_grafts convenience functions

CREATE OR REPLACE
FUNCTION no_xml_node_array() RETURNS doc_node_refs[] AS $$
	SELECT '{}'::doc_node_refs[]
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION no_xml_child_nodes() RETURNS doc_node_refs[] AS $$
	SELECT no_xml_node_array()
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION no_xml_sibling_nodes() RETURNS doc_node_refs[] AS $$
	SELECT no_xml_node_array()
$$ LANGUAGE SQL;

-- Move this to the associated table definition!!!
SELECT declare_name('xml', 'div', 'span', 'cdata');

CREATE OR REPLACE FUNCTION xml_parent_chiln_types_valid(
	parent_type name_refs, max_child_type name_refs
) RETURNS boolean AS $$
	SELECT CASE $1
		WHEN 'xml'::name_refs THEN true
		WHEN 'div'::name_refs THEN $2 != 'xml'::name_refs
		WHEN 'span'::name_refs THEN
			($2 = 'span'::name_refs OR  $2 = 'cdata'::name_refs)
		WHEN 'cdata'::name_refs THEN $2 = 'cdata'::name_refs
		ELSE case_failed_any_ref(
			'xml_parent_chiln_types_valid(name_refs, name_refs)',
			false, $1
		)
	END
$$ LANGUAGE sql;
COMMENT ON
FUNCTION xml_parent_chiln_types_valid(name_refs, name_refs)
IS 'determines if children are compatible with this kind of node';

CREATE OR REPLACE
FUNCTION xml_max_kind_type(doc_node_refs[])
RETURNS name_refs AS $$
DECLARE
	kinds doc_node_kind_refs[] := xml_node_kinds($1);
	ret_kind name_refs := 'cdata';
	k doc_node_kind_refs;
BEGIN
	FOREACH k IN ARRAY kinds LOOP
		CASE ref_type(k)
			WHEN 'doc_node_kind_refs'::regtype THEN RETURN 'xml';
			WHEN 'div_kind_refs'::regtype THEN
				ret_kind := 'div_kind_refs'::regtype;
			WHEN 'span_kind_refs'::regtype THEN
				IF ret_kind != 'div_kind_refs'::regtype THEN
					ret_kind := 'span_kind_refs'::regtype;
				END IF;
			ELSE
					RETURN case_failed_any_ref(
						'xml_max_kind_type(doc_node_refs[])',
--						unchecked_ref_null()::name_refs, $1
						NULL::name_refs, $1
					);
		END CASE;
	END LOOP;
	RETURN ret_kind;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION xml_max_kind_type(doc_node_refs[])
IS 'returns most general kind type of these nodes';

CREATE OR REPLACE FUNCTION xml_kind_chiln_valid(
	kind doc_node_kind_refs, chiln doc_node_refs[]
) RETURNS boolean AS $$
	SELECT true										-- !!!
$$ LANGUAGE sql;
COMMENT ON FUNCTION xml_kind_chiln_valid(
	kind doc_node_kind_refs, chiln doc_node_refs[]
) IS 'determines if children are compatible with this kind of node!!!';

-- now a bunch of convenience functions
-- for special cases of xml_root, xml_tree, and xml_leaf

-- * graft_doc_node_rows -> xml_doc_refs convenience functions

CREATE OR REPLACE FUNCTION xml_graft(
	doc_node_refs,
	kind doc_node_kind_refs,
	VARIADIC chiln doc_node_refs[] = no_xml_child_nodes()
) RETURNS doc_node_refs AS $$
	SELECT graft_node($1, $2, VARIADIC $3)
	WHERE xml_kind_chiln_valid($2, $3) -- or assert???
$$ LANGUAGE sql;
COMMENT ON FUNCTION
xml_graft(doc_node_refs, doc_node_kind_refs, doc_node_refs[])
IS 'returns a xml_graft to replace a xml_nonde';

-- * class xml_tree

--  new_tree_node(kind, children)
CREATE OR REPLACE FUNCTION new_xml_tree_node(
	doc_node_kind_refs,
	VARIADIC doc_node_refs[] = no_xml_child_nodes()
) RETURNS doc_node_refs AS $$
	SELECT new_tree_node($1, VARIADIC $2)
	WHERE xml_kind_chiln_valid($1, $2) -- or assert???
$$ LANGUAGE sql;
COMMENT ON FUNCTION
new_xml_tree_node(doc_node_kind_refs, doc_node_refs[]) IS
'Creates new tree_doc_node_rows row, of an xml kind.';
