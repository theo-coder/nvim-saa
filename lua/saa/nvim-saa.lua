local api = vim.api
local buf, win
local filepath
local filebuf
local filewin
local quitafter = false

local function open_window()
    buf = api.nvim_create_buf(false, true) -- create new empty buffer
    local border_buf = api.nvim_create_buf(false, true)

    api.nvim_buf_set_option(buf, "bufhidden", "wipe")

    -- get dimensions
    local height = api.nvim_get_option("lines")
    local width = api.nvim_get_option("columns")

    -- calculate our floating window size
    local win_height = 6 --math.ceil(height * 0.3 - 10)
    local win_width = math.ceil(width * 0.3)

    -- and its starting position
    local row = math.ceil((height - win_height) / 2 - 1)
    local col = math.ceil((width - win_width) / 2)

    -- set options
    local opts = {
        style = "minimal",
        relative = "editor",
        width = win_width,
        height = win_height,
        row = row,
        col = col,
    }

    local border_opts = {
        style = "minimal",
        relative = "editor",
        width = win_width + 2,
        height = win_height + 2,
        row = row - 1,
        col = col - 1,
    }

    local border_lines = { "╔" .. string.rep("═", win_width) .. "╗" }
    local middle_line = "║" .. string.rep(" ", win_width) .. "║"

    for _ = 1, win_height do
        table.insert(border_lines, middle_line)
    end

    table.insert(border_lines, "╚" .. string.rep("═", win_width) .. "╝")
    api.nvim_buf_set_lines(border_buf, 0, -1, false, border_lines)

    -- and finally create it with buffer attached
    api.nvim_open_win(border_buf, true, border_opts)
    win = api.nvim_open_win(buf, true, opts)
    api.nvim_command("au BufWipeout <buffer> exe 'silent bwipeout! '" .. border_buf)
end

local function update_view()
    api.nvim_buf_set_lines(
        buf,
        0,
        -1,
        false,
        { "", "  You don't have enough permissions to save this file !", "", "", "  Retry as root ? [y, n]" }
    )
end

local function close_window()
    api.nvim_win_close(win, true)
end

local function update_buf()
    api.nvim_set_current_win(filewin)
    vim.cmd("e!")
    if quitafter then
        vim.cmd([[ q ]])
    end
    --api.nvim_win_close(filewin, true)
end

local function sudo_write()
    local password = vim.fn.inputsecret("Password: ")

    if not password or #password == 0 then
        print("Invalid password, sudo aborted")
        return
    end

    local tmpfile = vim.fn.tempname()

    if not filepath or #filepath == 0 then
        print("Error processing file, sudo aborted")
        return
    end

    local cmd = string.format("dd if=%s of=%s bs=1048576", vim.fn.shellescape(tmpfile), vim.fn.shellescape(filepath))
    vim.fn.writefile(filebuf, tmpfile)

    local out = vim.fn.system(string.format("sudo -p '' -S %s", cmd), password)

    if vim.v.shell_error ~= 0 then
        print("\r\n")
        print(out)
        return
    end

    print(string.format('\r\n"%s" written', filepath))
    vim.fn.delete(tmpfile)
    return true
end

local function save_as_admin()
    if sudo_write() then
        print("Successfully saved !")
    else
        print("An error occured !")
    end
    close_window()
    update_buf()
end

local function check_root_needed()
    local result = vim.fn.system("[ -w " .. filepath .. " ] && echo 'yes' || echo 'no'")
    result = result:gsub("%s+", "")

    if result == "yes" then
        vim.cmd [[ 
        write
        ]]
        return false
    end

    return true
end

local function set_mappings()
    local mappings = {
        q = "close_window()",
        n = "close_window()",
        y = "save_as_admin()",
        o = "save_as_admin()",
    }

    for k, v in pairs(mappings) do
        api.nvim_buf_set_keymap(
            buf,
            "n",
            k,
            ':lua require"saa".' .. v .. "<cr>",
            { nowait = true, noremap = true, silent = true }
        )
    end

    local other_chars = {
        "a",
        "b",
        "c",
        "d",
        "e",
        "f",
        "g",
        "h",
        "i",
        "j",
        "k",
        "l",
        "m",
        "p",
        "r",
        "s",
        "t",
        "u",
        "v",
        "w",
        "x",
        "z",
    }

    for _, v in ipairs(other_chars) do
        api.nvim_buf_set_keymap(buf, "n", v, "", { nowait = true, noremap = true, silent = true })
        api.nvim_buf_set_keymap(buf, "n", v:upper(), "", { nowait = true, noremap = true, silent = true })
        api.nvim_buf_set_keymap(buf, "n", "<c-" .. v .. ">", "", { nowait = true, noremap = true, silent = true })
    end
end

local function saa()
    filepath = vim.fn.expand("%:p")
    filebuf = api.nvim_buf_get_lines(api.nvim_win_get_buf(0), 0, -1, true)
    filewin = vim.fn.win_getid()

    if check_root_needed() ~= true then
        vim.cmd[[ q ]]
        return
    end

    open_window()
    set_mappings()
    update_view()
end

local function saaq()
    quitafter = true
    saa()
end

local function setup()
    vim.cmd([[
    let s:IgnoreChange=0
    augroup _nvim-saa
    autocmd!
    autocmd! FileChangedRO * nested
    \ let s:IgnoreChange=1 |
    \ call system("p4 edit " . expand("%")) |
    \ set noreadonly
    autocmd! FileChangedShell *
    \ if 1 == s!IgnoreChange |
    \   let v:fcs_choice="" |
    \   let s:IgnoreChange=0 |
    \ else |
    \   let v:fcs_choice="ask" |
    \ endif
    augroup end
    command! Saa execute 'lua require("saa").saa()'
    command! SaaQ execute 'lua require("saa").saaq()'
    ]])
end

return {
    saa = saa,
    saaq = saaq,
    update_view = update_view,
    close_window = close_window,
    save_as_admin = save_as_admin,
    check_root_needed = check_root_needed,
    setup = setup,
}
