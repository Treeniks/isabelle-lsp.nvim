-- setting false means "don't do any highlighting for this group"
local hl_group_map = {
    ['background_unprocessed1'] = false,
    ['background_running1'] = false,
    ['background_canceled'] = false,
    ['background_bad'] = false,
    ['background_intensify'] = false,
    ['background_markdown_bullet1'] = 'markdownH1',
    ['background_markdown_bullet2'] = 'markdownH2',
    ['background_markdown_bullet3'] = 'markdownH3',
    ['background_markdown_bullet4'] = 'markdownH4',
    ['foreground_quoted'] = false,
    ['text_main'] = 'Normal',
    ['text_quasi_keyword'] = 'Keyword',
    ['text_free'] = 'Function',
    ['text_bound'] = 'Identifier',
    ['text_inner_numeral'] = false,
    ['text_inner_quoted'] = 'String',
    ['text_comment1'] = 'Comment',
    ['text_comment2'] = false, -- seems to not exist in the LSP
    ['text_comment3'] = false,
    ['text_dynamic'] = false,
    ['text_class_parameter'] = false,
    ['text_antiquote'] = 'Comment',
    ['text_raw_text'] = 'Comment',
    ['text_plain_text'] = 'String',
    ['text_overview_unprocessed'] = false,
    ['text_overview_running'] = 'Bold',
    ['text_overview_error'] = false,
    ['text_overview_warning'] = false,
    ['dotted_writeln'] = false,
    ['dotted_warning'] = "DiagnosticWarn",
    ['dotted_information'] = false,
    ['spell_checker'] = 'Underlined',
    -- currently unused by isabelle-emacs
    -- but will probably be used once my Language Server chages get merged into Isabelle
    ['text_inner_cartouche'] = false,
    ['text_var'] = 'Function',
    ['text_skolem'] = 'Identifier',
    ['text_tvar'] = 'Type',
    ['text_tfree'] = 'Type',
    ['text_operator'] = 'Function',
    ['text_improper'] = 'Keyword',
    ['text_keyword3'] = 'Keyword',
    ['text_keyword2'] = 'Keyword',
    ['text_keyword1'] = 'Keyword',
    ['foreground_antiquoted'] = false,
}

local default_config = {
    isabelle_path = 'isabelle',
    vsplit = false,
    sh_path = 'sh', -- only relevant for Windows
    unicode_symbols_output = false,
    unicode_symbols_edits = false,
    hl_group_map = hl_group_map,
}

return default_config
