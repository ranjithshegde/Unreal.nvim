local props = {
    dirs_to_watch = {
        compile_commands = nil,
        engine = nil,
        project = nil,
        plugins = {},
    },
    project = {
        name = nil,
        cwd = nil,
        plugins = {},
        type = nil,
    },
}

local project_types = { PROJECT = 1, PLUGIN = 2 }

local uv = vim.loop

local function dir_find(path, dir, tbl)
    local current = vim.fs.find(dir, { type = 'directory', path = path })
    if current and not vim.tbl_isempty(current) then
        table.insert(tbl, current[1])
    end
end

local function is_file(path)
    return uv.fs_stat(path)
end

local function is_dir(path)
    local fd = is_file(path)
    return fd and fd.type == 'directory'
end

local function get_name()
    local cwd = uv.cwd()
    local name = vim.fn.fnamemodify(cwd, ':t')
    if is_file(name .. '.uproject') then
        return name, project_types.PROJECT
    elseif is_file(name .. '.uplugin') then
        return name, project_types.PLUGIN
    else
        error 'Not inside a Unreal project directory'
    end
end

local function get_compile_commands()
    assert(
        is_dir '.vscode',
        'Project files have not been generated. Please run `UnrealBuildTool .. -VSCode` and rerun `require("Unreal").start()`'
    )
    local file = props.project.cwd .. '/.vscode/compileCommands_' .. props.project.name .. '.json'
    assert(
        is_file(file),
        'Project files have not been generated. Please run `UnrealBuildTool .. -VSCode` and rerun  `require("Unreal").start()`'
    )
    return file
end

local function get_build_files(path)
    local search_path = nil
    local dirs = { engine_modules = {}, project_modules = {} }

    if path then
        if not is_dir(path) then
            vim.notify(
                'Plugins have not been compiled or they do not contain C++ classes. They will not be wathced',
                vim.log.levels.WARN,
                { title = 'Unreal.nvim' }
            )
        else
            search_path = path
        end
    else
        search_path = props.project.cwd .. '/Intermediate/Build'

        assert(
            is_dir(search_path),
            'Header files have not been generated. Please run `UnrealHeaderTool` and rerun `require("Unreal").Start()`! Failure at: '
                .. search_path
        )
    end

    dir_find(search_path, 'UHT', dirs.engine_modules)
    dir_find(search_path, 'Development', dirs.project_modules)
    if vim.tbl_isempty(dirs.project_modules) then
        dir_find(search_path, 'DebugGame', dirs.project_modules)
    end

    if vim.tbl_isempty(dirs.engine_modules) or vim.tbl_isempty(dirs.project_modules) then
        if path then
            vim.notify(
                'Plugins have not been compiled. They will not be wathced',
                vim.log.levels.WARN,
                { title = 'Unreal.nvim' }
            )
            return
        else
            error(
                'Header files have not been generated. Please run `UnrealHeaderTool` and rerun `require("Unreal").Start()`! Failure at: '
                    .. search_path
            )
        end
    end

    return dirs
end

local function get_plugins()
    local path = props.project.cwd .. '/Plugins/'

    for folder, folder_type in vim.fs.dir(path, { depth = 1 }) do
        if folder_type == 'directory' then
            local name = vim.fn.fnamemodify(folder, ':t')
            local plugin_path = path .. name
            if is_file(plugin_path .. '/' .. name .. '.uplugin') then
                props.project.plugins[name] = { path = plugin_path }
                local plugin_folders = get_build_files(plugin_path)
                if plugin_folders and not vim.tbl_isempty(plugin_folders.project_modules) then
                    props.dirs_to_watch.plugins[name] = plugin_folders.project_modules
                end
            end
        end
    end
end

return function()
    props.project.name, props.project.type = get_name()
    props.project.cwd = uv.cwd()

    if is_dir 'Plugins' then
        get_plugins()
    end

    props.dirs_to_watch.compile_commands = get_compile_commands()

    local files = get_build_files()
    props.dirs_to_watch.project = files.project_modules
    props.dirs_to_watch.engine = files.engine_modules

    return props
end
