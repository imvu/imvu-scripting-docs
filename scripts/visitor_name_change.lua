-- this example makes use of the visitor data store to remember a room
-- visitor's name and comment when it changes between visits. It is incapable
-- of noticing right away, the moment the display name changes, because we do
-- not have an event for that. Instead, it checks whenever someone joins the
-- audience or the scene.

-- it uses the account scope, so you can share data across all your scripts.

local DATA_LABEL = 'visitor_name_change'    -- change this to relabel the data
local DATA_SCOPE = 'account'                -- change this to isolate the data

local script = {}

local function check_for_changes(user)
    local cid = user.cid
    local name = user.name
    data.load({ visitor = cid, scope = DATA_SCOPE, label = DATA_LABEL }, function(loaded_record)
        if loaded_record then
            if loaded_record == name then
                -- if the name matches our record, we do nothing
                return
            else
                -- if it's changed, send a comment!
                imvu.debug("Found a change for " .. cid .. " from \"" .. loaded_record .. "\" to \"" .. name .. "\"")
                imvu.message_audience("Hello, " .. name .. "! Last time you visited, you were known as " .. loaded_record)
            end
        end
        -- if the record is missing or out of date, update it
        data.save({ visitor = cid, scope = DATA_SCOPE, label = DATA_LABEL }, name, function()
            imvu.debug("Remebering " .. tostring(cid) .. " as " .. name)
        end, imvu_debug)
    end, imvu.debug)
end

function script.event_state_changed(context, user)
    if context == 'audience_join' or context == 'scene_join' then
        check_for_changes(user)
    end
end

return script