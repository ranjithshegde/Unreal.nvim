local props = {
    dirs_to_watch = {
        compile_commands = nil,
        engine = nil,
        project = nil,
    },
    project = {
        name = nil,
        cwd = nil,
        partials_dir = nil,
    },
}

local uv = vim.loop

local function is_file(path)
    return uv.fs_stat(path)
end

local function is_dir(path)
    local fd = is_file(path)
    if not fd then
        return nil
    end
    return fd.type == 'directory'
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
        'Project files have not been generated. Please run `UnrealBuildTool` and retrigger `VimEnter` autocmd'
    )
    local file = props.project.cwd .. '/.vscode/compileCommands_' .. props.project.name .. '.json'
    assert(
        is_file(file),
        'Project files have not been generated. Please run `UnrealBuildTool` and retrigger `VimEnter` autocmd'
    )
    return file
end

local function get_id()
    local path = props.project.cwd .. '/Intermediate/Build/Linux'

    assert(
        is_dir(path),
        'Header files have not been generated. Please run `UnrealHeaderTool` and retrigger `VimEnter` autocmd'
    )

    local id
    for file, file_type in vim.fs.dir(path, { depth = 1 }) do
        if file_type == 'directory' then
            id = file
        end
    end
    assert(id, 'Header files have not been generated. Please run `UnrealHeaderTool` and retrigger `VimEnter` autocmd')
    return path .. '/' .. id
end

local function get_engine_module()
    local editor_path = props.project.partials_dir .. '/UnrealEditor' .. '/Inc/' .. props.project.name .. '/UHT'
    local files = {}
    assert(
        is_dir(editor_path),
        'Header files have not been generated. Please run `UnrealHeaderTool` and retrigger `VimEnter` autocmd'
    )
    files.editor = editor_path
    local game_path = props.project.partials_dir .. '/UnrealGame' .. '/Inc/' .. props.project.name .. '/UHT'
    if is_dir(game_path) then
        files.game = game_path
    end
    return files
end

local function get_project_module()
    local game_path = props.project.partials_dir .. '/' .. props.project.name .. '/Development'
    local files = {}
    assert(
        is_dir(game_path),
        'Header files have not been generated. Please run `UnrealHeaderTool` and retrigger `VimEnter` autocmd'
    )
    files.game = game_path
    local editor_path = props.project.partials_dir .. '/' .. props.project.name .. 'Editor/Development'
    if is_dir(editor_path) then
        files.editor = editor_path
    end
    return files
end

return function()
    props.project.name = get_name()
    props.project.cwd = uv.cwd()
    props.project.partials_dir = get_id()
    props.dirs_to_watch.compile_commands = get_compile_commands()
    props.dirs_to_watch.engine = get_engine_module()
    props.dirs_to_watch.project = get_project_module()

    return props
end
