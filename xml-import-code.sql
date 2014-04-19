-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-import-code.sql', '$Id');

--	Wicci Project code to import XML as a new document

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** Updating XML Document Associated Tables

-- * doc_namespaces

CREATE OR REPLACE
FUNCTION ordered_xml_prefix_uri_set(xml_prefix_uri_pairs[])
RETURNS SETOF RECORD AS $$
	SELECT DISTINCT ON(x.uri) x.prefix, x.uri
	FROM unnest($1) x, xml_prefix_name_rows p
	WHERE x.prefix = p.ref
	ORDER BY x.uri, length(p.name_) DESC;
$$ LANGUAGE sql STRICT STABLE;

COMMENT ON FUNCTION 
ordered_xml_prefix_uri_set(xml_prefix_uri_pairs[])
IS 'Returns a set of xml_prefix_uri_pairs elements
ordered by the length of the prefix so that default
namespaces (prefix = '''') come before non-default';

CREATE OR REPLACE FUNCTION ordered_xml_prefix_uri_pairs(
	xml_prefix_uri_pairs[]
) RETURNS xml_prefix_uri_pairs[] AS $$
	SELECT ARRAY(
		SELECT xml_prefix_uri_pair(p, u)
		FROM ordered_xml_prefix_uri_set($1)
		AS (p xml_prefix_name_refs, u page_uri_refs)
	)
$$ LANGUAGE sql STRICT STABLE;

COMMENT ON FUNCTION 
ordered_xml_prefix_uri_pairs(xml_prefix_uri_pairs[])
IS 'Returns an array of xml_prefix_uri_pairs ordered by
the length of the prefix so that default namespaces
(prefix = '''') come before non-default';

CREATE OR REPLACE FUNCTION named_xml_default_uri_pairs(
	xml_prefix_uri_pairs[]
) RETURNS xml_prefix_uri_pairs[] AS $$
	SELECT ARRAY(
		SELECT xml_prefix_uri_pair(
			get_xml_prefix_name('_' || i::text), (pair).uri
		) FROM array_to_set($1)
			AS (i integer, pair xml_prefix_uri_pairs)
	)
$$ LANGUAGE sql STRICT STABLE;

COMMENT ON FUNCTION 
named_xml_default_uri_pairs(xml_prefix_uri_pairs[])
IS 'Given an array of default namespaces,
i.e. xml_prefix_uri_pairs where the prefixes are all
the empty string, return a new array of namespaces
where the prefixes have been filled in with names
_1, _2, etc.';

CREATE OR REPLACE
FUNCTION named_xml_prefix_uri_pairs( xml_prefix_uri_pairs[] )
RETURNS xml_prefix_uri_pairs[] AS $$
	SELECT
		named_xml_default_uri_pairs(ARRAY(
			SELECT x FROM unnest(all_pairs) x WHERE x.prefix = ''
		) ) || ARRAY(
			SELECT x FROM unnest(all_pairs) x WHERE x.prefix != ''
	)
	FROM ordered_xml_prefix_uri_pairs($1) all_pairs
$$ LANGUAGE sql STRICT;

COMMENT ON FUNCTION 
named_xml_prefix_uri_pairs(xml_prefix_uri_pairs[])
IS 'Given an array of namespaces, return a (possibly
reordered) array of the same values except with empty
prefixes (indicating default namespaces) filled in with
the names _1, _2, etc.';

