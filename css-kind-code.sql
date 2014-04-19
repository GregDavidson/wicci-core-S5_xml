-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('xml-kind-code.sql', '$Id');

--	Wicci Project CSS kind & document import code

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** the kinds

-- *** css_root_kind_rows

CREATE OR REPLACE
FUNCTION css_root_kind()
RETURNS doc_node_kind_refs AS $$
	SELECT ref FROM css_root_kind_rows
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE FUNCTION css_root_kind_text(
	doc_node_kind_refs,
	env_refs = env_nil(), crefs = crefs_nil(), doc_node_refs[] = '{}'
) RETURNS text AS $$
	SELECT array_to_string( ARRAY(
		SELECT doc_node_text(x, $2, $3) FROM unnest($4) x
	), E'\n' )
$$ LANGUAGE SQL;

SELECT  type_class_op_method(
	'doc_node_kind_refs', 'css_root_kind_rows',
	'ref_env_crefs_chiln_text_op(refs, env_refs, crefs, doc_node_refs[])',
	'css_root_kind_text(
		doc_node_kind_refs, env_refs, crefs, doc_node_refs[]
	)'
);

-- *** css_set_kind_rows

CREATE OR REPLACE
FUNCTION try_get_css_set_kind(text)  
RETURNS doc_node_kind_refs AS $$
DECLARE
	_ref doc_node_kind_refs;
	kilroy_was_here boolean := false;
	this regprocedure
		:= 'try_get_css_set_kind(text)';
BEGIN
	LOOP
		SELECT ref INTO _ref FROM css_set_kind_rows WHERE path_ = $1;
		IF FOUND THEN RETURN _ref; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% % looping', this, $1;
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO css_set_kind_rows(ref, path_)
			VALUES(next_doc_node_kind( 'css_set_kind_rows' ), $1);
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % raised %!', this, $1, 'unique_violation';
		END;
	END LOOP;
END;
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION get_css_set_kind(text) 
RETURNS doc_node_kind_refs AS $$
	SELECT non_null(
		try_get_css_set_kind($1), 'get_css_set_kind(text)'
	)
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION css_set_kind_text(
	doc_node_kind_refs,
	env_refs = env_nil(), crefs = crefs_nil(), doc_node_refs[] = '{}'
) RETURNS text AS $$
	SELECT path_ || ' { ' || array_to_string( ARRAY(
		SELECT doc_node_text(x, $2, $3) FROM unnest($4) x
	), E'\n' )
	|| '}' FROM css_set_kind_rows WHERE ref = $1
$$ LANGUAGE SQL;

SELECT  type_class_op_method(
	'doc_node_kind_refs', 'css_set_kind_rows',
	'ref_env_crefs_chiln_text_op(refs, env_refs, crefs, doc_node_refs[])',
	'css_set_kind_text(
		doc_node_kind_refs, env_refs, crefs, doc_node_refs[]
	)'
);

-- *** css_property_kind_rows

CREATE OR REPLACE
FUNCTION try_get_css_property_kind(css_name_refs, refs) 
RETURNS doc_node_kind_refs AS $$
DECLARE
	_ref doc_node_kind_refs;
	kilroy_was_here boolean := false;
	this regprocedure
		:= 'try_get_css_property_kind(css_name_refs, refs)';
BEGIN
	LOOP
		SELECT ref INTO _ref FROM css_property_kind_rows
		WHERE name_ = $1 AND val_ = $2;
		IF FOUND THEN RETURN _ref; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% % looping', this, $1;
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO css_property_kind_rows(ref, name_, val_)
			VALUES(next_doc_node_kind( 'css_property_kind_rows' ), $1, $2);
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % % raised %!', this, $1, $2, 'unique_violation';
		END;
	END LOOP;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION get_css_property_kind(css_name_refs, refs)
RETURNS doc_node_kind_refs AS $$
	SELECT non_null(
		try_get_css_property_kind($1,$2),
		'get_css_property_kind(css_name_refs,refs)'
	)
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION css_property_kind_text(
	doc_node_kind_refs,
	env_refs = env_nil(), crefs = crefs_nil(), doc_node_refs[] = '{}'
) RETURNS text AS $$
	SELECT name_::text || ': ' ||
		ref_env_crefs_text_op(val_, $2, $3) || E';\n'
	FROM css_property_kind_rows WHERE ref = $1
$$ LANGUAGE SQL;

SELECT  type_class_op_method(
	'doc_node_kind_refs', 'css_property_kind_rows',
	'ref_env_crefs_chiln_text_op(refs, env_refs, crefs, doc_node_refs[])',
	'css_property_kind_text(
		doc_node_kind_refs, env_refs, crefs, doc_node_refs[]
	)'
);

