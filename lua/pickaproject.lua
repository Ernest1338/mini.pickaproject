local M = {}

-- mini.pick needs to be installed
M.pick = require("mini.pick")

M.projects_file_path = vim.fn.stdpath("data") .. "/projects.txt"

local function string_split(string, delimiter)
    local result = {}
    for match in (string .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end

function M.start()
    local projects_file = io.open(M.projects_file_path)
    if projects_file == nil then
        -- create the file if it doesn't exist
        assert(io.open(M.projects_file_path, "w")):close()
        projects_file = io.open(M.projects_file_path)
    end
    local projects = {}
    for line in assert(projects_file):lines() do
        local project = string_split(line, ":")
        if project[1] ~= "" then
            table.insert(projects, project)
        end
    end
    assert(projects_file):close()
    local project_items = {}
    for _, project in ipairs(projects) do
        table.insert(project_items, project[1] .. "\t(" .. project[2] .. ")")
    end
    M.pick.ui_select(project_items, {}, function(_, nth)
        if nth == nil then
            return
        end

        local path = projects[nth][2]
        vim.cmd("cd " .. path)
        M.pick.builtin.files()
    end)
end

function M.new_project()
    local projects_file = io.open(M.projects_file_path, "a")
    if projects_file == nil then
        -- create the file if it doesn't exist
        assert(io.open(M.projects_file_path, "w")):close()
        projects_file = io.open(M.projects_file_path)
    end
    local name = vim.fn.input("Project name: ")
    if name == "" then return end
    local path = vim.fn.input("Project path: ")
    if path == "" then return end
    assert(projects_file):write(name .. ":" .. path .. "\n")
    assert(projects_file):close()
    print("\nProject added succesfully")
end

vim.api.nvim_command('command! PickAProject lua require("pickaproject").start()')
vim.api.nvim_command('command! NewProject lua require("pickaproject").new_project()')

return M