CREATE OR REPLACE FUNCTION try_add_doc_namespaces(
	doc_refs, xml_prefix_uri_pairs[]
)  RETURNS doc_refs AS $$
	INSERT INTO doc_namespaces(doc, prefix, uri)
	SELECT $1, x.prefix, x.uri
	FROM unnest( named_xml_prefix_uri_pairs($2) ) x;
	SELECT $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE FUNCTION add_doc_namespaces(
	doc_refs, xml_prefix_uri_pairs[]
) RETURNS doc_refs AS $$
	SELECT non_null(
		try_add_doc_namespaces($1,$2),
		'add_doc_namespaces(doc_refs,xml_prefix_uri_pairs[])',
		show_ref($1), show_xml_prefix_uri_pairs($2)
	)
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION try_add_doc_id_nodes(
	doc_refs, xml_id_node_pairs[]
)  RETURNS doc_refs AS $$
	INSERT INTO doc_id_nodes(doc, id, node)
	SELECT $1, x.id, x.node FROM unnest( $2 ) x;
	SELECT $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE FUNCTION add_doc_id_nodes(
	doc_refs, xml_id_node_pairs[]
) RETURNS doc_refs AS $$
	SELECT non_null(
		try_add_doc_id_nodes($1,$2),
		'add_doc_id_nodes(doc_refs,xml_id_node_pairs[])'
	)
$$ LANGUAGE sql;

-- ** the next doc_ref

CREATE OR REPLACE
FUNCTION next_xml_doc() RETURNS doc_refs AS $$
	SELECT next_doc_ref('tree_doc_rows')
$$ LANGUAGE SQL;

-- ** figuring out the attributes

CREATE OR REPLACE FUNCTION xml_attr(
	_namespace text, _qname text, _value text
) RETURNS xml_attr_returns AS $$
	SELECT ( SELECT xml_attr_return(
		get_xml_attr(_uri, get_xml_attr_name(_name), $3),
		get_xml_prefix_name(_prefix), _uri
	) FROM get_page_uri($1) _uri
	) FROM xml_split_prefix_name($2) as foo(_prefix, _name)
$$ LANGUAGE sql;

COMMENT ON FUNCTION 
xml_attr(_namespace text, _name text, _value text) IS '
	We could also have the language passed in if needed.
';

-- ** figuring out the kinds

CREATE OR REPLACE FUNCTION try_get_xml_element_kind(
	doc_lang_name_refs, xml_tag_refs,
	xml_attr_refs[], root bool
)  RETURNS doc_node_kind_refs AS $$
	SELECT CASE WHEN $4
		THEN try_get_xml_root_element_kind($2, $3)
		ELSE try_get_xml_element_kind($2, $3)
	END
	WHERE array_has_no_nulls($3) AND ok_xml_tag_lang($2, $1)
$$ LANGUAGE sql STRICT;

COMMENT ON FUNCTION 
try_get_xml_element_kind(
	doc_lang_name_refs, xml_tag_refs, xml_attr_refs[], bool
) IS 'Do we care about the tag_lang, and if so, do we
want to require an exact match or simply a family match??';

CREATE OR REPLACE FUNCTION get_xml_element_kind(
	doc_lang_name_refs, xml_tag_refs, xml_attr_refs[],
	root bool
) RETURNS doc_node_kind_refs AS $$
	SELECT non_null(
		try_get_xml_element_kind($1,$2,$3, $4),
		'get_xml_element_kind(
			doc_lang_name_refs,xml_tag_refs,xml_attr_refs[], bool
		)'
	)
$$ LANGUAGE sql;

