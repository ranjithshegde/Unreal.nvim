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
    },
}

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
    assert(is_file(name .. '.uproject'), 'Not inside a Unreal project directory')
    return name
end

local function get_compile_commands()
    assert(
        is_dir '.vscode',
        'Project files have not been generated. Please run `UnrealBuildTool -VSCode` and retrigger `VimEnter` autocmd'
    )
    local file = props.project.cwd .. '/.vscode/compileCommands_' .. props.project.name .. '.json'
    assert(
        is_file(file),
        'Project files have not been generated. Please run `UnrealBuildTool -VSCode` and retrigger `VimEnter` autocmd'
    )
    return file
end

local function get_build_files(path)
    local search_path = nil
    local dirs = { engine_modules = {}, project_modules = {} }

    if path then
        if not is_dir(path) then
            vim.notify(
                'Plugins have not been compiled. They will not be wathced',
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
            'Header files have not been generated. Please run `UnrealHeaderTool` and retrigger `VimEnter` autocmd! Failure at: '
                .. search_path
        )
    end

    local engine_modules = { 'UnrealEditor', 'UnrealGame' }
    local project_modules = { props.project.name .. 'Editor', props.project.name }

    for _, v in ipairs(engine_modules) do
        dir_find(search_path, v, dirs.engine_modules)
    end

    for _, v in ipairs(project_modules) do
        dir_find(search_path, v, dirs.project_modules)
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
                'Header files have not been generated. Please run `UnrealHeaderTool` and retrigger `VimEnter` autocmd! Failure at: '
                    .. search_path
            )
        end
    end

    return dirs
end

local function get_engine_module(paths)
    local dirs = {}
    for _, path in ipairs(paths) do
        local temp = path .. '/Inc/' .. props.project.name .. '/UHT'
        if is_dir(temp) then
            table.insert(dirs, temp)
        end
    end
    assert(
        not vim.tbl_isempty(dirs),
        'Header files have not been generated. Please run `UnrealHeaderTool` and retrigger `VimEnter` autocmd!'
    )
    return dirs
end

local function get_project_module(paths, plugin)
    local files = {}
    local types = { 'DebugGame', 'Development' }

    for _, path in ipairs(paths) do
        for _, type in ipairs(types) do
            if is_dir(path .. '/' .. type) then
                table.insert(files, path .. '/' .. type)
            end
        end
    end

    if vim.tbl_isempty(files) then
        if plugin then
            vim.notify(
                'Plugins have not been compiled. They will not be wathced',
                vim.log.levels.WARN,
                { title = 'Unreal.nvim' }
            )
            return
        else
            error 'Classes have not been compiled. Please run `UnrealBuildTool` and retrigger `VimEnter` autocmd!'
        end
    end
    return files
end

local function get_plugins()
    local path = props.project.cwd .. '/Plugins/'

    for folder, folder_type in vim.fs.dir(path, { depth = 1 }) do
        if folder_type == 'directory' then
            local name = vim.fn.fnamemodify(folder, ':t')
            local plugin_path = path .. name
            if is_file(plugin_path .. '/' .. name .. '.uplugin') then
                props.project.plugins[name] = { path = plugin_path }
                -- local plugin_folders = get_build_files(plugin_path)
                -- if plugin_folders then
                --     props.dirs_to_watch.plugins[name] = get_project_module(plugin_folders.project_modules, true)
                -- end
            end
        end
    end
end

return function()
    props.project.name = get_name()
    props.project.cwd = uv.cwd()

    if is_dir 'Plugins' then
        get_plugins()
        for _, v in pairs(props.project.plugins) do
            if v.partials_dir then
                table.insert(props.dirs_to_watch.plugins, v.partials_dir)
            end
        end
    end

    props.dirs_to_watch.compile_commands = get_compile_commands()

    local files = get_build_files()
    props.dirs_to_watch.engine = get_engine_module(files.engine_modules)
    props.dirs_to_watch.project = get_project_module(files.project_modules)

    return props
end
