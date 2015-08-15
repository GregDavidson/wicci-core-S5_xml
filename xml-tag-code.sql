-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-tag-code.sql', '$Id');

--	Wicci Project XML/HTML Encoding Schema

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * xml/html utility tables

-- remembering that inheritance doesn't actually create
-- a nested set situation and indices are NOT updated
-- in base classes.

-- OK, this is fine, but too complicated!
-- Let's represent a tag as a ref_tag_name + env_ref
-- where the env_ref can hold the namespace uri plus
-- xml schema constraints about where the tag can be used!

-- for what it's worth, the standard uses the name
-- qname for any symbol that might be qualified
-- with a namespace qualifier.

-- * class xml_tag

-- ** displaying

CREATE OR REPLACE FUNCTION xml_tag_text(
	xml_tag_refs, env_refs = env_nil(), crefs = crefs_nil()
) RETURNS text AS $$
	SELECT xml_ns_prefix_text(ns_, $2, $3)
	|| xml_tag_name_text(name_)
	FROM xml_tag_rows WHERE ref = $1
$$ LANGUAGE SQL;
COMMENT ON FUNCTION xml_tag_text(xml_tag_refs,env_refs,crefs) IS
'compute the text value
need to check for a namespace in env!!!
need to check for a namespace prefix in $2
';

-- ** finding and creating

CREATE OR REPLACE FUNCTION try_xml_split_tag(
	text, OUT prefix xml_prefix_name_refs, OUT xml_tag_name_refs
) AS $$
	SELECT
	try_xml_prefix_name(_prefix),  try_xml_tag_name(_name)
	FROM xml_split_prefix_name($1) AS foo(_prefix, _name)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE FUNCTION get_xml_split_tag(
	text, OUT prefix xml_prefix_name_refs, OUT xml_tag_name_refs
) AS $$
	SELECT
	get_xml_prefix_name(_prefix),  get_xml_tag_name(_name)
	FROM xml_split_prefix_name($1) AS foo(_prefix, _name)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE FUNCTION try_xml_tag(
	xml_tag_name_refs, page_uri_refs = page_uri_nil()
) RETURNS xml_tag_refs AS $$
	SELECT ref FROM xml_tag_rows
	WHERE name_ = $1 AND ns_ = $2
$$ LANGUAGE sql STRICT;

COMMENT ON FUNCTION try_xml_tag(
	xml_tag_name_refs, page_uri_refs
) IS 'returns tag given name and possible namespace uri';

-- CREATE OR REPLACE FUNCTION try_xml_text_ns_tag(
-- 	text, page_uri_refs = page_uri_nil()
-- ) RETURNS xml_tag_refs AS $$
-- 	SELECT try_xml_name_ns_tag( try_xml_tag_name($2), $2 )
-- $$ LANGUAGE sql STRICT;

CREATE OR REPLACE FUNCTION find_xml_tag(
	xml_tag_name_refs, page_uri_refs = page_uri_nil()
) RETURNS xml_tag_refs AS $$
	SELECT non_null(
		try_xml_tag($1, $2), _this, $1::text, $2::text
	) FROM debug_enter(
			'find_xml_tag(xml_tag_name_refs, page_uri_refs)',
			$1, $2::text
	) _this
$$ LANGUAGE sql;

-- CREATE OR REPLACE FUNCTION xml_text_ns_tag(
-- 	text, page_uri_refs = page_uri_nil()
-- ) RETURNS xml_tag_refs AS $$
-- 	SELECT non_null(
-- 		try_xml_text_ns_tag($1, $2), _this, $1::text, $2::text)
-- 		FROM debug_enter(
-- 			'xml_text_ns_tag(text, page_uri_refs)', $1::text, $2::text
-- 		) _this
-- $$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION try_get_xml_tag(
	xml_tag_name_refs, page_uri_refs = page_uri_nil()
) RETURNS xml_tag_refs AS $$
DECLARE
	row_ record;
	kilroy_was_here boolean := false;
	this regprocedure =
		'try_get_xml_tag(xml_tag_name_refs,page_uri_refs)';
BEGIN
	LOOP
		SELECT INTO row_ * FROM  xml_tag_rows
		WHERE name_ = $1 AND ns_ = $2;
		IF FOUND THEN RETURN row_.ref; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% % % looping!', this, $1, $2;
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO xml_tag_rows(name_, ns_) VALUES($1, $2);
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % % raised %!',
				this, $1, $2, 'unique_violation';
		END;
	END LOOP;	
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE FUNCTION get_xml_tag(
	xml_tag_name_refs, page_uri_refs = page_uri_nil()
) RETURNS xml_tag_refs AS $$
	SELECT non_null(
		try_get_xml_tag( $1, _ns ),
		'get_xml_tag(xml_tag_name_refs,page_uri_refs)',
		xml_tag_name_text($1), page_uri_text(_ns)
	) FROM COALESCE( $2, page_uri_nil() ) _ns
