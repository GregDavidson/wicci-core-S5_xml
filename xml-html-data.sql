-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-schema0-data.sql', '$Id');

--	Wicci Project XML/XHTML Encoding Schema
--	Accompanying Data

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * xml_char_refs

SELECT declare_name('amp', 'lt', 'gt');
SELECT
	get_xml_char('&', 'amp'),
	get_xml_char('<', 'lt'),
	get_xml_char('>', 'gt');

-- * DOCTYPEs

/*

SELECT xml_literal_kind_rows_ref( 'html-doctype', xml_literal_kind( get_text(
	'<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">'
) ) );

SELECT xml_literal_kind_rows_ref( 'xhtml-doctype', xml_literal_kind( get_text(
	'<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">'
) ) );

-- 
SELECT xml_literal_kind_rows_ref( 'svg-doctype', xml_literal_kind( get_text(
	E'<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.0//EN" "http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd">'
) ) );

DELETE FROM xml_lang_doctypes;

INSERT INTO xml_lang_doctypes(lang_, type_) VALUES
	('xhtml', xml_literal_kind_rows_ref('xhtml-doctype')),
	('html', xml_literal_kind_rows_ref('html-doctype')),
-- ('xhtml-strict', xml_literal_kind_rows_ref('xhtml-1.0-strict-doctype')),
-- ('html4', xml_literal_kind_rows_ref('html-4.01-strict-doctype')),
-- ('html4-strict', xml_literal_kind_rows_ref('html-4.01-strict-doctype')),
	('svg', xml_literal_kind_rows_ref('svg-doctype'));

CREATE OR REPLACE
FUNCTION xml_lang_doctype(doc_lang_name_refs)
RETURNS doc_node_kind_refs AS $$
		SELECT type_ FROM xml_lang_doctypes WHERE lang_ = $1
$$ LANGUAGE sql;

*/

-- * html tags

-- NOTE: This only handles very plain html.
-- At some point we need to accommodate other (x)html dialects.

-- We need to design a set of environment properties
-- which make it easy to classify tags for xml schema validation.
-- What we have now is the very rough notion of 'env_xml_kind_type':

--	values for 'env_xml_kind_type':
SELECT declare_name(
	'xml-doc',										-- top-level fixed document structure
	'html-block',								-- for html block element tags
	'html-inline',								-- html inline element tags
	'html-other'								-- other non-top-level html tags
);

SELECT declare_tagenv(
	'html-lang-env', _lang_ := 'html', _kind_ := 'xml-doc'
);

SELECT declare_tagenv('html-doc', 'html-lang-env');
-- the set of xml tags comprising the document, not allowed
-- inside of an html element

SELECT declare_tagenv('html-child', 'html-lang-env');
-- the set of xml tags which must be direct children
-- of an html element, i.e. head, body

SELECT declare_tagenv('html-head', 'html-lang-env');
-- tags allowed within html head elements

SELECT declare_tagenv('html-body', 'html-lang-env');
-- tags allowed within html body elements

SELECT declare_tagenv(
	'html-anywhere', 'html-lang-env', 'html-other'
);	-- tags allowed in html head or body

SELECT declare_tagenv(
	'html-div', 'html-body',  'html-block'
);	-- the set of xml tags formatted vertically by default

SELECT declare_tagenv(
	'html-span', 'html-body', 'html-inline'
);	-- the set of xml tags allowed within horizontally flowing text
-- they can only have xml text or other html-span children

SELECT declare_tagenv('html-dd', 'html-div');
-- the set of xml tags which must be immediate children of a dd
-- element, i.e. dt, dd

SELECT declare_tagenv('html-list', 'html-div');
-- the set of xml tags which must be immediate children of an
-- html list element, i.e. li

SELECT declare_tagenv(
	'html-table', 'html-body', 'html-other'
);	-- the set of xml tags involved in tables

SELECT declare_tagenv(
	'html-form', 'html-body', 'html-other'
);	-- the set of xml tags involved in forms

-- ** the tags

SELECT xml_env_tags('html-doc', 'html');

SELECT xml_env_tags('html-child', 'head', 'body');

SELECT xml_env_tags('html-head', 'title', 'link', 'style');

SELECT xml_env_tags('html-anywhere', 'meta', 'script');

SELECT xml_env_tags('html-body', -- can we be more specific??
	'noscript', 'bdo', 'ins', 'del', 'pre', 'area', 'map', 'param'
);

SELECT xml_env_tags('html-div', 'div', 'p', 'blockquote');

SELECT xml_env_tags('html-div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6');

SELECT xml_env_tags('html-div', 'ol', 'ul', 'dl');

SELECT xml_env_tags('html-list', 'li');

SELECT xml_env_tags('html-dd', 'dt', 'dd');

SELECT xml_env_tags('html-div', 'table');

