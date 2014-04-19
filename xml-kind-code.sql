-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-kind-code.sql', '$Id');

--	Wicci Project XML/HTML Encoding Schema
--	type xml_kind_refs code

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * TYPE xml_kind_refs TABLE abstract_xml_kind_rows

-- * miscellaneous support functions
CREATE OR REPLACE
FUNCTION xml_children_text(doc_node_refs[], env_refs, crefs)
RETURNS text AS $$
	SELECT xml_literal_text( ARRAY(
			SELECT ref_env_crefs_text_op(child, $2, $3)
			FROM unnest($1) child -- or rlist ??
	), xml_nl($2, $3) )
$$ LANGUAGE sql;
COMMENT ON
FUNCTION xml_children_text(doc_node_refs[], env_refs, crefs)
IS 'produces the child elements in proper order - see
new_xml_tree_node(); the children are really to be
regarded as xml, not refs';

-- * TABLE xml_literal_kind_rows

CREATE OR REPLACE FUNCTION xml_kind_text(
	doc_node_kind_refs, env_refs = env_nil(), crefs = crefs_nil()
) RETURNS text AS $$
	SELECT ref_env_crefs_chiln_text_op($1, $2, $3, '{}'::doc_node_refs[])
$$ LANGUAGE sql;
COMMENT ON FUNCTION xml_kind_text(doc_node_kind_refs, env_refs, crefs) IS
'Is this useful for anything other than testing?';

CREATE OR REPLACE FUNCTION xml_literal_kind_text(
	doc_node_kind_refs, env_refs, crefs, doc_node_refs[]
) RETURNS text AS $$
	SELECT  	ref_env_crefs_text_op(literal, $2, $3)
	||  	xml_children_text($4, $2, $3)
	FROM xml_literal_kind_rows WHERE ref = $1
$$ LANGUAGE sql;

SELECT  type_class_op_method(
	'doc_node_kind_refs', 'xml_literal_kind_rows',
	'ref_env_crefs_chiln_text_op(refs, env_refs, crefs, doc_node_refs[])',
	'xml_literal_kind_text(doc_node_kind_refs, env_refs, crefs, doc_node_refs[])'
);

-- -- find_xml_literal_kind(literal refs) -> xml_kind_refs
CREATE OR REPLACE
FUNCTION find_xml_literal_kind(refs) RETURNS doc_node_kind_refs AS $$
	SELECT ref FROM xml_literal_kind_rows WHERE literal = $1
$$ LANGUAGE sql;

-- +++ make_xml_literal_kind(literal refs) -> xml_kind_refs
CREATE OR REPLACE
FUNCTION make_xml_literal_kind(refs) RETURNS doc_node_kind_refs AS $$
DECLARE
	_ref doc_node_kind_refs := NULL; -- unchecked_ref_null();
	kilroy_was_here boolean := false;
	this regprocedure := 'make_xml_literal_kind(refs)';
BEGIN LOOP
		SELECT ref INTO _ref FROM xml_literal_kind_rows WHERE literal = $1;
		IF FOUND THEN RETURN _ref; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with %', this, $1;
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO xml_literal_kind_rows(literal) VALUES($1);
		EXCEPTION
				WHEN unique_violation THEN			-- another thread??
					RAISE NOTICE '% % raised %!', this, $1, 'unique_violation';
		END;
END LOOP; END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION make_xml_literal_kind(refs) IS
'return unique ref associated with argument, creating it if necessary';

-- -- xml_literal_kind(literal refs) -> xml_kind_refs
CREATE OR REPLACE
FUNCTION xml_literal_kind(refs) RETURNS doc_node_kind_refs AS $$
	SELECT COALESCE(
		find_xml_literal_kind($1),
		make_xml_literal_kind($1)
	)
$$ LANGUAGE sql;

-- * xml_element_kind

CREATE OR REPLACE FUNCTION xml_element_text(
	xml_tag_refs, xml_attr_refs[], env_refs, crefs, doc_node_refs[]
) RETURNS text AS $$
	SELECT (SELECT CASE
		WHEN array_is_empty($5) THEN
			xml_tag_attrs(
				tag_text, xml_attrs_text($2, $3, $4),
				_nl, no_close OR long_close
			) || CASE WHEN long_close
			THEN xml_close(tag_text, _nl) ELSE ''
			END
		ELSE
			xml_tag_attrs_body(
				tag_text, xml_attrs_text($2, $3, $4),
				xml_children_text($5, $3, $4), _nl, no_close
		)
	END FROM
		xml_nl($3,$4) _nl,
		xml_tag_text($1, $3, $4) tag_text,
		is_html_no_close_tag($1, _lang) no_close,
		is_xhtml_long_close_tag($1, _lang) long_close
	) FROM try_env_doc_lang($3) _lang
