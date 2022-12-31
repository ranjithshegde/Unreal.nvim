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
        partials_dir = nil,
        plugins = {},
        id = nil,
    },
}

local function asserter(callback, arg, files, tool)
    local results = callback(arg)
    if not results then
        vim.notify(
            string.format(
                '%s files have not been generated. Please rerun `%s` and restart nvim. Failure at: %s',
                files,
                tool,
                arg
            ),
            vim.log.levels.WARN,
            { title = 'Unreal.nvim' }
        )
        return
    else
        return results
    end
end

local uv = vim.loop

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

local function get_id()
    local path = props.project.cwd .. '/Intermediate/Build'
    local os = jit.os

    if os == 'Linux' then
        path = path .. '/Linux'
    elseif os:find 'Windows' then
        if is_dir(path .. '/Win64') then
            path = path .. '/Win64'
        elseif is_dir(path .. '/Win32') then
            path = path .. '/Win32'
        end
    end

    assert(
        is_dir(path),
        'Header files have not been generated. Please run `UnrealHeaderTool` and retrigger `VimEnter` autocmd! Failure at: '
            .. path
    )

    if os == 'Windows' then
        return path
    end

    local id
    vim.pretty_print(id)

    for file, file_type in vim.fs.dir(path, { depth = 1 }) do
        if file_type == 'directory' then
            id = file
        end
    end

    assert(
        is_dir(id),
        'Header files have not been generated. Please run `UnrealHeaderTool` and retrigger `VimEnter` autocmd! Failure at: '
            .. id
    )

    return path .. '/' .. id
end

local function get_plugin_id(path)
    local os = jit.os
    if os == 'Linux' then
        path = path .. '/Linux'
    elseif os:find 'Windows' then
        if is_dir(path .. '/Win64') then
            path = path .. '/Win64'
        elseif is_dir(path .. '/Win32') then
            path = path .. '/Win32'
        end
    end

    if not asserter(is_dir, path, 'Header files', 'Unreal Header Tool') then
        return
    end

    if os == 'Windows' then
        return path
    end

    local id
    for file, file_type in vim.fs.dir(path, { depth = 1 }) do
        if file_type == 'directory' then
            id = file
        end
    end

    if not asserter(is_dir, id, 'Header files', 'Unreal Header Tool') then
        return
    end

    return path .. '/' .. id
end

local function get_plugins()
    local path = props.project.cwd .. '/Plugins/'

    for folder, folder_type in vim.fs.dir(path, { depth = 1 }) do
        if folder_type == 'directory' then
            local name = vim.fn.fnamemodify(folder, ':t')
            local plugin_path = path .. name
            if is_file(plugin_path .. '/' .. name .. '.uplugin') then
                props.project.plugins[name] = { path = plugin_path }
                local id = get_plugin_id(plugin_path)
                if id then
                    props.project.plugins[name].partials_dir = id
                end
            end
        end
    end
end

local function get_engine_module()
    local editor_path = props.project.partials_dir .. '/UnrealEditor' .. '/Inc/' .. props.project.name .. '/UHT'
    local files = {}
    assert(
        is_dir(editor_path),
        'Header files have not been generated. Please run `UnrealHeaderTool` and retrigger `VimEnter` autocmd! Failure at: '
            .. editor_path
    )
    files.editor = editor_path
    local game_path = props.project.partials_dir .. '/UnrealGame' .. '/Inc/' .. props.project.name .. '/UHT'
    if is_dir(game_path) then
        files.game = game_path
    end
    return files
end

local function get_project_module()
    local game_path = props.project.partials_dir .. '/' .. props.project.name .. 'Editor/'
    local files = {}
    assert(
        is_dir(game_path),
        'Header files have not been generated. Please run `UnrealHeaderTool` and retrigger `VimEnter` autocmd! Failure at: '
            .. game_path
    )
    if is_dir(game_path .. 'Development') then
        files.game = game_path .. 'Development'
    elseif is_dir(game_path .. 'DebugGame') then
        files.game = game_path .. 'DebugGame'
    else
        error(
            'Header files have not been generated. Please run `UnrealHeaderTool` and retrigger `VimEnter` autocmd! Failure at: '
                .. game_path
        )
    end

    local editor_path = props.project.partials_dir .. '/' .. props.project.name
    if is_dir(editor_path) then
        if is_dir(editor_path .. '/Development') then
            files.editor = editor_path .. '/Development'
        elseif is_dir(editor_path .. '/DebugGame') then
            files.editor = editor_path .. '/DebugGame'
        end
    end
    return files
end

return function()
    props.project.name = get_name()
    props.project.cwd = uv.cwd()
    props.project.partials_dir = get_id()

    if is_dir 'Plugins' then
        get_plugins()
        for _, v in pairs(props.project.plugins) do
            if v.partials_dir then
                table.insert(props.dirs_to_watch.plugins, v.partials_dir)
            end
        end
    end

    props.dirs_to_watch.compile_commands = get_compile_commands()
    props.dirs_to_watch.engine = get_engine_module()
    props.dirs_to_watch.project = get_project_module()

    return props
end
