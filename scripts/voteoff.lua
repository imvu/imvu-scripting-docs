--[[

This script implements a framework for making games based on repeatedly "voting off" 
players / people until only one remains.

Currently, the game has the following commands:

- start: this will restart the game, and adds three default names (Alice, Bob, and Carol)
- add [name]: this will add [name] to the list of options, but only works if voting has not yet begun
- vote: this will present a maximum of [self.max_options] options for players to vote off. This will
also lock the game to prevent new players from being added. 
- list: this is a debug function to list the current options

Once there is only a single option remaining, a message is pasted into chat with the results.

]]--


script = {}

local function starts_with(str, start)
    return str:sub(1, #start) == start
end

local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

delay_callbacks = {}
local function add_delay_callback(seconds, callback)
    table.insert(delay_callbacks, {time=seconds + os.time(), callback=callback})
end
  
local function run_delay_callbacks()
    local time = os.time()
    for key, value in pairs(delay_callbacks) do
        if value.time <= time then
            value.callback()
            table.remove(delay_callbacks, key)
        end
    end
end

local voteoff_game = {
    state = {
        start_every = 3,
        poll_duration = 10,
        poll_counter = 0,
        poll_item_counter = 0,
        max_options = 10,
        game_open = false,
        is_voting = false,
        names = {}
    },

    init = function(self)
        self.state.names = {}
        self.state.names['Alice'] = 1
        self.state.names['Bob'] = 1
        self.state.names['Carol'] = 1
        self.state.game_open = true
    end,

    event_begin_iteration = function(self)
        local now = os.time()
        if self.state_next_poll and self.state.next_poll < now then
            self:ask_question()
        end
    end,

    add_player = function(self, name)
        if (tablelength(self.state.names) >= self.state.max_options) then
            imvu.message_audience('Limit of ' .. self.state.max_options .. ' reached. Cannot fit ' .. name)
        elseif (self.state.game_open) then 
            -- imvu.message_audience('adding player ' .. name)
            self.state.names[name] = 1
        else
            imvu.message_audience('game underway, no additions')
        end
    end,

    remove_player = function(self, name)
        self.state.names[name] = nil
    end,

    get_name_list = function(self)

        for i = #self.state.names, 2, -1 do
            local j = math.random(i)
            self.state.names[i], self.state.names[j] = self.state.names[j], self.state.names[i]
        end
        
        local output = {}
        local count = 0
        for k, _ in pairs(self.state.names) do
            if (count >= self.state.max_options) then
                break
            end
            table.insert(output, k)
            count = count + 1
        end
        return output
    end,

    process_votes = function(votes)
        local winner = nil
        local maxVote = 0
    
        for k, v in pairs(votes) do
            -- imvu.message_audience('process votes ' .. k .. ' ' .. v)
                
            if (type(v) == 'number' and v > maxVote) then
                -- imvu.message_audience('process votes ' .. k .. ' ' .. v)
                winner = k
                maxVote = v
            end
        end
    
        return winner
    end,

    check_for_winner = function(self)
        local count = 0
        local winner = nil
        for k, _ in pairs(self.state.names) do
            count = count + 1
            winner = k
        end
        if (count == 1) then
            imvu.message_audience('winner is ' .. winner)
        end
    end,

    conduct_vote = function(self)
        if (self.state.is_voting) then
            imvu.message_audience('voting underway... wait a sec')
            return 
        end

        self.state.is_voting = true
        local poll = { 
            type = 'custom',
            content = 'Vote off a player',
            duration = self.state.poll_duration,
            options = self:get_name_list()
        }
        imvu.create_poll(poll, function(results)
            self.state.is_voting = false
            local toRemove = nil
            local maxVote = 0
        
            local votes = {}
            for i, v in ipairs(results.tallies) do
                if (tonumber(v.tally) > maxVote) then
                    maxVote = tonumber(v.tally)
                    toRemove = v.content
                end
            end

            -- local toRemove = self:process_votes(votes)
            if toRemove then
                imvu.message_audience(toRemove .. ' was voted off!!!')
                remove_player(self, toRemove)
            end

            self:check_for_winner()

        end, imvu.debug)
    
    end,

    debug_names = function(self)
        output = ''
        for k, v in pairs(self.state.names) do
            output = output .. k .. ' '
        end
        imvu.message_audience(output)
    end,

    event_state_changed = function(self, context, actor, label)
        if context == "scene_join" then
            add_delay_callback(3, function()
                imvu.whisper_audience_member(actor.cid, "Welcome to this IMVU Labs room, " .. actor.name .. "! Whisper 'help' to me for more info about the room.")
            end)
        elseif (actor.seat_furni_pid == 58867085) then
            self:add_player(actor.name)
        else -- if they are not on the stage then make sure they are removed (in case they just left the stage)
            self:remove_player(actor.name)
        end
    end,

    event_message_received = function(self, context, sender, message) 
        if starts_with(message, 'start') then
            self:init()
        elseif (starts_with(message, 'add')) then
            local name = trim(message:sub(4))
            self:add_player(name)
        elseif (starts_with(message, 'list')) then
            self:debug_names()
        elseif (starts_with(message, 'vote')) then
            self.state.game_open = false
            self:conduct_vote()
        elseif (starts_with(message, 'remove')) then
            local name = trim(message:sub(7))
            remove_player(self, name)
        elseif (starts_with(message, 'help')) then
            imvu.message_audience("Welcome to IMVU Survivor. 'start' to begin the game. 'add user' adds a contestant. 'list' gives a list of contestants. 'vote' lets you choose who will be voted out. The last contestant left is the winner.")
        end          
    end
}

function script.event_message_received(context, sender, message)
    voteoff_game:event_message_received(context, sender, message)
end

function script.event_state_changed(context, actor)
    voteoff_game:event_state_changed(context, actor)
end

function script.event_start()
    imvu.debug("Script started")
    voteoff_game:init()
end

function script.event_begin_iteration() 
    voteoff_game:event_begin_iteration()
    run_delay_callbacks()
end

imvu.debug("Script loaded")

return script