/*
CREATE OR REPLACE
FUNCTION try_xml_special_kind(text)
RETURNS doc_node_kind_refs AS $$
	SELECT _kind FROM try_dynamic_doc_node_kind($1) _kind
	-- WHERE _kind IS NOT NULL AND
	-- try_dynamic_kind_method( _kind, 'ref_env_crefs_chiln_text_op(
	-- 	refs, env_refs, crefs, doc_node_refs[]
	-- )' ) IS NOT NULL
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION xml_special_kind(doc_lang_name_refs, xml_attr_refs[], _kind refs)
RETURNS doc_node_kind_refs AS $$
	SELECT non_null(
		try_xml_special_kind( string_ ), 'xml_special_kind(
			doc_lang_name_refs, xml_attr_refs[], refs
		)', string_
	) FROM text_string_rows WHERE ref::refs = $3
$$ LANGUAGE sql;

COMMENT ON FUNCTION xml_special_kind(
	doc_lang_name_refs, xml_attr_refs[], _kind refs
) IS 'called on import to a meta element with
kind=_kind attribute';

CREATE OR REPLACE FUNCTION maybe_xml_special_kind(
	_namespace page_uri_refs, _prefix xml_prefix_name_refs,
	xml_tag_name_refs, xml_attr_refs[]
) RETURNS refs AS $$
	SELECT _kind FROM xml_attrs_search($4, 'kind') _kind
	WHERE is_nil($1) AND $2 = '' AND $3 = 'meta'
	AND NOT is_nil(_kind)
$$ LANGUAGE sql STRICT STABLE;

COMMENT ON FUNCTION maybe_xml_special_kind(
	_namespace page_uri_refs, _prefix xml_prefix_name_refs,
	xml_tag_name_refs, xml_attr_refs[]
) IS '
	Returns value of kind attribute if this node
	is a special kind node - currently must be a meta!!
';

CREATE OR REPLACE FUNCTION try_xml_special_kind(
	doc_lang_name_refs, xml_attr_refs[], _kind refs
) RETURNS xml_kind_returns AS $$
	SELECT xml_kind_return(
		xml_special_kind($1, $2, $3),
		'{}'::xml_prefix_uri_pairs[]
	)
$$ LANGUAGE sql STRICT;
*/

CREATE OR REPLACE FUNCTION try_xml_known_kind(
	doc_lang_name_refs, _ns page_uri_refs,
	_prefix xml_prefix_name_refs, xml_tag_name_refs,
	xml_attr_refs[], root bool
) RETURNS xml_kind_returns AS $$
	SELECT ( SELECT xml_kind_return(_kind, try_xml_prefix_uri_pair($3, $2), _tag)
		FROM try_get_xml_element_kind( $1, _tag, $5, $6 ) _kind
		WHERE _kind IS NOT NULL
	) FROM try_xml_ns_name_lang_tag($2, $4, $1) _tag
	WHERE _tag IS NOT NULL
$$ LANGUAGE sql STRICT STABLE;

COMMENT ON FUNCTION try_xml_known_kind(
	doc_lang_name_refs, _ns page_uri_refs,
	_prefix xml_prefix_name_refs, xml_tag_name_refs,
	xml_attr_refs[], bool
) IS '
	Return an xml kind for a tag known to this language.
	Since we do not check whether this tag is parrt of
	a schema (indicated by a non-null env in xml_tag_rows)
	this function is partially redundant with try_xml_tagged_kind.
';

CREATE OR REPLACE FUNCTION try_xml_tagged_kind_(
	doc_lang_name_refs, xml_tag_refs,
	xml_attr_refs[], xml_prefix_uri_pairs,
	root bool
) RETURNS xml_kind_returns AS $$
	SELECT debug_return( this, xml_kind_return(_kind, $4, $2) )
	FROM
		try_get_xml_element_kind($1, $2, $3, $5) _kind,
		debug_enter('try_xml_tagged_kind_(
			doc_lang_name_refs, xml_tag_refs,
			xml_attr_refs[], xml_prefix_uri_pairs, bool
		)', $4 ) this
	WHERE NOT is_nil(_kind) AND NOT is_nil($2)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE FUNCTION try_xml_tagged_kind(
	doc_lang_name_refs, _ns page_uri_refs,
	_prefix xml_prefix_name_refs, xml_tag_name_refs,
	xml_attr_refs[],
	root bool
) RETURNS xml_kind_returns AS $$
	SELECT try_xml_tagged_kind_(
		$1, try_get_xml_tag( $4, $2 ),
		$5, try_xml_prefix_uri_pair( $3, $2 ), $6
	) WHERE NOT is_nil($2)
$$ LANGUAGE sql STRICT;

