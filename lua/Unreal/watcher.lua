local uv = vim.loop

local watcher = {}

local properties = require 'Unreal.properties'()

function watcher.dump()
    vim.pretty_print(properties)
end

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
                    if ft == 'file' then
                        local ext = f:match '[^.]+$'
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

-- function watcher.get_engine_files(paths)
--     local header_files = {}
--     for _, path in pairs(paths) do
--         for file, file_type in vim.fs.dir(path, { depth = 1 }) do
--             if file_type == 'file' then
--                 local ext = file:match '[^.]+$'
--                 if ext == 'h' or ext == 'cpp' or ext == 'hpp' then
--                     table.insert(header_files, '-I' .. path .. '/' .. file)
--                 end
--             end
--         end
--     end
--     return header_files
-- end

local function get_plugin_files(dirs, file, table)
    for pname, _ in pairs(dirs) do
        if file:find(pname) then
            local files = watcher.get_project_files(properties.dirs_to_watch.plugins[pname])
            if files and not vim.tbl_isempty(files) then
                for _, f in pairs(files) do
                    table.insert(table, f)
                end
                -- else
                --     print 'No files found'
            end
        end
    end
end

function watcher.generate()
    vim.notify('Regenerating compile_commands', vim.log.levels.INFO, { title = 'Unreal.nvim' })

    local data = watcher.readFileSync(properties.dirs_to_watch.compile_commands)
    local js = vim.json.decode(data)
    assert(js, 'Failed to decode json file')

    local command = ''
    if jit.os == 'Linux' then
        command = [[bin/clang++]]
    elseif jit.os == 'Windows' then
        command = [[cl.exe]]
    end

    -- local headers = watcher.get_engine_files { properties.dirs_to_watch.engine.editor }
    local includes = watcher.get_project_files(properties.dirs_to_watch.project)

    for i, v in ipairs(js) do
        if v.arguments and v.arguments[1]:find(command) then
            for _, g in ipairs(includes) do
                table.insert(js[i].arguments, g)
            end
            if v.file and v.file:find 'Plugins' then
                get_plugin_files(properties.project.plugins, v.file, js[i].arguments)
            end
        end

        -- for _, g in ipairs(headers) do
        --     table.insert(js[i][k], g)
        -- end
    end

    local back_js = vim.json.encode(js)
    watcher.WriteFileSync('compile_commands.json', back_js)
    vim.notify('compile_commands.json updated!', vim.log.levels.INFO, { title = 'Unreal.nvim' })
end

function watcher.callback(err, filename, events)
    if err then
        print(vim.inspect(err))
        return
    end

    if filename then
        if properties.dirs_to_watch.compile_commands:find(filename) then
            print(filename)
            if events then
                print(vim.inspect(events))
            end
            watcher.generate()
        end
        -- for _, v in ipairs(properties.dirs_to_watch.engine) do
        --    if filename:find(v) then
        --     print(filename)
        --         watcher.generate()
        --    end
        -- end
    end
end

watcher.event = uv.new_fs_event()

function watcher.Start()
    if not uv.fs_stat 'compile_commands.json' then
        watcher.generate()
    end
    uv.fs_event_start(
        watcher.event,
        properties.project.cwd .. '/.vscode',
        {},
        -- { watch_entry = true, stat = true, recursive = false },
        -- function()
        --     local timer = uv.new_timer()
        --     timer:start(1000, 0, watcher.Update)
        -- end
        watcher.callback
    )
end

function watcher.Stop()
    uv.close(watcher.event)
end

return watcher
