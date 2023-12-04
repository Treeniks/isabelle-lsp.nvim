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

Refer to [`nvim-lspconfig`](https://github.com/neovim/nvim-lspconfig)'s instructions on how to set up the language server client and keybinds.

### Vertical Split instead of Horizontal Split

If you want to open a vertical split instead of a horizontal split when you open an Isabelle file, you can specify so in the setup:
```lua
require('isabelle-lsp').setup({
    vsplit = true,
})
```

### Font

You will need to use a font in your terminal that supports the special symbols of Isabelle. [JuliaMono](https://juliamono.netlify.app) has worked quite well for me.