$$ LANGUAGE sql;

COMMENT ON FUNCTION get_xml_tag(
	xml_tag_name_refs, page_uri_refs
) IS 'Find or create tag with given name and possible namespace.';

-- CREATE OR REPLACE FUNCTION try_get_xml_tag(
-- 	text, page_uri_refs = page_uri_nil()
-- ) RETURNS xml_tag_refs AS $$
-- 	SELECT try_get_xml_tag( get_xml_tag_name($1), $2 )
-- $$ LANGUAGE sql;

-- ** register type xml_tag_refs class xml_tag_rows

SELECT type_class_op_method(
	'xml_tag_refs', 'xml_tag_rows',
	'ref_env_crefs_text_op(refs, env_refs, crefs)',
	'xml_tag_text(xml_tag_refs, env_refs, crefs)'
);

-- * xml_tags_envs

CREATE OR REPLACE FUNCTION try_xml_tag_env(
	xml_tag_refs, doc_lang_name_refs
) RETURNS env_refs AS $$
	SELECT env FROM xml_tags_envs
	WHERE tag = $1 AND lang = $2
$$ LANGUAGE sql STRICT;

COMMENT ON FUNCTION try_xml_tag_env(
	xml_tag_refs, doc_lang_name_refs
) IS 'returns possible env given tag and language';

CREATE OR REPLACE FUNCTION try_xml_tag_env(
	xml_tag_refs, doc_lang_name_refs
) RETURNS env_refs AS $$
	SELECT COALESCE( try_xml_tag_env($1, $2), env_nil() )
$$ LANGUAGE sql STRICT;

COMMENT ON FUNCTION try_xml_tag_env(
	xml_tag_refs, doc_lang_name_refs
) IS 'returns possible env or nil given tag and language';

CREATE OR REPLACE FUNCTION try_xml_ns_name_lang_tag(
	page_uri_refs, xml_tag_name_refs, doc_lang_name_refs
) RETURNS xml_tag_refs AS $$
	SELECT tag FROM xml_tag_rows, xml_tags_envs
	WHERE ref = tag AND ns_ = $1 AND name_ = $2 AND lang = $3
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE FUNCTION try_xml_tag_env(
	text, doc_lang_name_refs
) RETURNS env_refs AS $$
	SELECT e.env FROM
		xml_tag_name_rows n, xml_tag_rows t, xml_tags_envs e
	WHERE n.name_ = $1 AND n.ref = t.name_
	AND t.ref = e.tag AND e.lang = $2
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE FUNCTION xml_tag_env(
	xml_tag_refs, doc_lang_name_refs
) RETURNS env_refs AS $$
	SELECT non_null(
		try_xml_tag_env($1, $2), _this, $1::text, $2::text)
		FROM debug_enter(
			'xml_tag_env(xml_tag_refs, doc_lang_name_refs)', $1, $2::text
		) _this
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION xml_tag_env(text, doc_lang_name_refs)
RETURNS env_refs AS $$
	SELECT non_null(
		try_xml_tag_env($1, $2), _this, $1::text, $2::text)
		FROM debug_enter(
			'xml_tag_env(xml_tag_refs, doc_lang_name_refs)', $1, $2::text
		) _this
$$ LANGUAGE sql;

-- CREATE OR REPLACE
-- FUNCTION try_xml_tag_env(xml_tag_name_refs, env_refs) 
-- RETURNS env_refs AS $$
-- 	SELECT ref FROM xml_tags_envs
-- 	WHERE name_ = $1 AND env = $2
-- $$ LANGUAGE sql STRICT;

-- CREATE OR REPLACE
-- FUNCTION xml_tag_env(xml_tag_name_refs, env_refs)
-- RETURNS env_refs AS $$
-- 	SELECT non_null(
-- 		try_xml_tag_env($1,$2),
-- 		'xml_tag_env(xml_tag_name_refs,env_refs)'
-- 	)
-- $$ LANGUAGE sql;

-- CREATE OR REPLACE
-- FUNCTION try_xml_tag_env(text, env_refs) 
-- RETURNS env_refs AS $$
-- 	SELECT try_xml_tag_env(try_xml_tag_name($1), $2)
-- $$ LANGUAGE sql STRICT;

