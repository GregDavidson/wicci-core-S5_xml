-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-import-schema.sql', '$Id');

--	Wicci Project code to import XML as a new document

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** helper functions for TYPE xml_id_node_pairs

CREATE OR REPLACE
FUNCTION show_xml_id_node_pair(xml_id_node_pairs)
RETURNS text AS $$
	SELECT ($1).id || '-->' || show_ref( ($1).node )
$$ LANGUAGE sql IMMUTABLE STRICT;

CREATE OR REPLACE
FUNCTION show_xml_id_node_pairs(xml_id_node_pairs[])
RETURNS text AS $$
	SELECT 'id_node_pairs:' || E'\n' || array_to_string( ARRAY(
		SELECT show_xml_id_node_pair(x) FROM unnest($1) x
	), '' )
$$ LANGUAGE sql IMMUTABLE STRICT;

CREATE OR REPLACE
FUNCTION try_xml_id_node_pair(id xml_id_name_refs, node doc_node_refs)
RETURNS xml_id_node_pairs AS $$
	SELECT ($1, $2)::xml_id_node_pairs
$$ LANGUAGE sql IMMUTABLE STRICT;

CREATE OR REPLACE
FUNCTION try_xml_id_node_pair(id text, node doc_node_refs)
RETURNS xml_id_node_pairs AS $$
	SELECT try_xml_id_node_pair(get_xml_id_name($1), $2)
	WHERE NOT $1 = ''
$$ LANGUAGE sql IMMUTABLE STRICT;

CREATE OR REPLACE
FUNCTION xml_id_node_pair(id xml_id_name_refs, node doc_node_refs)
RETURNS xml_id_node_pairs AS $$
	SELECT non_null(
		try_xml_id_node_pair($1,$2),
		'xml_id_node_pair(xml_id_name_refs,doc_node_refs)'
	)
$$ LANGUAGE sql IMMUTABLE;

-- ** helper functions for TYPE xml_prefix_uri_pairs

CREATE OR REPLACE
FUNCTION show_xml_prefix_uri_pair(xml_prefix_uri_pairs)
RETURNS text AS $$
	SELECT (($1).prefix)::text || '=' || show_ref( ($1).uri )
$$ LANGUAGE sql IMMUTABLE STRICT;

CREATE OR REPLACE
FUNCTION show_xml_prefix_uri_pairs(xml_prefix_uri_pairs[])
RETURNS text AS $$
	SELECT 'prefix_uri_pairs:' || E'\n' || array_to_string( ARRAY(
		SELECT show_xml_prefix_uri_pair(x) FROM unnest($1) x
	), E'\n' )
$$ LANGUAGE sql IMMUTABLE STRICT;

CREATE OR REPLACE
FUNCTION try_xml_prefix_uri_pair(xml_prefix_name_refs, page_uri_refs) 
RETURNS xml_prefix_uri_pairs AS $$
	SELECT ($1, $2)::xml_prefix_uri_pairs
	WHERE NOT is_nil($2)
$$ LANGUAGE sql IMMUTABLE STRICT;


CREATE OR REPLACE
FUNCTION xml_prefix_uri_pair(xml_prefix_name_refs, page_uri_refs)
RETURNS xml_prefix_uri_pairs AS $$
	SELECT non_null(
		try_xml_prefix_uri_pair($1,$2),
		'xml_prefix_uri_pair(xml_prefix_name_refs,page_uri_refs)'
	)
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE
FUNCTION try_xml_prefix_uri_pair(text, page_uri_refs) 
RETURNS xml_prefix_uri_pairs AS $$
	SELECT try_xml_prefix_uri_pair(get_xml_prefix_name($1), $2)
	WHERE NOT is_nil($2)
$$ LANGUAGE sql IMMUTABLE STRICT;

CREATE OR REPLACE
FUNCTION xml_prefix_uri_pair(text, page_uri_refs)
RETURNS xml_prefix_uri_pairs AS $$
	SELECT non_null(
		try_xml_prefix_uri_pair($1,$2),
		'xml_prefix_uri_pair(text,page_uri_refs)'
	)
$$ LANGUAGE sql IMMUTABLE;

-- * composite return types for xml tree construction

-- ** xml_attr

DROP TYPE IF EXISTS xml_attr_returns CASCADE;
CREATE TYPE xml_attr_returns AS (
	attr xml_attr_refs,
	ns_pair xml_prefix_uri_pairs
);

COMMENT ON TYPE xml_attr_returns IS
'The return type of FUNCTION xml_attr';

CREATE OR REPLACE FUNCTION xml_attr_return(
	xml_attr_refs, xml_prefix_name_refs, page_uri_refs
)  RETURNS xml_attr_returns AS $$
-- various checks could go here!!
	SELECT debug_return(
		'xml_attr_return(
			xml_attr_refs, xml_prefix_name_refs, page_uri_refs
		)',
		($1, try_xml_prefix_uri_pair($2,$3))::xml_attr_returns
	)
$$ LANGUAGE sql IMMUTABLE;

-- ** xml_kind

DROP TYPE IF EXISTS xml_kind_returns CASCADE;
CREATE TYPE xml_kind_returns AS (
	kind doc_node_kind_refs,
	ns_pairs xml_prefix_uri_pairs[],
	tag xml_tag_refs							-- for convenience
);

COMMENT ON TYPE xml_kind_returns IS
'The return type of FUNCTION xml_kind';

