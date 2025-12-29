_addon.name = 'abFarm'
_addon.author = 'abFarm'
_addon.version = '1.0.0'
_addon.commands = {'abfarm', 'abf'}

require('logger')
require('tables')
require('strings')
require('math')
require('coroutine')
texts = require('texts')

-- Simple config system (fallback if config library not available)
local config_file = windower.addon_path..'data/settings.lua'
local defaults = {
    enabled = true,
    pos_x = 100,
    pos_y = 100,
    font_size = 10,
    show_location = true,
    show_items = true,
    show_timers = true,
    show_enemies = true,
    update_rate_key_items = 2.0,  -- Update key items every X seconds
    update_rate_inventory = 2.0,   -- Update inventory items every X seconds
    last_config = nil,  -- Remember last loaded config
    display = {
        text = {size = 10, font = 'Consolas'},
        pos = {x = 100, y = 100},
        bg = {visible = true, alpha = 128}
    }
}

local settings = T(defaults)

-- Try to load config, fallback to defaults
local function load_config()
    local success, result = pcall(function()
        if windower.file_exists(config_file) then
            local file = io.open(config_file, 'r')
            if file then
                local content = file:read('*all')
                file:close()
                
                -- Special handling for last_config (nil default, quoted string)
                local last_config_match = content:match('last_config%s*=%s*"([^"]+)"')
                if last_config_match then
                    settings.last_config = last_config_match
                end
                
                -- Simple parsing (very basic)
                for key, default_val in pairs(defaults) do
                    -- Skip last_config since we handled it above
                    if key == 'last_config' then
                        -- Already handled above, skip
                    else
                        -- Try to match as a quoted string first (for any key, including nil defaults)
                        -- Pattern: key = "value" or key="value" with optional whitespace
                        local string_pattern = key..'%s*=%s*"([^"]+)"'
                        local string_match = content:match(string_pattern)
                        if string_match then
                            -- Found a quoted string - use it (could be string or nil default)
                            settings[key] = string_match
                        else
                            -- Try to match as unquoted value
                            local pattern = key..'%s*=%s*([%w%.]+)'
                            local match = content:match(pattern)
                            if match then
                                if type(default_val) == 'boolean' then
                                    settings[key] = (match:lower() == 'true')
                                elseif type(default_val) == 'number' then
                                    settings[key] = tonumber(match) or default_val
                                elseif type(default_val) == 'string' then
                                    settings[key] = match
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    if not success then
        settings = T(defaults)
    end
end

local function save_config()
    local success, result = pcall(function()
        -- Create data directory if it doesn't exist
        local data_dir = windower.addon_path..'data/'
        if not windower.dir_exists(data_dir) then
            windower.create_dir(data_dir)
        end
        
        local file = io.open(config_file, 'w')
        if file then
            file:write('-- abFarm Settings\n')
            for key, value in pairs(settings) do
                if type(value) == 'boolean' then
                    file:write(string.format('%s = %s\n', key, tostring(value)))
                elseif type(value) == 'number' then
                    -- Check if it's a whole number or decimal
                    if value == math.floor(value) then
                        file:write(string.format('%s = %d\n', key, value))
                    else
                        file:write(string.format('%s = %.2f\n', key, value))
                    end
                elseif type(value) == 'string' then
                    file:write(string.format('%s = "%s"\n', key, value))
                end
            end
            file:close()
        end
    end)
end

load_config()

-- Unified data structures (will be loaded from config files)
local farm_config = {
    -- Items: {name = {id = number, type = 'key'|'item', count = number, has = bool}}
    items = {},
    
    -- Tracked items (for counting): {name = count}
    tracked_items = {},
    
    -- Enemies: {name = {zone = string, pos = string, x/y/z = number, tracked = bool, spawnType = 'pop'|'timer'|'lottery'|'default', popItems = {array}}}
    enemies = {},
    
    -- Trade locations: {name = {zone = string, pos = string, items = {array}}}
    trade_locations = {},
}

-- Current loaded config name
local current_config_name = nil

-- Mob tracking
local last_seen_mobs = {}  -- Track mob IDs we've seen
local kill_timers = {}     -- Kill timers for timer-based enemies

-- UI drag tracking
local drag_save_timer = nil  -- Timer to debounce drag saves

-- List available config files
local function list_configs()
    local configs_dir = windower.addon_path..'configs/'
    local configs = {}
    
    if not windower.dir_exists(configs_dir) then
        return configs
    end
    
    -- Try to use io.popen to list files (Windows)
    local handle = io.popen('dir /b "'..configs_dir..'" 2>nul')
    if handle then
        for filename in handle:lines() do
            -- Check if it's a .lua file
            if filename:match('%.lua$') then
                -- Remove .lua extension
                local config_name = filename:gsub('%.lua$', '')
                table.insert(configs, config_name)
            end
        end
        handle:close()
    else
        -- Fallback: try common config names
        local common_configs = {'glavoid', 'itzpapalotl'}
        for _, name in ipairs(common_configs) do
            local config_path = configs_dir..name..'.lua'
            if windower.file_exists(config_path) then
                table.insert(configs, name)
            end
        end
    end
    
    -- Sort alphabetically
    table.sort(configs)
    return configs
end

-- Load farm configuration from external file
local function load_farm_config(config_name, is_fallback)
    is_fallback = is_fallback or false  -- Default to false (explicit load)
    -- Create configs directory if it doesn't exist
    local configs_dir = windower.addon_path..'configs/'
    if not windower.dir_exists(configs_dir) then
        windower.create_dir(configs_dir)
    end
    
    local config_path = configs_dir..config_name..'.lua'
    
    if not windower.file_exists(config_path) then
        windower.add_to_chat(8, string.format('[abFarm] Config file not found: %s', config_path))
        windower.add_to_chat(8, '[abFarm] Create a config file in: '..configs_dir)
        return false
    end
    
    -- Load the config file
    local success, result = pcall(function()
        local file = io.open(config_path, 'r')
        if not file then 
            error('Could not open file: '..config_path)
        end
        local content = file:read('*all')
        file:close()
        
        if not content or content == '' then
            error('Config file is empty')
        end
        
        -- Execute the config file in a safe environment
        local env = {}
        setmetatable(env, {__index = _G})
        
        -- Try to load the file (Lua 5.1 uses loadstring, Lua 5.2+ uses load)
        local func, load_err
        if loadstring then
            -- Lua 5.1
            func, load_err = loadstring(content, config_path)
        else
            -- Lua 5.2+
            func, load_err = load(content, config_path, 't', env)
        end
        
        if not func then
            error('Failed to compile config: '..tostring(load_err))
        end
        
        -- For Lua 5.1, we need to set the environment after loading
        if loadstring and setfenv then
            setfenv(func, env)
        end
        
        -- Execute the function
        local exec_success, exec_err = pcall(func)
        if not exec_success then
            error('Failed to execute config: '..tostring(exec_err))
        end
        
        -- Extract the config table
        if not env.config then
            error('Config file must define a "config" table')
        end
        
        return env.config
    end)
    
    if not success then
        windower.add_to_chat(8, string.format('[abFarm] Failed to load config: %s', config_name))
        windower.add_to_chat(8, string.format('[abFarm] Error: %s', tostring(result)))
        return false
    end
    
    local config = result
    if not config then
        windower.add_to_chat(8, string.format('[abFarm] Failed to load config: %s (config table is nil)', config_name))
        return false
    end
    
    -- Validate and load the config
    farm_config.items = config.items or {}
    farm_config.tracked_items = config.tracked_items or {}
    farm_config.enemies = config.enemies or {}
    farm_config.trade_locations = config.trade_locations or {}
    
    -- Initialize item tracking states
    for item_name, item_data in pairs(farm_config.items) do
        if type(item_data) == 'table' then
            item_data.has = false
            item_data.count = 0
        end
    end
    
    -- Initialize tracked items (preserve IDs if they exist)
    for item_name, tracked_data in pairs(farm_config.tracked_items) do
        if type(tracked_data) == 'table' and tracked_data.id then
            farm_config.tracked_items[item_name] = {id = tracked_data.id, count = 0}
        else
            farm_config.tracked_items[item_name] = 0
        end
    end
    
    -- Initialize kill timers for timer-based enemies
    kill_timers = {}
    for enemy_name, enemy_data in pairs(farm_config.enemies) do
        if enemy_data.spawnType == 'timer' and enemy_data.tracked then
            kill_timers[enemy_name] = nil
        end
    end
    
    current_config_name = config_name
    
    -- Save the config name:
    -- - Always save non-glavoid configs
    -- - Save glavoid only if explicitly loaded by user (not as fallback)
    if config_name ~= 'glavoid' then
        -- Always save non-glavoid configs
        settings.last_config = config_name
        save_config()
    elseif not is_fallback then
        -- User explicitly loaded glavoid, save it
        settings.last_config = config_name
        save_config()
    end
    -- If config_name is 'glavoid' and is_fallback is true, don't save it
    -- This preserves any previously saved config when glavoid is used as fallback
    
    windower.add_to_chat(8, string.format('[abFarm] Loaded config: %s', config_name))
    
    return true
end

-- No default config - we'll load from config files instead

-- UI element
local display_box = nil

-- Helper function to get item count from inventory
local function get_item_count(item_name)
    local item_data = farm_config.items[item_name]
    local item_id = nil
    
    -- Try to get ID from farm_config.items first
    if item_data and item_data.id then
        item_id = item_data.id
    end
    
    -- Fallback: check tracked_items (for items not in items table)
    if not item_id and farm_config.tracked_items[item_name] then
        local tracked_data = farm_config.tracked_items[item_name]
        -- Check if tracked_items entry has an ID (can be table with id, or just a number for count)
        if type(tracked_data) == 'table' and tracked_data.id then
            item_id = tracked_data.id
        end
        -- If no ID, will fall back to name matching
    end
    
    local count = 0
    local search_name = item_name:lower()
    
    -- Function to check a single item
    local function check_item(item)
        if not item then return false, 0 end
        -- Check by ID first (more reliable)
        if item_id and item.id == item_id then
            return true, (item.count or 1)
        end
        -- Fallback to name matching
        if item.name and type(item.name) == 'string' and item.name:lower() == search_name then
            return true, (item.count or 1)
        end
        return false, 0
    end
    
    -- Check all bags using Windower API
    -- Bag IDs: 0=inventory, 1=wardrobe, 2=wardrobe2, 3=wardrobe3, 4=wardrobe4, 5=wardrobe5, 6=wardrobe6, 7=wardrobe7, 8=sack, 9=satchel, 10=case
    for bag = 0, 10 do
        local bag_items = windower.ffxi.get_items(bag)
        if bag_items and type(bag_items) == 'table' then
            -- Iterate through items in the bag
            for i = 1, #bag_items do
                local item = bag_items[i]
                if item and item.id then
                    local found, amount = check_item(item)
                    if found then
                        count = count + amount
                    end
                end
            end
        end
    end
    
    return count
end

-- Check if key item is owned (using Windower API like findAll does)
local function has_key_item(item_name)
    local item_data = farm_config.items[item_name]
    if not item_data or item_data.type ~= 'key' or not item_data.id then return false end
    
    local key_item_id = item_data.id
    
    -- Use windower.ffxi.get_key_items() like findAll does
    local key_items = windower.ffxi.get_key_items()
    if key_items then
        for _, id in ipairs(key_items) do
            if id == key_item_id then
                return true
            end
        end
    end
    
    return false
end

-- Update key items only
local function update_key_items()
    for item_name, item_data in pairs(farm_config.items) do
        if item_data.type == 'key' then
            item_data.has = has_key_item(item_name)
        end
    end
end

-- Update inventory items only
local function update_inventory_items()
    -- Update all items
    for item_name, item_data in pairs(farm_config.items) do
        if item_data.type == 'item' then
            local count = get_item_count(item_name)
            item_data.count = count
            item_data.has = count > 0
        end
    end
    
    -- Update tracked items (for counting)
    for item_name, tracked_data in pairs(farm_config.tracked_items) do
        -- Preserve the ID before calling get_item_count (which reads from tracked_items)
        local item_id = nil
        if type(tracked_data) == 'table' and tracked_data.id then
            item_id = tracked_data.id
        end
        
        local count = get_item_count(item_name)
        
        -- Store back with ID preserved
        if item_id then
            farm_config.tracked_items[item_name] = {id = item_id, count = count}
        else
            farm_config.tracked_items[item_name] = count
        end
    end
end

-- Update all items (for backwards compatibility)
local function update_items()
    update_key_items()
    update_inventory_items()
end

-- Get player position
local function get_player_pos()
    local player = windower.ffxi.get_player()
    if not player then return nil, nil, nil end
    
    local mob = windower.ffxi.get_mob_by_id(player.id)
    if not mob then return nil, nil, nil end
    
    return mob.x, mob.y, mob.z
end

-- Get current zone
local function get_current_zone()
    local info = windower.ffxi.get_info()
    if info and info.zone then
        return info.zone
    end
    
    -- Fallback: try to get from player
    local player = windower.ffxi.get_player()
    if player and player.zone then
        return player.zone
    end
    
    return 'Unknown'
end

-- Format time string
local function format_time(seconds)
    if not seconds then return 'N/A' end
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format('%02d:%02d', mins, secs)
end

-- Calculate time since kill
local function get_time_since_kill(enemy_name)
    if not kill_timers[enemy_name] then return nil end
    return os.time() - kill_timers[enemy_name]
end

-- Check if enemy should have respawned (10-15 min window)
local function check_respawn_time(enemy_name)
    local time_since = get_time_since_kill(enemy_name)
    if not time_since then return false, nil end
    
    local min_respawn = 10 * 60  -- 10 minutes
    local max_respawn = 15 * 60  -- 15 minutes
    
    if time_since >= min_respawn and time_since <= max_respawn then
        return true, time_since  -- In respawn window
    elseif time_since > max_respawn then
        return true, time_since  -- Should have respawned
    else
        return false, time_since  -- Not ready yet
    end
end

-- Create UI
local function create_ui()
    if display_box then
        display_box:destroy()
        display_box = nil
    end
    
    -- Update display settings
    settings.display.text.size = settings.font_size
    settings.display.pos.x = settings.pos_x
    settings.display.pos.y = settings.pos_y
    
    display_box = texts.new('', settings.display, settings)
    if display_box then
        display_box:visible(settings.enabled)
        
        -- Enable drag functionality (if supported)
        if display_box.drag then
            display_box:drag(true)
        end
    else
        windower.add_to_chat(8, '[abFarm] Error creating UI element.')
    end
end

-- Update UI
local function update_ui()
    if not display_box then
        create_ui()
    end
    
    if not settings.enabled then
        if display_box then display_box:hide() end
        return
    end
    
    local lines = {}
    
    -- Header - use config name if loaded, otherwise default
    local title_name = 'Glavoid'
    if current_config_name then
        -- Capitalize first letter of config name
        title_name = current_config_name:sub(1,1):upper() .. current_config_name:sub(2):lower()
    end
    table.insert(lines, string.format('\\cs(255,255,0)=== %s Spawn Tracker ===\\cr', title_name))
    table.insert(lines, '')
    
    -- Current position
    if settings.show_location then
        local zone = get_current_zone()
        local x, y, z = get_player_pos()
        if x and y then
            table.insert(lines, string.format('\\cs(200,200,255)Zone: %s\\cr', zone))
            table.insert(lines, string.format('\\cs(200,200,255)Pos: %.1f, %.1f\\cr', x, y))
        end
        table.insert(lines, '')
    end
    
    -- Items Status
    if settings.show_items then
        -- Key Items
        local key_items_list = {}
        local trade_items_list = {}
        for item_name, item_data in pairs(farm_config.items) do
            if item_data.type == 'key' then
                table.insert(key_items_list, {name = item_name, has = item_data.has})
            elseif item_data.type == 'item' then
                table.insert(trade_items_list, {name = item_name, has = item_data.has, count = item_data.count})
            end
        end
        
        if #key_items_list > 0 then
            table.insert(lines, '\\cs(255,200,0)Key Items:\\cr')
            for _, item in ipairs(key_items_list) do
                local status = item.has and '\\cs(0,255,0)O\\cr' or '\\cs(255,0,0)X\\cr'
                table.insert(lines, string.format('  %s %s', status, item.name))
            end
            table.insert(lines, '')
        end
        
        -- Trade Items
        if #trade_items_list > 0 then
            table.insert(lines, '\\cs(255,200,0)Trade Items:\\cr')
            for _, item in ipairs(trade_items_list) do
                local status = item.has and '\\cs(0,255,0)O\\cr' or '\\cs(255,0,0)X\\cr'
                local count_str = item.count > 0 and string.format(' (%d)', item.count) or ''
                table.insert(lines, string.format('  %s %s%s', status, item.name, count_str))
            end
            table.insert(lines, '')
        end
        
        -- Tracked Items (for counting)
        if next(farm_config.tracked_items) then
            table.insert(lines, '\\cs(255,200,0)Tracked Items:\\cr')
            for item_name, tracked_data in pairs(farm_config.tracked_items) do
                local count = type(tracked_data) == 'table' and tracked_data.count or tracked_data
                local item_color = count > 0 and '\\cs(0,255,0)' or '\\cs(128,128,128)'
                table.insert(lines, string.format('  %s%s: %d\\cr', item_color, item_name, count))
            end
            table.insert(lines, '')
        end
    end
    
    -- Enemy Locations
    if settings.show_enemies then
        table.insert(lines, '\\cs(255,200,0)Enemy Locations:\\cr')
        
        -- Sort enemies: mainTarget first, then others
        local enemy_list = {}
        local main_targets = {}
        local other_enemies = {}
        
        for enemy_name, enemy_data in pairs(farm_config.enemies) do
            if enemy_data.mainTarget then
                table.insert(main_targets, {name = enemy_name, data = enemy_data})
            else
                table.insert(other_enemies, {name = enemy_name, data = enemy_data})
            end
        end
        
        -- Sort each group alphabetically
        table.sort(main_targets, function(a, b) return a.name < b.name end)
        table.sort(other_enemies, function(a, b) return a.name < b.name end)
        
        -- Combine: mainTargets first, then others
        for _, enemy in ipairs(main_targets) do
            table.insert(enemy_list, enemy)
        end
        for _, enemy in ipairs(other_enemies) do
            table.insert(enemy_list, enemy)
        end
        
        -- Display enemies
        for _, enemy in ipairs(enemy_list) do
            local enemy_name = enemy.name
            local enemy_data = enemy.data
            
            -- Show exact position if we have it, otherwise show grid position
            local location_str
            if enemy_data.x ~= 0 and enemy_data.y ~= 0 then
                location_str = string.format('%s: %s (%.1f, %.1f)', enemy_name, enemy_data.pos, enemy_data.x, enemy_data.y)
            else
                location_str = string.format('%s: %s', enemy_name, enemy_data.pos)
            end
            
            -- Add mainTarget indicator
            local main_indicator = ''
            if enemy_data.mainTarget then
                main_indicator = ' \\cs(255,255,0)[MAIN]\\cr'
            end
            
            -- Check if this enemy requires pop items
            if enemy_data.popItems and #enemy_data.popItems > 0 then
                local has_all = true
                local pop_status = {}
                
                for _, pop_item in ipairs(enemy_data.popItems) do
                    local has_item = false
                    local item_data = farm_config.items[pop_item]
                    if item_data then
                        has_item = item_data.has or false
                    end
                    
                    if has_item then
                        table.insert(pop_status, string.format('\\cs(0,255,0)%s\\cr', pop_item))
                    else
                        table.insert(pop_status, string.format('\\cs(255,0,0)%s\\cr', pop_item))
                        has_all = false
                    end
                end
                
                -- Add pop items indicator
                local pop_indicator = has_all and '\\cs(0,255,0)[READY]\\cr' or '\\cs(255,128,0)[NEED]\\cr'
                table.insert(lines, string.format('  %s%s %s', location_str, main_indicator, pop_indicator))
                table.insert(lines, string.format('    Pop: %s', table.concat(pop_status, ', ')))
            else
                table.insert(lines, string.format('  %s%s', location_str, main_indicator))
            end
        end
        table.insert(lines, '')
    end
    
    -- Kill Timers (dynamic based on timer-type tracked enemies)
    if settings.show_timers then
        local has_timers = false
        for enemy_name, enemy_data in pairs(farm_config.enemies) do
            if enemy_data.spawnType == 'timer' and enemy_data.tracked then
                if not has_timers then
                    table.insert(lines, '\\cs(255,200,0)Kill Timers:\\cr')
                    has_timers = true
                end
                
                local time_since = get_time_since_kill(enemy_name)
                if time_since then
                    local ready, time = check_respawn_time(enemy_name)
                    local color = ready and '\\cs(0,255,0)' or '\\cs(255,255,0)'
                    table.insert(lines, string.format('  %s: %s%s\\cr', enemy_name, color, format_time(time)))
                else
                    table.insert(lines, string.format('  %s: \\cs(128,128,128)Not killed\\cr', enemy_name))
                end
            end
        end
        
        if has_timers then
            table.insert(lines, '')
        end
    end
    
    -- Summary
    local needed_items = {}
    for item_name, item_data in pairs(farm_config.items) do
        if item_data.type == 'key' and not item_data.has then
            table.insert(needed_items, item_name)
        end
    end
    
    if #needed_items > 0 then
        table.insert(lines, '\\cs(255,100,100)Still Need:\\cr')
        for _, item in ipairs(needed_items) do
            table.insert(lines, string.format('  - %s', item))
        end
    else
        local has_key_items = false
        for _, item_data in pairs(farm_config.items) do
            if item_data.type == 'key' then
                has_key_items = true
                break
            end
        end
        if has_key_items then
            table.insert(lines, '\\cs(0,255,0)All Key Items Obtained!\\cr')
        end
    end
    
    -- Update display box
    if display_box then
        display_box:clear()
        display_box:append(table.concat(lines, '\n'))
        display_box:show()
    end
end

-- Handle mob death - multiple detection methods
windower.register_event('action', function(act)
    if not act then return end
    
    -- Check for death category
    if act.category == 6 then  -- Category 6 is death
        local target = act.targets and act.targets[1]
        if target then
            local mob = windower.ffxi.get_mob_by_id(target.id)
            if mob then
                local mob_name = mob.name
                local enemy_data = farm_config.enemies[mob_name]
                -- Check if it's a tracked timer-based enemy
                if enemy_data and enemy_data.tracked and enemy_data.spawnType == 'timer' then
                    kill_timers[mob_name] = os.time()
                    windower.add_to_chat(8, string.format('[abFarm] %s killed! Timer started.', mob_name))
                    update_items()
                    update_ui()
                    return
                end
            end
        end
    end
    
    -- Also check action message for death
    if act.targets then
        for _, target in ipairs(act.targets) do
            if target.actions then
                for _, action in ipairs(target.actions) do
                    -- Message ID 6 is death
                    if action.message == 6 or action.message == 20 then
                        local mob = windower.ffxi.get_mob_by_id(target.id)
                        if mob then
                            local mob_name = mob.name
                            local enemy_data = farm_config.enemies[mob_name]
                            -- Check if it's a tracked timer-based enemy
                            if enemy_data and enemy_data.tracked and enemy_data.spawnType == 'timer' then
                                kill_timers[mob_name] = os.time()
                                windower.add_to_chat(8, string.format('[abFarm] %s killed! Timer started.', mob_name))
                                update_items()
                                update_ui()
                                return
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Also listen for death messages
windower.register_event('incoming text', function(original, modified, mode)
    -- Check all message modes for death messages
    local text = modified:lower()
    local text_original = original:lower()
    
    -- Death message patterns
    local death_patterns = {
        'defeated', 'falls', 'is defeated', 'falls to the ground', 'falls down',
        'is no longer', 'has been defeated', 'meets its end'
    }
    
    -- Check each tracked timer-based enemy
    for enemy_name, enemy_data in pairs(farm_config.enemies) do
        if enemy_data.tracked and enemy_data.spawnType == 'timer' then
            local enemy_lower = enemy_name:lower()
            if text:match(enemy_lower) or text_original:match(enemy_lower) then
                -- Check if it's a death message
                for _, pattern in ipairs(death_patterns) do
                    if text:match(pattern) or text_original:match(pattern) then
                        -- Only update if we don't have a recent timer
                        if kill_timers[enemy_name] == nil or (os.time() - kill_timers[enemy_name]) > 5 then
                            kill_timers[enemy_name] = os.time()
                            windower.add_to_chat(8, string.format('[abFarm] %s killed! Timer started (text detection).', enemy_name))
                            update_items()
                            update_ui()
                        end
                        return
                    end
                end
            end
        end
    end
end)

-- Scan for enemies and update their positions (no targeting required)
-- Only tracks exact positions for enemies with tracked=true
local function scan_enemy_positions()
    local found_any = false
    local player = windower.ffxi.get_player()
    
    if not player then return false end
    
    -- Get all mobs in the area - this is the key function that finds all mobs
    local mobs = windower.ffxi.get_mob_array()
    if not mobs then return false end
    
    local max_distance = 100  -- Maximum distance to scan (in game units)
    
    -- Iterate through all mobs returned
    for id, mob in pairs(mobs) do
        if mob and mob.name then
            -- Quick distance check first (fastest filter)
            if mob.distance and mob.distance <= max_distance then
                local mob_name = mob.name
                local enemy_data = farm_config.enemies[mob_name]
                -- Only update positions for tracked enemies
                if enemy_data and enemy_data.tracked then
                    if mob.x and mob.y and mob.z then
                        enemy_data.x = mob.x
                        enemy_data.y = mob.y
                        enemy_data.z = mob.z
                        found_any = true
                    end
                end
            end
        end
    end
    
    return found_any
end

-- Mob tracking: scan for tracked enemies and detect when they disappear
local function track_mobs()
    local current_mobs = {}
    
    -- Create a set of tracked enemy names for faster lookup (only timer-based enemies)
    local tracked_enemies_set = {}
    for enemy_name, enemy_data in pairs(farm_config.enemies) do
        if enemy_data.tracked and enemy_data.spawnType == 'timer' then
            tracked_enemies_set[enemy_name] = true
        end
    end
    
    -- Get all mobs in the area - this finds all mobs without targeting
    local mobs = windower.ffxi.get_mob_array()
    if not mobs then return end
    
    -- Iterate through all mobs
    for id, mob in pairs(mobs) do
        if mob and mob.name then
            local mob_name = mob.name
            local enemy_data = farm_config.enemies[mob_name]
            -- Check if it's a tracked timer-based enemy
            if enemy_data and tracked_enemies_set[mob_name] then
                current_mobs[mob.id] = {
                    name = mob_name,
                    id = mob.id,
                    hpp = mob.hpp or 100
                }
                -- Update position if we have it
                if mob.x and mob.y and mob.z then
                    enemy_data.x = mob.x
                    enemy_data.y = mob.y
                    enemy_data.z = mob.z
                end
                -- If we haven't seen this mob before, add it to tracking
                if not last_seen_mobs[mob.id] then
                    last_seen_mobs[mob.id] = {
                        name = mob_name,
                        id = mob.id,
                        first_seen = os.time()
                    }
                end
            end
        end
    end
    
    -- Check for mobs that disappeared (were tracked but no longer present)
    for mob_id, mob_data in pairs(last_seen_mobs) do
        if not current_mobs[mob_id] then
            -- Mob disappeared - check if it was recently seen (within last 30 seconds)
            local time_since_seen = os.time() - (mob_data.last_seen or mob_data.first_seen)
            if time_since_seen < 30 then
                -- Mob disappeared recently, likely killed
                local enemy_name = mob_data.name
                -- Check if we should update the timer
                local should_update = false
                if kill_timers[enemy_name] == nil then
                    should_update = true
                elseif (os.time() - kill_timers[enemy_name]) > 60 then
                    -- Only update if it's been more than a minute (avoid duplicate detections)
                    should_update = true
                end
                
                if should_update then
                    kill_timers[enemy_name] = os.time()
                    windower.add_to_chat(8, string.format('[abFarm] %s killed! Timer started (mob tracking).', enemy_name))
                    update_items()
                    update_ui()
                end
            end
            -- Remove from tracking
            last_seen_mobs[mob_id] = nil
        else
            -- Update last seen time
            last_seen_mobs[mob_id].last_seen = os.time()
        end
    end
end

-- Periodic update using separate timers
local last_key_items_update = 0
local last_inventory_update = 0
local last_mob_scan = 0
local last_position_scan = 0

-- Periodic update event
windower.register_event('prerender', function()
    local now = os.clock()
    local logged_in = windower.ffxi.get_info().logged_in
    
    if not logged_in then return end
    
    -- Check if UI position has changed (drag detection)
    if display_box then
        local current_x, current_y = display_box:pos()
        if current_x and current_y then
            -- Check if position differs from saved position
            if math.abs(current_x - settings.pos_x) > 1 or math.abs(current_y - settings.pos_y) > 1 then
                -- Position has changed, update settings
                settings.pos_x = current_x
                settings.pos_y = current_y
                settings.display.pos.x = current_x
                settings.display.pos.y = current_y
                
                -- Debounce saves (only save every 0.5 seconds)
                if not drag_save_timer or (now - drag_save_timer) >= 0.5 then
                    save_config()
                    drag_save_timer = now
                end
            end
        end
    end
    
    -- Update key items at configured rate
    if now - last_key_items_update >= settings.update_rate_key_items then
        update_key_items()
        update_ui()
        last_key_items_update = now
    end
    
    -- Update inventory items at configured rate
    if now - last_inventory_update >= settings.update_rate_inventory then
        update_inventory_items()
        update_ui()
        last_inventory_update = now
    end
    
    -- Scan for mobs every 1 second
    if now - last_mob_scan >= 1 then
        track_mobs()
        last_mob_scan = now
    end
    
    -- Scan for enemy positions every 5 seconds (automatic position updates)
    if now - last_position_scan >= 5 then
        scan_enemy_positions()
        update_ui()
        last_position_scan = now
    end
end)


-- Initialize
windower.register_event('load', function()
    if windower.ffxi.get_info().logged_in then
        local config_loaded = false
        
        -- Debug: show what we have in settings
        -- windower.add_to_chat(8, string.format('[abFarm] Debug: settings.last_config = %s', tostring(settings.last_config)))
        
        -- Try to load last config if one was saved
        if settings.last_config and settings.last_config ~= '' and settings.last_config ~= 'glavoid' then
            --windower.add_to_chat(8, string.format('[abFarm] Attempting to load saved config: %s', settings.last_config))
            if load_farm_config(settings.last_config, false) then
                config_loaded = true
            else
                windower.add_to_chat(8, string.format('[abFarm] Failed to load saved config "%s", trying glavoid', settings.last_config))
            end
        else
            windower.add_to_chat(8, string.format('[abFarm] No saved config found (or is glavoid), will try glavoid as default'))
        end
        
        -- If no saved config or it failed, try glavoid as default (but don't save it)
        if not config_loaded then
            if load_farm_config('glavoid', true) then  -- true = is_fallback
                windower.add_to_chat(8, '[abFarm] Loaded default config: glavoid')
                config_loaded = true
            else
                windower.add_to_chat(8, '[abFarm] Warning: Could not load any config. Please load a config manually with //abfarm load <name>')
            end
        end
        
        if config_loaded then
            update_items()
            create_ui()
            update_ui()
        end
    end
end)

windower.register_event('login', function()
    local config_loaded = false
    
    -- Try to load last config if one was saved
    if settings.last_config and settings.last_config ~= '' and settings.last_config ~= 'glavoid' then
        if load_farm_config(settings.last_config) then
            config_loaded = true
        else
            windower.add_to_chat(8, string.format('[abFarm] Failed to load saved config "%s", trying glavoid', settings.last_config))
        end
    end
    
    -- If no saved config or it failed, try glavoid as default (but don't save it)
    if not config_loaded then
        if load_farm_config('glavoid', true) then  -- true = is_fallback
            windower.add_to_chat(8, '[abFarm] Loaded default config: glavoid')
            config_loaded = true
        else
            windower.add_to_chat(8, '[abFarm] Warning: Could not load any config. Please load a config manually with //abfarm load <name>')
        end
    end
    
    if config_loaded then
        update_items()
        create_ui()
        update_ui()
    end
end)

windower.register_event('logout', function()
    if display_box then display_box:hide() end
end)

-- Commands
windower.register_event('addon command', function(command, ...)
    local args = {...}
    command = command and command:lower() or ''
    
    if command == 'toggle' or command == 't' then
        settings.enabled = not settings.enabled
        save_config()
        update_ui()
        windower.add_to_chat(8, string.format('[abFarm] %s', settings.enabled and 'Enabled' or 'Disabled'))
        
    elseif command == 'pos' or command == 'position' then
        if #args >= 2 then
            settings.pos_x = tonumber(args[1]) or settings.pos_x
            settings.pos_y = tonumber(args[2]) or settings.pos_y
            save_config()
            create_ui()
            update_ui()
            windower.add_to_chat(8, string.format('[abFarm] Position set to %d, %d', settings.pos_x, settings.pos_y))
        else
            windower.add_to_chat(8, '[abFarm] Usage: //abfarm pos <x> <y>')
        end
        
    elseif command == 'font' or command == 'size' then
        if #args >= 1 then
            settings.font_size = tonumber(args[1]) or settings.font_size
            save_config()
            create_ui()
            update_ui()
            windower.add_to_chat(8, string.format('[abFarm] Font size set to %d', settings.font_size))
        else
            windower.add_to_chat(8, '[abFarm] Usage: //abfarm font <size>')
        end
        
    elseif command == 'rate' or command == 'update' then
        if #args >= 2 then
            local type_arg = args[1]:lower()
            local rate = tonumber(args[2])
            if rate and rate > 0 then
                if type_arg == 'key' or type_arg == 'keyitems' or type_arg == 'ki' then
                    settings.update_rate_key_items = rate
                    save_config()
                    windower.add_to_chat(8, string.format('[abFarm] Key items update rate set to %.1f seconds', rate))
                elseif type_arg == 'inventory' or type_arg == 'inv' or type_arg == 'items' then
                    settings.update_rate_inventory = rate
                    save_config()
                    windower.add_to_chat(8, string.format('[abFarm] Inventory update rate set to %.1f seconds', rate))
                else
                    windower.add_to_chat(8, '[abFarm] Usage: //abfarm rate <key|inventory> <seconds>')
                end
            else
                windower.add_to_chat(8, '[abFarm] Invalid rate value. Must be a positive number.')
            end
        else
            windower.add_to_chat(8, '[abFarm] Current update rates:')
            windower.add_to_chat(8, string.format('  Key items: %.1f seconds', settings.update_rate_key_items))
            windower.add_to_chat(8, string.format('  Inventory: %.1f seconds', settings.update_rate_inventory))
            windower.add_to_chat(8, '[abFarm] Usage: //abfarm rate <key|inventory> <seconds>')
        end
        
    elseif command == 'load' then
        if #args >= 1 then
            local config_name = args[1]
            if load_farm_config(config_name, false) then  -- false = explicit user load
                -- Update items and UI after successful load
                update_items()
                update_ui()
            end
        else
            windower.add_to_chat(8, '[abFarm] Usage: //abfarm load <config_name>')
            if current_config_name then
                windower.add_to_chat(8, string.format('[abFarm] Current config: %s', current_config_name))
            end
            -- Show available configs
            local configs = list_configs()
            if #configs > 0 then
                windower.add_to_chat(8, '[abFarm] Available configs: '..table.concat(configs, ', '))
            else
                windower.add_to_chat(8, '[abFarm] No config files found in configs/ directory')
            end
        end
        
    elseif command == 'list' or command == 'configs' then
        local configs = list_configs()
        if #configs > 0 then
            windower.add_to_chat(8, '[abFarm] Available configs:')
            for _, config_name in ipairs(configs) do
                local marker = (config_name == current_config_name) and ' [CURRENT]' or ''
                windower.add_to_chat(8, string.format('  - %s%s', config_name, marker))
            end
        else
            windower.add_to_chat(8, '[abFarm] No config files found in configs/ directory')
            windower.add_to_chat(8, '[abFarm] Create config files in: '..windower.addon_path..'configs/')
        end
        
    elseif command == 'kill' then
        if #args >= 1 then
            local enemy = table.concat(args, ' ')
            -- Capitalize first letter
            enemy = enemy:sub(1,1):upper() .. enemy:sub(2):lower()
            
            -- Check if it's a tracked timer-based enemy
            local enemy_data = farm_config.enemies[enemy]
            if enemy_data and enemy_data.tracked and enemy_data.spawnType == 'timer' then
                kill_timers[enemy] = os.time()
                windower.add_to_chat(8, string.format('[abFarm] %s kill timer started manually.', enemy))
                update_ui()
            else
                -- Build list of valid enemies
                local valid_enemies = {}
                for enemy_name, enemy_data in pairs(farm_config.enemies) do
                    if enemy_data.tracked and enemy_data.spawnType == 'timer' then
                        table.insert(valid_enemies, enemy_name)
                    end
                end
                if #valid_enemies > 0 then
                    local valid_list = table.concat(valid_enemies, ', ')
                    windower.add_to_chat(8, string.format('[abFarm] Valid enemies: %s', valid_list))
                else
                    windower.add_to_chat(8, '[abFarm] No timer-based tracked enemies configured.')
                end
            end
        else
            -- Build list of valid enemies
            local valid_enemies = {}
            for enemy_name, enemy_data in pairs(farm_config.enemies) do
                if enemy_data.tracked and enemy_data.spawnType == 'timer' then
                    table.insert(valid_enemies, enemy_name)
                end
            end
            if #valid_enemies > 0 then
                local valid_list = table.concat(valid_enemies, '|')
                windower.add_to_chat(8, string.format('[abFarm] Usage: //abfarm kill <%s>', valid_list))
            else
                windower.add_to_chat(8, '[abFarm] No timer-based tracked enemies configured.')
            end
        end
        
    elseif command == 'scan' then
        windower.add_to_chat(8, '[abFarm] Scanning for enemy positions...')
        local found = scan_enemy_positions()
        if found then
            windower.add_to_chat(8, '[abFarm] Enemy positions updated!')
            update_ui()
        else
            windower.add_to_chat(8, '[abFarm] No tracked enemies found nearby.')
        end
        
    elseif command == 'reset' then
        -- Reset all tracked timer-based enemy timers
        for enemy_name, enemy_data in pairs(farm_config.enemies) do
            if enemy_data.tracked and enemy_data.spawnType == 'timer' then
                kill_timers[enemy_name] = nil
            end
        end
        windower.add_to_chat(8, '[abFarm] Kill timers reset.')
        update_ui()
        
    elseif command == 'debug' or command == 'd' then
        -- Check key items using the API like findAll does
        local key_items_list = windower.ffxi.get_key_items()
        if key_items_list then
            windower.add_to_chat(8, string.format('[abFarm] Debug - Found %d key items using get_key_items()', #key_items_list))
            if #key_items_list > 0 then
                windower.add_to_chat(8, '  First 10 key item IDs:')
                for i = 1, math.min(10, #key_items_list) do
                    windower.add_to_chat(8, string.format('    [%d] = %d', i, key_items_list[i]))
                end
            end
        else
            windower.add_to_chat(8, '[abFarm] Debug - get_key_items() returned nil')
        end
        
        -- Try to find our key items
        windower.add_to_chat(8, '[abFarm] Checking for specific key items:')
        for item_name, item_data in pairs(farm_config.items) do
            if item_data.type == 'key' then
                local has_it = has_key_item(item_name)
                local id_str = item_data.id and string.format(' (ID: %d)', item_data.id) or ' (ID: unknown)'
                windower.add_to_chat(8, string.format('  %s%s: %s', item_name, id_str, has_it and 'FOUND' or 'NOT FOUND'))
            end
        end
        
        -- Debug tracked items
        windower.add_to_chat(8, '[abFarm] Tracked items:')
        for item_name, tracked_data in pairs(farm_config.tracked_items) do
            if type(tracked_data) == 'table' then
                local id_str = tracked_data.id and string.format(' (ID: %d)', tracked_data.id) or ' (ID: unknown)'
                windower.add_to_chat(8, string.format('  %s%s: count = %d', item_name, id_str, tracked_data.count or 0))
                -- Test get_item_count
                local test_count = get_item_count(item_name)
                windower.add_to_chat(8, string.format('    get_item_count returned: %d', test_count))
            else
                windower.add_to_chat(8, string.format('  %s: count = %d (no ID)', item_name, tracked_data))
            end
        end
        
    elseif command == 'help' or command == 'h' then
        windower.add_to_chat(8, '[abFarm] Commands:')
        windower.add_to_chat(8, '  //abfarm toggle - Toggle display on/off')
        windower.add_to_chat(8, '  //abfarm load <name> - Load farm configuration')
        windower.add_to_chat(8, '  //abfarm pos <x> <y> - Set UI position')
        --windower.add_to_chat(8, '  //abfarm font <size> - Set font size')
        --windower.add_to_chat(8, '  //abfarm rate <key|inventory> <seconds> - Set update rate')
        -- Build list of valid enemies
        local valid_enemies = {}
        for enemy_name, enemy_data in pairs(farm_config.enemies) do
            if enemy_data.tracked and enemy_data.spawnType == 'timer' then
                table.insert(valid_enemies, enemy_name)
            end
        end
        if #valid_enemies > 0 then
            local valid_list = table.concat(valid_enemies, '|')
            windower.add_to_chat(8, string.format('  //abfarm kill <%s> - Manually set kill time', valid_list))
        end
        windower.add_to_chat(8, '  //abfarm scan - Scan for enemy positions')
        windower.add_to_chat(8, '  //abfarm reset - Reset kill timers')
        --windower.add_to_chat(8, '  //abfarm debug - Debug key items detection')
        windower.add_to_chat(8, '  //abfarm help - Show this help')
        
    else
        windower.add_to_chat(8, '[abFarm] Unknown command. Use //abfarm help for commands.')
    end
end)

-- Cleanup on unload
windower.register_event('unload', function()
    if display_box then display_box:destroy() end
end)


