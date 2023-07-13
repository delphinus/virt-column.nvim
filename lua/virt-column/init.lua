local utils = require "virt-column.utils"

local M = {
    config = {
        char = "┃",
        virtcolumn = "",
    },
    buffer_config = {},
}

M.clear_buf = function(bufnr)
    if M.namespace then
        vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)
    end
end

M.setup = function(config)
    M.config = vim.tbl_deep_extend("force", M.config, config or {})
    M.namespace = vim.api.nvim_create_namespace "virt-column"

    vim.cmd [[command! -bang VirtColumnRefresh lua require("virt-column.commands").refresh("<bang>" == "!")]]
    vim.cmd [[highlight default link VirtColumn Whitespace]]
    vim.cmd [[highlight clear ColorColumn]]

    vim.cmd [[
        augroup VirtColumnAutogroup
            autocmd!
            autocmd ColorScheme * highlight clear ColorColumn
            autocmd FileChangedShellPost,TextChanged,TextChangedI,CompleteChanged,BufWinEnter * VirtColumnRefresh
            autocmd OptionSet colorcolumn VirtColumnRefresh
            autocmd VimEnter,SessionLoadPost * VirtColumnRefresh!
        augroup END
    ]]
end

M.setup_buffer = function(config)
    M.buffer_config[vim.api.nvim_get_current_buf()] = config
    M.refresh()
end

M.refresh = function()
    local bufnr = vim.api.nvim_get_current_buf()

    if not vim.api.nvim_buf_is_loaded(bufnr) then
        return
    end

    local config = vim.tbl_deep_extend("force", M.config, M.buffer_config[bufnr] or {})
    local textwidth = vim.opt.textwidth:get()
    local colorcolumn = utils.concat_table(vim.opt.colorcolumn:get(), vim.split(config.virtcolumn, ","))

    for i, c in ipairs(colorcolumn) do
        if vim.startswith(c, "+") then
            if textwidth ~= 0 then
                colorcolumn[i] = textwidth + tonumber(c:sub(2))
            else
                colorcolumn[i] = nil
            end
        elseif vim.startswith(c, "-") then
            if textwidth ~= 0 then
                colorcolumn[i] = textwidth - tonumber(c:sub(2))
            else
                colorcolumn[i] = nil
            end
        else
            colorcolumn[i] = tonumber(c)
        end
    end

    table.sort(colorcolumn, function(a, b)
        return a > b
    end)

    M.clear_buf(bufnr)

    local extmarks = vim.api.nvim_buf_get_extmarks(
        bufnr,
        -1,
        { 0, 0 },
        { -1, -1 },
        { type = "virt_text", details = true }
    )
    local offsets = {}
    for _, extmark in ipairs(extmarks) do
        local row, col, details = extmark[2], extmark[3], extmark[4]
        if details.virt_text_pos == "inline" then
            local len = 0
            for _, entry in ipairs(details.virt_text) do
                local text = entry[1]
                len = len + vim.fn.strdisplaywidth(text, col)
            end
            offsets[row] = (offsets[row] or 0) + len
        end
    end

    for i = 1, vim.fn.line "$", 1 do
        for _, column in ipairs(colorcolumn) do
            local offset = offsets[i - 1] or 0
            local width = vim.fn.virtcol { i, "$" } - 1
            if width < column then
                vim.api.nvim_buf_set_extmark(bufnr, M.namespace, i - 1, 0, {
                    virt_text = { { config.char, "VirtColumn" } },
                    virt_text_pos = "overlay",
                    hl_mode = "combine",
                    virt_text_win_col = column + offset - 1,
                    priority = 1,
                })
            end
        end
    end
end

return M