-- ** the nodes

CREATE OR REPLACE
FUNCTION css_root_node( VARIADIC doc_node_refs[] = '{}' )
RETURNS doc_node_refs AS $$
	SELECT new_tree_node(css_root_kind(), VARIADIC $1)
	-- WHERE of_kind('css_set_kind_rows', $1)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION css_set_node( text, VARIADIC doc_node_refs[] = '{}' )
RETURNS doc_node_refs AS $$
	SELECT new_tree_node(get_css_set_kind($1), VARIADIC $2)
	-- WHERE of_kind('css_property_kind_rows', $2)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION css_property_node(css_name_refs, refs)
RETURNS doc_node_refs AS $$
	SELECT new_tree_node(get_css_property_kind($1, $2))
$$ LANGUAGE sql;

-- ** the docs

CREATE OR REPLACE
FUNCTION css_doc(text)
RETURNS doc_refs AS $$
	SELECT try_page_doc( try_page_uri($1) )
$$ LANGUAGE sql STRICT;

COMMENT ON FUNCTION css_doc(text)
IS 'In importing a css document, checks
if the document might already exist';

CREATE OR REPLACE
FUNCTION css_doc(text, VARIADIC doc_node_refs[])
RETURNS doc_refs AS $$
	SELECT get_page_doc(
		get_page_uri($1),
		new_tree_doc( css_root_node(VARIADIC $2), 'css' )
	)
$$ LANGUAGE sql STRICT;
-- a page_uri + a bunch of css_set nodes

CREATE OR REPLACE
FUNCTION css_path(VARIADIC text[]) RETURNS text AS $$
	SELECT array_to_string(
		ARRAY( SELECT str_trim(x) FROM unnest($1) x ), ' '
	)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION css_set(text, VARIADIC doc_node_refs[] = '{}')
RETURNS doc_node_refs AS $$
	SELECT css_set_node($1, VARIADIC $2)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION css_property(css_name_refs, VARIADIC text[])
RETURNS doc_node_refs AS $$
	SELECT css_property_node(
		$1,
		CASE WHEN array_length($2, 1) = 1 THEN get_text(($2)[1])
		ELSE get_text_join_tree(' ', VARIADIC ARRAY(
			SELECT get_text(x)::refs FROM unnest($2) x
		) )
		END
	)
$$ LANGUAGE sql STRICT;

SELECT declare_css_name(
'azimuth',
'background-attachment',
'background-color',
'background-image',
'background-position',
'background-repeat',
'background',
'border-collapse',
'border-color',
'border-spacing',
'border-style',
'border-top',
'border-top-color',
'border-top-style',
'border-top-width',
'border-width',
'border',
'bottom',
'caption-side',
'clear',
'clip',
'color',
'content',
'counter-increment',
'counter-reset',
'cue-after',
'cue-before',
'cue',
'cursor',
'direction',
'display',
'elevation',
'empty-cells',
'float',
'font-family',
'font-size',
'font-style',
'font-variant',
'font-weight',
'font',
'height',
'left',
'letter-spacing',
'line-height',
'list-style-image',
'list-style-position',
'list-style-type',
'list-style',
'margin-right',
'margin-top',
'margin',
'max-height',
'max-width',
'min-height',
'min-width',
'orphans',
'outline-color',
'outline-style',
'outline-width',
'outline',
'overflow',
'padding-top',
'padding',
'page-break-after',
'page-break-before',
'page-break-inside',
'pause-after',
'pause-before',
'pause',
'pitch-range',
'pitch',
'play-during',
'position',
'quotes',
'richness',
'right',
'speak-header',
'speak-numeral',
'speak-punctuation',
'speak',
'speech-rate',
'stress',
'table-layout',
'text-align',
'text-decoration',
'text-indent',
'text-transform',
'top',
'unicode-bidi',
'vertical-align',
'visibility',
'voice-family',
'volume',
'white-space',
'widows',
'width',
'word-spacing',
'z-index'
);

SELECT declare_css_name(
'alignment-adjust',
'alignment-baseline',
'animation',
'animation-delay',
'animation-direction',
'animation-duration',
'animation-iteration-count',
'animation-name',
'animation-play-state',
'animation-timing-function',
'appearance',
'azimuth'
);

