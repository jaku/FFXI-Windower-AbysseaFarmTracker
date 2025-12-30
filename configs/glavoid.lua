-- Glavoid Farm Configuration
-- This file defines all items, enemies, and settings for farming Glavoid

config = {
    -- Zone information (applies to all enemies and trade locations)
    zone = 'Abyssea - Altepa',  -- Zone name (optional, for display)
    zone_id = 45,                -- Zone ID (required for zone matching)
    
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
    
    -- Enemies: {name = {pos, tracked, spawnType, popItems}}
    -- spawnType: 'pop' = requires pop items, 'timer' = respawns after kill timer, 'lottery' = random spawn, 'default' = normal spawn
    -- tracked: true = track position and kills, false = just show location
    -- popItems: array of item names required to pop this enemy
    enemies = {
        ['Cluckatrice'] = {
            pos = 'G-7',
            x = 0, y = 0, z = 0,  -- Will be updated if tracked
            tracked = false,
            spawnType = 'default',
            popItems = {},
        },
        ['Jaguarundi'] = {
            pos = 'H-6',
            x = 0, y = 0, z = 0,
            tracked = false,
            spawnType = 'default',
            popItems = {},
        },
        ['Eft'] = {
            pos = 'K-10',
            x = 0, y = 0, z = 0,
            tracked = false,
            spawnType = 'default',
            popItems = {},
        },
        ['Abas'] = {
            pos = 'K-10',
            x = 403.68, y = -399.65, z = -16.00,
            tracked = false,
            spawnType = 'pop',
            popItems = {'Eft Egg'},
            showPopLocation = true,  -- Show ??? location when nearby
        },
        ['Alectryon'] = {
            pos = 'G-7',
            x = -40.00, y = 33.61, z = -7.88,  -- Optional: exact coordinates for distance tracking
            spawnType = 'pop',
            popItems = {'Cockatrice Tailmeat', 'Quivering Eft Egg'},
            tracked = false,
            showPopLocation = true,  -- Show ??? location when nearby
        },
        ['Hieracosphinx'] = {
            pos = 'I-6',
            x = 0, y = 0, z = 0,
            tracked = false,
            spawnType = 'default',
            popItems = {},
        },
        ['Tefenet'] = {
            pos = 'G-6',
            x = -127.83, y = 238.43, z = 15.04,  -- Exact coordinates for pop location
            tracked = false,
            spawnType = 'pop',
            popItems = {'Shk. Whisker'},
            showPopLocation = true,  -- Show ??? location when nearby
        },
        ['Adze'] = {
            pos = 'G-5',
            x = 0, y = 0, z = 0,
            tracked = true,
            spawnType = 'timer',
            popItems = {},
        },
        ['Minhocao'] = {
            pos = 'I-6',
            x = 0, y = 0, z = 0,
            tracked = true,
            spawnType = 'timer', 
            popItems = {},
        },
        ['Glavoid'] = {
            pos = 'I-5',
            x = 196.85, y = 400.71, z = 32.00,
            tracked = false,
            spawnType = 'default',
            showPopLocation = true,
            popItems = {'Luxuriant manticore mane', 'Fat-lined cockatrice skin', 'Sticky gnat wing', 'Sodden sandworm husk'},
            mainTarget = true,  -- Main target - will be listed first with [MAIN] indicator
        },
        ['Muscaliet'] = {
            pos = 'J-6',
            x = 247.63, y = 290.42, z = 46.00,
            tracked = false,
            spawnType = 'pop',
            popItems = {'Smooth Whisker', 'Resilient Mane'},
            showPopLocation = true,  -- Show ??? location when nearby
        },
    },
    
    -- Trade Locations: Where to trade items for key items
    -- These are actual trade spots (like NPCs or special locations)
    -- For pop locations (??? spots), use showPopLocation = true on the enemy entry instead
    -- Optional: Add x, y, z coordinates for exact distance tracking (only shows when within 50 yalms)
    trade_locations = {
        -- ['Manticore Mane Trade'] = {
        --     pos = 'J-6',
        --     x = -19, y = 44, z = -10,  -- Optional: exact coordinates for distance tracking
        --     items = {'Resilient Mane', 'Smooth Whisker'},
        -- }
    },
}

