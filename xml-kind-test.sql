-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-kind-test.sql', '$Id');

\set ECHO all

-- SELECT refs_debug_on(), text_refs_debug_on(), xml_debug_on();

SELECT declare_name('hello');

SELECT test_func(
	'xml_literal_kind_text(doc_node_kind_refs, env_refs, crefs, doc_node_refs[])',
	ref_env_crefs_chiln_text_op(
		xml_literal_kind('hello'::name_refs::refs), env_nil(), crefs_nil(), '{}'::doc_node_refs[]
	), E'hello\n'
);

SELECT test_func(
	'xml_text_kind_text(doc_node_kind_refs, env_refs, crefs, doc_node_refs[])',
	ref_env_crefs_chiln_text_op(
		get_xml_text_kind( 'hello'::name_refs::refs ),
		env_nil(), crefs_nil(), '{}'::doc_node_refs[]
	), 'hello'
);

SELECT test_func(
	'xml_to_xml_text_kind_text(doc_node_kind_refs, env_refs, crefs, doc_node_refs[])',
	ref_env_crefs_chiln_text_op(
		xml_to_xml_text_kind(get_text('hello & goodbye')::refs),
		env_nil(), crefs_nil(), '{}'::doc_node_refs[]
	), E'hello &amp; goodbye\n'
);