$$ LANGUAGE SQL;

/*
CREATE OR REPLACE FUNCTION xml_body_wrap(
	doc_node_kind_refs,
	env_refs=env_nil(), crefs=crefs_nil(), doc_node_refs[]='{}'
) RETURNS text AS $$
	SELECT xml_element_text(tag, attrs, $2, $3, $4)
	FROM xml_element_kind_rows WHERE ref = $1
$$ LANGUAGE SQL;
*/

CREATE OR REPLACE FUNCTION xml_element_kind_text(
	doc_node_kind_refs,
	env_refs=env_nil(), crefs=crefs_nil(), doc_node_refs[]='{}'
) RETURNS text AS $$
	SELECT xml_element_text(tag, attrs, $2, $3, $4)
	FROM xml_element_kind_rows WHERE ref = $1
$$ LANGUAGE SQL;

SELECT  type_class_op_method(
	'doc_node_kind_refs', 'xml_element_kind_rows',
	'ref_env_crefs_chiln_text_op(refs, env_refs, crefs, doc_node_refs[])',
	'xml_element_kind_text(doc_node_kind_refs, env_refs, crefs, doc_node_refs[])'
);

-- old comment -- upgradable???
-- For the future:
-- o Maybe the xml_attr_rows of an element_kind should be the fixed ones,
--   and then additional ones can be supplied by the context?
-- o Or Maybe values of SOME of the xml_attr_rows can be changed.
-- o Or a mixture, with defaults, a special case for id, etc.

CREATE OR REPLACE
FUNCTION try_xml_element_kind(xml_tag_refs, xml_attr_refs[]='{}') 
RETURNS doc_node_kind_refs AS $$
	Select ref FROM xml_element_kind_rows
	WHERE $1 = tag AND $2 = attrs
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION xml_element_kind(xml_tag_refs, xml_attr_refs[]='{}')
RETURNS doc_node_kind_refs AS $$
	SELECT non_null(
		try_xml_element_kind($1,$2),
		'xml_element_kind(xml_tag_refs,xml_attr_refs[])'
	)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION try_xml_element_tag(doc_node_kind_refs)
RETURNS xml_tag_refs AS $$
	SELECT tag FROM xml_element_kind_rows WHERE ref = $1
$$ LANGUAGE sql;

-- --- make_xml_element_kind(tag, xml_attr_list) -> xml_kind_refs
CREATE OR REPLACE
FUNCTION try_make_xml_element_kind(xml_tag_refs, xml_attr_refs[]) 
RETURNS doc_node_kind_refs AS $$
DECLARE
	_ref doc_node_kind_refs := NULL; -- unchecked_ref_null();
	kilroy_was_here boolean := false;
	this regprocedure
		:= 'make_xml_element_kind(xml_tag_refs, xml_attr_refs[])';
BEGIN
	LOOP
		SELECT ref INTO _ref FROM xml_element_kind_rows
			WHERE tag = $1 AND attrs = $2;
		IF FOUND THEN RETURN _ref; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with % %', this, $1, $2;
		END IF;
		kilroy_was_here := true;
		DECLARE
			_kind doc_node_kind_refs
				:= next_doc_node_kind('xml_element_kind_rows');
		BEGIN
			INSERT INTO xml_element_kind_rows(ref, tag, attrs)
			VALUES(_kind, $1, $2);
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % % raised %!',
					this, $1, $2, 'unique_violation';
			WHEN OTHERS THEN
				RAISE NOTICE '%: tag % attrs % kind %', this, $1, $2, _kind;
				RAISE;
		END;
	END LOOP;
END;
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION make_xml_element_kind(xml_tag_refs, xml_attr_refs[])
RETURNS doc_node_kind_refs AS $$
	SELECT non_null(
		try_make_xml_element_kind($1,$2),
		'make_xml_element_kind(xml_tag_refs,xml_attr_refs[])'
	)
$$ LANGUAGE sql;

