local configs = require 'lspconfig.configs'
local util = require 'lspconfig.util'

local M = {}

local function get_uri_from_fname(fname)
    return vim.uri_from_fname(util.path.sanitize(fname))
end

local function send_message(message, payload)
    local clients = vim.lsp.get_active_clients { name = 'isabelle' }
    for _, client in ipairs(clients) do
        client.request('PIDE/' .. message, payload, function(err)
            if err then
                error(tostring(err))
            end
        end, 0)
    end
end

local function caret_update(bufnr)
    bufnr = util.validate_bufnr(bufnr)

    local fname = vim.api.nvim_buf_get_name(bufnr)
    local pos = vim.api.nvim_win_get_cursor(0)

    if fname and pos then
        local uri = get_uri_from_fname(fname)
        send_message('caret_update', { uri = uri, line = pos[1] - 1, character = pos[2] - 1 })
    end
end

local function preview_request(bufnr)
    bufnr = util.validate_bufnr(bufnr)

    local fname = vim.api.nvim_buf_get_name(bufnr)

    if fname then
        local uri = get_uri_from_fname(fname)
        send_message('preview_request', { uri = uri, column = 1 })
    end
end

local function state_init()
    send_message('state_init', nil)
end

local function state_update(id)
    send_message('state_update', { id = id })
end

local function set_message_margin(size)
    send_message('set_message_margin', { value = size })
end

local function find_buffer_by_uri(uri)
    for _, bufnr in ipairs(vim.fn.getbufinfo({ bufloaded = 1 })) do
        local bufname = vim.fn.bufname(bufnr.bufnr)
        -- get the full path of the buffer's file
        -- bufname will typically only be the filename
        local fname = vim.fn.fnamemodify(bufname, ":p")
        local bufuri = get_uri_from_fname(fname)

        if bufuri == uri then
            return bufnr.bufnr
        end
    end
    return nil
end

