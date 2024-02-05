local configs = require 'lspconfig.configs'
local util = require 'lspconfig.util'

local M = {}

local is_windows = vim.loop.os_uname().version:match 'Windows'

local function get_uri_from_fname(fname)
    return vim.uri_from_fname(util.path.sanitize(fname))
end

local function find_buffer_by_uri(uri)
    for _, buf in ipairs(vim.fn.getbufinfo({ bufloaded = 1 })) do
        local bufname = vim.fn.bufname(buf.bufnr)
        -- get the full path of the buffer's file
        -- bufname will typically only be the filename
        local fname = vim.fn.fnamemodify(bufname, ":p")
        local bufuri = get_uri_from_fname(fname)

        if bufuri == uri then
            return buf.bufnr
        end
    end
    return nil
end

local function send_message(client, message, payload)
    client.request('PIDE/' .. message, payload, function(err)
        if err then
            error(tostring(err))
        end
    end, 0)
end

local function send_message_to_all(message, payload)
    local clients = vim.lsp.get_active_clients { name = 'isabelle' }
    for _, client in ipairs(clients) do
        send_message(client, message, payload)
    end
end

-- assumes `client` is the client associated with the current window's buffer
local function caret_update(client)
    local bufnr = vim.api.nvim_get_current_buf()
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local uri = get_uri_from_fname(fname)

    local win = vim.api.nvim_get_current_win()
    local pos = vim.api.nvim_win_get_cursor(win)

    send_message(client, 'caret_update', { uri = uri, line = pos[1] - 1, character = pos[2] - 1 })
end

local function set_message_margin(client, size)
    send_message(client, 'set_message_margin', { value = size })
end

local function apply_config(cmd, vsplit)
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
            -- requires isabelle path to look something like this:
            -- /c/isabelle/isabelle-emacs/bin/isabelle
            -- then uses msys2 sh (or bash/fish alternatively) to run isabelle
            -- to use WSL instead, replace with bash and add '/mnt' in front of the path
            -- be aware that WSL will force a bash alias, so getting msys2's bash to work
            -- when WSL is installed requires a full path
            cmd = cmd,
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
                        caret_update(client)
                    end,
                })

                -- only create output buffer if it doesn't exist yet
                -- otherwise reuse it
                if not output_window then
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

                    -- place the output window
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
                    -- if it's the last window
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
                    set_message_margin(client, width)
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
                                vim.notify("Failed to apply decoration")
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
                            else
                                vim.notify("Could not find hl_group " .. entry.type .. ".")
                            end
                        end
                    else
                        vim.notify("Could not find buffer for " .. result.uri .. ".")
                    end
                end,
            },
        },
        commands = {},
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

    local cmd

    if not is_windows then
        cmd = {
            isabelle_path, 'vscode_server',
            '-o', 'vscode_unicode_symbols',
            '-o', 'vscode_pide_extensions',
            '-o', 'vscode_html_output=false',

            -- for logging
            -- '-v',
            -- '-L', '~/Documents/isabelle/isabelle-lsp.log',
        }
    else -- windows cmd
        local sh_path = user_config['sh_path']
        if not sh_path then
            sh_path = 'sh'
        end

        cmd = {
            sh_path, '-c',
            'cd ' ..
            util.path.dirname(isabelle_path) ..
            ' && ./isabelle vscode_server -o vscode_unicode_symbols -o vscode_pide_extensions -o vscode_html_output=false',

            -- for logging
            -- it is not possible to set the log file via a full-path for windows because Isabelle refuses ':' in paths...
            -- 'cd ' .. util.path.dirname(isabelle_path) .. ' && ./isabelle vscode_server -o vscode_unicode_symbols -o vscode_pide_extensions -o vscode_html_output=false -v -L "isabelle-lsp.log"',
        }
    end

    apply_config(cmd, vsplit)
end

return M