COMMENT ON FUNCTION 
try_xml_tagged_kind(
	doc_lang_name_refs, page_uri_refs,
	xml_prefix_name_refs, xml_tag_name_refs, xml_attr_refs[], bool)
IS 'As a concession to expediency, this allows us
to internalize a namespace/tag which is not already
in a schema.  Such tags can be distinguished by the
lack of a corresponding entry in xml_tag_envs.';

CREATE OR REPLACE FUNCTION join_xml_prefix_uri_pairs(
	xml_prefix_uri_pairs[], xml_prefix_uri_pairs[]
)  RETURNS xml_prefix_uri_pairs[] AS $$
	SELECT array_non_nulls(
		COALESCE($1, '{}') || COALESCE($2, '{}')
	)
$$ LANGUAGE sql IMMUTABLE;

COMMENT ON FUNCTION join_xml_prefix_uri_pairs(
	xml_prefix_uri_pairs[], xml_prefix_uri_pairs[]
) IS 'Should not need this but we were getting the error:
ERROR:  22004: function returning set of rows cannot return null value
CONTEXT:  SQL function "array_non_nulls" statement 1
SQL function "try_get_xml_kind" statement 1
make[3]: *** [404.html-out] Error 3
';

CREATE OR REPLACE FUNCTION try_get_xml_kind(
	doc_lang_name_refs, _namespace text, _tag text,
	xml_attr_returns[], root bool
)  RETURNS xml_kind_returns AS $$
	SELECT ( SELECT xml_kind_return(
		(kind_ret).kind, join_xml_prefix_uri_pairs(
			(kind_ret).ns_pairs, ARRAY(
			SELECT (x).ns_pair FROM unnest($4) x
		) ), COALESCE( (kind_ret).tag, xml_tag_nil() )
	) FROM COALESCE(
		try_xml_known_kind($1, _ns, _prefix, _name, attrs, $5),
		try_xml_tagged_kind($1, _ns, _prefix, _name, attrs, $5),
		debug_assert(
			_this, false, NULL::xml_kind_returns,
			'lang', $1::text, 'namespace', $2, 'tag', $3,
			'prefix', _prefix::text, 'name', _name::text,
			'root', CASE $5 WHEN 'true' THEN 'true'::text ELSE 'false' END
		)
	) kind_ret
	) FROM
		get_page_uri($2) _ns,
		get_xml_split_tag($3) AS foo(_prefix, _name),
		COALESCE(ARRAY( SELECT (x).attr FROM unnest($4) x )) attrs,
		debug_enter('try_get_xml_kind(
			doc_lang_name_refs, text, text, xml_attr_returns[], bool
		)', $3, 'tag'
		) _this
$$ LANGUAGE sql STRICT;

COMMENT ON FUNCTION try_get_xml_kind(
	doc_lang_name_refs, _namespace text, _tag text,
	xml_attr_returns[], root bool
) IS 'feature of "root" argument not yet tested!!!';

CREATE OR REPLACE FUNCTION xml_kind(
	doc_lang_name_refs, _namespace text,
	_tag text, VARIADIC xml_attr_returns[] = '{}'
) RETURNS xml_kind_returns AS $$
	SELECT non_null(
		try_get_xml_kind($1, $2, $3, $4, false),
		'xml_kind(doc_lang_name_refs,text,text,xml_attr_returns[])',
		show_ref($1), $2 || ':', $3
	)
$$ LANGUAGE sql;

COMMENT ON FUNCTION xml_kind(
	doc_lang_name_refs, text, text, xml_attr_returns[]
) IS '
	Called by doc-to-sql code.
	Return a reference to a (possibly already existing) row
	representing the data (kind) of an XML tree node or graft
	with the given language, namespaces, tag name
	and XML attributes.  Recognize special kinds as a special
	case of <meta kind="..."> elements.
';

