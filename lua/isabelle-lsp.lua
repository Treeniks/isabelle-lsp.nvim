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

local function send_notification(client, method, payload)
    client.request('PIDE/' .. method, payload, function(err)
        if err then
            error(tostring(err))
        end
    end, 0)
end

local function send_notification_to_all(method, payload)
    local clients = vim.lsp.get_active_clients { name = 'isabelle' }
    for _, client in ipairs(clients) do
        send_notification(client, method, payload)
    end
end

-- assumes `client` is the client associated with the current window's buffer
local function caret_update(client)
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
end

local function set_message_margin(client, size)
    -- the `- 8` is for some headroom
    send_notification(client, 'set_message_margin', { value = size - 8 })
end

local function apply_decoration(bufnr, hl_group, syn_id, content)
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
        local success, _ = pcall(vim.api.nvim_buf_set_extmark, bufnr, syn_id, start_line, start_col,
            { hl_group = hl_group, end_line = end_line, end_col = end_col })
        if not success then
            -- we do however write a message to the status line just in case
            vim.notify("Failed to apply decoration.")
        end
    end
end

local function apply_config(config)
    local hl_group_namespace_map = {}
    -- create namespaces for syntax highlighting
    for group, _ in pairs(config.hl_group_map) do
        local id = vim.api.nvim_create_namespace('isabelle-lsp.' .. group)
        hl_group_namespace_map[group] = id
    end

    local cmd
    if not is_windows then
        cmd = {
            config.isabelle_path, 'vscode_server',
            '-o', 'vscode_pide_extensions',
            '-o', 'vscode_html_output=false',
            '-o', 'editor_output_state',

            -- for logging
            -- '-v',
            -- '-L', '~/Documents/isabelle/isabelle-lsp.log',
        }

        if config.unicode_symbols then
            table.insert(cmd, '-o')
            table.insert(cmd, 'vscode_unicode_symbols')
        end
    else -- windows cmd
        local unicode_option = ''
        if config.unicode_symbols then
            unicode_option = ' -o vscode_unicode_symbols'
        end

        cmd = {
            config.sh_path, '-c',
            'cd ' ..
            util.path.dirname(config.isabelle_path) ..
            ' && ./isabelle vscode_server -o vscode_pide_extensions -o vscode_html_output=false -o editor_output_state' ..
            unicode_option,

            -- for logging
            -- it is not possible to set the log file via a full-path for windows because Isabelle refuses ':' in paths...
            -- 'cd ' .. util.path.dirname(isabelle_path) .. ' && ./isabelle vscode_server -o vscode_unicode_symbols -o vscode_pide_extensions -o vscode_html_output=false -v -L "isabelle-lsp.log"',
        }
    end

    local output_window
    local output_buffer
    local prev_output_width

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
                if not output_window then
                    -- create a new scratch buffer for output & state
                    output_buffer = vim.api.nvim_create_buf(true, true)
                    vim.api.nvim_buf_set_name(output_buffer, "--OUTPUT--")
                    vim.api.nvim_set_option_value('filetype', 'isabelle_output', { buf = output_buffer })

                    -- set the content of the output buffer
                    vim.api.nvim_buf_set_lines(output_buffer, 0, -1, false, {})

                    -- place the output window
                    if config.vsplit then
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

                    prev_output_width = vim.api.nvim_win_get_width(output_window)
                    set_message_margin(client, prev_output_width)
                end

                -- handle resizes of output window
                vim.api.nvim_create_autocmd('WinResized', {
                    callback = function(info)
                        if info.buf ~= output_buffer and info.buf ~= bufnr then return end

                        local new_output_width = vim.api.nvim_win_get_width(output_window)
                        if new_output_width ~= prev_output_width then
                            prev_output_width = new_output_width
                            set_message_margin(client, prev_output_width)
                        end
                    end,
                })
            end,
            handlers = {
                ['PIDE/dynamic_output'] = function(_, params, _, _)
                    if not output_buffer then return end

                    local lines = {}
                    -- this regex makes sure that empty lines are still kept
                    for s in params.content:gmatch("([^\r\n]*)\n?") do
                        table.insert(lines, s)
                    end
                    vim.api.nvim_buf_set_lines(output_buffer, 0, -1, false, lines)
                end,
                ['PIDE/decoration'] = function(_, params, _, _)
                    local thy_buffer = find_buffer_by_uri(params.uri)

                    if not thy_buffer then
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

                        vim.api.nvim_buf_clear_namespace(thy_buffer, syn_id, 0, -1)
                        apply_decoration(thy_buffer, hl_group, syn_id, entry.content)

                        ::continue::
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
    -- use default_config instead of returning nil if a config value is not set in user_config
    local mt = { __index = function(_, k) return defaults[k] end }
    setmetatable(user_config, mt)

    apply_config(user_config)
end

return M
