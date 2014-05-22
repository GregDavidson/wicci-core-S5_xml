-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-tag-schema.sql', '$Id');

--	Wicci Project XML/HTML Encoding Schema

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- Visibly, an xml_tag has
--	- an optional prefix
--	- a tag name
--  Semantically, a xml_tag is
--	- part of the vocabulary of a specific xml doc_lang_name, where:
--	- it may have an associated namespace
--	- that namespace may have a tag
--	- the xml doc_lang_name schema specifies
--	-	allowed, children, parents, multiplicities, etc.

-- the w3 standard uses the term
-- qname for any symbol that might be qualified
-- with a namespace qualifier.

-- * xml_tag_name

SELECT create_name_ref_schema(
	'xml_tag_name', _nil_ := false
);
COMMENT ON TYPE xml_tag_name_refs IS
'Good for type checking but likely overkill!!';

-- * class xml_tag

SELECT create_ref_type('xml_tag_refs');

CREATE TABLE IF NOT EXISTS xml_tag_rows (
	ref xml_tag_refs PRIMARY KEY,
	name_ xml_tag_name_refs NOT NULL,
	ns_ page_uri_refs DEFAULT page_uri_nil()
		NOT NULL REFERENCES page_uri_rows,
	UNIQUE(name_, ns_)
);
COMMENT ON TABLE xml_tag_rows IS
'A qname representing a tag.';

COMMENT ON COLUMN xml_tag_rows.ns_ IS
'The uri of any namespace associated with this
tag or page_uri_nil() if none..';

CREATE TABLE IF NOT EXISTS xml_tags_envs (
	tag xml_tag_refs NOT NULL REFERENCES xml_tag_rows,
	lang doc_lang_name_refs
		NOT NULL REFERENCES doc_lang_name_rows,
	PRIMARY KEY(tag, lang),
	env env_refs DEFAULT env_nil()
		NOT NULL REFERENCES env_rows,
	UNIQUE(tag, env),
	CHECK( env_doc_lang(env) = lang)
);
COMMENT ON TABLE xml_tags_envs IS
'Associates an env with a given tag to
supply language and xml schema context.';
COMMENT ON COLUMN xml_tags_envs.lang IS
'The document language of documents which use
this tag.  Should also be recorded in the env.';
COMMENT ON COLUMN xml_tags_envs.env IS
'holds namespace, language, xml schema constraints
or any other special information about this tag;
Tags that are part of the xml schema of a given
language should all have environments;
tags discovered during document import must be
in some namespace and will NOT have an env';

/*
CREATE TABLE IF NOT EXISTS xml_tag_rows (
	ref xml_tag_refs PRIMARY KEY,
	name_ xml_tag_name_refs
		NOT NULL REFERENCES xml_tag_name_rows,
	lang doc_lang_name_refs
		NOT NULL REFERENCES doc_lang_name_rows,
	ns_ page_uri_refs DEFAULT page_uri_nil()
		NOT NULL REFERENCES page_uri_rows,
	env env_refs DEFAULT env_nil()
		NOT NULL REFERENCES env_rows,
	UNIQUE(name_, lang, ns_),
	CHECK( is_nil(env) OR env_doc_lang(env) = lang),
	CHECK(
		is_nil(env) AND NOT is_nil(ns_)
		OR try_env_namespace_uri(env) = ns_
	)
);
COMMENT ON TABLE xml_tag_rows IS
'Associates context with a given qname to
create it as a reusable tag in documents of
the given language.';
COMMENT ON COLUMN xml_tag_rows.env IS
'holds namespace, language, xml schema constraints
or any other special information about this tag;
Tags that are part of the xml schema of a given
language should all have environments;
tags discovered during document import must be
in some namespace and will NOT have an env;
UNIQUE(non-nil env, name_)';
COMMENT ON COLUMN xml_tag_rows.lang IS
'The document language of documents which use
this tag.';
COMMENT ON COLUMN xml_tag_rows.ns_ IS
'The uri of any namespace associated with this
tag or page_uri_nil() if none..';
*/

SELECT declare_ref_class_with_funcs('xml_tag_rows');
SELECT create_simple_serial('xml_tag_rows');

-- * special html tag support

CREATE TABLE IF NOT EXISTS html_no_close_tags (
	tag xml_tag_refs NOT NULL REFERENCES xml_tag_rows,
	lang doc_lang_name_refs
		NOT NULL REFERENCES doc_lang_name_rows,
	PRIMARY KEY(tag, lang)
);

COMMENT ON TABLE html_no_close_tags IS
'Those html tags which must NOT be closed!';

CREATE TABLE IF NOT EXISTS xhtml_long_close_tags (
	tag xml_tag_refs PRIMARY KEY REFERENCES xml_tag_rows
);

COMMENT ON TABLE xhtml_long_close_tags IS
'Any xhtml tags which must be closed with an explicit
</TAG> construct, even when empty, not with an xml
<TAG ... /> - does this only apply to the script tag??';
