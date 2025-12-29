-- Glavoid Farm Configuration
-- This file defines all items, enemies, and settings for farming Glavoid

config = {
    -- Items: {name = {id = number, type = 'key'|'item'}}
    -- type 'key' = key item, type 'item' = regular inventory item
    items = {
        -- Key Items
        ['Luxuriant manticore mane'] = {id = 1474, type = 'key'},
        ['Fat-lined cockatrice skin'] = {id = 1472, type = 'key'},
        ['Sticky gnat wing'] = {id = 1475, type = 'key'},
        ['Sodden sandworm husk'] = {id = 1473, type = 'key'},
        
        -- Trade Items
        ['Resilient Mane'] = {id = 2925, type = 'item'},
        ['Smooth Whisker'] = {id = 2950, type = 'item'},
        ['Shk. Whisker'] = {id = 2924, type = 'item'},
        ['Cockatrice Tailmeat'] = {id = 2923, type = 'item'},
        ['Quivering Eft Egg'] = {id = 2949, type = 'item'},
        ['Eft Egg'] = {id = 2922, type = 'item'},
    },
    
    -- Tracked Items: Items to count (like Glavoid shell)
    -- These are items you want to track the count of
    -- Format: {id = item_id} - the count will be updated automatically
    tracked_items = {
        ['Glavoid shell'] = {id = 2927},  -- Will be updated automatically
    },
    
    -- Enemies: {name = {zone, pos, tracked, spawnType, popItems}}
    -- spawnType: 'pop' = requires pop items, 'timer' = respawns after kill timer, 'lottery' = random spawn, 'default' = normal spawn
    -- tracked: true = track position and kills, false = just show location
    -- popItems: array of item names required to pop this enemy
    enemies = {
        ['Cluckatrice'] = {
            zone = 'Abyssea - Altepa',
            pos = 'G-7',
            x = 0, y = 0, z = 0,  -- Will be updated if tracked
            tracked = false,
            spawnType = 'default',
            popItems = {},
        },
        ['Abas'] = {
            zone = 'Abyssea - Altepa',
            pos = 'K-10',
            x = 0, y = 0, z = 0,
            tracked = false,
            spawnType = 'pop',
            popItems = {'Eft Egg'},
        },
        ['Hieracosphinx'] = {
            zone = 'Abyssea - Altepa',
            pos = 'I-6',
            x = 0, y = 0, z = 0,
            tracked = false,
            spawnType = 'default',
            popItems = {},
        },
        ['Tefenet'] = {
            zone = 'Abyssea - Altepa',
            pos = 'G-6',
            x = 0, y = 0, z = 0,
            tracked = false,
            spawnType = 'pop',
            popItems = {'Shk. Whisker'},
        },
        ['Adze'] = {
            zone = 'Abyssea - Altepa',
            pos = 'G-5',
            x = 0, y = 0, z = 0,
            tracked = true,  -- Track position and kills
            spawnType = 'timer',  -- Respawns 10-15 minutes after kill
            popItems = {},
        },
        ['Minhocao'] = {
            zone = 'Abyssea - Altepa',
            pos = 'I-6',
            x = 0, y = 0, z = 0,
            tracked = true,  -- Track position and kills
            spawnType = 'timer',  -- Respawns 10-15 minutes after kill
            popItems = {},
        },
        ['Glavoid'] = {
            zone = 'Abyssea - Altepa',
            pos = 'I-5',
            x = 0, y = 0, z = 0,
            tracked = false,
            spawnType = 'default',
            popItems = {},
            mainTarget = true,  -- Main target - will be listed first with [MAIN] indicator
        },
    },
    
    -- Trade Locations: Where to trade items for key items
    trade_locations = {
        ['Manticore Mane Trade'] = {
            zone = 'Abyssea - Altepa',
            pos = 'J-6',
            items = {'Resilient Mane', 'Smooth Whisker'},
        },
        ['Cockatrice Skin Trade'] = {
            zone = 'Abyssea - Altepa',
            pos = 'H-8',
            items = {'Cockatrice Tailmeat', 'Quivering Eft Egg'},
        },
    },
}

