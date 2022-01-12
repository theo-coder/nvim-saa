local saa = require("saa.nvim-saa").saa
local update_view = require("saa.nvim-saa").update_view
local close_window = require("saa.nvim-saa").close_window
local save_as_admin = require("saa.nvim-saa").save_as_admin
local check_root_needed = require("saa.nvim-saa").check_root_needed
local setup = require("saa.nvim-saa").setup

return {
    saa = saa,
    update_view = update_view,
    close_window = close_window,
    save_as_admin = save_as_admin,
    check_root_needed = check_root_needed,
    setup = setup
}
