--[[
Dice Roller is a room script that is intended to be used with a collection of furniture PIDs that are a set of typical D&D dice.
The collection of furniture PIDs will include up to maximum number of dice that can be rolled.
User sees one of each dice when they first enter the room and will be in an "idle" state before the begin to interact with them.
They might type "help" or "roll" and they will get a message which will instruct them on how to use the commands.
There will be an in scene "help" arrow pointing at the dice that says 'Roll Me! Type "roll" in chat'.
Once they roll the dice, the in scene help will go away.
The dice will "reset" after a period of time.
Each roll will spawn the appropriate number of individual dice PIDs (D4, D6, D8, D10, D12, and D20). More info: https://www.dieharddice.com/pages/dnd-dice-explained
Each roll will also trigger an action unique to all dice PIDs.
The roll action will play a random unique animation from a set of ensembles for the number rolled to add variety.
The PIDs used by this script are: 67298051,67320927,67680993,67681003,67681011,67681047,67681055,67321455,67321595,67321932,67322002,67322102,67462863
--]]

imvu.debug("Dice Roller Example")

-- BEGIN - UTILITY FUNCTIONS - Functions to do some common things --------------------------------------------------------------------

-- Parses the incoming string by word and performs a match on the first word
-- Parameters:
--  str <string> String to parse
--  start <string> String of starting word to match
-- Returns: <boolean> Returns true if match found false if not
local function starts_with(str, start)
    return str:sub(1, #start) == start
end


local function copy(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return obj end
    local s = seen or {}
    local res = {}
    s[obj] = true
    for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
    return res
end


local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end


-- Same as maxscript 'filterString'
local function split(str, pat)
    local t = {}  -- NOTE: use {n = 0} in Lua-5.0
    local fpat = "(.-)" .. pat
    local last_end = 1
    local s, e, cap = str:find(fpat, 1)
    while s do
        if s ~= 1 or cap ~= "" then
            table.insert(t, cap)
        end
        last_end = e+1
        s, e, cap = str:find(fpat, last_end)
    end
    if last_end <= #str then
        cap = str:sub(last_end)
        table.insert(t, cap)
    end
    return t
end


local function list_contains(list, x)
    for _, v in pairs(list) do
        if v == x then return true end
    end
    return false
end


local function table_keys(tbl)
    local ret = {}
    for i, _ in pairs(tbl) do
        table.insert(ret, i)
    end
    return ret
end


function table_size(tbl)
    local count = 0
    for _, __ in pairs(tbl) do
        count = count + 1
    end
    return count
end

local sqrt = math.sqrt

local getDistance = function(a, b)
    if a.x == nil or a.y == nil or a.z == nil or b.x == nil or b.y == nil or b.z == nil then
        imvu.debug('ERROR: getDistance was supplied nil values!')
        return nil
    else
        local x, y, z = a.x-b.x, a.y-b.y, a.z-b.z
        return sqrt(x*x+y*y+z*z)
    end
end

local randomFloat = function(a, b)
    return math.random() + math.random(a, (b-1))
end

-- BEGIN - SCRIPT DEFINITIONS - All scripts to be run --------------------------------------------------------------------
local dice_help = {
    basic_message = 'Try "roll" to find out how to roll the dice you want',
    topics = { ["roll"] = 'Anyone can roll dice with the command "roll: ", specifying the dice in standard "2d6" format. For example: "roll:1d20,4d6" will roll 1 D20 an 4 D6 dice. Valid dice are "d4", "d6", "d8", "d10-0", "d10-00", "d12", and "d20".' },
    valid_topics = {"roll", "dice", "bones"},
    event_message_received = function(self, context, sender, message)
        local msg = trim(message):lower()
        if msg == "help" then
            imvu.message_audience(self.basic_message)
        elseif starts_with(msg, "help") then
            local topic = msg:sub(6)
            if list_contains(self.valid_topics, topic) then
                imvu.message_audience(self.topics["roll"])
            end
        else
            if list_contains(self.valid_topics, msg) then
                imvu.message_audience(self.topics["roll"])
            end
        end
    end
}


local dice_roll = {
    VERSION = "0.1.0.0",
    IMVU_TRIGGER = '*imvu:trigger ',
    LOCATION_NODE = "furniture.Floor.778",
    DICE_PIDS = {
        ["d4.1"] = {pid = 67298051, label = "D4_1"},
        ["d6.1"] = {pid = 67320927, label = "D6_1"},
        ["d6.2"] = {pid = 67680993, label = "D6_2"},
        ["d6.3"] = {pid = 67681003, label = "D6_3"},
        ["d6.4"] = {pid = 67681011, label = "D6_4"},
        ["d6.5"] = {pid = 67681047, label = "D6_5"},
        ["d6.6"] = {pid = 67681055, label = "D6_6"},
        ["d8.1"] = {pid = 67321455, label = "D8_1"},
        ["d10-00.1"] = {pid = 67321595, label = "D10_00_1"},
        ["d10-0.1"] = {pid = 67321932, label = "D10_0_1"},
        ["d12.1"] = {pid = 67322002, label = "D12_1"},
        ["d20.1"] = {pid = 67322102, label = "D20_1"}
    },
    VALID_DICE = {
        ["d4"] = {max_rolls = 1},
        ["d6"] = {max_rolls = 6},
        ["d8"] = {max_rolls = 1},
        ["d10-0"] = {max_rolls = 1},
        ["d10-00"] = {max_rolls = 1},
        ["d12"] = {max_rolls = 1},
        ["d20"] = {max_rolls = 1}
    },
    DICE_TO_DISPLAY_ON_RESET = {"d4.1", "d6.1", "d8.1", "d10-0.1", "d10-00.1", "d12.1", "d20.1"},
    SIGN_PID = {pid = 67462863, label = "DiceRollerSign", y = 3},
    RESET_IN_SECONDS = 30,
    DICE_OFFSET_MINMAX = {MIN = -3.0, MAX = 3.0},
    DICE_MIN_DIST = 1.0, -- Check for dice idle positions such that they don't intersect and look dumb.
    ROLLSTATE = {START = 0, INIT = 1, IDLE = 2, ACTIVE = 3},
    SCALE_HIDE = 0.01,
    SCALE_SHOW = 1.0,
    iterCounter = 0,
    curRollState,
    event_start = function(self)
        imvu.debug('Script started!')
        self.curRollState = self.ROLLSTATE.START
        math.randomseed(os.time())
        local dice_keys = table_keys(self.DICE_PIDS)
        -- Set the FAN that the sign and dice will be palced on
        self.SIGN_PID.node = self.LOCATION_NODE
        for i = 1, #dice_keys, 1 do
            self.DICE_PIDS[dice_keys[i]].node = self.LOCATION_NODE
        end
    end,
    event_begin_iteration = function(self, iteration, time)
        local INTERVAL = 20 -- This function is called approximately 20 times a second by the scripting engine once the script has been started.
        local INIT_ITER = 20 -- How long to hold in the init state. We need to wait until all of the furniture have loaded, before we call the 'idle' triggers.
                                -- This is not ideal. A callback for furniture loaded would be good in this use case.
        --imvu.debug(tostring(iteration)) -- DEBUGGING
        if self.curRollState == self.ROLLSTATE.START then
            -- This is the first call to place funiture and will add the dice furniture to the scene.
            -- show_dice uses place_furniture to set the scale
            self:show_dice(false)
            self.curRollState = self.ROLLSTATE.INIT
        elseif self.curRollState == self.ROLLSTATE.INIT then
            -- This is the second call to reset() which will call all of the 'idle' triggers on the dice since
            --  triggers cannot be called on furniture in the same frame that they are instantiated.
            if iteration > INIT_ITER then
                self:reset()
                self.curRollState = self.ROLLSTATE.IDLE
            end
        end
        if math.fmod (iteration, INTERVAL) == 0 then
            --imvu.debug("iteration = " .. tostring(iteration) .. " iterCounter = " .. tostring(self.iterCounter))
            self.iterCounter += 1
            if self.iterCounter > self.RESET_IN_SECONDS and self.curRollState == self.ROLLSTATE.ACTIVE then
                self:reset()
                self.curRollState = self.ROLLSTATE.IDLE
            end
        end
    end,
    event_message_received = function(self, context, sender, message)
         if starts_with(message, "roll:") then
            local input = message:sub(6)
            if input == "clear" then
                self:reset(true)
            elseif input == "reset" then
                self:reset()
            else
                self:roll(input)
            end
        end
    end,
    -- Resets the state of the "game" at startup  and after a "timeout" of there being no input from the player after a roll.
    reset = function(self, force_reset)
        imvu.debug("RESET!")
        force_reset = force_reset or false
        local dice
        local trigger_idle
        local dice_locations = {}
        local cur_dist
        local check_dist = true
        -- show and reset the placement of the sign
        self.SIGN_PID.scale = self.SCALE_SHOW
        imvu.place_furniture(self.SIGN_PID)
        -- reset the placement of the idle dice by first hiding them all
        self:show_dice(false)
        for i = 1, #self.DICE_TO_DISPLAY_ON_RESET, 1 do
            dice = self.DICE_PIDS[self.DICE_TO_DISPLAY_ON_RESET[i]]
            if force_reset then
                imvu.remove_furniture(dice.label)
            else
                -- BEGIN - Check for dice being placed too near each other
                check_dist = true
                dice.x = randomFloat(self.DICE_OFFSET_MINMAX.MIN, self.DICE_OFFSET_MINMAX.MAX)
                dice.z = randomFloat(self.DICE_OFFSET_MINMAX.MIN, self.DICE_OFFSET_MINMAX.MAX)
                while check_dist and i > 1 do
                    check_dist = false
                    for j = 1, table_size(dice_locations), 1 do
                        cur_dist = getDistance({x = dice.x, y = 0.0, z = dice.z}, dice_locations[j])
                        --imvu.debug("getDistance() cur_dist:" .. tostring(cur_dist))
                        if cur_dist <= self.DICE_MIN_DIST then
                            dice.x = randomFloat(self.DICE_OFFSET_MINMAX.MIN, self.DICE_OFFSET_MINMAX.MAX)
                            dice.z = randomFloat(self.DICE_OFFSET_MINMAX.MIN, self.DICE_OFFSET_MINMAX.MAX)
                            check_dist = true
                            break
                        end
                    end
                end
                table.insert(dice_locations, {x = dice.x, y = 0.0, z = dice.z})
                -- END - Check for dice being placed too near each other
                -- show and place the dice
                dice.scale = self.SCALE_SHOW
                imvu.place_furniture(dice)
                -- Calling a trigger on a furniture that has just been instantiated cannot happen on the same frame.
                if self.curRollState ~= nil and self.curRollState ~= self.ROLLSTATE.START and self.curRollState ~= self.ROLLSTATE.IDLE then
                    trigger_idle = (self.IMVU_TRIGGER .. self.DICE_TO_DISPLAY_ON_RESET[i] .. '_idle')
                    --imvu.debug(trigger_idle)
                    imvu.message_scene(trigger_idle) -- Call the action trigger
                end
            end
        end
        -- reset the timeout counter
        self.iterCounter = 0
    end,
    -- Hides and shows dice by setting the scale of the supplied dice in 'dice_table'
    show_dice = function(self, vis, dice_table)
        if vis == nil then vis = true end
        dice_table = dice_table or self.DICE_PIDS
        local dice_keys = table_keys(dice_table)
        local dice
        for i = 1, #dice_keys, 1 do
            dice = dice_table[dice_keys[i]]
            if vis then dice.scale = self.SCALE_SHOW
            else dice.scale = self.SCALE_HIDE
            end
            imvu.place_furniture(dice)
        end
    end,
    -- The function that is call after player input to "roll:"
    roll = function(self, input)
        imvu.debug("Roll!")
        if self.curRollState == self.ROLLSTATE.IDLE or self.curRollState == self.ROLLSTATE.ACTIVE then
            local input_strings = {}
            local num_rolls
            local dice_roll
            local dice_rolled = {}
            local dice
            local str_after_dice
            local sides = 1
            local skip = false
            local trigger
            local total = 0
            self.curRollState = self.ROLLSTATE.ACTIVE
            -- reset the timeout counter
            self.iterCounter = 0
            -- hide the sign and all of the dice
            self.SIGN_PID.scale = self.SCALE_HIDE
            imvu.place_furniture(self.SIGN_PID)
            self:show_dice(false)
            -- Parse the player's inout, build the roll triggers, and provide the player some feedback on bad input.
            input_strings = split(string.lower(input), ',')
            for idx = 1, table_size(input_strings), 1 do
                num_rolls = 1
                -- Parse the input string. Expected format is <num_rolls>d<dice>
                i, j = string.find(input_strings[idx], "d")
                -- If the <num_rolls> is omitted then it defaults to 1
                if i > 1 then
                    num_rolls = tonumber(string.sub(input_strings[idx], 0, (j-1)))
                end
                --imvu.debug("roll() idx: " .. tostring(idx) .. " num_rolls:" .. tostring(num_rolls))
                if num_rolls == nil then
                    imvu.message_audience('Invalid number of rolls! "roll:" command must begin with a number. Example: "roll:1d4"')
                    skip = true
                end
                if skip ~= true then
                    dice = string.sub(input_strings[idx], j, string.len(input_strings[idx]))
                    if list_contains(table_keys(self.VALID_DICE), dice) == false then
                        imvu.message_audience('Invalid dice name: ' .. dice .. '! Valid dice are "d4", "d6", "d8", "d10-0", "d10-00", "d12", and "d20".')
                        skip = true
                    elseif num_rolls > self.VALID_DICE[dice].max_rolls then
                        imvu.message_audience('Too many rolls for this dice! You can only roll a maximum of ' ..  tostring(self.VALID_DICE[dice].max_rolls) .. ' ' .. dice .. ' dice.')
                        skip = true
                    end
                end
                if skip ~= true then
                    str_after_dice = string.sub(input_strings[idx], (j+1), string.len(input_strings[idx]))
                    i, j = string.find(str_after_dice, "%d+")
                    if i == nil then
                        imvu.message_audience('Invalid dice number! Valid dice are "d4", "d6", "d8", "d10-0", "d10-00", "d12", and "d20".')
                        skip = true
                    else
                        sides = tonumber(string.sub(str_after_dice, i, j))
                        --imvu.debug("idx:" .. idx .. " sides:" .. tostring(sides))
                    end
                end
                if skip ~= true then
                    table.insert(dice_rolled, dice)
                    for i = 1, num_rolls, 1 do
                        dice_roll = math.random(1, sides)
                        -- special case math for d10-0 and d10-00 (percent roll)
                        if dice == "d10-0" or dice == "d10-00" then
                            dice_roll = dice_roll - 1
                            if dice == "d10-00" then
                                if dice_roll == 0 then dice_roll = 100
                                else dice_roll = dice_roll * 10 end
                            end
                        end
                        self:show_dice(true, {self.DICE_PIDS[(dice .. "." .. tostring(i))]})
                        trigger = (dice .. "." .. tostring(i) .. "_" .. tostring(dice_roll))
                        --imvu.debug("roll() trigger " .. trigger)
                        imvu.message_scene("*imvu:trigger " .. trigger) -- Call the action trigger
                        total = total + dice_roll
                    end
                end
            end
            -- We assume that if the roll includes both the d10-0 and d10-00 that it was intended to be a percentage roll and clamp the total to 100
            if list_contains(dice_rolled, "d10-0") and list_contains(dice_rolled, "d10-00") then total = math.min(total, 100) end
            imvu.message_audience('You rolled a total of ' .. tostring(total))
        end
    end
}


-- BEGIN - FINAL - Declare all event handling --------------------------------------------------------------------

local final = {}

function final.event_message_received(context, user, message)
    if starts_with(message, "[Script]") then
        return
    end

    dice_help:event_message_received(context, user, message)
    dice_roll:event_message_received(context, user, message)
end

function final.event_begin_iteration(iteration, steady_clock)
    dice_roll:event_begin_iteration(iteration, steady_clock)
end

function final.event_start()
    dice_roll:event_start()
end

imvu.debug("Loaded script!")

-- Execute this script
return final