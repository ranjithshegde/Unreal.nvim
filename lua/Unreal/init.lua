local unreal = {}

unreal.au_id = vim.api.nvim_create_augroup('FileWatcher', { clear = true })

-- function unreal.setup(config)
--     assert(type(config) == 'table', 'The setup function requires a table')
--     for i, v in pairs(config) do
--         unreal.defaults[i] = v
--     end
-- end

function unreal.Start()
    vim.api.nvim_create_autocmd('VimLeave', {
        group = unreal.au_id,
        callback = function()
            print 'Closing event'
            require('Unreal.watcher').End()
        end,
    })

    pcall(require('Unreal.watcher').Start)
end

function unreal.End()
    require('Unreal.watcher').End()
end

function unreal.generate()
    pcall(require('Unreal.watcher').generate)
end

return unreal
