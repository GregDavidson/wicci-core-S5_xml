-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-doc-simple-data.sql', '$Id');

-- SELECT refs_debug_on(), text_refs_debug_on(), xml_debug_on();

SELECT get_doc_page(
	get_page_uri('wicci.org/simple'), find_page_doc('simple.html')
);

SELECT COALESCE(
	doc_node_keys_key('simple-graft'),
	doc_node_keys_key('simple-graft',
			xml_graft(
				doc_id_node(doc, 'h1.1'),
				get_xml_text_kind( get_xml_text('How do you do?') )
			)
) ) FROM find_page_doc('simple.html') doc;

SELECT COALESCE(
	doc_keys_key('simple-howdy'),
	doc_keys_key('simple-howdy',
		get_changeset_doc( doc, doc_node_keys_key('simple-graft' )
) )	) FROM find_page_doc('simple.html') doc;

CREATE OR REPLACE
FUNCTION html_br_tag() RETURNS xml_tag_refs AS $$
	SELECT xml_tag('', 'br', 'html'::doc_lang_name_refs)
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE
FUNCTION html_br_kind() RETURNS doc_node_kind_refs AS $$
	SELECT xml_element_kind(html_br_tag())
$$ LANGUAGE sql IMMUTABLE;

SELECT ref_tag(html_br_kind());

SELECT * FROM typed_object_classes WHERE tag_ = ref_tag(html_br_kind());

SELECT * FROM typed_object_methods WHERE tag_ = ref_tag(html_br_kind());

SELECT is_xml_name('br');

SELECT debug_assert('xml_open(text)', is_xml_name('br'), true, 'br');

SELECT xml_open('br'), xml_open('br') IS NULL;

SELECT
	xml_tag_text(tag, env_nil(), crefs_nil()),
	xml_open(xml_tag_text(tag, env_nil(), crefs_nil())) IS NULL
FROM xml_element_kind_rows WHERE ref = html_br_kind();

SELECT xml_open(xml_tag_text(tag, env_nil(), crefs_nil())) IS NULL,
	xml_attrs_text(attrs, env_nil(), crefs_nil()) IS NULL,
	xml_close('')
FROM xml_element_kind_rows WHERE ref = html_br_kind();

SELECT xml_tag_attrs(
	xml_tag_text(tag, env_nil(), crefs_nil()),
	xml_attrs_text(attrs, env_nil(), crefs_nil()),
	''
) IS NULL
FROM xml_element_kind_rows WHERE ref = html_br_kind();

SELECT xml_attrs_text(attrs, env_nil(), crefs_nil()) =''
FROM xml_element_kind_rows WHERE ref = html_br_kind();

SELECT xml_element_kind_text(
	html_br_kind(),
	env_nil(), crefs_nil(), no_doc_node_array()
);

SELECT tree_doc_text(doc)
FROM find_page_doc('simple.html') doc;