CREATE OR REPLACE FUNCTION xml_root_kind(
	doc_lang_name_refs, _namespace text,
	_tag text, VARIADIC xml_attr_returns[] = '{}'
) RETURNS xml_kind_returns AS $$
-- Will this suffice???
	SELECT non_null(
		try_get_xml_kind($1, $2, $3, $4, true),
		'xml_root_kind(doc_lang_name_refs,text,text,xml_attr_returns[])',
		show_ref($1), $2 || ':', $3
	)
$$ LANGUAGE sql;

-- ** doctype

CREATE OR REPLACE FUNCTION xml_doctype(
	doc_type citext, root_tag text
) RETURNS doc_lang_name_refs AS $$
		SELECT find_doc_lang_name($1)
$$ LANGUAGE sql;

COMMENT ON FUNCTION xml_doctype(doc_type citext, root_tag text) IS '
	Called by doc-to-sql code.
	At one time the 2nd argument was used to provide a
	default or a disambiguation if the 1st was missing or
	ambiguous but no longer.  It might be desirable to check the
	2nd argument for compatibility with the 1st.
';

-- ** nodes and kinds

CREATE OR REPLACE FUNCTION try_new_xml_id_kind_tree(
	_id xml_id_name_refs, xml_kind_returns,
	xml_tree_returns[] = '{}'
) RETURNS xml_tree_returns AS $$
	SELECT xml_tree_return(
		new_node,
		CASE WHEN $1 = '' THEN id_pairs
		ELSE xml_id_node_pair($1, new_node) || id_pairs END,
		($2).ns_pairs || ns_pairs
	) FROM new_xml_tree_node(
		($2).kind, VARIADIC xml_tree_returns_nodes($3)
	) new_node,
	xml_tree_returns_ns_pairs($3) ns_pairs,
	xml_tree_returns_id_pairs($3) id_pairs
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE FUNCTION new_xml_id_kind_tree(
	regprocedure, text, xml_kind_returns,
	xml_tree_returns[] = '{}'
) RETURNS xml_tree_returns AS $$
	SELECT non_null(
		try_new_xml_id_kind_tree(get_xml_id_name($2),$3,$4),
		$1, 'id', $2, 'kind',
		ref_env_crefs_chiln_text_op(($3).kind, env_nil(), crefs_nil(), '{}')
	)
$$ LANGUAGE sql;

-- ** building the tree

CREATE OR REPLACE FUNCTION xml_meta(text)
RETURNS xml_tree_returns AS $$
	SELECT new_xml_id_kind_tree(
		this, '', xml_kind_return( find_dynamic_doc_node_kind($1) )
	) FROM  debug_enter('xml_meta(text)', $1) this
$$ LANGUAGE sql IMMUTABLE;

COMMENT ON FUNCTION xml_meta(text)
IS 'Returns a tree node that wraps a function
which will generate that node''s value dynamically
when the tree is sent to the client.  Right now
such nodes are not equipped with ids; see the
code in doc-to-sql.xsl to rectify this!!';

CREATE OR REPLACE FUNCTION xml_tree(
	_id text, xml_kind_returns,
	VARIADIC xml_tree_returns[] = '{}'
) RETURNS xml_tree_returns AS $$
	SELECT new_xml_id_kind_tree( this, $1, $2, CASE ($2).tag
		WHEN html_tag('head') THEN
			$3 || xml_meta('html_head_extra')
		WHEN html_tag('body') THEN
			xml_meta('html_body_top') || $3 || xml_meta('html_body_extra')
		ELSE $3
	END ) FROM debug_enter(
		'xml_tree(text, xml_kind_returns,xml_tree_returns[])',
		show_ref(($2).kind), 'node kind'
	) this
$$ LANGUAGE sql;

COMMENT ON FUNCTION xml_tree(
	text, xml_kind_returns, xml_tree_returns[]
) IS '
	Called by doc-to-sql code.
	Construct a new tree node for the given document reference,
	inside the given namespace scope, with optional id attribute,
	given node data (kind) and given children.
	Rename to new_xml_tree??
';