-- --- get_xml_element_kind(tag, attrs) -> xml_kind_refs
CREATE OR REPLACE FUNCTION try_get_xml_element_kind(
	xml_tag_refs, xml_attr_refs[]='{}'
) RETURNS doc_node_kind_refs AS $$
	SELECT COALESCE(
		try_xml_element_kind($1, $2),
		try_make_xml_element_kind($1, $2)
	)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE FUNCTION get_xml_element_kind(
	xml_tag_refs, xml_attr_refs[]='{}'
) RETURNS doc_node_kind_refs AS $$
	SELECT non_null(
		try_get_xml_element_kind($1,$2),
		'get_xml_element_kind(xml_tag_refs,xml_attr_refs[])'
	)
$$ LANGUAGE sql;

-- * xml_root_element_kind

CREATE OR REPLACE FUNCTION xml_root_element_text(
	xml_tag_refs, xml_attr_refs[], env_refs, crefs, doc_node_refs[]
) RETURNS text AS $$
	SELECT ( SELECT xml_open(tag_text) || COALESCE(
		try_xml_doc_namespaces_text(try_env_doc($3)), ''
	) || xml_attrs_text($2, $3, $4) || CASE
		WHEN array_is_empty($5)
		THEN xml_close(_nl, no_close OR long_close)
		ELSE '>' || xml_nl(_nl) || xml_children_text($5, $3, $4)
		|| xml_close(tag_text, _nl, no_close)
	END FROM
		xml_nl($3,$4) _nl,
		xml_tag_text($1, $3, $4) tag_text,
		is_html_no_close_tag($1, _lang) no_close,
		is_xhtml_long_close_tag($1, _lang) long_close
	) FROM try_env_doc_lang($3) _lang
$$ LANGUAGE SQL;

COMMENT ON FUNCTION xml_root_element_text(
	xml_tag_refs, xml_attr_refs[], env_refs, crefs, doc_node_refs[]
) IS 'Could be merged with xml_element_text above';

CREATE OR REPLACE FUNCTION xml_root_element_kind_text(
	doc_node_kind_refs,
	env_refs=env_nil(), crefs=crefs_nil(), doc_node_refs[]='{}'
) RETURNS text AS $$
	SELECT xml_root_element_text(tag, attrs, $2, $3, $4)
	FROM xml_root_element_kind_rows WHERE ref = $1
$$ LANGUAGE SQL;

SELECT  type_class_op_method(
	'doc_node_kind_refs', 'xml_root_element_kind_rows',
	'ref_env_crefs_chiln_text_op(refs, env_refs, crefs, doc_node_refs[])',
	'xml_root_element_kind_text(doc_node_kind_refs, env_refs, crefs, doc_node_refs[])'
);

CREATE OR REPLACE
FUNCTION try_xml_root_element_kind(xml_tag_refs, xml_attr_refs[]='{}') 
RETURNS doc_node_kind_refs AS $$
	Select ref FROM xml_root_element_kind_rows
	WHERE $1 = tag AND $2 = attrs
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION xml_root_element_kind(xml_tag_refs, xml_attr_refs[]='{}')
RETURNS doc_node_kind_refs AS $$
	SELECT non_null(
		try_xml_root_element_kind($1,$2),
		'xml_root_element_kind(xml_tag_refs,xml_attr_refs[])'
	)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION try_xml_root_tag(doc_node_kind_refs)
RETURNS xml_tag_refs AS $$
	SELECT tag FROM xml_root_element_kind_rows WHERE ref = $1
$$ LANGUAGE sql;

-- --- make_xml_root_element_kind(tag, xml_attr_list) -> xml_kind_refs
CREATE OR REPLACE
FUNCTION try_make_xml_root_element_kind(xml_tag_refs, xml_attr_refs[]) 
RETURNS doc_node_kind_refs AS $$
DECLARE
	_ref doc_node_kind_refs := NULL; -- unchecked_ref_null();
	kilroy_was_here boolean := false;
	this regprocedure
		:= 'make_xml_root_element_kind(xml_tag_refs, xml_attr_refs[])';
BEGIN
	LOOP
		SELECT ref INTO _ref FROM xml_root_element_kind_rows
			WHERE tag = $1 AND attrs = $2;
		IF FOUND THEN RETURN _ref; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with % %', this, $1, $2;
		END IF;
		kilroy_was_here := true;
		DECLARE
			_kind doc_node_kind_refs
				:= next_doc_node_kind('xml_root_element_kind_rows');
		BEGIN
			INSERT INTO xml_root_element_kind_rows(ref, tag, attrs)
			VALUES(_kind, $1, $2);
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % % raised %!',
					this, $1, $2, 'unique_violation';
			WHEN OTHERS THEN
				RAISE NOTICE '%: tag % attrs % kind %', this, $1, $2, _kind;
				RAISE;
		END;
	END LOOP;
