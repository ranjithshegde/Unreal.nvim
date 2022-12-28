local uv = vim.loop

local watcher = {}

local properties = require 'Unreal.properties'()

function watcher.readFileSync(path)
    local fd = assert(uv.fs_open(path, 'r', 438))
    local stat = assert(uv.fs_fstat(fd))
    local data = assert(uv.fs_read(fd, stat.size, 0))
    assert(uv.fs_close(fd))
    return data
end

function watcher.WriteFileSync(path, data)
    local fd = assert(uv.fs_open(path, 'w+', 438))
    assert(uv.fs_write(fd, data))
    assert(uv.fs_close(fd))
end

function watcher.get_project_files(paths)
    local header_dirs = {}

    for _, path in pairs(paths) do
        for file, file_type in vim.fs.dir(path, { depth = 1 }) do
            if file_type == 'directory' then
                for f, ft in vim.fs.dir(path .. '/' .. file, { depth = 1 }) do
                    local ext = vim.fn.fnamemodify(f, ':e')
                    if ft == 'file' then
                        if ext == 'h' or ext == 'cpp' or ext == 'hpp' then
                            table.insert(header_dirs, '-I' .. path .. '/' .. file .. '/' .. f)
                        elseif ext == 'response' then
                            table.insert(header_dirs, '@' .. path .. '/' .. file .. '/' .. f)
                        end
                    end
                end
            end
        end
    end
    return header_dirs
end

function watcher.get_engine_files(paths)
    local header_files = {}
    for _, path in pairs(paths) do
        for file, file_type in vim.fs.dir(path, { depth = 1 }) do
            local ext = vim.fn.fnamemodify(file, ':e')
            if file_type == 'file' and (ext == 'h' or ext == 'cpp' or ext == 'hpp') then
                table.insert(header_files, '-I' .. path .. '/' .. file)
            end
        end
    end
    return header_files
end

function watcher.watcher(err, _, _)
    if err then
        print(vim.inspect(err))
        return
    end

    local data = watcher.readFileSync(properties.dirs_to_watch.compile_commands)
    local js = vim.json.decode(data)
    assert(js, 'Failed to decode json file')

    local command =
        '/opt/unreal-engine/Engine/Extras/ThirdPartyNotUE/SDKs/HostLinux/Linux_x64/v20_clang-13.0.1-centos7/x86_64-unknown-linux-gnu/bin/clang++'

    local headers = watcher.get_engine_files { properties.dirs_to_watch.engine.editor }
    local includes =
        watcher.get_project_files { properties.dirs_to_watch.project.game, properties.dirs_to_watch.project.editor }

    for i, v in ipairs(js) do
        for k, va in pairs(v) do
            if k == 'arguments' then
                if vim.tbl_contains(va, command) then
                    for _, g in ipairs(headers) do
                        table.insert(js[i][k], g)
                    end
                    for _, g in ipairs(includes) do
                        table.insert(js[i][k], g)
                    end
                end
            end
        end
    end

    local back_js = vim.json.encode(js)
    watcher.WriteFileSync('compile_commands.json', back_js)
end

watcher.event = uv.new_fs_event()

function watcher.Start()
    uv.fs_event_start(
        watcher.event,
        '/storage/Games/Unreal/NeovimTrial/.vscode/',
        { watch_entry = true, stat = true, recursive = false },
        watcher.watcher
    )
end

function watcher.Stop()
    uv.close(watcher.event)
end

return watcher
