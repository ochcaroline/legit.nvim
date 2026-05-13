# legit.nvim

I tried fugitive. I liked the idea, I didn't like how complex it was to understand all that.

I tried building my own plugin for gitui, which I use as a Git TUI.

And I was missing the simplicty.

So I built (with the help of copilot) my own thing.

## Features

In-nvim git status, staging, commiting, pushing etc.

In-nvim git blame

Replaced gitsigns.nvim with it

Opinionated AF

## Setup

```lua
-- lazy.nvim
{
  "ochcaroline/legit.nvim",
  config = function()
    require('legit').setup()
  end,
}

-- or with custom keymaps / packer / etc.
require('legit').setup({
  keymaps = {
    status = '<leader>gs',
    commit = '<leader>gc',
    push   = '<leader>gp',
    pull   = '<leader>gl',
    log    = '<leader>gg',
    blame  = '<leader>gb',
    rebase = '<leader>gr',
  },
})
```

## Keymaps

| Key          | Action                                 |
| ------------ | -------------------------------------- |
| `<leader>gs` | Git status (floating window)           |
| `<leader>gc` | Git commit (prompt for message)        |
| `<leader>gp` | Git push                               |
| `<leader>gl` | Git log (last 50 commits, right split) |
| `<leader>gf` | Git pull                               |
| `<leader>gb` | Blame sidebar (toggle, cursor-synced)  |
| `<leader>gr` | Git rebase (prompt for ref)            |

## Status window keymaps

| Key | Action                    |
| --- | ------------------------- |
| `s` | Stage file under cursor   |
| `u` | Unstage file under cursor |
| `x` | Discard changes           |
| `d` | Show diff for file        |
| `r` | Refresh                   |
| `q` | Close                     |