CREATE OR REPLACE FUNCTION try_xml_kind_return(
	kind doc_node_kind_refs,
	xml_prefix_uri_pairs[],
	xml_tag_refs = xml_tag_nil()
) RETURNS xml_kind_returns AS $$
-- various checks could go here!!
	SELECT (
		$1, $2, NULLIF( $3, xml_tag_nil() )
	)::xml_kind_returns
$$ LANGUAGE sql IMMUTABLE STRICT;

COMMENT ON FUNCTION try_xml_kind_return(
	kind doc_node_kind_refs, xml_prefix_uri_pairs[], xml_tag_refs
) IS 'Should check nil tag iff not an element  kind!!';

CREATE OR REPLACE FUNCTION xml_kind_return(
	kind doc_node_kind_refs,
	xml_prefix_uri_pairs[] = '{}',
	xml_tag_refs = xml_tag_nil()
)  RETURNS xml_kind_returns AS $$
	SELECT debug_return( this, non_null(
		try_xml_kind_return($1, $2, $3), this
	) ) FROM this('xml_kind_return(
		doc_node_kind_refs,xml_prefix_uri_pairs[],xml_tag_refs
	)')
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE FUNCTION xml_kind_return(
	kind doc_node_kind_refs, xml_prefix_uri_pairs,
	xml_tag_refs=xml_tag_nil()
)  RETURNS xml_kind_returns AS $$
	SELECT xml_kind_return($1, ARRAY[$2], $3)
$$ LANGUAGE sql IMMUTABLE;

-- ** xml_tree

DROP TYPE IF EXISTS xml_tree_returns CASCADE;
CREATE TYPE xml_tree_returns AS (
	node doc_node_refs,
	id_pairs xml_id_node_pairs[],
	ns_pairs xml_prefix_uri_pairs[]
);

COMMENT ON TYPE xml_tree_returns IS
'The return type of FUNCTION xml_tree';

CREATE OR REPLACE
FUNCTION show_xml_tree_return(xml_tree_returns)
RETURNS text AS $$
	SELECT 'xml_tree_return: ' || show_ref( ($1).node)
	|| show_xml_prefix_uri_pairs( ($1).ns_pairs )
	|| show_xml_id_node_pairs( ($1).id_pairs )
$$ LANGUAGE sql IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION try_xml_tree_return(
	node doc_node_refs,
	id_pairs xml_id_node_pairs[],
	ns_pairs xml_prefix_uri_pairs[]
)  RETURNS xml_tree_returns AS $$
	SELECT ($1, $2, $3)::xml_tree_returns
$$ LANGUAGE sql IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION xml_tree_return(
	node doc_node_refs,
	id_pairs xml_id_node_pairs[],
	ns_pairs xml_prefix_uri_pairs[]
) RETURNS xml_tree_returns AS $$
	SELECT debug_return(
		this, non_null( try_xml_tree_return($1,$2,$3), this )
	) FROM this('xml_tree_return(
		doc_node_refs,xml_id_node_pairs[],xml_prefix_uri_pairs[]
	)')
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE
FUNCTION xml_tree_returns_nodes(xml_tree_returns[])
RETURNS doc_node_refs[] AS $$
	SELECT ARRAY( SELECT (x).node FROM unnest($1) x )
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE
FUNCTION xml_tree_returns_ns_pairs(xml_tree_returns[])
RETURNS xml_prefix_uri_pairs[] AS $$
DECLARE
	tree_ret xml_tree_returns;
	pairs xml_prefix_uri_pairs[] := '{}';
	this regprocedure
		:= 'xml_tree_returns_ns_pairs(xml_tree_returns[])';
BEGIN
	IF $1 IS NULL THEN
		RAISE EXCEPTION '%: NULL tree returns!', this;
	END IF;
	FOREACH tree_ret IN ARRAY $1 LOOP
		IF tree_ret.ns_pairs IS NULL THEN
			RAISE EXCEPTION '%: NULL ns_pair list!', this;
		END IF;
    pairs := pairs || tree_ret.ns_pairs;
	END LOOP;
	RETURN pairs;
END
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION 
xml_tree_returns_ns_pairs(xml_tree_returns[])
IS 'How can this be done in sql??';

CREATE OR REPLACE
FUNCTION xml_tree_returns_id_pairs(xml_tree_returns[])
RETURNS xml_id_node_pairs[] AS $$
DECLARE
	tree_ret xml_tree_returns;
	pairs xml_id_node_pairs[] := '{}';
	pair xml_id_node_pairs;
	this regprocedure
		:= 'xml_tree_returns_id_pairs(xml_tree_returns[])';
BEGIN
	IF $1 IS NULL THEN
		RAISE EXCEPTION '%: NULL tree returns!', this;
	END IF;
	FOREACH tree_ret IN ARRAY $1 LOOP
		IF tree_ret.id_pairs IS NULL THEN
			RAISE EXCEPTION '%: NULL id_pair list!', this;
		END IF;
    pairs := pairs || tree_ret.id_pairs;
	END LOOP;
	FOREACH pair IN ARRAY pairs LOOP
		IF pair.id = '' THEN
			RAISE EXCEPTION '%: empty id on node %!',
				this, show_ref(doc_node_kind(pair.node));
		END IF;
	END LOOP;
	RETURN pairs;
END
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION 
xml_tree_returns_id_pairs(xml_tree_returns[])
IS 'How can this be done in sql??';
