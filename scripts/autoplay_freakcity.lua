-- This script was written for the FreakCity partnership event as a test of the
-- scripting prototype. It automatically plays videos from a shortlist of youtube
-- videos requested by our partners, filtered down to the ones that youtube's
-- embedded media api would actually play in the United States.

-- The pids, nodes, and youtube information provided here do not comprise a
-- personal or corporate endorsement for the content or content creators. They
-- are included for demonstration purposes only.

imvu.debug("Loading script...")

local function starts_with(str, start)
    return str:sub(1, #start) == start
end

local autoplay = { 
    -- first, we define some parameters for the function calls we're going to make.
    -- we have to target a material on the product that's playing the media.
    target_name = "material1",
    -- we have to place the furniture we're going to target.
    target_furniture = {
        label = "autoplay_target",
        pid = 50710629, 
        node = "furniture.Floor.1047",
        x = 0,
        y = 0.74,
        z = -2.95,
    },
    -- and we have to define the videos we're going to cycle through.
    entries = {
        { media_title = "EYEDRESS - COMMITTING CRIMES (OFFICIAL VIDEO)", media_url = "https://www.youtube.com/watch?v=KQX2hXhTTzI", media_timestamp = 0, duration = 82 },
        { media_title = "MCR-T & Miss Bashful - Lollipops & Limousines (Official Video)", media_url = "https://www.youtube.com/watch?v=jDW2P8cG6cI", media_timestamp = 0, duration = 269 },
        { media_title = "MCR-T & horsegiirL - My Little White Pony (Official Video) [LFEKD002]", media_url = "https://www.youtube.com/watch?v=MI-rOs2o4eA", media_timestamp = 0, duration = 272 },
        { media_title = "Baby Tate & Saweetie - Hey, Mickey! (Official Music Video)", media_url = "https://www.youtube.com/watch?v=3aJsrdAvI4A", media_timestamp = 0, duration = 180 },
        
        { media_title = "Rico Nasty - Gotsta Get Paid (Official Music Video)", media_url = "https://www.youtube.com/watch?v=QsjqqzGHs1E", media_timestamp = 0, duration = 198 },
        { media_title = "Isabella Lovestory - Fashion Freak (Official Music Video)", media_url = "https://www.youtube.com/watch?v=cU0328feQag", media_timestamp = 0, duration = 148 },
        { media_title = "TAICHU - TIC TAC (VIDEO OFICIAL)", media_url = "https://www.youtube.com/watch?v=dDIrapHKPi4", media_timestamp = 0, duration = 168 },
        { media_title = "Alexis Jae - Dangerous Emotion (OFFICIAL VIDEO)", media_url = "https://www.youtube.com/watch?v=JpiuvTp10e0", media_timestamp = 0, duration = 165 },
        { media_title = "Yung Lean ft. FKA twigs - Bliss (Official Video)", media_url = "https://www.youtube.com/watch?v=2N1liztehz8", media_timestamp = 0, duration = 195 },
        { media_title = "Nasty Noona - New Ricks (Official Music Video)", media_url = "https://www.youtube.com/watch?v=YdB1HfQb4pg", media_timestamp = 0, duration = 96 },
        { media_title = "cumgirl8 - cicciolina (Official Video)", media_url = "https://www.youtube.com/watch?v=GyhZd0o9aEM", media_timestamp = 0, duration = 300 },
        
        { media_title = "✂️Come 2 Brazil (Official Music Video)✂️ - Alice Longyu Gao", media_url = "https://www.youtube.com/watch?v=dSBYl6WCG9M", media_timestamp = 0, duration = 148 },
        { media_title = "N8NOFACE \"A JOY IN DEATH\" Official Music Video.", media_url = "https://www.youtube.com/watch?v=WKci0EiWrQ0", media_timestamp = 0, duration = 132 },
        { media_title = "Lil Mariko - Boring ft. Full Tac (Official Video)", media_url = "https://www.youtube.com/watch?v=qtjdI0baXfY", media_timestamp = 0, duration = 149 },

    },
    current_index = 0,
    current_iteration = 0,
    current_time = 0,
    started_playing = 0,
    resume_timestamp = 0,
    resume_duration = 0,
    next_after = 0,
    resume_after = nil,
    should_play_next = false,
    is_active = false,
    stop_playing = function(self)
        imvu.debug("Entered autoplay:stop_playing()")
        self.is_active = false
        local input = { media_title = 'Stopped',
            media_url = '',
            media_timestamp = 0,
            label = self.target_furniture.label,
            target_name = self.target_name
        }
        self.next_after = 0,
        imvu.control_media("stop_media", input)
    end,
    next_song = function(self)
        imvu.debug("Entered autoplay:next_song()")
        -- cycle through our playlist. remember, lua tables begin indexing at 1
        self.current_index = self.current_index + 1
        if self.current_index > #self.entries then
            self.current_index = 1
        end
        -- reset some of our local state, get the entry we're going to play
        local entry = self.entries[self.current_index]
        self.current_media_timestamp = entry.media_timestamp
        self.started_playing = self.current_time
        self.next_after = self.current_time + entry.duration
        self.resume_after = nil
        self.is_active = true
        -- build the control_media callout
        local input = { media_title = entry.media_title,
            media_url = entry.media_url,
            media_timestamp = self.current_media_timestamp, 
            label = self.target_furniture.label, 
            target_name = self.target_name
        }
        imvu.debug("Attempting to play " .. input.media_url .. " onto " .. input.label .. " and " .. input.target_name)
        imvu.control_media("play_media", input)
    end,
    resume_playlist = function(self)
        imvu.debug("Entering autoplay:resume_playlist")
        local entry = self.entries[self.current_index]
        self.next_after = self.current_time + self.resume_duration
        self.resume_after = nil
        self.is_active = true
        local input = { media_title = entry.media_title,
            media_url = entry.media_url,
            media_timestamp = self.resume_timestamp,
            label = self.target_furniture.label,
            target_name = self.target_name
        }
        imvu.control_media("play_media", input)
    end,
    interrupt = function(self, interruption)
        imvu.debug("Entering autoplay:interrupt")
        local entry = self.entries[self.current_index]
        self.resume_after = self.current_time + interruption.duration
        self.resume_timestamp = self.current_time - self.started_playing
        self.resume_duration = entry.duration - (self.resume_timestamp - entry.media_timestamp)
        self.next_after = nil
        self.is_active = true
        local input = {
            media_title = interruption.media_title,
            media_url = interruption.media_url,
            media_timestamp = interruption.media_timestamp,
            label = self.target_furniture.label,
            target_name = self.target_name
        }
        imvu.control_media("play_media", input)
    end,
    check_members = function(self)
        local members = imvu.get_audience_members()
        if #members == 0 then
            imvu.debug('Detected empty audience.')
            self.should_play_next = false
        elseif self.should_play_next == false then
            imvu.debug('Detected audience member!')
            self.should_play_next = true
        end
    end,
    event_state_changed = function(self, context, user, message)
        self:check_members()
    end,
    event_message_received = function(self, context, user, message)
        -- we have a special cheat code here, which allows us to interrupt the playlist with
        -- an arbitrary youtube video for an arbitrary duration.
        -- our access to the youtube api does not include finding metadata at this time, so
        -- we can't ask youtube how long the video is. we force our user to specify how many
        -- seconds the interruption should play before we resume the playlist.
        _, _, name, duration = string.find(message, "interrupt (%w+) (%d+)")
        if name ~= nil and duration ~= nil then
            local val = {
                media_title = 'Special Request',
                media_url = 'https://www.youtube.com/watch?v=' .. name,
                media_timestamp = 0,
                duration = duration
            }
            imvu.debug("Interrupting with " .. name .. " for " .. duration .. " seconds")
            self:interrupt(val)
        end
    end,
    event_start = function(self)
        imvu.place_furniture(self.target_furniture)
        self:check_members()
    end,
    event_begin_iteration = function(self, iteration, time)
        self.current_iteration = iteration
        self.current_time = time
    end,
    event_end_iteration = function(self)
        if self.should_play_next then
            if self.resume_after ~= nil and self.resume_after <= self.current_time then
                self:resume_playlist()
            elseif self.next_after ~= nil and self.next_after <= self.current_time then
                self:next_song()
            end
        elseif self.is_active then
            self:stop_playing()
        end
    end,
}

local final = {
    event_state_changed = function(context, user, message)
        autoplay:event_state_changed(context, user, message)
    end,
    event_message_received = function(context, user, message)
        autoplay:event_message_received(context, user, message)
    end,
    event_start = function()
        autoplay:event_start()
    end,
    event_begin_iteration = function(iteration, time)
        autoplay:event_begin_iteration(iteration, time)
    end,
    event_end_iteration = function()
        autoplay:event_end_iteration()
    end
}

imvu.debug("Loaded script!")

return final