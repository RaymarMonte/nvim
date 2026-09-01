-- ~/.config/nvim/init.lua

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
