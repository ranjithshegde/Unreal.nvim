local uv = vim.loop
local M = {}

local properties = require 'Unreal.properties'(true, false)

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

function M.get_project_files(paths)
    local header_dirs = {}

    for _, path in ipairs(paths) do
        for file, file_type in vim.fs.dir(path, { depth = 1 }) do
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
            end
        end
    end
    return header_dirs
end

function M.get_engine_files(paths)
    local header_files = {}
    for _, path in ipairs(paths) do
        for file, file_type in vim.fs.dir(path, { depth = 1 }) do
            local ext = vim.fn.fnamemodify(file, ':e')
            if file_type == 'file' and (ext == 'h' or ext == 'cpp' or ext == 'hpp') then
                table.insert(header_files, file)
            end
        end
    end
    return header_files
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

    local headers = M.get_engine_files { properties.dirs_to_watch.engine.editor }
    local includes =
        M.get_project_files { properties.dirs_to_watch.project.game, properties.dirs_to_watch.project.editor }

    for i, v in ipairs(js) do
        for k, va in pairs(v) do
            if k == 'arguments' then
                if vim.tbl_contains(va, command) then
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

function M.Start()
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
