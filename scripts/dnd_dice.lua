--[[

This script implements a simple "roll" function like D&D dice.
The user types "roll:" followed by the rolling format 2d20+4 (this means roll 2 twenty sided dice and add 4 to the result)
The script will pass the results into the chat window, listing the results of each roll followed by the final sum
Note: you can roll "dice" that are not real, such as a 17 sided die or a 212 sided die

]]--


script = {}

local function starts_with(str, start)
    return str:sub(1, #start) == start
end

local dnd_dice = {
    version = "0.1.0.0",

    event_message_received = function(self, context, sender, message)
        if starts_with(message, "roll:") then
            local input = message:sub(6)
            local result = self:roll(input)
            local output = sender.name .. " (" .. input .. "): " .. result
            imvu.message_audience(output)
        elseif starts_with(message, "help") then
            imvu.message_audience("Get the results of a dice roll by typing the standard dice rolling format, like 'roll: 2d20+2")
        end
    end,
    
    roll = function(self, die)
        local rolls
        local sides
        local operation = '+'
        local modifier = 0
        i, j = string.find(die, "d")
        if i == 1 then
            rolls = 1
        else
            rolls = tonumber(string.sub(die, 0, (j-1)))
        end
        afterD = string.sub(die, (j+1), string.len(die))
        i, j = string.find(afterD, "%d+")
        sides = tonumber(string.sub(afterD, i, j))
        afterSides = string.sub(afterD, (j+1), string.len(afterD))
        if string.len(afterSides) == 0 then
            operation = '+'
            modifier = 0
        else
            operation = string.sub(afterSides, 1, 1)
            modifier = tonumber(string.sub(afterSides, 2, string.len(afterSides)))
        end
        math.randomseed(os.time())
        local roll = 0
        local total = 0
        local output = ""
        while roll < rolls do
            onedie = math.random(1, sides)
            output = output .. onedie .. "    "
            total = total + onedie
            roll = roll + 1
            if roll < rolls then
                output = output .. " + "
            else 
                if modifier > 0 then
                    output = output .. " (" .. operation .. modifier .. ")"
                end
            end
        end
        -- Now add or subtract the modifier
        if operation == "+" then
            total = total + modifier
        elseif operation == "-" then
            total = total - modifier
        end
        output = output .. "    Total: " .. total
        return output
    end
}

function script.event_message_received(context, sender, message)
    dnd_dice:event_message_received(context, sender, message)
end

function script.event_start()
    imvu.debug("Script started")
end

function script.event_begin_iteration() 
end

imvu.debug("Script loaded")

return script