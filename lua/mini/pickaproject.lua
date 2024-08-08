-- NOTE: mini.pick needs to be installed and available

local M = {}

local function string_split(string, delimiter)
    local result = {}

    for match in (string .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end

    return result
end

local function string_trim(str)
    return str:match("^%s*(.-)%s*$")
end

local function parse_file(file)
    local flines = {}
    for line in file:lines() do
        if string.len(line) ~= 0 then
            table.insert(flines, line)
        end
    end
    file:close()

    local function parse_block(lines, level)
        local block_data = {}
        while #lines > 0 do
            local line = lines[1]
            local indent = line:find("[^ ]") - 1
            if indent < level then
                break                  -- End of the block
            elseif indent == level then
                table.remove(lines, 1) -- Consume the line
                local ident_data_split = string_split(line, ":")
                local identifier = ident_data_split[1]
                local data = ident_data_split[2]
                identifier = string_trim(identifier)
                if data ~= "" then
                    block_data[identifier] = { type = "project", data = data }
                else
                    -- Start of a new block
                    block_data[identifier] = { type = "nest", data = parse_block(lines, level + 4) }
                end
            else
                -- Lines are more indented, ignore them as they belong to a nested block
                table.remove(lines, 1)
            end
        end
        return block_data
    end

    return parse_block(flines, 0)
end

local function parse_items(parsed)
    local names, items = {}, {}

    for name, project in pairs(parsed) do
        local spaces = string.rep(" ", 40 - string.len(name))
        if project["type"] == "project" then
            table.insert(names, " " .. name .. spaces .. "(" .. project["data"] .. ")")
        elseif project["type"] == "nest" then
            table.insert(names, "⛘ " .. name .. spaces)
        end
        table.insert(items, project)
    end

    return names, items
end

function M.start()
    local projects_file = io.open(M.projects_file_path)
    if projects_file == nil then
        -- create the file if it doesn't exist
        assert(io.open(M.projects_file_path, "w")):close()
        projects_file = io.open(M.projects_file_path)
    end

    local parsed = parse_file(assert(projects_file))
    local names, items = parse_items(parsed)
    local opts = { prompt = "Pick A Project" }

    M.pick_handler = function(_, nth)
        if nth == nil then return end

        local project = items[nth]
        if project["type"] == "project" then
            local path = project["data"]
            local ok, _ = pcall(vim.cmd, "cd " .. path)
            if not ok then
                vim.notify("ERROR: Directory \"" .. path .. "\" doesn't exist", vim.log.levels.ERROR)
                return
            end
            M.pick.builtin.files()
        elseif project["type"] == "nest" then
            names, items = parse_items(project["data"])
            M.pick.ui_select(names, opts, M.pick_handler)
        end
    end

    M.pick.ui_select(names, opts, M.pick_handler)
end

local function add_project(name, path)
    -- assert both name and path are correct
    if name == nil or name == "" or path == nil or path == "" then
        print("\nFailed to add a project. Incorrect values provided")
        return
    end

    local projects_file = io.open(M.projects_file_path, "a")
    if projects_file == nil then
        -- create the file if it doesn't exist
        assert(io.open(M.projects_file_path, "w")):close()
        projects_file = io.open(M.projects_file_path)
    end

    assert(projects_file):write(name .. ":" .. path .. "\n")
    assert(projects_file):close()

    print("\nProject '" .. name .. "' added succesfully")
end

function M.new_project()
    local name = vim.fn.input("Project name: ")
    local path = vim.fn.input("Project path (Current working directory if empty): ")
    if path == "" then path = vim.fn.getcwd() end
    add_project(name, path)
end

function M.new_project_cwd(proj_name)
    local path = vim.fn.getcwd()
    local name = path:match("([^/]+)$")
    if proj_name ~= nil and proj_name ~= "" then name = proj_name end
    add_project(name, path)
end

function M.setup(opts)
    -- NOTE: maybe add some configuration options?
    M.opts = opts

    M.pick = _G.MiniPick
    M.projects_file_path = vim.fn.stdpath("data") .. "/projects.txt"

    -- Register in 'mini.pick'
    if type(M.pick) == 'table' then
        -- NOTE: replaced by :Pick project
        -- vim.api.nvim_create_user_command("PickAProject", function()
        --     M.start()
        -- end, {})
        M.pick.registry["project"] = M.start

        vim.api.nvim_create_user_command("NewProject", function() M.new_project() end, {})
        vim.api.nvim_create_user_command("NewProjectCwd", function(input)
            local option = input.args
            if #option == 0 then option = nil end
            M.new_project_cwd(option)
        end, { force = true, nargs = "*" })
    end
end

return M
