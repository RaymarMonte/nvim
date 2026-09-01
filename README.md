# nvim

My Neovim configuration.

## Install

Clone into Neovim's config path — the repo *is* the config directory:

```sh
git clone <this-repo> ~/.config/nvim
```

On Windows the path is `~/AppData/Local/nvim` instead.

Nothing else to do: Neovim reads `init.lua` on next launch.

## Requirements

- **Neovim** — developed against v0.13.0-dev.
- **A clipboard provider**, for `clipboard = "unnamedplus"` (yank/put go to the
  system clipboard). Without one, clipboard ops silently fall back to Neovim's
  own registers.
  - X11: `xclip` or `xsel`
  - Wayland: `wl-clipboard`
  - macOS: `pbcopy`/`pbpaste`, already present

  Check what Neovim found with `:checkhealth provider`.

## Layout

```
init.lua    entry point; indentation + clipboard + keymaps, all here for now
```

Once `init.lua` outgrows a single file, split into `lua/raymar/` — a namespaced
subdirectory, so module names can't collide with plugins on the runtime path.

## Indentation

Four spaces, no literal tabs (`expandtab`, `tabstop`/`shiftwidth`/`softtabstop`
= 4). These are global *defaults*: Neovim's bundled ftplugins still override
them where a language requires it, which is intentional — Makefiles keep real
tabs, Go keeps tabs for gofmt. No blanket `FileType` autocmd fights that.

## Clipboard persistence

On X11 the clipboard is a live handoff between processes, not storage: the
selection belongs to whoever set it and dies with that process. A yank made
just before `:q` can therefore be gone before you paste it — measured here at
roughly 2 in 5 lost when quitting straight after a yank.

`init.lua` fixes this by remembering the last clipboard-bound yank
(`TextYankPost`) and, on `VimLeave`, piping it to a **detached** helper that
outlives Neovim. After the fix, 5 of 5 test yanks survived. The helper is
chosen per platform — `pbcopy`, `wl-copy`, `xclip`, or `xsel` — and the hook
no-ops when none is installed, so the config stays portable.

## Ctrl+Backspace

`Ctrl+Backspace` deletes the word before the cursor in Insert mode, and on the
`:` command line.

This needs a mapping because a terminal cannot report the *chord*: it sends a
single byte. Measured on xfce4-terminal (VTE 0.80) here:

| key              | bytes sent            | Neovim reads |
| ---------------- | --------------------- | ------------ |
| `Backspace`      | `0x7f`                | `<BS>`       |
| `Ctrl+Backspace` | `0x08`                | `<C-h>`      |
| `Ctrl+Delete`    | `\x1b[3;5~`           | `<C-Del>`    |

So Ctrl+Backspace arrives as `<C-h>`, which *already* means "delete one
character" — hence the key appearing to do nothing special. `init.lua` maps it
to `<C-w>` instead.

`<C-BS>` is bound alongside `<C-h>`, because terminals speaking the kitty
keyboard protocol (kitty, foot, Ghostty, WezTerm) and the GUI front-ends report
the key under that name. The extra binding is inert where it never arrives.

Two details worth knowing:

- The mapping prefixes `<C-g>u`, opening a new undo block, so one `u` restores
  the deleted word rather than folding it into the surrounding insert.
- Vim deliberately **stops once** at the point insert started (see `:h i_CTRL-W`
  with `'backspace'` containing `start`). Deleting back past where you began
  inserting takes one extra press. This is upstream behaviour, not the mapping.

Plain `Backspace` is untouched, and `<C-h>` keeps its normal-mode meaning — only
Insert and Command-line mode are remapped.

## Notes

- Keep paths in this config machine-independent: use `vim.fn.stdpath("config")`
  and `vim.fn.stdpath("data")` rather than absolute `/home/...` paths.
- Neovim writes nothing back into this directory. Plugins and parsers go to
  `~/.local/share/nvim`, undo/swap/shada to `~/.local/state/nvim`, and cache to
  `~/.cache/nvim` — so the repo stays clean without a `.gitignore`.
- If a plugin manager is added later, **commit its lockfile** (e.g.
  `lazy-lock.json`). It pins plugin revisions so a fresh clone reproduces this
  setup exactly.
