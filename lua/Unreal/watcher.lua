local uv = vim.loop
local M = { watch_file = nil, uht_dir = nil, uht_inc = nil, id_dir = nil }

M.au_id = vim.api.nvim_create_augroup('FileWatcher', { clear = true })

function M.readFileSync(path)
    local fd = assert(uv.fs_open(path, 'r', 438))
    local stat = assert(uv.fs_fstat(fd))
    local data = assert(uv.fs_read(fd, stat.size, 0))
    assert(uv.fs_close(fd))
    return data
end

function M.WriteFileSync(path, data)
    local fd = assert(uv.fs_open(path, 'w+', 438))
    assert(uv.fs_write(fd, data))
    assert(uv.fs_close(fd))
end

local proj_name = vim.b.unreal_dir or vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
local proj_dir = uv.cwd()
local vscode_dir = uv.fs_stat(proj_dir .. '/.vscode')

if vscode_dir and vscode_dir.type == 'directory' then
    if vim.loop.fs_stat(proj_dir .. '/.vscode/compileCommands_' .. proj_name .. '.json') then
        M.watch_file = proj_dir .. '/.vscode/compileCommands_' .. proj_name .. '.json'
    end
end

if M.watch_file == nil then
    vim.notify(
        'Project files have not been generated. Please run `UnrealBuildTool` and retrigger `VimEnter` autocmd',
        vim.log.levels.ERROR
    )
    return
end

local function get_header_dir()
    local id_dir = proj_dir .. '/Intermediate/Build/Linux'

    if not uv.fs_stat(id_dir) then
        vim.notify(
            'Header files have not been generated. Please run `UnrealHeaderTool` and retrigger `VimEnter` autocmd',
            vim.log.levels.ERROR
        )
        return
    end

    local id
    for file, file_type in vim.fs.dir(id_dir, { depth = 1 }) do
        if file_type == 'directory' then
            id = file
        end
    end
    M.id_dir = id_dir .. '/' .. id

    local h_dir = M.id_dir .. '/UnrealEditor/Inc/' .. proj_name .. '/UHT'

    if not uv.fs_stat(h_dir) then
        vim.notify(
            'Header files have not been generated. Please run `UnrealHeaderTool` and retrigger `VimEnter` autocmd',
            vim.log.levels.ERROR
        )
        return
    end
    return h_dir
end

M.header_loc = get_header_dir()

function M.get_header_loc()
    M.uht_inc = M.id_dir .. '/' .. proj_name .. 'Editor/Development/'
    local header_dirs = {}

    if uv.fs_stat(M.uht_inc) then
        for file, file_type in vim.fs.dir(M.uht_inc, { depth = 1 }) do
            if file_type == 'directory' then
                for f, ft in vim.fs.dir(M.uht_inc .. file, { depth = 1 }) do
                    local ext = vim.fn.fnamemodify(f, ':e')
                    if ft == 'file' then
                        if ext == 'h' or ext == 'cpp' or ext == 'hpp' then
                            table.insert(header_dirs, '-I' .. M.uht_inc .. file .. '/' .. f)
                        elseif ext == 'response' then
                            table.insert(header_dirs, '@' .. M.uht_inc .. file .. '/' .. f)
                        end
                    end
                end
                -- table.insert(header_dirs, M.uht_inc .. file)
            end
        end
        return header_dirs
    end
end

if not M.header_loc then
    vim.notify(
        'Header files have not been generated. Please run `UnrealHeaderTool` and retrigger `VimEnter` autocmd',
        vim.log.levels.ERROR
    )
    return
end

function M.get_headers()
    local header_files = {}
    if uv.fs_stat(M.header_loc) then
        for file, file_type in vim.fs.dir(M.header_loc, { depth = 1 }) do
            local ext = vim.fn.fnamemodify(file, ':e')
            if file_type == 'file' and (ext == 'h' or ext == 'cpp' or ext == 'hpp') then
                table.insert(header_files, file)
            end
        end
        return header_files
    end
    return nil
end

function M.watcher(err, prev, curr)
    if err then
        print(vim.inspect(err))
        return
    end

    local data = M.readFileSync(M.watch_file)
    local js = vim.json.decode(data)

    local command =
        '/opt/unreal-engine/Engine/Extras/ThirdPartyNotUE/SDKs/HostLinux/Linux_x64/v20_clang-13.0.1-centos7/x86_64-unknown-linux-gnu/bin/clang++'

    local headers = M.get_headers()
    local includes = M.get_header_loc()

    for i, v in ipairs(js) do
        for k, va in pairs(v) do
            if k == 'arguments' then
                if vim.tbl_contains(va, command) then
                    -- js[i].command = command
                    -- table.remove(js[i][k], 2)
                    for _, g in ipairs(headers) do
                        table.insert(js[i][k], '-I' .. M.header_loc .. '/' .. g)
                    end
                    for _, g in ipairs(includes) do
                        table.insert(js[i][k], g)
                    end
                end
            end
        end
    end

    local back_js = vim.json.encode(js)
    M.WriteFileSync('compile_commands.json', back_js)
end

M.event = uv.new_fs_event()

vim.api.nvim_create_autocmd('VimLeave', {
    group = M.au_id,
    callback = function()
        uv.close(M.event)
        print 'Closing event'
    end,
})

function M.Start()
    local compile_commands = uv.fs_stat 'compile_commands.json'
    if not compile_commands then
        M.watcher()
    end
    uv.fs_event_start(
        M.event,
        '/storage/Games/Unreal/NeovimTrial/.vscode/',
        { watch_entry = true, stat = true, recursive = false },
        M.watcher
    )
end

function M.Stop()
    uv.close(M.event)
end

return M
