> This plugin is still *highly* experimental and alpha software.

# ghci.vim

Tight integration between `ghci` and `vim` via `tmux`.

## Features

- No-nonsense `ghci` integration
    - Send code directly to `ghci` without worrying whether or not it's in the
        IO monad; ghci.vim handles all of the syntax for you.
- All the power of the REPL directly in `vim`!
- Automatically fill in types for definitions in three keystrokes

## Installation

Use your favorite plugin manager.

Using [vim-plug](https://github.com/junegunn/vim-plug):

```
Plug 'isovector/ghci.vim'
```

## Quickstart Guide

Start a `tmux` session, and open `ghci` in it.

ghci.vim exposes the following key combinations (currently over `s`, because
it's a shitty mode and a really good key):

- `ssM<Enter>`
    - send a movement command `M` to `ghci`
    - character-wise movements will be printed in `ghci`, while line-wise will
        be entered as a definition
- `sL`
    - reload the current buffer in `ghci`
- `st`
    - get the type of the symbol under the cursor
- `sT`
    - fill in the type of the definition under the cursor

        ```haskell
        test a = show a
        ```

    - press `sT` with the cursor anywhere on this line, result:

        ```haskell
        test :: Show a => a -> [Char]
        test a = show a
        ```
- `sr`
    - sync the current definition to `ghci` and run a command afterwards
    - the first time you use this, you will be asked to set the command
    - this can be used to set test a function you're writing
- `sR`
    - clear the command assigned on the current definition

On your first invocation of a `ghci.vim` command, you will be asked to choose a
tmux pane.

