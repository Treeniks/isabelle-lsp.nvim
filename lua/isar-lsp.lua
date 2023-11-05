local configs = require 'lspconfig.configs'
local util = require 'lspconfig.util'

local function send_message(message, payload)
    local clients = vim.lsp.get_active_clients { name = 'isabelle', bufnr = bufnr }
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

    send_message('caret_update', { uri = 'file://' .. fname, line = pos[1] - 1, character = pos[2] - 1 })
end

local function preview_request(bufnr)
    bufnr = util.validate_bufnr(bufnr)

    local fname = vim.api.nvim_buf_get_name(bufnr)
    local pos = vim.fn.getpos(bufnr)

    send_message('preview_request', { uri = 'file://' .. fname, column = 1 })
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

-- Function to convert a Lua table to a list of strings
function tableToListStrings(table)
    local list = {}
    for _, value in ipairs(table) do
        table.insert(list, tostring(value))
    end
    return list
end

local state_buffer = -1
local output_buffer = -1

configs.isabelle = {
    default_config = {
        cmd = {
            'isabelle', 'vscode_server',
            '-o', 'vscode_unicode_symbols',
            '-o', 'vscode_pide_extensions',
            '-v',
            '-L', '~/Documents/isa.log',
        },
        filetypes = { 'isabelle' },
        root_dir = function(fname)
            return vim.fn.fnamemodify(fname, ':h')
        end,
        single_file_support = true,
        on_attach = function(client, bufnr)
            vim.api.nvim_create_autocmd({"CursorMoved","CursorMovedI"}, {
                buffer = bufnr,
                callback = function(info)
                    caret_update(bufnr)
                    set_message_margin(40)
                end,
            })

            -- Create a new scratch buffer for "--STATE--"
            state_buffer = vim.api.nvim_create_buf(true, true)
            vim.api.nvim_buf_set_name(state_buffer, "--STATE--")
            -- vim.api.nvim_buf_set_option(state_buffer, 'buftype', 'nofile')
            -- vim.api.nvim_buf_set_option(state_buffer, 'bufhidden', 'hide')
            -- vim.api.nvim_buf_set_option(state_buffer, 'swapfile', false)
            -- vim.api.nvim_buf_set_option(state_buffer, 'buflisted', false)
            -- vim.api.nvim_buf_set_option(state_buffer, 'filetype', 'scratch-state')

            -- Set the content of the "--STATE--" buffer
            vim.api.nvim_buf_set_lines(state_buffer, 0, -1, false, {})

            -- Create a new scratch buffer for "--OUTPUT--"
            output_buffer = vim.api.nvim_create_buf(true, true)
            vim.api.nvim_buf_set_name(output_buffer, "--OUTPUT--")
            -- vim.api.nvim_buf_set_option(output_buffer, 'buftype', 'nofile')
            -- vim.api.nvim_buf_set_option(output_buffer, 'bufhidden', 'hide')
            -- vim.api.nvim_buf_set_option(output_buffer, 'swapfile', false)
            -- vim.api.nvim_buf_set_option(output_buffer, 'buflisted', false)
            -- vim.api.nvim_buf_set_option(output_buffer, 'filetype', 'scratch-output')

            -- Set the content of the "--OUTPUT--" buffer
            vim.api.nvim_buf_set_lines(output_buffer, 0, -1, false, {})

            -- Open the scratch buffers in a split window
            vim.api.nvim_command('vsplit')
            vim.api.nvim_command('wincmd l')
            vim.api.nvim_set_current_buf(output_buffer)

            vim.api.nvim_command('split')
            vim.api.nvim_command('wincmd j')
            vim.api.nvim_set_current_buf(state_buffer)

            vim.api.nvim_command('wincmd h')
        end,
        handlers = {
            ['PIDE/dynamic_output'] = function(err, result, ctx, config)
                lines = {}
                for s in result.content:gmatch("[^\r\n]+") do
                    table.insert(lines, s)
                end
                vim.api.nvim_buf_set_lines(output_buffer, 0, -1, false, lines)
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
        CaretUpdate = {
            function()
                caret_update(0)
            end,
        },
        PreviewRequest = {
            function()
                preview_request(0)
            end,
        },
        SetMessageMargin = {
            function()
                set_message_margin(40)
            end
        },
    },
    docs = {
        description = [[
Isabelle VSCode Language Server
]],
    },
}
