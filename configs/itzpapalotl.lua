-- Itzpapalotl Farm Configuration
-- This file defines all items, enemies, and settings for farming Itzpapalotl

config = {
    -- Items: {name = {id = number, type = 'key'|'item'}}
    -- type 'key' = key item, type 'item' = regular inventory item
    items = {
        -- Key Items
        ['Venomous wamoura feeler'] = {id = 1474, type = 'key'},
        ['Bulbous crawler cocoon'] = {id = 1489, type = 'key'},
        ['Distended chigoe abdomen'] = {id = 1490, type = 'key'},
        
        -- Trade Items
        ['Withered Cocoon'] = {id = 3072, type = 'item'},
        ['Eruca Egg'] = {id = 3073, type = 'item'},
    },
    
    -- Tracked Items: Items to count (like Itzpapalotl Scales)
    -- These are items you want to track the count of
    -- Format: {id = item_id} - the count will be updated automatically
    tracked_items = {
        ['Itzpapalotl\'s scale'] = {id = 2962},  -- Will be updated automatically
    },
    
    -- Enemies: {name = {zone, pos, tracked, spawnType, popItems}}
    -- spawnType: 'pop' = requires pop items, 'timer' = respawns after kill timer, 'lottery' = random spawn, 'default' = normal spawn
    -- tracked: true = track position and kills, false = just show location
    -- popItems: array of item names required to pop this enemy
    enemies = {
        ['Granite Borer'] = {
            zone = 'Abyssea - Altepa',
            pos = 'G-7',
            x = 0, y = 0, z = 0,  -- Will be updated if tracked
            tracked = false,
            spawnType = 'pop',
            popItems = {'Withered Cocoon'},
        },
        ['Blazing Eruca'] = {
            zone = 'Abyssea - Altepa',
            pos = 'J-10',
            x = 0, y = 0, z = 0,
            tracked = false,
            spawnType = 'pop',
            popItems = {'Eruca Egg'},
        },
        ['Ignis Eruca'] = {
            zone = 'Abyssea - Altepa',
            pos = 'I-10',
            x = 0, y = 0, z = 0,
            tracked = false,
            spawnType = 'default',
            popItems = {},
        },
        ['Gullycampa'] = {
            zone = 'Abyssea - Altepa',
            pos = 'K-10',
            x = 0, y = 0, z = 0,
            tracked = false,
            spawnType = 'default',
            popItems = {},
        },
        ['Tunga'] = {
            zone = 'Abyssea - Altepa',
            pos = 'K-10',
            x = 0, y = 0, z = 0,
            tracked = true,  -- Track position and kills
            spawnType = 'timer',  -- Respawns 10-15 minutes after kill
            popItems = {},
        },
        ['Itzpapalotl'] = {
            zone = 'Abyssea - Altepa',
            pos = 'K-10',
            x = 0, y = 0, z = 0,
            tracked = false,
            spawnType = 'pop',
            popItems = {},
            mainTarget = true,
        },
    },
    
    -- Trade Locations: Where to trade items for key items
    trade_locations = {
        ['Withered Cocoon Trade'] = {
            zone = 'Abyssea - Altepa',
            pos = 'K-10',
            items = {'Withered Cocoon'},
        },
        ['Eruca Egg Trade'] = {
            zone = 'Abyssea - Altepa',
            pos = 'J-10',
            items = {'Eruca Egg'},
        },
    },
}

