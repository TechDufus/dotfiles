vim.g.vimtex_view_method = "skim"
vim.g.vimtex_view_skim_sync = 1
vim.g.vimtex_view_skim_activate = 1
vim.g.vimtex_quickfix_ignore_filters = {
	"Underfull",
	"Overfull",
	"specifier changed to",
	"Token not allowed in a PDF string",
	"You have requested package",
	"LaTeX Warning: Float too large for page",
	"contains only floats",
	"LaTeX Warning: Citation",
	'Missing "author" in',
	"LaTeX Font Warning:",
	'Package option "final" no longer has any effect with minted v3+',
}

vim.pack.add({
	{ src = "https://github.com/lervag/vimtex" },
})

local function vimtex_toc_picker()
	local entries = vim.fn["vimtex#toc#get_entries"]()
	local items = {}

	for _, entry in ipairs(entries) do
		if entry.active and not entry.hidden then
			local indent = string.rep("  ", entry.level or 0)
			local title = (entry.title or ""):gsub("\n", " ")
			items[#items + 1] = {
				text = indent .. vim.trim(title),
				level = entry.level or 0,
				file = entry.file,
				line = entry.line,
			}
		end
	end

	require("plugins.snacks").load().picker({
		title = "LaTeX Table of Contents",
		items = items,
		format = function(item)
			return { { item.text, "VimtexTocSec" .. math.min(item.level, 4) } }
		end,
		layout = "left",
		confirm = function(picker, item)
			picker:close()
			vim.cmd("edit " .. vim.fn.fnameescape(item.file))
			vim.api.nvim_win_set_cursor(0, { item.line, 0 })
			vim.cmd("normal! zv")
		end,
	})
end

vim.api.nvim_create_autocmd("FileType", {
 	pattern = { "tex", "latex" },
 	callback = function(event)
 		vim.opt_local.textwidth = 80
 		vim.opt_local.formatoptions:remove("a") -- no auto-reflow
 		vim.opt_local.formatoptions:append("t") -- wrap text while typing
 		vim.keymap.set("n", "<leader>lt", vimtex_toc_picker, {
 			buffer = event.buf,
 			desc = "Find LaTeX table of contents",
 		})
 	end,
})
