local props = {
    dirs_to_watch = {
        compile_commands = nil,
        engine = {
            game = nil,
            editor = nil,
        },
        project = {
            game = nil,
            editor = nil,
        },
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

local function get_engine_module(type)
    local path = props.project.partials_dir .. '/Unreal' .. type .. '/Inc/' .. props.project.name .. '/UHT'
    assert(
        is_dir(path),
        'Header files have not been generated. Please run `UnrealHeaderTool` and retrigger `VimEnter` autocmd'
    )
    return path
end

local function get_project_module(type)
    local path = props.project.partials_dir .. '/' .. props.project.name .. type .. '/Development'
    assert(
        is_dir(path),
        'Header files have not been generated. Please run `UnrealHeaderTool` and retrigger `VimEnter` autocmd'
    )
    return path
end

return function(is_editor, is_game)
    props.project.name = get_name()
    props.project.cwd = uv.cwd()
    props.project.partials_dir = get_id()
    props.dirs_to_watch.compile_commands = get_compile_commands()
    props.dirs_to_watch.engine.game = get_engine_module 'Game'

    if is_game then
        props.dirs_to_watch.engine.editor = get_engine_module 'Editor'
    end

    props.dirs_to_watch.project.game = get_project_module ''

    if is_editor then
        props.dirs_to_watch.project.editor = get_project_module 'Editor'
    end
    return props
end
