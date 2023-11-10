# isabelle-lsp.nvim \[WIP\]

Isabelle LSP configuration for [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig).

The plugin uses the [**isabelle-emacs** fork](https://github.com/m-fleury/isabelle-emacs)'s Language Server, it will *not* work with the original Isabelle LSP.

Neovim does not have an isabelle filetype, so you have to add one yourself or install a plugin which introduces one (like [isabelle-syn.nvim](https://github.com/Treeniks/isabelle-syn.nvim)). See [Quickstart](#Quickstart) on how to do so.

The Isabelle language server will handle most syntax highlighting, in particular all dynamic syntax highlighting, however for some more static things (keywords like `theorem` and `lemma`), you will additionally need a normal vim syntax definition, e.g. [isabelle-syn.nvim](https://github.com/Treeniks/isabelle-syn.nvim).

Mind you also that the language server needs a little bit before it starts up. When you open a `.thy` file, it will start the language server in the background and open an output panel once it's running. If it's the first time starting the language server, it will take *much* longer as isabelle will first have to build it.

## Install

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
2. Close the [isabelle-emacs](https://github.com/m-fleury/isabelle-emacs) Repository:
    ```sh
    git clone https://github.com/m-fleury/isabelle-emacs.git
    ```
3. Add the isabelle LSP to your LSP configurations:
    ```lua
    require('isabelle-lsp').setup({
        isabelle_path = '/path/to/isabelle-emacs/bin/isabelle'
    })
    ```
    If the isabelle-emacs `isabelle` binary is already in your PATH (and *before* the original `isabelle` binary), then you can also leave out the `isabelle_path` part.
4. Enable the language server:
    ```lua
    local lspconfig = require('lspconfig')
    lspconfig.isabelle.setup({})
    ```

Refer to [`nvim-lspconfig`](https://github.com/neovim/nvim-lspconfig)'s instructions on how to set up the language server client and keybinds.
