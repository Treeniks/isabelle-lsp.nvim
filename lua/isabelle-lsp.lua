-- vi: foldmethod=marker

local configs = require('lspconfig.configs')
local util = require('lspconfig.util')

local defaults = require('defaults')

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

local function send_request(client, method, payload, callback)
    client.request('PIDE/' .. method, payload, function(err, result)
        if err then
            error(tostring(err))
        end

        callback(result)
    end, 0)
end

local function send_notification(client, method, payload)
    send_request(client, method, payload, function(_) end)
end

local function send_notification_to_all(method, payload)
    local clients = vim.lsp.get_clients({ name = 'isabelle' })
    for _, client in ipairs(clients) do
        send_notification(client, method, payload)
    end
end

-- assumes `client` is the client associated with the current window's buffer
local function caret_update(client)
    -- {{{
    local bufnr = vim.api.nvim_get_current_buf()
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local uri = get_uri_from_fname(fname)

    local win = vim.api.nvim_get_current_win()
    local line, col = unpack(vim.api.nvim_win_get_cursor(win))
    -- required becuase win_get_cursor is (1, 0) indexed -.-
    line = line - 1

    -- convert to char index for Isabelle
    local line_s = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1]
    -- the extra space is so that it still gives us a correct column
    -- even if the cursor is in insert mode at the end of the line
    col = vim.fn.charidx(line_s .. " ", col)

    send_notification(client, 'caret_update', { uri = uri, line = line, character = col })
    -- }}}
end

-- may return nil if there are no windows with that buffer
local function get_min_width(bufnr)
    -- {{{
    local windows = vim.fn.win_findbuf(bufnr)
    local min_width
    for _, window in ipairs(windows) do
        local width = vim.api.nvim_win_get_width(window)
        if not min_width or min_width < width then
            min_width = width
        end
    end
    return min_width
    -- }}}
end

local function set_output_margin(client, size)
    if size then
        -- the `- 8` is for some headroom
        send_notification(client, 'output_set_margin', { margin = size - 8 })
    end
end

local function set_state_margin(client, id, size)
    if size then
        -- the `- 8` is for some headroom
        send_notification(client, 'state_set_margin', { id = id, margin = size - 8 })
    end
end

local function convert_symbols(client, bufnr, text)
    -- {{{
    send_request(
        client,
        "symbols_convert_request",
        { text = text, unicode = true },
        function(t)
            local lines = {}
            for s in t.text:gmatch("([^\r\n]*)\n?") do
                table.insert(lines, s)
            end
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        end
    )
    -- }}}
end

local function apply_decoration(bufnr, hl_group, syn_id, content)
    -- {{{
    for _, range in ipairs(content) do
        -- range.range has the following format:
        -- {start_line, start_column, end_line, end_column}
        -- where all values are character indexes, not byte indexes
        local start_line = range.range[1]
        local start_col = range.range[2]
        local end_line = range.range[3]
        local end_col = range.range[4]

        -- convert indexes to byte indexes
        local sline = vim.api.nvim_buf_get_lines(bufnr, start_line, start_line + 1, false)[1]
        start_col = vim.fn.byteidx(sline, start_col)
        local eline = vim.api.nvim_buf_get_lines(bufnr, end_line, end_line + 1, false)[1]
        end_col = vim.fn.byteidx(eline, end_col)

        -- it can happen that one changes the buffer while the LSP sends a decoration message
        -- and then the decorations in the message apply to text that was just deleted
        -- in which case vim.api.nvim_buf_set_extmark fails
        --
        -- thus we use pcall to suppress errors if they occur, as they are disrupting and not of importance
        local _ = pcall(vim.api.nvim_buf_set_extmark, bufnr, syn_id, start_line, start_col,
            { hl_group = hl_group, end_line = end_line, end_col = end_col })
    end
    -- }}}
end