END;
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION make_xml_root_element_kind(xml_tag_refs, xml_attr_refs[])
RETURNS doc_node_kind_refs AS $$
	SELECT non_null(
		try_make_xml_root_element_kind($1,$2),
		'make_xml_root_element_kind(xml_tag_refs,xml_attr_refs[])'
	)
$$ LANGUAGE sql;

-- --- get_xml_root_element_kind(tag, attrs) -> xml_kind_refs
CREATE OR REPLACE FUNCTION try_get_xml_root_element_kind(
	xml_tag_refs, xml_attr_refs[]='{}'
) RETURNS doc_node_kind_refs AS $$
	SELECT COALESCE(
		try_xml_root_element_kind($1, $2),
		try_make_xml_root_element_kind($1, $2)
	)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE FUNCTION get_xml_root_element_kind(
	xml_tag_refs, xml_attr_refs[]='{}'
) RETURNS doc_node_kind_refs AS $$
	SELECT non_null(
		try_get_xml_root_element_kind($1,$2),
		'get_xml_root_element_kind(xml_tag_refs,xml_attr_refs[])'
	)
$$ LANGUAGE sql;

-- * xml_text_kind_rows

-- -- find_xml_text_kind(xml_text refs) -> xml_kind_refs
CREATE OR REPLACE
FUNCTION find_xml_text_kind(refs)
RETURNS doc_node_kind_refs AS $$
	SELECT ref FROM xml_text_kind_rows
	WHERE xml_text = $1
$$ LANGUAGE sql;

-- +++ make_xml_text_kind(xml_text refs) -> doc_node_kind_refs
CREATE OR REPLACE
FUNCTION make_xml_text_kind(refs)
RETURNS doc_node_kind_refs AS $$
DECLARE
	_ref doc_node_kind_refs := NULL; -- unchecked_ref_null();
	kilroy_was_here boolean := false;
	this regprocedure := 'make_xml_text_kind(refs)';
BEGIN LOOP
		SELECT ref INTO _ref FROM xml_text_kind_rows
		WHERE xml_text = $1;
		IF FOUND THEN RETURN _ref; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with %', this, $1;
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO xml_text_kind_rows(xml_text) VALUES($1);
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % raised %!', this, $1, 'unique_violation';
		END;
END LOOP; END
$$ LANGUAGE plpgsql STRICT;
COMMENT ON FUNCTION make_xml_text_kind(refs) IS
'return unique ref associated with argument, creating it if necessary';

-- -- get_xml_text_kind(xml_text refs) -> xml_kind_refs
CREATE OR REPLACE
FUNCTION try_get_xml_text_kind(refs) 
RETURNS doc_node_kind_refs AS $$
	SELECT COALESCE(find_xml_text_kind($1),make_xml_text_kind($1))
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION get_xml_text_kind(refs)
RETURNS doc_node_kind_refs AS $$
	SELECT non_null(
		try_get_xml_text_kind($1),
		'get_xml_text_kind(refs)'
	)
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION xml_text_kind_text(
	doc_node_kind_refs, env_refs = env_nil(), crefs = crefs_nil(),
	doc_node_refs[] = '{}'
) RETURNS text AS $$
-- assert array_is_empty($4);
	SELECT ref_env_crefs_text_op( xml_text, $2, $3 )
	FROM xml_text_kind_rows WHERE ref = $1
$$ LANGUAGE sql;

-- SELECT  type_class_out(
-- 	 'xml_text_kind_refs', 'xml_text_kind_rows',
-- 	'xml_kind_text(xml_kind_refs, env_refs, crefs)'
-- );

SELECT  type_class_op_method(
	'doc_node_kind_refs', 'xml_text_kind_rows',
	'ref_env_crefs_chiln_text_op(refs, env_refs, crefs, doc_node_refs[])',
	'xml_text_kind_text(doc_node_kind_refs, env_refs, crefs, doc_node_refs[])'
);

-- * xml_to_xml_text_kind_rows