-- CREATE OR REPLACE
-- FUNCTION xml_tag_env(text, env_refs)
-- RETURNS env_refs AS $$
-- 	SELECT non_null(
-- 		try_xml_tag_env($1,$2), 'xml_tag_env(text,env_refs)'
-- 	)
-- $$ LANGUAGE sql;

-- CREATE OR REPLACE
-- FUNCTION try_xml_tag_env(
-- 	xml_tag_name_refs, doc_lang_name_refs,
-- 	page_uri_refs = page_uri_nil() 
-- ) RETURNS xml_tag_refs AS $$
-- 	SELECT ref FROM xml_tags_envs
-- 	WHERE name_ = $1 AND lang = $2 AND ns_ = $3
-- $$ LANGUAGE sql STRICT;

-- CREATE OR REPLACE
-- FUNCTION find_xml_tag_env(
-- 	xml_tag_name_refs, doc_lang_name_refs,
-- 	page_uri_refs = page_uri_nil()
-- ) RETURNS xml_tag_refs AS $$
-- 	SELECT non_null(
-- 		try_xml_tag_env($1,$2,$3),
-- 		'find_xml_tag_env(xml_tag_name_refs,doc_lang_name_refs,page_uri_refs)'
-- 	)
-- $$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION try_get_xml_tag_env(
	xml_tag_refs, doc_lang_name_refs, env_refs
) RETURNS env_refs AS $$
DECLARE
	row_ record;
	kilroy_was_here boolean := false;
	this regprocedure =
		'try_get_xml_tag_env(xml_tag_refs, doc_lang_name_refs, env_refs)';
BEGIN
	LOOP
		SELECT INTO row_ * FROM  xml_tags_envs
		WHERE tag = $1 AND lang = $2;
		IF FOUND THEN
			IF row_.env = $3 THEN RETURN row_.env; END IF;
			RAISE EXCEPTION '% % % % != %',
				this, $1, $2, $3, row_.env;
		END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% % % % looping!', this, $1, $2, $3;
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO xml_tags_envs(tag, lang, env)
			VALUES($1, $2, $3);
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % % % raised %!',
				this, $1, $2, $3, 'unique_violation';
		END;
	END LOOP;	
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE FUNCTION get_xml_tag_env(
	xml_tag_refs, doc_lang_name_refs, env_refs
) RETURNS env_refs AS $$
	SELECT non_null(
		try_get_xml_tag_env($1,$2,$3),
		'get_xml_tag_env(xml_tag_refs,doc_lang_name_refs,env_refs)'
	)
$$ LANGUAGE sql;

COMMENT ON FUNCTION try_get_xml_tag_env(
	xml_tag_refs, doc_lang_name_refs, env_refs
) IS '
	Find or create an environment associated with
	the given tag, language, and env.
	Will we always have the environment with which
	to create this if we need to??
	Maybe we need to have default environments for
	each language and substitute those here!!
';

-- CREATE OR REPLACE
-- FUNCTION try_get_xml_tag_env(
-- 	text,  doc_lang_name_refs,
-- 	page_uri_refs = NULL,   env_refs = env_nil()
-- ) RETURNS xml_tag_refs AS $$
-- 	SELECT try_get_xml_tag_env( find_xml_tag($1, $3), $2,$4 )
-- $$ LANGUAGE sql;

-- COMMENT ON FUNCTION try_get_xml_tag_env(
-- 	text,  doc_lang_name_refs, page_uri_refs, env_refs
-- ) IS 'I do NOT like this signature!!!';

-- * code: methods and other functions

CREATE OR REPLACE FUNCTION declare_tagenv(
	handles,
	_base_ env_refs = NULL,
	_kind_ name_refs = NULL,
	_lang_ doc_lang_name_refs = NULL,
	_namespace_ page_uri_refs = NULL
) RETURNS env_refs AS $$
DECLARE
	_env env_refs;
	base_envs env_refs[] := '{}';
	kind_type name_refs := 'env_xml_kind_type';
BEGIN
		IF _base_ IS NOT NULL THEN
			base_envs := ARRAY[ _base_ ];
		END IF;
		SELECT ref INTO _env FROM env_rows_row_handles
		WHERE handle = $1;
		IF NOT FOUND THEN
			SELECT env_rows_ref(
				$1, make_system_env(VARIADIC base_envs)
			) INTO _env;
		END IF;
		IF _kind_ IS NOT NULL THEN
			PERFORM env_add_binding( _env, kind_type, _kind_ );
		END IF;
		IF _lang_ IS NOT NULL THEN
			PERFORM env_doc_lang( _env, _lang_ );
		END IF;
		IF _namespace_ IS NOT NULL THEN
			PERFORM env_namespace_uri( _env, _namespace_ );
		END IF;
	RETURN _env;
