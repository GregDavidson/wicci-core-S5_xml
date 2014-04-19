-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-doc-fancy-data.sql', '$Id');

-- SELECT refs_debug_on(), text_refs_debug_on(), xml_debug_on();

--xsltproc html-to-sql-new.xsl xml-doc-fancy-new.html

SELECT get_doc_page(
	get_page_uri('wicci.org/fancy'), find_page_doc('fancy.html')
);

SELECT COALESCE(
	doc_keys_key('fancy-send-love'),
	doc_keys_key('fancy-send-love',
		get_changeset_doc(
			doc,
			xml_graft(
				doc_id_node(doc, 'header.1'),
				get_xml_text_kind( get_xml_text('We Send Our Love To You!') )
			)
		)
	)
) FROM find_page_doc('fancy.html') doc;

SELECT COALESCE(
	doc_keys_key('fancy-give-love'),
	doc_keys_key('fancy-give-love',
		get_changeset_doc(
			doc,
			xml_graft(
				doc_id_node(doc, 'list.1.1'),
				get_xml_text_kind( get_xml_text('I need lots of love!') )
			),
			xml_graft(
				doc_id_node(doc, 'list.2.1'),
				get_xml_text_kind( get_xml_text('I have lots of love to give!') )
			),
			xml_graft(
				doc_id_node(doc, 'list.3.1'),
				get_xml_text_kind( get_xml_text('Let''s love each other!') )
			)
		)
	)
) FROM find_page_doc('fancy.html') doc;

SELECT COALESCE(
	doc_keys_key('fancy-less'),
	doc_keys_key('fancy-less',
		get_changeset_doc(
			doc,
			xml_graft(
				doc_id_node(doc, 'list'),
				html_kind('ul'),
				doc_id_node(doc, 'list.1'),
				doc_id_node(doc, 'list.2')
			)
		)
	)
) FROM find_page_doc('fancy.html') doc;

SELECT COALESCE(
	doc_keys_key('fancy-more'),
	doc_keys_key('fancy-more',
		get_changeset_doc(
			doc,
			xml_graft(
				doc_id_node(doc, 'list'),
				html_kind('ul'),
				doc_id_node(doc, 'list.1'),
				doc_id_node(doc, 'list.2'),
				new_xml_tree_node(  html_kind('li' ),
					new_xml_tree_node(  get_xml_text_kind( get_xml_text('Our home is full of love!') ) ) ),
				new_xml_tree_node(  html_kind('li' ),
					new_xml_tree_node(  get_xml_text_kind( get_xml_text('Let''s spread it to the world!') ) ) ),
				new_xml_tree_node(  html_kind('li' ),
					new_xml_tree_node(  get_xml_text_kind( get_xml_text('Sher loves Greg like crazy!') ) ) )
			)
		)
	)
) FROM find_page_doc('fancy.html') doc;
