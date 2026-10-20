-- ~/.config/nvim/init.lua

-- ---------------------------------------------------------------------------
-- Line numbers
-- ---------------------------------------------------------------------------
-- Absolute numbers in the gutter, so what is on screen matches what compilers,
-- linters and stack traces report. 'relativenumber' -- alone, or alongside this
-- one for hybrid numbering -- is the alternative: it makes counted motions like
-- 12j readable at a glance, at the cost of the absolute number for the cursor
-- line being the only true one on screen. Left off; add it if the counts earn it.
vim.opt.number = true

-- ---------------------------------------------------------------------------
-- Indentation
-- ---------------------------------------------------------------------------
-- Four spaces, no literal tabs. These are the *global defaults*; Neovim's
-- bundled ftplugins deliberately override them per-filetype where a language
-- demands it (Makefiles need real tabs, Go uses tabs via gofmt). That override
-- is wanted, so nothing here forces the issue with a blanket FileType autocmd.
vim.opt.expandtab = true   -- Tab key inserts spaces
vim.opt.tabstop = 4        -- a literal tab renders 4 columns wide
vim.opt.shiftwidth = 4     -- >> / << and autoindent step
vim.opt.softtabstop = 4    -- Tab/BS treat 4 spaces as one unit
vim.opt.smartindent = true

-- ---------------------------------------------------------------------------
-- Search
-- ---------------------------------------------------------------------------
-- Case-insensitive / and ? (also affects * and #, and :s patterns). A \C
-- anywhere in a pattern forces case-sensitive for that one search. 'smartcase'
-- is the usual companion: it goes case-sensitive automatically whenever the
-- pattern contains an uppercase letter. Left off; add it if you want that.
vim.opt.ignorecase = true

-- ---------------------------------------------------------------------------
-- Clipboard
-- ---------------------------------------------------------------------------
-- Share the system clipboard, so y/p need no "+ prefix.
vim.opt.clipboard = "unnamedplus"

-- On X11 the clipboard is not storage -- it is a live handoff between running
-- processes. The selection belongs to whichever process set it, and is served
-- on request; when that process exits, the content is gone. So a yank made
-- just before :q can vanish before you paste it. (Measured on this machine:
-- ~2 in 5 yanks lost when quitting immediately after.) A clipboard manager
-- normally papers over this by taking ownership; one is not always running.
--
-- Fix: on exit, hand the clipboard to a detached helper that outlives Neovim.
local function clipboard_persist_cmd()
    if vim.fn.has("mac") == 1 then
        return { "pbcopy" }
    elseif vim.env.WAYLAND_DISPLAY and vim.fn.executable("wl-copy") == 1 then
        return { "wl-copy", "--foreground" }
    elseif vim.fn.executable("xclip") == 1 then
        return { "xclip", "-selection", "clipboard", "-i" }
    elseif vim.fn.executable("xsel") == 1 then
        return { "xsel", "--clipboard", "--input" }
    end
    return nil -- no provider; nothing to hand off to
end

-- Track what was yanked, rather than reading "+ back at exit: querying the X11
-- selection when no process owns it prints "target STRING not available".
local last_yank = nil

vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Remember the most recent clipboard-bound yank",
    callback = function()
        local ev = vim.v.event
        if ev.regname ~= "" and ev.regname ~= "+" then
            return -- an explicit "x yank; not clipboard-bound
        end
        local text = table.concat(ev.regcontents, "\n")
        if ev.regtype == "V" then
            text = text .. "\n" -- linewise yanks carry a trailing newline
        end
        last_yank = text ~= "" and text or nil
    end,
})

vim.api.nvim_create_autocmd("VimLeave", {
    desc = "Keep the last yank on the system clipboard after Neovim exits",
    callback = function()
        if not last_yank then
            return
        end
        local cmd = clipboard_persist_cmd()
        if not cmd then
            return
        end
        -- detach = true reparents the helper, so it survives this process.
        local ok, job = pcall(vim.fn.jobstart, cmd, { detach = true })
        if not ok or job <= 0 then
            return
        end
        pcall(vim.fn.chansend, job, last_yank)
        pcall(vim.fn.chanclose, job, "stdin")
    end,
})

-- ---------------------------------------------------------------------------
-- Ctrl+Backspace in Insert mode
-- ---------------------------------------------------------------------------
-- A terminal cannot report "Ctrl+Backspace" as such; it sends one byte. VTE
-- terminals (xfce4-terminal, gnome-terminal) send 0x08, which Neovim reads as
-- <C-h> -- and <C-h> already means "delete one character", which is why the
-- key seems to do nothing special. Remap it to delete the previous word.
--
-- <C-BS> is bound alongside it: terminals speaking the kitty keyboard protocol
-- (kitty, foot, Ghostty, WezTerm) and the GUI front-ends report the key under
-- that name instead. The binding is simply inert where it never arrives, so
-- the config stays portable.
--
-- <C-g>u opens a new undo block first, so a single u restores the deleted word
-- instead of folding it into the surrounding insert.
for _, lhs in ipairs({ "<C-h>", "<C-BS>" }) do
    vim.keymap.set("i", lhs, "<C-g>u<C-w>", { desc = "Delete word before cursor" })
    vim.keymap.set("c", lhs, "<C-w>", { desc = "Delete word before cursor" })
end

-- ---------------------------------------------------------------------------
-- Ctrl+S to save
-- ---------------------------------------------------------------------------
-- :update rather than :write -- it writes only when the buffer is modified, so
-- repeatedly hitting the key does not keep bumping mtime and waking watchers.
--
-- <Cmd> rather than a plain ":" mapping, because <Cmd> does not change mode:
-- Ctrl+S from Insert saves and leaves you in Insert, mid-word, cursor in place.
--
-- Ctrl+S is ASCII 0x13 = XOFF, which a terminal's line discipline traditionally
-- eats to pause output -- the reason "stty -ixon" advice is everywhere. It is
-- not needed here: Neovim puts the terminal in raw mode, which clears IXON, and
-- xfce4-terminal does not claim the key as a shortcut of its own. Measured: the
-- key arrives as 0x13 and input keeps flowing afterwards. (Inside :terminal the
-- key still reaches the shell's own tty, which is left alone deliberately.)
vim.keymap.set({ "n", "i", "v" }, "<C-s>", "<Cmd>update<CR>", { desc = "Save buffer if modified" })