END
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION  declare_tagenv(
	handles, env_refs, name_refs, doc_lang_name_refs, page_uri_refs
) IS 'convenience function for declaring a tag envs with
optional base environment, kind type, language and
namespace;
this is likely going to have to be redesigned after we design
a proper xml schema validation system.
Hey - we are not even using most of the arguments!!!
';

CREATE OR REPLACE FUNCTION xml_env_tags(
	handles, VARIADIC text[]
) RETURNS env_refs[] AS $$
	SELECT declare_xml_tag_name(VARIADIC $2);
	SELECT ARRAY(
		SELECT get_xml_tag_env(
			get_xml_tag( get_xml_tag_name(_name), _ns ), _lang, _env
		) FROM
			unnest($2) _name,
			env_doc_lang(_env) _lang,
			COALESCE( try_env_namespace_uri(_env), page_uri_nil() ) _ns
	) FROM find_env($1) _env
$$ LANGUAGE SQL;
COMMENT ON FUNCTION xml_env_tags(handles, text[]) IS
'convenience function for creating tags inside a named env_ref';

-- ** validity checking

CREATE OR REPLACE FUNCTION ok_xml_env_lang(
	env_refs, doc_lang_name_refs
) RETURNS boolean AS $$
	SELECT COALESCE(
		env_lang = $2 OR env_lang = doc_lang_name_nil()
			OR in_doc_lang_family(env_lang, $2),
		false
	) FROM try_env_doc_lang($1) env_lang
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE FUNCTION ok_xml_tag_lang(
	xml_tag_refs, doc_lang_name_refs
) RETURNS boolean AS $$
	SELECT lang = $2 FROM xml_tags_envs WHERE tag = $1
$$ LANGUAGE sql STRICT;

COMMENT ON FUNCTION 
ok_xml_tag_lang(xml_tag_refs, doc_lang_name_refs)
IS 'Does not deal with families!! When do we need this??';

-- * special html tag support

-- ** TABLE html_no_close_tags

CREATE OR REPLACE FUNCTION try_is_html_no_close_tag(
	xml_tag_refs, doc_lang_name_refs
) RETURNS boolean AS $$
	SELECT CASE
		WHEN in_doc_lang_family($2, 'xhtml') THEN 'false'
		WHEN in_doc_lang_family($2, 'html') THEN EXISTS(
			SELECT tag FROM html_no_close_tags
			WHERE tag = $1 AND (lang = $2 OR lang = 'html') -- ??
	) ELSE 'false' END
$$ LANGUAGE sql IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION is_html_no_close_tag(
	xml_tag_refs, doc_lang_name_refs
) RETURNS boolean AS $$
	SELECT non_null(
		try_is_html_no_close_tag( $1, _lang ),
		'is_html_no_close_tag(xml_tag_refs,doc_lang_name_refs)',
		xml_tag_text($1), _lang::text
	) FROM COALESCE($2, 'xml') _lang
$$ LANGUAGE sql IMMUTABLE;

COMMENT ON FUNCTION is_html_no_close_tag(
	xml_tag_refs, doc_lang_name_refs
) IS '
	All X/HTML dialects now use same set of tags.
	WHERE (lang = $2 OR lang = ''html'') -- ??
	Should we pass an env as well as or instead of a language?
';

CREATE OR REPLACE FUNCTION try_is_xhtml_long_close_tag(
	xml_tag_refs, doc_lang_name_refs
) RETURNS boolean AS $$
	SELECT CASE
		WHEN in_doc_lang_family($2, 'xhtml') THEN NOT EXISTS(
			SELECT tag FROM xhtml_long_close_tags WHERE tag = $1
		)
		WHEN in_doc_lang_family($2, 'html') THEN 'true'
		ELSE 'false'								-- some non-X/HTML xml language
	END
$$ LANGUAGE sql IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION is_xhtml_long_close_tag(
	xml_tag_refs, doc_lang_name_refs
) RETURNS boolean AS $$
	SELECT non_null(
		try_is_xhtml_long_close_tag($1,  _lang ),
		'is_xhtml_long_close_tag(xml_tag_refs,doc_lang_name_refs)',
		xml_tag_text($1), _lang::text
	) FROM COALESCE($2, 'xml') _lang
$$ LANGUAGE sql IMMUTABLE;

COMMENT ON FUNCTION is_xhtml_long_close_tag(
	xml_tag_refs, doc_lang_name_refs
) IS '
	All X/HTML dialects now use same set of tags.
	WHERE (lang = $2 OR lang = ''html'') -- ??
	Should we pass an env as well as or instead of a language?
';

