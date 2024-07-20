# isabelle-language-server

Since building this plugin, I have taken up the task of improving the underlying Isabelle language server in the context of my bachelor's thesis. The plan is to eventually upstream my changes into the Isabelle distribution, however I cannot say when that will happen. For now, the fork can be found [here](https://github.com/Treeniks/isabelle-language-server). An accompanying updated Neovim plugin with instructions can be found [in the `isabelle-language-server` branch](https://github.com/Treeniks/isabelle-lsp.nvim/tree/isabelle-language-server), which will eventually replace master once the changes have been upstreamed.

I strongly recommend using that instead of what is described below, as it is both newer and includes many new features.

# isabelle-lsp.nvim \[WIP\]

![isabelle-lsp.nvim](https://github.com/Treeniks/isabelle-lsp.nvim/assets/56131826/2ce8bef0-9176-43e0-a12c-13969f1ea91d)

Isabelle LSP configuration for [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig).

The plugin uses the [**isabelle-emacs** fork](https://github.com/m-fleury/isabelle-emacs)'s Language Server, it will *not* work with the original Isabelle LSP.

Neovim does not have an isabelle filetype, so you have to add one yourself or install a plugin which introduces one (like [isabelle-syn.nvim](https://github.com/Treeniks/isabelle-syn.nvim)). See [Quickstart](#Quickstart) on how to do so.

The Isabelle language server will handle most syntax highlighting, in particular all dynamic syntax highlighting, however for some more static things (keywords like `theorem` and `lemma`), you will additionally need a normal vim syntax definition, e.g. [isabelle-syn.nvim](https://github.com/Treeniks/isabelle-syn.nvim).

Mind you also that the language server needs a little bit before it starts up. When you open a `.thy` file, it will start the language server in the background and open an output panel once it's running. If it's the first time starting the language server, it might take *much* longer as isabelle will first have to build it.

## Install

### isabelle-lsp.nvim

Install with your package manager of choice, e.g. [lazy.nvim](https://github.com/folke/lazy.nvim):
```lua
require('lazy').setup({
    {
        'Treeniks/isabelle-lsp.nvim',
        dependencies = {
            'neovim/nvim-lspconfig'
        },
    },
})
```

### isabelle-emacs

See also the [Preparation section of the isabelle-emacs install guide](https://github.com/m-fleury/isabelle-emacs/blob/Isabelle2023-vsce/src/Tools/emacs-lsp/spacemacs_layers/isabelle/README.org#preparation).

1. Clone the [isabelle-emacs](https://github.com/m-fleury/isabelle-emacs) Repository:
    ```sh
    git clone https://github.com/m-fleury/isabelle-emacs.git
    cd isabelle-emacs
    git checkout Isabelle2023-vsce
    ```
2. Initialize Isabelle:
    ```sh
    ./bin/isabelle components -I
    ./bin/isabelle components -a
    ./bin/isabelle build -b HOL
    ```

### Patch isabelle-emacs

The Language Server has one particular quirk that doesn't play nice with neovim's LSP client: The way document changes are registered within the Server often desynchronizes with the neovim client. To fix this, you will have to manually edit `isabelle-emacs`'s LSP code.

In the file `isabelle-emacs/src/Tools/VSCode/src/language_server.scala`, you will have to change the `change_document` function:
```scala
  private def change_document(
    file: JFile,
    version: Long,
    changes: List[LSP.TextDocumentChange]
  ): Unit = {
    changes.foreach(change =>
      resources.change_model(session, editor, file, version, change.text, change.range))

    delay_input.invoke()
    delay_output.invoke()
  }
```
Afterwards, you will need to let isabelle rebuild its tools. Simply running the `isabelle-emacs/bin/isabelle` binary again is enough.

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
        isabelle_path = '/path/to/isabelle-emacs/bin/isabelle',
    })
    ```
    The `isabelle_path` line if optional if the isabelle-emacs `isabelle` binary is already in your PATH (and *not* the original `isabelle` binary).
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

By default, symbols like `⟹` will be shown with their ascii representation (`\<Longrightarrow>`) within the output panel. If you want unicode symbols instead, you can set it so in the setup:
```lua
require('isabelle-lsp').setup({
    unicode_symbols = true,
})
```

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
