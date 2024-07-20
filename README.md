# isabelle-lsp.nvim \[WIP\]

![isabelle-lsp.nvim](https://github.com/user-attachments/assets/19c7780e-5e30-4129-978b-4bff5e18c39f)

Isabelle LSP configuration for [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) using the [isabelle-language-server](https://github.com/Treeniks/isabelle-language-server) fork.

Neovim does not have an isabelle filetype, so you have to add one yourself or install a plugin which introduces one (like [isabelle-syn.nvim](https://github.com/Treeniks/isabelle-syn.nvim)). See [Quickstart](#Quickstart) on how to do so.

Mind you also that the language server needs a little bit before it starts up. When you open a `.thy` file, it will start the language server in the background and open an output panel once it's running.

## Additions/Improvements of the isabelle-language-server fork for Neovim

- highlighting in output panel
- correct line-breaks in output panel
- full dynamic syntax highlighting (it was only partial before)
- code actions for active markup (e.g. in JEdit, clicking on a proof when sledgehammering to insert it can instead be done via a code action)
- working autocompletion for symbols (so no need for manual snippets no more)

## Install

### isabelle-lsp.nvim

Install with your package manager of choice, e.g. [lazy.nvim](https://github.com/folke/lazy.nvim):
```lua
require('lazy').setup({
    {
        'Treeniks/isabelle-lsp.nvim',
        branch = 'isabelle-language-server',
        dependencies = {
            'neovim/nvim-lspconfig'
        },
    },
})
```

### isabelle-language-server

See also the [isabelle-language-server wiki](https://github.com/Treeniks/isabelle-language-server/wiki).

1. Clone the [isabelle-language-server](https://github.com/Treeniks/isabelle-language-server) Repository:
    ```sh
    git clone https://github.com/Treeniks/isabelle-language-server.git
    cd isabelle-language-server
    git checkout language-server # should be the default anyway
    ```
2. Add a unique Isabelle identifier to keep it separate from other Isabelle instances on the system:
    ```sh
    echo "isabelle-language-server" >> ./etc/ISABELLE_IDENTIFIER
    ```
3. Initialize Isabelle:
    ```sh
    ./Admin/init
    ./bin/isabelle build -b HOL
    ```

## Quickstart

1. Neovim does not have an isabelle filetype, so you have to add one yourself:
    ```lua
    vim.filetype.add({
        extension = {
            thy = 'isabelle',
        },
    })
    ```
    Alternatively you can install a plugin that creates this filetype for you, like [isabelle-syn.nvim](https://github.com/Treeniks/isabelle-syn.nvim) (which will also include some static syntax highlighting).
2. Add the isabelle LSP to your LSP configurations:
    ```lua
    require('isabelle-lsp').setup({
        isabelle_path = '/path/to/isabelle-language-server/bin/isabelle',
    })
    ```
    The `isabelle_path` line if optional if the isabelle-language-server `isabelle` binary is already in your PATH.
3. Enable the language server:
    ```lua
    local lspconfig = require('lspconfig')
    lspconfig.isabelle.setup({})
    ```

## Configuration

Refer to [`nvim-lspconfig`](https://github.com/neovim/nvim-lspconfig)'s instructions on how to set up the language server client and keybinds.

### Vertical Split instead of Horizontal Split

If you want to open a vertical split instead of a horizontal split when you open an Isabelle file, you can specify so in the setup:
```lua
require('isabelle-lsp').setup({
    vsplit = true,
})
```

### Unicode Symbols

Isabelle has its own concept of Symbols. For simplicity, symbols can be either shown in a unicode representation (`⟹`) or in their ascii representation (`\<Longrightarrow>`). By default, the language server will always use the ascii representation. If you use [isabelle-syn.nvim](https://github.com/Treeniks/isabelle-syn.nvim), this isn't a big problem because that plugin uses vim's [conceal](https://neovim.io/doc/user/options.html#'conceallevel') feature to display the correct symbols anyway, however this might still be annoying to edit in practice.

Thus, there are two options to adjust the behaviour: `unicode_symbols_output` and `unicode_symbols_edits`.
- `unicode_symbols_output`: adjusts what representation should be used in output and state panels, as well as other displayed messages
- `unicode_symbols_edits`: adjusts what representation should be used for anything editing the buffer, e.g. completions and code actions

Both settings are *false* by default.

```lua
require('isabelle-lsp').setup({
    unicode_symbols_output = true,
    unicode_symbols_edits = true,
})
```

Additionally, if you want to convert the current buffer from ascii to unicode representations, you can use the `:SymbolsConvert` command.

### Font

You will need to use a font in your terminal that supports the special symbols of Isabelle. [JuliaMono](https://juliamono.netlify.app) has worked quite well for me.

### Dynamic Highlight Colors

Isabelle has dynamic syntax highlighting. While [isabelle-syn.nvim](https://github.com/Treeniks/isabelle-syn.nvim) offers some static syntax highlighting, most of it will be overwritten by the language server. In order to customize the scopes used for each Isabelle decoration type, you can overwrite the `hl_group_map` table:
```lua
require('isabelle-lsp').setup({
    -- setting false means "don't do any highlighting for this group"
    -- these are the defaults currently in use
    hl_group_map = {
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
})
```

## Windows

**The following was tested before the isabelle-language-server fork existed and has not been tested since. I have no idea if it currently works.**

This plugin *can* work on Windows, but it requires a little more setup and can be rather jank. It's also rather slow (it takes ~20 seconds to start the server).

1. The core installation procedure is the same as above.
2. You'll need some kind of bash-like shell. For this, you can either use [MSYS2](https://www.msys2.org/), [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) or [Cygwin](https://www.cygwin.com/). I'd recommend MSYS2.
3. You'll need to either have a `sh` binary on PATH, or define a `sh_path` in your config:
    ```lua
    -- for MSYS2's sh
    require('isabelle-lsp').setup({
        sh_path = 'C:\\msys64\\usr\\bin\\sh.exe'
    })

    -- for WSL's bash
    require('isabelle-lsp').setup({
        sh_path = 'C:\\Windows\\system32\\bash.exe'
        -- usually just 'bash' is enough as it's typically on PATH
    })

    -- for Cygwin, example installed with scoop
    require('isabelle-lsp').setup({
        sh_path = 'C:\\Users\\USERNAME\\scoop\\apps\\cygwin\\current\\root\\bin\\sh.exe'
    })
    ```
    Note this only has to be *sh-like*. I.e. you can also use `bash` or `fish` if you like, as long as they support a `-c` CLI argument.
    Note also that WSL forces a `bash` program on PATH, so if you want to use MSYS2's bash and have WSL installed, you will have to specify the full path.
4. You will need to edit the `isabelle-path` setting to your shell's path translation:

    Instead of using `C:\\isabelle\\...` use
    - **MSYS2**: `C:/isabelle/...` or `/c/isabelle/...`
    - **WSL**: `/mnt/c/isabelle/...`
    - **Cygwin**: `C:/isabelle/...` or `/cygdrive/c/isabelle/...`
5. Imports will usually give a `Bad theory import` error when opening a file. The only way I found to fix this for now is to just hover the import and do an LSP goto definition or open the imported file manually. After going back, the error will *probably*™ go away.
