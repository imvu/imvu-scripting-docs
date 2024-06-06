-- This script provides a presenter-controlled jukebox.
-- The first thing the script does is place two furniture items in the scene.
-- The screen product is what displays the youtube videos. Right now, the youtube videos only play on Desktop, iOS, and Android.
-- This is a pain, because the script editor only works on Web! You have to write the script on one platform and test on another.
-- Sorry!
-- This product is one of very few imvu-provided products which can display youtube videos in the scene. You can only use a youtube-enabled product for this.

local SCREEN_PRODUCT = 52977230 -- change this value to change which furniture product displays the content. Only a few are capable!
local SCREEN_PRODUCT_MATERIAL = "material1"

-- The second furniture item placed in the scene is entirely up to you. I tested it with a jukebox, because I'm old.
-- You can substitute any furniture product you happen to own for this value. For instance, 29882610 would use the penthouse couch.
-- I selected 56190467 from the product catalog, arbitrarily, and this does not imply an endorsement of the product or creator.

local JUKEBOX_PRODUCT = 29882610 -- change this value to change which furniture product controls the screen.

-- Once the two furniture items are placed in the scene, any avatar which uses the JUKEBOX_PRODUCT furniture will have control over the screen.
-- If we use 29882610, for instance, any avatar which sits on that couch should be able to control the screen.
-- If we use 56190467, any avatar which stands at the jukebox should be able to control the screen.