-- -- find_xml_to_xml_text_kind(to_xml_text refs) -> xml_kind_refs
CREATE OR REPLACE
FUNCTION find_xml_to_xml_text_kind(refs)
RETURNS doc_node_kind_refs AS $$
	SELECT ref FROM xml_to_xml_text_kind_rows
	WHERE to_xml_text = $1
$$ LANGUAGE sql;

-- +++ make_xml_to_xml_text_kind(to_xml_text refs) -> xml_kind_refs
CREATE OR REPLACE
FUNCTION make_xml_to_xml_text_kind(refs)
RETURNS doc_node_kind_refs AS $$
DECLARE
	_ref doc_node_kind_refs := NULL; -- unchecked_ref_null();
	kilroy_was_here boolean := false;
	this regprocedure := 'make_xml_to_xml_text_kind(refs)';
BEGIN LOOP
		SELECT ref INTO _ref FROM xml_to_xml_text_kind_rows
		WHERE to_xml_text = $1;
		IF FOUND THEN RETURN _ref; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with %', this, $1;
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO xml_to_xml_text_kind_rows(to_xml_text) VALUES($1);
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % raised %!', this, $1, 'unique_violation';
		END;
END LOOP; END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION make_xml_to_xml_text_kind(refs) IS
'return unique ref associated with argument, creating it if necessary';

-- -- xml_to_xml_text_kind(to_xml_text refs) -> xml_kind_refs
CREATE OR REPLACE
FUNCTION xml_to_xml_text_kind(refs) RETURNS doc_node_kind_refs AS $$
	SELECT COALESCE(
		find_xml_to_xml_text_kind($1),
		make_xml_to_xml_text_kind($1)
	)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION xml_to_xml_text_kind_text(doc_node_kind_refs, env_refs, crefs, doc_node_refs[])
RETURNS text AS $$
-- assert array_is_empty($4);
	SELECT xml_pure_text( ref_env_crefs_text_op(
		to_xml_text, $2, $3
	) )
	FROM xml_to_xml_text_kind_rows WHERE ref = $1
$$ LANGUAGE sql;

-- SELECT  type_class_out(
-- 	'xml_text_kind_refs', 'xml_to_xml_text_kind_rows',
-- 	'xml_kind_text(xml_kind_refs, env_refs, crefs)'
-- );

SELECT  type_class_op_method(
	'doc_node_kind_refs', 'xml_to_xml_text_kind_rows',
	'ref_env_crefs_chiln_text_op(refs, env_refs, crefs, doc_node_refs[])',
	'xml_to_xml_text_kind_text(doc_node_kind_refs, env_refs, crefs, doc_node_refs[])'
);

-- * xml_proc_kind_rows

/*
CREATE OR REPLACE
FUNCTION xml_proc_kind_text(xml_kind_refs, env_refs, crefs, doc_node_refs[])
RETURNS text AS $$
	SELECT xml_kind_text_stub($2, $3, 'proc')
$$ LANGUAGE sql;

SELECT  type_class_op_method(
	'xml_kind_refs', 'xml_proc_kind_rows',
	'ref_env_crefs_chiln_text_op(refs, env_refs, crefs, doc_node_refs[])',
	'xml_proc_kind_text(xml_kind_refs, env_refs, crefs, doc_node_refs[])'
);
*/

-- * search

CREATE OR REPLACE
FUNCTION xml_element_kind_search(doc_node_kind_refs, xml_attr_name_refs)
RETURNS refs AS $$
	SELECT attrs ^ $2 FROM xml_element_kind_rows
	WHERE ref = $1 AND ref_table($1) = 'xml_element_kind_rows'::regclass
$$ LANGUAGE sql;

COMMENT ON FUNCTION 
xml_element_kind_search(doc_node_kind_refs, xml_attr_name_refs)
IS 'What about xml_root_element_kind_rows???';

SELECT type_class_op_method(
	'doc_node_kind_refs', 'xml_element_kind_rows',
	'ref_name_search_op(refs, name_refs)',
	'xml_element_kind_search(doc_node_kind_refs, xml_attr_name_refs)'
);

DROP OPERATOR IF EXISTS ^ (doc_node_kind_refs , xml_attr_name_refs) CASCADE;

-- we could use the operator instead if we wanted to allow
-- for different xml kinds to be searched differently

CREATE OPERATOR ^ (
		leftarg = doc_node_kind_refs,
		rightarg = xml_attr_name_refs,
		procedure = xml_element_kind_search
);