CREATE OR REPLACE
FUNCTION xml_leaf(_id text, _value text)
RETURNS xml_tree_returns AS $$
	SELECT new_xml_id_kind_tree(
		this, $1, xml_kind_return( get_xml_text_kind( get_xml_text($2) ) )
	) FROM debug_enter( 'xml_leaf(text, text)', $1, $2 ) this
$$ LANGUAGE sql;

COMMENT ON FUNCTION xml_leaf(_id text, _value text)
IS 'Called by doc-to-sql code to import a text node; rename??';

-- * finding or creating the doc & doc_page

CREATE OR REPLACE FUNCTION doc_page_from_uri_lang(
	page_uri_refs, doc_lang_name_refs
) RETURNS doc_page_refs AS $$
	SELECT page.ref FROM
		doc_page_rows page, doc_keys doc,
		debug_enter(
			'doc_page_from_uri_lang(page_uri_refs, doc_lang_name_refs)',
			show_ref($1, 'page_uri'), show_ref($2, 'doc_lang')
		) this
	WHERE page.uri = $1 AND page.doc = doc.key
	AND debug_assert(
		this, COALESCE(try_doc_lang_name(doc.key) = $2, true),
		true, show_ref($1), show_ref($2)
	)
$$ LANGUAGE sql STRICT;

SELECT debug_on(
'doc_page_from_uri_lang(page_uri_refs, doc_lang_name_refs)', true
);

COMMENT ON FUNCTION doc_page_from_uri_lang(
	page_uri_refs, doc_lang_name_refs
) IS 'Called by doc-to-sql code.';

CREATE OR REPLACE FUNCTION try_doc_page_from_uri_lang_root(
	page_uri_refs, doc_lang_name_refs, xml_tree_returns
) RETURNS doc_page_refs AS $$
	SELECT get_doc_page(
		$1, 
		add_doc_id_nodes(
			add_doc_namespaces(
				new_tree_doc( ($3).node, $2 ),
				($3).ns_pairs
			),
			($3).id_pairs
		)
	) FROM raise_debug_show('try_doc_page_from_uri_lang_root(
		page_uri_refs, doc_lang_name_refs, xml_tree_returns
	)', show_ref($1), show_ref($2), show_xml_tree_return($3) )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE FUNCTION doc_page_from_uri_lang_root(
	page_uri_refs, doc_lang_name_refs, xml_tree_returns
) RETURNS doc_page_refs AS $$
	SELECT non_null(
		try_doc_page_from_uri_lang_root($1,$2,$3),
		'doc_page_from_uri_lang_root(
			page_uri_refs,doc_lang_name_refs,xml_tree_returns
		)', 'uri', show_ref($1)
	)
$$ LANGUAGE sql;

COMMENT ON FUNCTION doc_page_from_uri_lang_root(
	page_uri_refs, doc_lang_name_refs, xml_tree_returns
) IS 'Called by doc-to-sql code.';


-- * old tag API

-- ** kludge:  !!!

CREATE OR REPLACE FUNCTION xml_tag(
	page_uri_refs, xml_tag_name_refs, doc_lang_name_refs
) RETURNS xml_tag_refs AS $$
	SELECT get_xml_tag($2, $1)
$$ LANGUAGE sql;

COMMENT ON FUNCTION 
xml_tag(page_uri_refs, xml_tag_name_refs, doc_lang_name_refs)
IS 'For import; lang argument obsolete!!';

-- * specialization for html

CREATE OR REPLACE FUNCTION html_kind(
	xml_tag_name_refs, VARIADIC xml_attr_returns[]='{}'
) RETURNS doc_node_kind_refs AS $$
	SELECT non_null( ( try_xml_known_kind(
		'html', page_uri_nil(), '', $1,
		ARRAY(SELECT (x).attr FROM unnest($2) x),
		false
	) ).kind, 'html_kind(xml_tag_name_refs, xml_attr_returns[])' )
$$ LANGUAGE sql;