SELECT declare_css_name(
'backface-visibility',
'background',
'background-attachment',
'background-break',
'background-clip',
'background-color',
'background-image',
'background-origin',
'background-position',
'background-repeat',
'background-size',
'baseline-shift',
'binding',
'bleed',
'bookmark-label',
'bookmark-level',
'bookmark-state',
'bookmark-target',
'border',
'border-bottom',
'border-bottom-color',
'border-bottom-left-radius',
'border-bottom-right-radius',
'border-bottom-style',
'border-bottom-width',
'border-collapse',
'border-color',
'border-image',
'border-image-outset',
'border-image-repeat',
'border-image-slice',
'border-image-source',
'border-image-width',
'border-left',
'border-left-color',
'border-left-style',
'border-left-width',
'border-radius',
'border-right',
'border-right-color',
'border-right-style',
'border-right-width',
'border-spacing',
'border-style',
'border-top',
'border-top-color',
'border-top-left-radius',
'border-top-right-radius',
'border-top-style',
'border-top-width',
'border-width',
'bottom',
'box-align',
'box-decoration-break',
'box-direction',
'box-flex',
'box-flex-group',
'box-lines',
'box-ordinal-group',
'box-orient',
'box-pack',
'box-shadow',
'box-sizing',
'break-after',
'break-before',
'break-inside'
);

SELECT declare_css_name(
'caption-side',
'clear',
'clip',
'color',
'color-profile',
'column-count',
'column-fill',
'column-gap',
'column-rule',
'column-rule-color',
'column-rule-style',
'column-rule-width',
'column-span',
'column-width',
'columns',
'content',
'counter-increment',
'counter-reset',
'crop',
'cue',
'cue-after',
'cue-before',
'cursor'
);

SELECT declare_css_name(
'direction',
'display',
'dominant-baseline',
'drop-initial-after-adjust',
'drop-initial-after-align',
'drop-initial-before-adjust',
'drop-initial-before-align',
'drop-initial-size',
'drop-initial-value'
);

SELECT declare_css_name(
'elevation',
'empty-cells',
'fit',
'fit-position',
'float',
'float-offset',
'font',
'font-family',
'font-size',
'font-size-adjust',
'font-stretch',
'font-style',
'font-variant',
'font-weight',
'grid-columns',
'grid-rows',
'hanging-punctuation',
'height',
'hyphenate-after',
'hyphenate-before',
'hyphenate-character',
'hyphenate-lines',
'hyphenate-resource',
'hyphens',
'icon',
'image-orientation',
'image-rendering',
'image-resolution',
'inline-box-align',
'left',
'letter-spacing',
'line-height',
'line-stacking',
'line-stacking-ruby',
'line-stacking-shift',
'line-stacking-strategy',
'list-style',
'list-style-image',
'list-style-position',
'list-style-type'
);

SELECT declare_css_name(
'margin',
'margin-bottom',
'margin-left',
'margin-right',
'margin-top',
'mark',
'mark-after',
'mark-before',
'marks',
'marquee-direction',
'marquee-play-count',
'marquee-speed',
'marquee-style',
'max-height',
'max-width',
'min-height',
'min-width',
'move-to',
'nav-down',
'nav-index',
'nav-left',
'nav-right',
'nav-up',
'opacity',
'orphans',
'outline',
'outline-color',
'outline-offset',
'outline-style',
'outline-width',
'overflow',
'overflow-style',
'overflow-x',
'overflow-y',
'padding',
'padding-bottom',
'padding-left',
'padding-right',
'padding-top',
'page',
'page-break-after',
'page-break-before',
'page-break-inside',
'page-policy',
'pause',
'pause-after',
'pause-before',
'perspective',
'perspective-origin',
'phonemes',
'pitch',
'pitch-range',
'play-during',
'position',
'presentation-level',
'punctuation-trim',
'quotes'
);

SELECT declare_css_name(
'rendering-intent',
'resize',
'rest',
'rest-after',
'rest-before',
'richness',
'right',
'rotation',
'rotation-point',
'ruby-align',
'ruby-overhang',
'ruby-position',
'ruby-span',
'size',
'speak',
'speak-header',
'speak-numeral',
'speak-punctuation',
'speech-rate',
'stress',
'string-set',
'table-layout',
'target',
'target-name',
'target-new',
'target-position',
'text-align',
'text-align-last',
'text-decoration',
'text-emphasis',
'text-height',
'text-indent',
'text-justify',
'text-outline',
'text-shadow',
'text-transform',
'text-wrap',
'top',
'transform',
'transform-origin',
'transform-style',
'transition',
'transition-delay',
'transition-duration',
'transition-property',
'transition-timing-function',
'unicode-bidi',
'vertical-align',
'visibility',
'voice-balance',
'voice-duration',
'voice-family',
'voice-pitch',
'voice-pitch-range',
'voice-rate',
'voice-stress',
'voice-volume',
'volume',
'white-space',
'white-space-collapse',
'widows',
'width',
'word-break',
'word-spacing',
'word-wrap',
'z-index'
);
