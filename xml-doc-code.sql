-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-doc-code.sql', '$Id');

--	Wicci Project XML/HTML Encoding Schema
--	type xml_doc support code

-- ** Copyright

--	Copyright (c) 2011, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * doc_id_nodes

CREATE OR REPLACE
FUNCTION try_doc_ref_node(doc_refs, xml_id_name_refs)  
RETURNS doc_node_refs AS $$
	SELECT node FROM doc_id_nodes
	WHERE doc = $1 AND id = $2
$$ LANGUAGE SQL STRICT STABLE;

CREATE OR REPLACE
FUNCTION doc_ref_node(doc_refs, xml_id_name_refs) 
RETURNS doc_node_refs AS $$
	SELECT non_null(
		try_doc_ref_node($1,$2), 'doc_ref_node(doc_refs,xml_id_name_refs)'
	)
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE
FUNCTION try_doc_id_node(doc_refs, text)  
RETURNS doc_node_refs AS $$
	SELECT try_doc_ref_node($1, try_xml_id_name($2))
$$ LANGUAGE SQL STRICT STABLE;

CREATE OR REPLACE
FUNCTION doc_id_node(doc_refs, text) 
RETURNS doc_node_refs AS $$
	SELECT non_null(
		try_doc_id_node($1,$2), 'doc_id_node(doc_refs,text)', $2
	)
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE
FUNCTION try_page_id_node(page_uri_refs, text)  
RETURNS doc_node_refs AS $$
	SELECT try_doc_id_node(try_page_doc($1), $2)
$$ LANGUAGE SQL STRICT STABLE;

CREATE OR REPLACE
FUNCTION page_id_node(page_uri_refs, text) 
RETURNS doc_node_refs AS $$
	SELECT non_null(
		try_page_id_node($1,$2),
		'page_id_node(page_uri_refs,text)', $2
	)
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE
FUNCTION try_get_doc_id_node(doc_refs, xml_id_name_refs, doc_node_refs) 
RETURNS doc_node_refs AS $$
DECLARE
	maybe doc_node_refs;
	kilroy_was_here boolean := false;
	this regprocedure :=
		'try_get_doc_id_node(doc_refs, xml_id_name_refs, doc_node_refs)';
BEGIN
	LOOP
		SELECT node INTO maybe FROM doc_id_nodes
		WHERE doc = $1 AND id = $2;
		IF FOUND THEN
			IF maybe IS NOT DISTINCT FROM $3 THEN RETURN maybe; END IF;
			RAISE NOTICE  '% % % % != %', this, $1, $2, $3, maybe;
			RETURN NULL;
		END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with % % %', this, $1, $2, $3;
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO doc_id_nodes(doc,id,node) VALUES($1,$2,$3);
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % % % raised %!',
					this, $1, $2, $3, 'unique_violation';
		END;	
	END LOOP;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION get_doc_id_node(doc_refs, xml_id_name_refs, doc_node_refs)
RETURNS doc_node_refs AS $$
	SELECT non_null(
		try_get_doc_id_node($1,$2,$3),
		'get_doc_id_node(doc_refs,xml_id_name_refs,doc_node_refs)'
	)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION try_get_doc_id_node(doc_refs, text, doc_node_refs)
RETURNS doc_node_refs AS $$
	SELECT try_get_doc_id_node($1, get_xml_id_name($2), $3)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION get_doc_id_node(doc_refs, text, doc_node_refs)
RETURNS doc_node_refs AS $$
	SELECT get_doc_id_node($1, get_xml_id_name($2), $3)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION try_get_page_id_node(page_uri_refs, text, doc_node_refs)
RETURNS doc_node_refs AS $$
	SELECT try_get_doc_id_node(try_page_doc($1), get_xml_id_name($2), $3)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION try_get_page_id_node(page_uri_refs, text, doc_node_refs)
RETURNS doc_node_refs AS $$
	SELECT try_get_doc_id_node(find_page_doc($1), get_xml_id_name($2), $3)
$$ LANGUAGE sql;
