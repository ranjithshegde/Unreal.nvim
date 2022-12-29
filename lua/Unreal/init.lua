local unreal = {
    defaults = {
        os = 'linux',
        unreal_dir = '/opt/unreal-engine',
    },
}

unreal.au_id = vim.api.nvim_create_augroup('FileWatcher', { clear = true })

function unreal.setup(config)
    assert(type(config) == 'table', 'The setup function requires a table')
    for i, v in pairs(config) do
        unreal.defaults[i] = v
    end
end

function unreal.Start()
    vim.api.nvim_create_autocmd('VimLeave', {
        group = unreal.au_id,
        callback = function()
            print 'Closing event'
            require('Unreal.watcher').End()
        end,
    })

    require('Unreal.watcher').Start()
end

function unreal.End()
    require('Unreal.watcher').End()
end

function unreal.generate()
    local compile_commands = vim.loop.fs_stat 'compile_commands.json'
    if not compile_commands then
        require('Unreal.watcher').Update()
    end
end

return unreal