SELECT xml_env_tags('html-table',
	'tr', 'td', 'th', 'tbody', 'thead', 'tfoot', 'col', 'colgroup', 'caption'
);

SELECT xml_env_tags('html-div', 'form');

SELECT xml_env_tags('html-form',
	'input', 'textarea', 'select', 'option', 'optgroup',
	'button', 'label', 'fieldset', 'legend'
);

-- these can appear inside of text - are they -div or -span type???
SELECT xml_env_tags('html-div', 'br', 'hr');

SELECT xml_env_tags('html-span',
	'object',
	'span', 'a', 'base', 'abbr', 'acronym', 'address', 'img', 'q',
	'sub', 'sup'
);

SELECT xml_env_tags('html-span',
	'tt', 'em', 'b', 'i', 'big', 'small', 'strong', 'kbd', 'cite',
	'var', 'dfn', 'code', 'samp'
);


CREATE OR REPLACE
FUNCTION html_tag(xml_tag_name_refs)
RETURNS xml_tag_refs AS $$
		SELECT find_xml_tag($1)
$$ LANGUAGE sql;


DELETE FROM html_no_close_tags;
INSERT INTO html_no_close_tags(tag, lang) VALUES
	( html_tag('br'), 'html' ), ( html_tag('hr'), 'html' ),
	( html_tag('img'), 'html' ), ( html_tag('link'), 'html' ),
	( html_tag('meta'), 'html' ), ( html_tag('input'), 'html' ),
	( html_tag('param'), 'html' );

-- I've fixed it so that a short close is only
-- considered for XHTML dialects, so this
-- list may be too long.  Alternatively, it may
-- be necessary to add a column for language
-- family if HTML dialects get less consistent!!
DELETE FROM xhtml_long_close_tags;
INSERT INTO xhtml_long_close_tags VALUES
	(html_tag('script')),
	(html_tag('object'));

-- * dynamic kinds for adding code to html elements
	
-- these should really be in S7_wicci, but they are used
-- in xml-import-code-test; sigh!!

SELECT create_dynamic_kind('html_head_extra');

SELECT create_dynamic_kind_text_method(
	'html_head_extra', $$
	SELECT $head$
		<link rel="stylesheet" type="text/css" media="screen" href="http://wicci.org/CSS/wicci4screen.css" />
		<style type="text/css">
			<!--
				.wi_hide { display: none; }
			-->
		</style>
	$head$::text
$$);

SELECT create_dynamic_kind('html_body_top');

SELECT create_dynamic_kind_text_method(
	'html_body_top', $$
	SELECT $body_top$
		<ul id="wi_panel" class="wi_menu wi wi_hide">
			<li id="wi_panel_home" class="wi_icon wi">
					<object class="wi_image wi" data="Theme/wicci-home.svg">
					</object>
			</li>
		</ul>
		<div id="wi_toggle_parent" class="wi wi_show">
			<object id="wi_toggle_image" class="wi_image wi"
							data="Theme/wicci-toggle.svg"
							type="image/svg+xml">
			</object> 
			<div id="wi_toggle" class="wi_jigger wi" title="Wicci Toggle"> </div>
		</div>																										 <!-- wi_panel -->
	$body_top$::text
$$);

SELECT create_dynamic_kind('html_body_extra');

SELECT create_dynamic_kind_text_method(
	'html_body_extra', $$
	SELECT $body_extra$
		<div id="wi_stash"  class="wi_hide">
			<h2> This section hidden in production version</h2>
			<dl>
				<dt> Wicci Inline Controls </dt>
				<dd id="wi_inline_controls_stash">
					<span id="wi_inline_controls" class="wi_controls wi">
						<span id="wi_inline_controls_0" class="wi_group wi">
							<span id="wi_inline_move_up" class="wi_move wi_control wi" title="move up">&uArr; </span>
							<span id="wi_inilne_move_dn" class="wi_move wi_control wi" title="move down">&dArr; </span>
							<span id="wi_inline_more_0" class="wi_next wi_control wi" title="more">&raquo; </span>
						</span>
						<span id="wi_inline_controls_1" class="wi_group wi">
							<span id="wi_inline_back_1" class="wi_prev wi_control wi" title="back">&laquo; </span>
							<span id="wi_inline_add_above" class="wi_add wi_control wi" title="add above">+&uarr; </span>
							<span id="wi_inline_add_below" class="wi_add wi_control wi" title="add below">+&darr; </span>
							<span id="wi_inline_delete" class="wi_delete wi_control wi" title="delete">&times; </span>
						</span>
					</span>
				</dd>
			</dl>
		</div>											<!-- wi_stash -->
		<script src="JS/jquery.js" type="text/javascript"></script>
		<script src="JS/tooltip.js" type="text/javascript"></script>
		<script src="JS/cci.js" type="text/javascript"></script>
		<script src="JS/wi.js" type="text/javascript"></script>
	$body_extra$::text
$$);
