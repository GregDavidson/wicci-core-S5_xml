-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-attr-test.sql', '$Id');

--	Wicci Project Virtual Text Schema
--	attr: a text-family abstract type representing xml attributes
--	test code

-- ** Copyright

--	Copyright (c) 2005, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.


SELECT declare_xml_attr_name('color', 'width', 'ratio');

/*
SELECT test_func(
	'get_xml_attr(text)',
	ref_tag(get_xml_attr('color=red')),
	type_class_tag('xml_attr_refs', 'xml_attr_rows')
);
*/

SELECT test_func(
	'get_xml_attr(text, text, text)',
	ref_tag(_attr),
	type_class_tag('xml_attr_refs', 'xml_attr_rows')
) FROM get_xml_attr('', 'color', 'red') _attr;

SELECT test_func(
	'xml_attr_name(xml_attr_refs)',
	xml_attr_name(_attr),
	'color'::xml_attr_name_refs
) FROM get_xml_attr('', 'color', 'red') _attr;

SELECT test_func(
	'xml_attr_value(xml_attr_refs)',
	xml_attr_value(_attr),
	get_text('red')::refs
) FROM get_xml_attr('', 'color', 'red') _attr;

SELECT spx_debug_set(2);
SELECT refs_debug_set(3);

SELECT test_func(
	'xml_attr_text(xml_attr_refs, env_refs, crefs)',
	ref_text_op( _attr ),
	xml_safe_attr('color', 'red')
) FROM get_xml_attr('', 'color', 'red') _attr;

-- let's test that we can create and display in one transaction:
SELECT get_xml_attr('', 'width', '10');

SELECT test_func(
	'get_xml_attr(page_uri_refs, xml_attr_name_refs, integer)',
	xml_attr_value(_attr),
	get_int_ref(10)::refs
) FROM get_xml_attr('', 'width', '10') _attr;
-- ERROR:  42846: cannot cast type cstring to bigint
-- LINE 4:  '10'::int_refs::refs
-- QUERY:  SELECT s3_more.get_int_ref($1::bigint)

SELECT test_func(
	'get_xml_attr(page_uri_refs, xml_attr_name_refs, double precision)',
	xml_attr_value(get_xml_attr('', 'ratio', x)),
	get_float_ref(x)::refs
) FROM CAST ('1.6180339887' AS double precision) x;