local function apply_config(isabelle_path, vsplit)
    local output_window
    local output_buffer

    local hl_group_map = {
        ['background_unprocessed1'] = nil,
        ['background_running1'] = nil,
        ['background_canceled'] = nil,
        ['background_bad'] = nil,
        ['background_intensify'] = nil,
        ['background_markdown_bullet1'] = 'markdownH1',
        ['background_markdown_bullet2'] = 'markdownH2',
        ['background_markdown_bullet3'] = 'markdownH3',
        ['background_markdown_bullet4'] = 'markdownH4',
        ['foreground_quoted'] = nil,
        ['text_main'] = 'Normal',
        ['text_quasi_keyword'] = 'Keyword',
        ['text_free'] = 'Function',
        ['text_bound'] = 'Identifier',
        ['text_inner_numeral'] = nil,
        ['text_inner_quoted'] = 'String',
        ['text_comment1'] = 'Comment',
        ['text_comment2'] = nil, -- seems to not exist in the LSP
        ['text_comment3'] = nil,
        ['text_dynamic'] = nil,
        ['text_class_parameter'] = nil,
        ['text_antiquote'] = 'Comment',
        ['text_raw_text'] = 'Comment',
        ['text_plain_text'] = 'String',
        ['text_overview_unprocessed'] = nil,
        ['text_overview_running'] = 'Todo',
        ['text_overview_error'] = nil,
        ['text_overview_warning'] = nil,
        ['dotted_writeln'] = nil,
        ['dotted_warning'] = "DiagnosticWarn",
        ['dotted_information'] = nil,
        ['spell_checker'] = 'Underlined',
    }

    local hl_group_namespace_map = {}

    -- create namespaces for syntax highlighting
    for group, _ in pairs(hl_group_map) do
        local id = vim.api.nvim_create_namespace('isabelle-lsp.' .. group)
        hl_group_namespace_map[group] = id
    end

    configs.isabelle = {
        default_config = {
            cmd = {
                isabelle_path, 'vscode_server',
                '-o', 'vscode_unicode_symbols',
                '-o', 'vscode_pide_extensions',
                '-o', 'vscode_html_output=false',
                -- '-v',
                -- '-L', '~/Documents/isa.log',
            },
            filetypes = { 'isabelle' },
            root_dir = function(fname)
                -- TODO we should be searching for a ROOT file here
                -- and only use this as a fallback
                -- or better yet: prompt the user like isabelle-emacs does
                --
                -- :h gets us the path to the current file's directory
                return vim.fn.fnamemodify(fname, ':h')
            end,
            single_file_support = true,
            on_attach = function(client, bufnr)
                vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                    buffer = bufnr,
                    callback = function(info)
                        -- TODO use info instead of grabbing the cursors position through the bufnr
                        caret_update(bufnr)
                    end,
                })

                -- only create output buffer if it doesn't exist yet
                -- otherwise reuse it
                if not output_buffer then
                    -- create a new scratch buffer for output & state
                    output_buffer = vim.api.nvim_create_buf(true, true)
                    vim.api.nvim_buf_set_name(output_buffer, "--OUTPUT--")
                    vim.api.nvim_buf_set_option(output_buffer, 'buftype', 'nofile')
                    vim.api.nvim_buf_set_option(output_buffer, 'bufhidden', 'hide')
                    vim.api.nvim_buf_set_option(output_buffer, 'swapfile', false)
                    vim.api.nvim_buf_set_option(output_buffer, 'buflisted', false)
                    vim.api.nvim_buf_set_option(output_buffer, 'filetype', 'scratch-output')

                    -- set the content of the output buffer
                    vim.api.nvim_buf_set_lines(output_buffer, 0, -1, false, {})

                    -- place the output buffer
                    if vsplit then
                        vim.api.nvim_command('vsplit')
                        vim.api.nvim_command('wincmd l')
                    else
                        vim.api.nvim_command('split')
                        vim.api.nvim_command('wincmd j')
                    end
                    vim.api.nvim_set_current_buf(output_buffer)
                    output_window = vim.api.nvim_get_current_win()

                    -- make the output buffer automatically quit
                    -- if it's the last buffer
                    vim.api.nvim_create_autocmd({ "BufEnter" }, {
                        buffer = output_buffer,
                        callback = function(info)
                            if #vim.api.nvim_list_wins() == 1 then
                                vim.cmd "quit"
                            end
                        end,
                    })

                    -- put focus back on main buffer
                    if vsplit then
                        vim.api.nvim_command('wincmd h')
                    else
                        vim.api.nvim_command('wincmd k')
                    end

                    -- TODO update on change
                    local width = vim.api.nvim_win_get_width(output_window)
                    set_message_margin(width)
                end
            end,
            handlers = {
                ['PIDE/dynamic_output'] = function(err, result, ctx, config)
                    local lines = {}
                    for s in result.content:gmatch("[^\r\n]+") do
                        table.insert(lines, s)
                    end
                    vim.api.nvim_buf_set_lines(output_buffer, 0, -1, false, lines)
                end,
                ['PIDE/decoration'] = function(err, result, ctx, config)
                    local decorator = function(hl_group, content, syn_id, bufnr)
                        for _, range in ipairs(content) do
                            local start_line = range.range[1]
                            local start_col = range.range[2]
                            local end_line = range.range[3]
                            local end_col = range.range[4]

                            -- it can happen that one changes the buffer while the LSP sends a decoration message
                            -- and then the decorations in the message apply to text that was just deleted
                            -- in which case vim.api.nvim_buf_set_extmark fails
                            --
                            -- thus we use pcall to suppress errors if they occur, as they are disrupting and not of importance
                            local success, _ = pcall(vim.api.nvim_buf_set_extmark, bufnr, syn_id, start_line, start_col,
                                { hl_group = hl_group, end_line = end_line, end_col = end_col })
                            if not success then
                                -- we do however write a message to the status line just in case
                                print("Failed to apply decoration")
                            end
                        end
                    end

                    local thy_buffer = find_buffer_by_uri(result.uri)

                    if thy_buffer then
                        for _, entry in ipairs(result.entries) do
                            local hl_group = hl_group_map[entry.type]
                            local id = hl_group_namespace_map[entry.type]
                            if hl_group and id then
                                vim.api.nvim_buf_clear_namespace(thy_buffer, id, 0, -1)
                                decorator(hl_group, entry.content, id, thy_buffer)
                            end
                        end
                    end
                end,
            },
        },
        commands = {
            -- these are just for debug purposes
            StateInit = {
                function()
                    state_init()
                end,
            },
            StateUpdate = {
                function()
                    state_update(-1)
                end,
            },
            -- TODO maybe this can be useful
            -- PreviewRequest = {
            --     function()
            --         preview_request(thy_buffer)
            --     end,
            -- },
            SetMessageMargin = {
                function()
                    local width = vim.api.nvim_win_get_width(output_window)
                    set_message_margin(width)
                end
            },
        },
        docs = {
            description = [[
Isabelle VSCode Language Server
]],
        },
    }
end

M.setup = function(user_config)
    local isabelle_path = user_config['isabelle_path']
    if not isabelle_path then
        isabelle_path = 'isabelle'
    end

    local vsplit = user_config['vsplit']
    -- technically not needed
    -- but for transparency
    if not vsplit then
        vsplit = false
    end

    apply_config(isabelle_path, vsplit)
end

return M