local function apply_config(config)
    local hl_group_namespace_map = {}
    -- create namespaces for syntax highlighting
    for group, _ in pairs(config.hl_group_map) do
        local id = vim.api.nvim_create_namespace('isabelle-lsp.' .. group)
        hl_group_namespace_map[group] = id
    end

    local output_namespace = vim.api.nvim_create_namespace('isabelle-lsp.dynamic_output')

    -- set up the cmd to run isabelle's language server
    local cmd
    -- {{{
    if not is_windows then
        cmd = {
            config.isabelle_path, 'vscode_server',
            '-o', 'vscode_pide_extensions',
            '-o', 'vscode_html_output=false',
            '-o', 'editor_output_state',

            -- for logging
            '-v',
            '-L', '~/Documents/isabelle/isabelle-lsp.log',
        }

        if config.unicode_symbols_output then
            table.insert(cmd, '-o')
            table.insert(cmd, 'vscode_unicode_symbols_output')
        end

        if config.unicode_symbols_edits then
            table.insert(cmd, '-o')
            table.insert(cmd, 'vscode_unicode_symbols_edits')
        end
    else -- windows cmd
        local unicode_options_output = ''
        if config.unicode_symbols_output then
            unicode_options_output = ' -o vscode_unicode_symbols_output'
        end

        local unicode_option_edits = ''
        if config.unicode_symbols_edits then
            unicode_option_edits = ' -o vscode_unicode_symbols_edits'
        end

        cmd = {
            config.sh_path, '-c',
            'cd ' ..
            util.path.dirname(config.isabelle_path) ..
            ' && ./isabelle vscode_server -o vscode_pide_extensions -o vscode_html_output=false -o editor_output_state' ..
            unicode_options_output .. unicode_option_edits,

            -- for logging
            -- it is not possible to set the log file via a full-path for windows because Isabelle refuses ':' in paths...
            -- 'cd ' .. util.path.dirname(isabelle_path) .. ' && ./isabelle vscode_server -o vscode_unicode_symbols -o vscode_pide_extensions -o vscode_html_output=false -v -L "isabelle-lsp.log"',
        }
    end
    -- }}}

    local output_buffer
    local state_buffers = {}

    configs.isabelle = {
        default_config = {
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
                    callback = function(_)
                        caret_update(client)
                    end,
                })

                -- only create output buffer if it doesn't exist yet
                -- otherwise reuse it
                if not output_buffer then
                    -- create a new scratch buffer for output & state
                    output_buffer = vim.api.nvim_create_buf(true, true)
                    vim.api.nvim_buf_set_name(output_buffer, "--OUTPUT--")
                    vim.api.nvim_set_option_value('filetype', 'isabelle_output', { buf = output_buffer })

                    -- set the content of the output buffer
                    vim.api.nvim_buf_set_lines(output_buffer, 0, -1, false, {})

                    -- TODO replace with nvim_open_win()
                    -- place the output window
                    if config.vsplit then
                        vim.api.nvim_command('vsplit')
                        vim.api.nvim_command('wincmd l')
                    else
                        vim.api.nvim_command('split')
                        vim.api.nvim_command('wincmd j')
                    end
                    vim.api.nvim_set_current_buf(output_buffer)

                    -- make the output buffer automatically quit
                    -- if it's the last window
                    vim.api.nvim_create_autocmd({ "BufEnter" }, {
                        buffer = output_buffer,
                        callback = function(_)
                            if #vim.api.nvim_list_wins() == 1 then
                                vim.cmd "quit"
                            end
                        end,
                    })

                    -- put focus back on main buffer
                    if config.vsplit then
                        vim.api.nvim_command('wincmd h')
                    else
                        vim.api.nvim_command('wincmd k')
                    end

                    local min_width = get_min_width(output_buffer)
                    set_output_margin(client, min_width)
                end

                -- handle resizes of output buffers
                vim.api.nvim_create_autocmd('WinResized', {
                    callback = function(_)
                        local min_width = get_min_width(output_buffer)
                        set_output_margin(client, min_width)
                    end,
                })
            end,
            handlers = {
                ['PIDE/dynamic_output'] = function(_, params, _, _)
                    -- {{{
                    if not output_buffer then return end

                    local lines = {}
                    -- this regex makes sure that empty lines are still kept
                    for s in params.content:gmatch("([^\r\n]*)\n?") do
                        table.insert(lines, s)
                    end
                    vim.api.nvim_buf_set_lines(output_buffer, 0, -1, false, lines)

                    -- clear all decorations
                    vim.api.nvim_buf_clear_namespace(output_buffer, output_namespace, 0, -1)

                    for _, dec in ipairs(params.decorations) do
                        local hl_group = config.hl_group_map[dec.type]

                        -- if hl_group is nil, it means the hl_group_map doesn't know about this group
                        if hl_group == nil then
                            -- in particular, hl_group is nil here too
                            vim.notify("Could not find hl_group " .. dec.type .. ".")
                            goto continue
                        end

                        -- if hl_group is false, it just means there is no highlighting done for this group
                        if hl_group == false then goto continue end

                        apply_decoration(output_buffer, hl_group, output_namespace, dec.content)

                        ::continue::
                    end
                    -- }}}
                end,
                ['PIDE/decoration'] = function(_, params, _, _)
                    -- {{{
                    local bufnr = find_buffer_by_uri(params.uri)

                    if not bufnr then
                        vim.notify("Could not find buffer for " .. params.uri .. ".")
                        return
                    end

                    for _, entry in ipairs(params.entries) do
                        local syn_id = hl_group_namespace_map[entry.type]
                        local hl_group = config.hl_group_map[entry.type]

                        -- if id is nil, it means the hl_group_map doesn't know about this group
                        if not syn_id then
                            -- in particular, hl_group is nil here too
                            vim.notify("Could not find hl_group " .. entry.type .. ".")
                            goto continue
                        end

                        -- if hl_group is false, it just means there is no highlighting done for this group
                        if not hl_group then goto continue end

                        vim.api.nvim_buf_clear_namespace(bufnr, syn_id, 0, -1)
                        apply_decoration(bufnr, hl_group, syn_id, entry.content)

                        ::continue::
                    end
                    -- }}}
                end,
                ['PIDE/state_output'] = function(_, params, _, _)
                    -- {{{
                    local id = params.id
                    local buf = state_buffers[id]

                    local lines = {}
                    -- this regex makes sure that empty lines are still kept
                    for s in params.content:gmatch("([^\r\n]*)\n?") do
                        table.insert(lines, s)
                    end
                    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

                    -- clear all decorations
                    vim.api.nvim_buf_clear_namespace(buf, output_namespace, 0, -1)

                    for _, dec in ipairs(params.decorations) do
                        local hl_group = config.hl_group_map[dec.type]

                        -- if hl_group is nil, it means the hl_group_map doesn't know about this group
                        if hl_group == nil then
                            -- in particular, hl_group is nil here too
                            vim.notify("Could not find hl_group " .. dec.type .. ".")
                            goto continue
                        end

                        -- if hl_group is false, it just means there is no highlighting done for this group
                        if hl_group == false then goto continue end

                        apply_decoration(buf, hl_group, output_namespace, dec.content)

                        ::continue::
                    end
                    -- }}}
                end,
            },
        },
        commands = {
            StateInit = {
                -- {{{
                function()
                    local clients = vim.lsp.get_clients({ name = 'isabelle' })

                    for _, client in ipairs(clients) do
                        send_request(client, 'state_init', {}, function(result)
                            local id = result.state_id

                            local new_buf = vim.api.nvim_create_buf(true, true)
                            vim.api.nvim_buf_set_name(new_buf, "--STATE-- " .. id)
                            vim.api.nvim_set_option_value('filetype', 'isabelle_output', { buf = new_buf })

                            vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, {})

                            -- place the state window
                            vim.api.nvim_command('vsplit')
                            vim.api.nvim_command('wincmd l')

                            vim.api.nvim_set_current_buf(new_buf)

                            -- put focus back on main buffer
                            vim.api.nvim_command('wincmd h')

                            local min_width = get_min_width(new_buf)
                            set_state_margin(client, id, min_width)

                            -- handle resizes
                            vim.api.nvim_create_autocmd('WinResized', {
                                callback = function(_)
                                    local min_width2 = get_min_width(new_buf)
                                    set_state_margin(client, id, min_width2)
                                end,
                            })

                            state_buffers[id] = new_buf
                        end)
                    end
                end,
                -- }}}
            },
            SymbolsRequest = {
                -- {{{
                function()
                    send_notification_to_all("symbols_request", {})
                end,
                -- }}}
            },
            SymbolsConvert = {
                -- {{{
                function()
                    local clients = vim.lsp.get_clients({ name = 'isabelle' })
                    local buf = vim.api.nvim_get_current_buf()
                    local text = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                    local t = table.concat(text, '\n')
                    for _, client in ipairs(clients) do
                        convert_symbols(client, buf, t)
                    end
                end,
                -- }}}
            }

        },
        docs = {
            description = [[
Isabelle VSCode Language Server
]],
        },
    }
end

M.setup = function(user_config)
    -- use default_config instead of returning nil if a config value is not set in user_config
    local mt = { __index = function(_, k) return defaults[k] end }
    setmetatable(user_config, mt)

    apply_config(user_config)
end

return M