local function starts_with(str, start)
    return str:sub(1, #start) == start
end

local jukebox_script = {
    screen = { label = "jukebox_screen", pid = SCREEN_PRODUCT, node = "furniture.Floor.53", x = 0.6399999856948853, y = 0, z = 0.009999999776482582, yaw = 4.677482604980469, pitch = 0, roll = 0, scale = 1},
    jukebox = { label = "jukebox", pid = JUKEBOX_PRODUCT, node = "furniture.Floor.53", x = 0.9700000286102295, y = 0, z = 5.46999979019165, yaw = 4.70017147064209, pitch = 0, roll = 0, scale = 1},
    cid_lookup = {},
    media_request = { label = "jukebox_screen", target_name = SCREEN_PRODUCT_MATERIAL },
    entries = {},
    entry_keys = {},

    -- this function is called when someone places their avatar at the control furniture.
    -- it sends instructions to the public channel for how to request a particular video.
    send_instructions = function(self, actor_cid)
        local msg = "Welcome to the jukebox! Enter 'press 1' through 'press 7' to select a song, or 'press (code)' with a youtube video id. ("
        local not_first = false
        for _, k in ipairs(self.entry_keys) do
            local v = self.entries[k]
            if not_first then
                msg = msg .. ", "
            else
                not_first = true
            end
            msg = msg .. k .. ": " .. v.media_title
        end
        msg = msg .. ")"
        imvu.message_audience(msg)
    end,
    get_valid_input = function(self, message)
        if starts_with(message, 'press ') then
            return self.entries[message:sub(7)]
        end
        return nil
    end,
    event_begin_execution = function(self)
        imvu.debug("Placing furniture")
        imvu.place_furniture(self.screen)
        imvu.place_furniture(self.jukebox)
    end,
    event_state_change_received = function(self, context, actor_cid, actor_name, seat_number, seat_furni_id, seat_furni_pid, actor_outfit)
        -- when someone stands on the jukebox, send them instructions and note their cid for future reference.
        local key = 'cid.' .. actor_cid
        if seat_furni_pid == self.jukebox.pid then
            self.cid_lookup[key] = true
            self:send_instructions(actor_cid)
        elseif context == 'scene_leave' or context == 'scene_move' then
            self.cid_lookup[key] = nil
        end
    end,
    event_message_received = function(self, context, message, sender_cid, sender_name, sender_node)
        -- when we get input from the person standing at the jukebox, parse it.
        local key = "cid." .. sender_cid
        if self.cid_lookup[key] ~= nil then
            -- first, check to see if they're requesting a video we know about
            -- the list of known videos is provided below
            local input = self:get_valid_input(message)
            if input ~= nil then
                imvu.message_audience("Playing " .. sender_name .. "'s request: " .. input.media_title )
                imvu.control_media("play_media", input)
            elseif starts_with(message, 'press ') then
                -- if what they request isn't a key to our array of known entries,
                -- treat it as a youtube video id and give it a shot.
                imvu.message_audience("Couldn't find an entry for " .. message:sub(7) .. " but I'm going to try to play it anyway, " .. sender_name .. "!")
                self.media_request.media_title = sender_name .. "'s special request"
                self.media_request.media_url = "https://www.youtube.com/watch?v=" .. message:sub(7)
                imvu.control_media("play_media", self.media_request)
            end
        end
    end
}

-- Now we add the jukebox entries.
-- These example vidoes are a harrowing insight into my own, bad, taste.
-- Nonetheless, their inclusion is the result of arbitrary youtube searches,
-- and does not qualify as a personal or corporate endorsement of the videos,
-- the channels, or anyone involved in their production.
-- These are simply some videos that tended to play consistently on embedded
-- youtube applications in the united states when they were last tested.
jukebox_script.entries["1"] = { media_title = "Jazz Cat", media_url = "https://www.youtube.com/watch?v=zWLAbNHn5Ho", media_timestamp = 0, label = "jukebox_screen", target_name = "material1" }
jukebox_script.entries["2"] = { media_title = "The Abyss", media_url = "https://www.youtube.com/watch?v=hYMFYtoyhek", media_timestamp = 0, label = "jukebox_screen", target_name = "material1" }
jukebox_script.entries["3"] = { media_title = "Welcome to the Internet", media_url = "https://www.youtube.com/watch?v=k1BneeJTDcU", media_timestamp = 0, label = "jukebox_screen", target_name = "material1" }
jukebox_script.entries["4"] = { media_title = "History of the Entire World", media_url = "https://www.youtube.com/watch?v=xuCn8ux2gbs", media_timestamp = 0, label = "jukebox_screen", target_name = "material1" }
jukebox_script.entries["5"] = { media_title = "Megalovania", media_url = "https://www.youtube.com/watch?v=wDgQdr8ZkTw", media_timestamp = 0, label = "jukebox_screen", target_name = "material1" }
jukebox_script.entries["6"] = { media_title = "Just One Day", media_url = "https://www.youtube.com/watch?v=AdVgPCM5wEk", media_timestamp = 0, label = "jukebox_screen", target_name = "material1" }
jukebox_script.entries["7"] = { media_title = "Those Who Fight Further", media_url = "https://www.youtube.com/watch?v=NzFh9GuE0rA", media_timestamp = 0, label = "jukebox_screen", target_name = "material1" }

-- after we have the jukebox entries populated, we create the entry_keys lookup.
-- this provides the list of options that are presented to users.
for k in pairs(jukebox_script.entries) do table.insert(jukebox_script.entry_keys, k) end
table.sort(jukebox_script.entry_keys)

-- entries added after we create entry_keys won't be listed. here are your secret jukebox shitposts
-- for example, "press metaverse" will play The Future is a Dead Mall
-- originally this section was for never gonna give you up, but it's copyrighted and banned from embedded youtube
jukebox_script.entries["7remake"] = { media_title = "Those Who Fight Further??", media_url = "https://www.youtube.com/watch?v=lwfgb7kvx2Q", media_timestamp = 0, label = "jukebox_screen", target_name = "material1" }
jukebox_script.entries["7rebound"] = { media_title = "Those Who Jam Further!", media_url = "https://www.youtube.com/watch?v=jw9OGbHcAhg", media_timestamp = 0, label = "jukebox_screen", target_name = "material1" }
jukebox_script.entries["7rebirth"] = { media_title = "Those Who Toot Further", media_url = "https://www.youtube.com/watch?v=5DNkTL2cWwI", media_timestamp = 0, label = "jukebox_screen", target_name = "material1" }
jukebox_script.entries["metaverse"] = { media_title = "The Future is a Dead Mall", media_url = "https://www.youtube.com/watch?v=EiZhdpLXZ8Q", media_timestamp = 0, label = "jukebox_screen", target_name = "material1" }

imvu.debug("Loaded script")

return {
    event_start = function()
        jukebox_script:event_begin_execution()
    end,
    event_message_received = function(context, sender, message)
        jukebox_script:event_message_received(context, message, sender.cid, sender.name, sender.node)
    end,
    event_state_changed = function(context, actor, message)
        jukebox_script:event_state_change_received(context, actor.cid, actor.name, actor.seat_number, actor.seat_furni_id, actor.seat_furni_pid, actor.outfit)
    end
}