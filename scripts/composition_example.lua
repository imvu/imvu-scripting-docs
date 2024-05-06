-- This example script combines several smaller toys into a single room script.
-- It is the pattern we're going to use for the first version of the scripting
-- system, which only allows a single file to run against a room.

-- When we launch furniture scripting, we will port some of these examples to
-- their products, to demonstrate the distinction between scripting a room and
-- scripting a product.

-- The selection of the included pids does not constitute an endorsement of the
-- products or the creators, as they were arbitrarily chosen from the product
-- catalog for demonstration purposes only.

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

local function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end  
    return tbl
end

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

-- The zoltar machine was the first script requested by management, and is
-- included as an example of suspended output. It prints to the audience chat,
-- but not all at once.
local zoltar = {
    total_iterations = 0,
    customers = {},

    -- Output is divided into stages. We print a greeting, wait a few frames,
    -- then print a middle, wait a few frames, then print a final.
    -- The interruptions are printed if the user moves away from the zoltar
    -- machine in the middle of their fortune. Rude!
    greetings = {
        "Who dares approach Zoltar..? Why, !NAME!, I didn't know you were so courageous!", 
        "Tread carefully, !NAME!, for you encroach upon the threads of destiny!", 
        "!NAME!: the time to unveil your fortune is now at hand."
        },
    interruptions =
        { "Wha--wait, !NAME!, where do you think you're going?! Very well then, begone with you!"
        , "Perhaps it is wise to run, !NAME!; not everyone can stand the dread wisdom of my future sight."
        , "Wander off if you like, !NAME!. I have a strict no-refunds policy."
        },
    middles = 
        {"... the deck of destiny shuffles, !NAME!, and your card rises to the surface..."
        , "... focus upon my incantation, !NAME!... azamar sinthia zoltros... Azamar! Sinthia! Zoltros!"
        , "... yes, I can see the mists of the future parting before me, !NAME!!" },
    finals = 
        {"Your card, !NAME!, is the Fool. Though you may find yourself out of your depths, it is only because you are on the first step to a grand adventure!"
        ,"!NAME!, your card is the Magician. Perhaps you feel frustrated? If so, it is only because you are brimming with untapped potential that begs to be given a worthy cause! Seek the magnificent and the divine!"
        ,"Ah, how exciting for you, !NAME!. You have drawn the High Priestess, a sure sign that you will engage in the pursuit of timeless mystery."
        ,"The Empress! Begging your pardon, !NAME!, but it surprises me to discover that you are indwelt with potential for vast creation. The seed of something great nears surfacing!"
        ,"Ah, !NAME!, you have drawn the Emperor. It is clear that you maintain authority over something worthy of protection and just stewardship--but take care! If your will or wisdom falters, many will suffer for it."
        ,"!NAME!, pay heed to your card, the Hierophant. It calls upon you to seek out worthy alliances and to exercise mercy. Bless others with your presence, and you will be blessed in turn!"
        ,"Do not get too excited about your card, !NAME!, for the Lovers is a call to sacrifice. You must give up something to gain something in return, as one gives up the life of the bachelor to enjoy the love of his partner."
        ,"Such ferocity! Why, the Chariot nearly leaped out of the deck towards you, !NAME!! Conflict may be inevitable, but triumph will be yours so long as you keep moving forward. Do not cease!"
        ,"An auspicious draw, !NAME!. You have selected the Strength card, which guarantees victory in your near future. Choose your pursuits and your battles with care, for too many heroes have been undone by getting precisely what they fight for."
        ,"Interesting. !NAME! has drawn the card of the Hermit, a sign that they walk a shadowed path, whether they know it or not. Be prudent! Pay attention! Something or someone means you ill, and the path to glory may be a lonely one."
        ,"!NAME! has drawn the Wheel of Fortune, most often a sign of excellent luck but always a sign of dramatic change. Keep a loose chance and try to stay on your feet. If you can manage that, you'll come out ahead."
        ,"Alas, !NAME!, I do not envy you. To have drawn the Justice card is to be given a terrible burden. Yours will be the fate that renders judgment over what is right and what is wrong. Think carefully, and do not deceive yourself!"
        ,"Do not despair, !NAME!, for the Hanged Man cares naught whether you shed tears over the sacrifice to come. Something will be lost, but not all loss is in vain."
        ,"The most inevitable of the cards seeks you, !NAME!! To draw Death is to near the end of something dear to you. Let it go and seek renewal elsewhere, for to cling is to wither as surely as the vine upon a decaying branch."
        ,"Measure twice, cut once. The Temperance card calls !NAME! to be exacting in the distribution of their responsibilities and resources. Balance your needs and wants, or risk losing both!"
        ,"Unleash yourself, !NAME!. That is the call of the Devil card, which is everything violent and primal and unimpeded about your nature. Do not hold back!"
        ,"Woe! The Tower's ruin is upon you, !NAME!, and you must brace yourself for your ambitions to falter or fail entirely. Something terrible will go wrong, and the balance of your fate will rest upon how well you endure."
        ,"It is a time for retreat and separation, !NAME!. The Star card indicates that someone will abandon you, or you them. Take comfort, however dim this comfort may be, that this separation is for the best."
        ,"The night is dark and full of dangers, !NAME!. The Moon card beseeches you to stay on guard, to hold fast to your friends and allies, and to brave the way to morning."
        ,"Behold, the Sun! !NAME!, a most auspicious pull! You march into the midday, when things are at their brightest, when the time is ripe to grow and to flourish. Do not sit idle, do not waste this opportunity!"
        ,"Steel yourself, !NAME!, for the time of Judgment is at hand. Someone with authority will proclaim the worth of your deeds to the world. If you have done well, proclaim yourself proudly. If you have done wrong, prepare to make amends."
        ,"The World is yours, !NAME!! Whether good or ill, your latest adventure will soon come to an end, and you must prepare to bring it to a just and fruitful closing. Then, be on the lookout for new opportunities!"
        },

    -- By changing this pid, you can orient the script around a different product.
    is_zoltar = function(self, seat_furni_pid)
        return seat_furni_pid == 47298395
    end,
    random_message = function(self, possibilities, name)
        key = math.random(1, #possibilities)
        msg = possibilities[key]
        return (msg:gsub("!NAME!", name))
    end,
    event_state_change_received = function(self, context, actor_cid, actor_name, seat_number, seat_furni_id, seat_furni_pid)
        if context == "scene_move" then
            if seat_number == 1 and self:is_zoltar(seat_furni_pid) then
                if self.customers[actor_cid] == nil then
                    -- when we have a customer on the zoltar seat, create an entry for them.
                    -- we care about their name, and when we should play the subsequent stages.
                    self.customers[actor_cid] = { 
                        name = actor_name, 
                        middle_iteration = self.total_iterations + 40, 
                        final_iteration = self.total_iterations + 80 
                    }
                    -- then, send the initial stage right away.
                    imvu.message_audience(self:random_message(self.greetings, actor_name))
                end
                -- if they move to zoltar but are already a customer, they either repeated the packet or moved to a different zoltar.
            elseif self.customers[actor_cid] ~= nil then
                -- in this case, they moved from a zoltar seat to a non-zoltar seat while their fortune was playing
                -- complain about their rudeness!
                self.customers[actor_cid] = nil
                imvu.message_audience(self:random_message(self.interruptions, actor_name))
            end
        end
    end,
    event_end_iteration = function(self)
        self.total_iterations = self.total_iterations + 1
        for key, value in pairs(self.customers) do
            if value.middle_iteration == self.total_iterations then
                imvu.message_audience(self:random_message(self.middles, value.name))
            end
            if value.final_iteration == self.total_iterations then
                imvu.message_audience(self:random_message(self.finals, value.name))
                self.customers[key] = nil
            end
        end
    end,
    event_begin_execution = function(self)
        -- when the script first starts, make sure we place the zoltar machine where we think it should go.
        imvu.place_furniture({label="zoltar_one", pid=47298395, node='furniture.Floor.137', x=0, y=0, z=0, yaw=0, pitch=0, roll=0, scale=1})
    end
}

-- This one should hopefully be self-explanatory. It simply sends messages or whispers when someone tips in the room.
local tip_thanker = {
    event_tip_received = function(self, sender_cid, sender_name, recipient_cid, recipient_name, credits_received, is_private)
        if recipient_cid == imvu.get_owner_cid() then
            if is_private then
                imvu.whisper_audience_member(sender_cid, "Pssst, " .. sender_name .. ", thanks for the " .. credits_received .. " credits!")
            else
                imvu.message_audience("HEY EVERYONE! " .. sender_name .. " is my new best friend after tipping me " .. credits_received .. " credits!")
            end
        else
            imvu.message_audience("It looks like " .. sender_name .. " sent credits to " .. recipient_name .. ". I didn't realize we launched tipping to non-room-owners?!")
        end
    end
}

-- This was the first test of the scripting prototype.
local trivial_echo = {
    event_message_received = function(self, context, message, sender_cid, sender_name)
        if starts_with(message, "echo:") then
            if context == "audience" then
                imvu.message_audience(sender_name .. ": " .. message:sub(6))
            elseif context == "audience_whisper" then
                imvu.whisper_audience_member(sender_cid, "whisper: " .. message:sub(6))
            else
                imvu.debug("Received a message on the unknown context " .. context)
            end
        end
    end
}

-- This was the second test of the scripting prototype. When you call into it, it prints
-- messages directly into the scene using letter furniture products.
local scene_print = {
    -- the location where we print
    -- for this demonstration, it's a static value, based on the room I use for testing.
    -- feel free to parameterize this!
    location_node = "furniture.Floor.178",

    -- the letter lookup
    -- one of the things I'd like to improve going forward is product dependency injection
    -- for now, we simply pass pids into imvu callouts. these pids are manually curated
    -- You may have to change these pids to products you own, if you want to try it.
    letters = { ["0"] = {pid=59572780, width=2.0},
                ["1"] = {pid=59572789, width=2.0},
                ["2"] = {pid=59572795, width=2.0},
                ["3"] = {pid=59572799, width=2.0},
                ["4"] = {pid=59572811, width=2.0},
                ["5"] = {pid=59572816, width=2.0},
                ["6"] = {pid=59572822, width=2.0},
                ["7"] = {pid=59572839, width=2.0},
                ["8"] = {pid=59572847, width=2.0},
                ["9"] = {pid=59572856, width=2.0},
                ["a"] = {pid=59572383, width=2.2},
                ["b"] = {pid=59572344, width=1.7},
                ["c"] = {pid=59572496, width=2.1},
                ["d"] = {pid=59572501, width=2.1},
                ["e"] = {pid=59572512, width=1.8},
                ["f"] = {pid=59572519, width=1.7},
                ["g"] = {pid=59572522, width=2.1},
                ["h"] = {pid=59572540, width=2.0},
                ["i"] = {pid=59572544, width=1.0},
                ["j"] = {pid=59572551, width=1.2},
                ["k"] = {pid=59572563, width=2.0},
                ["l"] = {pid=59572569, width=2.0},
                ["m"] = {pid=59572582, width=2.3},
                ["n"] = {pid=59572585, width=2.1},
                ["o"] = {pid=59572589, width=2.2},
                ["p"] = {pid=59572600, width=1.7},
                ["q"] = {pid=59572605, width=2.3},
                ["r"] = {pid=59572609, width=2.0},
                ["s"] = {pid=59572616, width=1.7},
                ["t"] = {pid=59572627, width=2.1},
                ["u"] = {pid=59572634, width=2.0},
                ["v"] = {pid=59572651, width=2.1},
                ["w"] = {pid=59572663, width=2.6},
                ["x"] = {pid=59572698, width=2.0},
                ["y"] = {pid=59572725, width=2.0},
                ["z"] = {pid=59572734, width=2.0},
                [" "] = {pid=nil, width=1.0}
    },

    -- we store the owner cid so we can limit access to the print: function to the owner
    -- you can also add individual cids you want to have permission
    valid_cids = { [imvu.get_owner_cid()] = true, [159820459] = true},

    -- this version of print can only print a single string to the room
    -- with further parameterization, you can maintain multiple strings simultaneously
    furni_print = function(self, label, message, y_offset, location_node)
        local my_node = location_node or self.location_node
        self:furni_clear(label)
        self.print_counter = (self.print_counter or 0) + 1
        local total_width = 0
        for i=1,#message do 
            local letter = self.letters[message:sub(i,i)]
            if letter ~= nil then
                total_width = total_width + self.letters[message:sub(i, i)]["width"]
            end
        end
        if self.print_attempts[label] == nil then
            self.print_attempts[label] = {}
        end
        local x_offset = total_width / -2
        for i=1,#message do
            local letter = self.letters[message:sub(i, i)]
            if letter ~= nil then
                if letter["pid"] ~= nil then
                    local label_inner = label .. "letter_" .. self.print_counter .. "_" .. i
                    imvu.place_furniture({label=label_inner, pid=letter["pid"], node=my_node, x=x_offset + (letter["x"] or 0), y=y_offset + (letter["y"] or 0), z=letter["z"] or 0, yaw=letter["yaw"] or 0, pitch=letter["pitch"] or 0, roll=letter["roll"] or 0, scale=letter["scale"] or 1})
                    self.print_attempts[label][label_inner] = label_inner
                end
                x_offset = x_offset + letter["width"]
            end
        end
    end,

    furni_clear = function(self, label)
        if self.print_attempts == nil then 
            self.print_attempts = {}
            return
        end
        if self.print_attempts[label] ~= nil then
            for key, val in pairs(self.print_attempts[label]) do
                imvu.remove_furniture(key)
            end
        end
        self.print_attempts[label] = {}
    end,

    -- this is our primary input. it's pretty simple!
    event_message_received = function(self, context, message, sender_cid, sender_name)
        if self.valid_cids[sender_cid] then
            if starts_with(message, "print:") then
                imvu.debug("Entering print with: " .. message:sub(7):lower())
                self:furni_print("scene_print", message:sub(7):lower(), 3.0)
            elseif message == "clear" then
                self:furni_clear("scene_print")
            end
        end
    end,

    -- we'll add the save/load functions once we settle on the function signatures once and for all
    event_begin_execution = function(self)
        local loaded_data = nil

        if loaded_data ~= nil then
            self.print_attempts = loaded_data["print_attempts"] or {}
            self.print_counter = loaded_data["print_counter"] or 0
        else
            self.print_attempts = {}
            self.print_counter = 0
        end
    end,

    event_end_execution = function(self)
    end
}

-- This is an example of writing a script based on another script.
-- audience_vote uses scene_print to make a poll for the audience, printed directly into the 3D scene
-- once scene_print was working, it took me about 3 hours to write audience_vote, which was the proof
-- of concept that we needed to convince me that scripting was a worthwhile project.
local audience_vote = {
    -- contains the info we want to save between executions
    default_vote_state = { version= "0.1.0.1", last_print = {}, print_attempts = {}, print_counter = 0, names = {}, 
            vote = { ongoing = false, votes = {}, options = {}, changed_mind = {}, doubled_down = {}, discussed = {} }},
    vote_state = nil,
    -- contains ephemeral data. in a kinder world, this would be better organized.
    print_every = 50, -- print every second
    iteration_total = 0,
    iteration_cutoff = 0,
    save_every = 6000,
    save_cutoff = 6000,
    owner = imvu.get_owner_cid(),
    
    event_message_received = function(self, context, message, sender_cid, sender_name)
        -- hopefully, this never happens. as an early test of the scripting prototype, it used to happen intermittently
        if sender_cid == nil then
            imvu.debug('Oh no, nil sender_cid!!')
            return
        end
        -- we build a string key here, 'cid' .. sender_cid rather than using sender_cid directly.
        -- this is so lua never mistakenly attempts to store the names table as an array.
        -- integer indices are dangerous in that way.
        local sender_key = 'cid' .. sender_cid
        if self.vote_state == nil then
            imvu.debug('Oh no, nil vote_state')
            self.vote_state = copy(self.default_vote_state)
        end
        if self.vote_state.names == nil then
            imvu.debug('Oh no, nil names array')
            self.vote_state = copy(self.default_vote_state)
        end
        self.vote_state.names[sender_key] = sender_name
        if self.owner == sender_cid then
            if starts_with(message, "vote:") then
                local command = message:sub(7):lower()
                -- when the owner of the room sends "vote: stop"
                if self.vote_state.vote.ongoing and command == "stop" then
                    self:vote_stop()
                    return
                -- when the owner of the room sends "vote: clear"
                elseif command == "clear" then
                    self:vote_clear()
                    return
                else
                -- when the owner of the room sends "vote: anything else"
                -- the parser below, try_get_options, will split the anything else into options, eg:
                -- "vote: cats or dogs or sonic the hedgehog OCs" will start a vote between three options
                -- "cats", "dogs", and "sonic the hedgehog OCs"
                    local options = self:try_get_options(command)
                    if options ~= nil then
                        if self.vote_state.vote.ongoing then
                            imvu.message_audience("A vote is still ongoing! Enter \"vote: stop\" to finish that vote first!")
                        else
                            self:vote_start(options)
                            return
                        end
                    else
                        imvu.message_audience("Didn't recognize command " .. command .. ". Use \"vote: SOMETHING or OTHER\" to start a vote between something or other! Then, everyone can \"vote something\" or \"vote other\" to register their opinions!")
                    end
                end
            end
        end
        if self.vote_state.vote.ongoing then
            -- "vote cats" will vote for cats
            -- "vote sonic the hedgehog OCs" will vote for sonic the hedgehog OCs
            if starts_with(message, "vote") then
                local remainder = message:sub(5):lower()
                for key, val in pairs(self.vote_state.vote.options) do
                    if string.find(remainder, val.text, 1, true) then
                        self:vote_for(sender_key, key)
                        return
                    end
                end
            else
                -- "cats are better than dogs" will not vote, but we make note of it
                -- when people chatter about options without voting, we keep a record for banter upon vote end
                local lowered = message:lower()
                for key, val in pairs(self.vote_state.vote.options) do
                    if string.find(lowered, val.text, 1, true) then
                        self.vote_state.vote.discussed[sender_key] = (self.vote_state.vote.discussed[sender_key] or 0) + 1
                        return
                    end
                end
            end
        end
    end,
    -- we allow up to five and require at least two options, separated by " or "
    try_get_options = function(self, lowered_command)
        local options = {}
        local count = 0
        for key, val in pairs(split(lowered_command, " or ")) do
            count = count + 1
            options[count] = trim(val)
        end
        if count >= 2 and count <= 5 then
            return options
        else
            imvu.message_audience("Votes may only have between two and five options, but \"" .. lowered_command .. "\" contained " .. count)
        end
    end,
    -- We want the output to be something like: "Starting vote for cats or dogs or sonic the hedgehog OCs"
    vote_start = function(self, options)
        local output = "Starting vote f"
        local furni = ""
        -- this is cheesy, joining the inputs with "or ", and starting with "Starting vote f"
        for key, val in pairs(options) do
            output = output .. "or " .. val .. " "
            furni = furni .. " or " .. val
            self.vote_state.vote.options[key] = { text = val, count = 0 }
        end
        scene_print:furni_print("vote_header", "vote", 9)
        scene_print:furni_print("vote_options", furni:sub(5), 6.5)
        self.vote_state.vote.ongoing = true
        imvu.message_audience(output)
    end,
    vote_stop = function(self)
        local winner_count = 0
        local winner_qty = 0
        local total_qty = 0
        local winners = {}
        -- decide the winners!
        for key, val in pairs(self.vote_state.vote.options) do
            total_qty = total_qty + 1
            if val.count > winner_count then
                winner_count = val.count
                winner_qty = 1
                winners = {}
                winners[key] = val.text
            elseif val.count == winner_count then
                winners[key] = val.text
                winner_qty = winner_qty + 1
            end
        end
        if winner_count == 0 then
            imvu.message_audience("BOO! Nobody voted at all?! Everyone's a loser, I guess...")
            self:vote_reset()
            return
        elseif winner_qty == total_qty then
            msg = "It's a tie! "
            if winner_qty == 2 then
                msg = msg .. " Both options"
            else
                msg = msg .. " Every option"
            end
            scene_print:furni_print("vote_header", "winner", 9)
            scene_print:furni_print("vote_options", "everyone", 6.5)
            msg = msg .. " got " .. winner_count .. " votes! Incredible!"
            imvu.message_audience(msg)
        elseif winner_qty > 1 then
            winner_val = ""
            for key, val in pairs(winners) do
                winner_val = winner_val .. val .. " and "
            end
            winner_val = winner_val:sub(1, #winner_val - 5)
            scene_print:furni_print("vote_header", "winner", 9)
            scene_print:furni_print("vote_options", winner_val, 6.5)
            msg = "It's a tie! Our winners are " .. winner_val .. ". They received " .. winner_count .. " votes!"
            imvu.message_audience(msg)
        else
            winner_val = nil
            for key, val in pairs(winners) do
                winner_val = val
            end
            scene_print:furni_print("vote_header", "winner", 9)
            scene_print:furni_print("vote_options", winner_val, 6.5)
            msg = "Congratulations, " .. winner_val .. ", for winning with " .. winner_count .. " votes!"
            imvu.message_audience(msg)
        end
        self:awards()
        self:vote_print()
        self:vote_reset()
    end,
    -- just for fun, we track user activity in the chat during a poll
    -- when someone talks about the options a lot, they're the chattiest participant.
    -- when someone changes their vote a lot, they're the flightiest participant.
    -- when someone repeatedly tries to vote for the same option, they're the most forgetful participant.
    awards = function(self)
        local winner = self:award_winner(self.vote_state.vote.discussed)
        if winner ~= nil then
            imvu.message_audience("Award: Our chattiest participant is " .. self.vote_state.names[winner.cid] .. " who discussed the options without voting " .. winner.count .. " times!")
        end
        winner = self:award_winner(self.vote_state.vote.changed_mind)
        if winner ~= nil then
            imvu.message_audience("Award: Our flightiest participant is " .. self.vote_state.names[winner.cid] .. " who changed their vote " .. winner.count .. " times!")
        end
        winner = self:award_winner(self.vote_state.vote.doubled_down)
        if winner ~= nil then
            imvu.message_audience("Award: Our most forgetful participant is " .. self.vote_state.names[winner.cid] .. " who repeated their vote " .. winner.count .. " times!")
        end
    end,
    award_winner = function(self, records)
        local winner_count = 0
        local winner_qty = 0
        local winner = 0
        for key, val in pairs(records) do
            if val > winner_count then
                winner_count = val
                winner_qty = 1
                winner = key
            elseif val == winner_count then
                winner_qty = winner_qty + 1
            end
        end
        -- there can be only one!
        if winner_qty == 1 then
            return { cid = winner, count = winner_count }
        else
            return nil
        end
    end,
    -- track votes registered in chat. we track more than just who votes for what, for banter purposes.
    vote_for = function(self, cid, option)
        local existing_vote = self.vote_state.vote.votes[cid]
        if existing_vote ~= nil then 
            if existing_vote ~= option then
                self.vote_state.vote.changed_mind[cid] = (self.vote_state.vote.changed_mind[cid] or 0) + 1
                self.vote_state.vote.votes[cid] = option
                self.vote_state.vote.options[existing_vote].count = self.vote_state.vote.options[existing_vote].count - 1
                self.vote_state.vote.options[option].count = self.vote_state.vote.options[option].count + 1
            else
                self.vote_state.vote.doubled_down[cid] = (self.vote_state.vote.doubled_down[cid] or 0) + 1
            end
        else
            self.vote_state.vote.votes[cid] = option
            self.vote_state.vote.options[option].count = self.vote_state.vote.options[option].count + 1
        end
    end,
    
    event_begin_execution = function(self)
        self:load_vote_state()
    end,
    
    event_end_execution = function(self)
        self:save_vote_state()
    end,
    
    -- this script was written before we passed in the iteration and steady_clock
    -- the approach it takes is preserved for historical purposes
    -- what is noteworthy about it is that it persists through restarts
    -- if the script is updated repeatdly, but save_vote_state and load_vote_state work,
    -- this iteration counting will maintain itself no matter what else happens
    event_begin_iteration = function(self)
        self.iteration_total = self.iteration_total + 1 -- given a 52 digit mantissa in the double underlying iteration_total, this will have precision errors in > 1 million years
    end,
    
    event_end_iteration = function(self)
        if self.iteration_total >= self.save_cutoff then
            self.save_cutoff = self.save_cutoff + self.save_every
            self:save_vote_state()
        end 
        if self.vote_state and self.vote_state.vote and self.vote_state.vote.ongoing and self.iteration_total > self.iteration_cutoff then
            self:vote_print()
            self.iteration_cutoff = self.iteration_total + self.print_every
        end
    end,
    -- vote_print uses scene_print, making use of our prior module
    vote_print = function(self)
        local current_counts = ""
        for key, val in pairs(self.vote_state.vote.options) do
            current_counts = current_counts .. " to " .. val.count
        end  
        current_counts = current_counts:sub(5)
        if current_counts ~= self.vote_state.last_print then
            self.vote_state.last_print = current_counts
            scene_print:furni_print("vote_counts", current_counts, 4)
        end
    end,
    vote_clear = function(self)
        scene_print:furni_clear("vote_header")
        scene_print:furni_clear("vote_options")
        scene_print:furni_clear("vote_counts")
        self.vote_state.last_print = ""
    end,
    -- we will update save_state and load_state when we finalize the customer-facing pattern we want to use.
    save_vote_state = function(self)
        imvu.debug("saving vote state with version " .. ((self.vote_state or {}).version or "MISSING"))
    end,
    load_vote_state = function(self)
        local load = {} 
        if load.version == nil or load.version ~= self.default_vote_state.version then
            imvu.debug("Reset vote state with version " .. (load.version or "MISSING") .. " against expectation " .. (self.default_vote_state.version or "MISSING"))
            self.vote_state = copy(self.default_vote_state)
        else 
            imvu.debug("Loaded vote state with version " .. (self.vote_state.version or "MISSING") .. " against expectation " .. (self.default_vote_state.version or "MISSING"))
            self.vote_state = load
        end
    end,
    vote_reset = function(self)
        self.vote_state.names = {}
        self.vote_state.vote = { ongoing = false, votes = {}, options = {}, changed_mind = {}, doubled_down = {}, discussed = {} }
    end
}

-- podium print uses scene_print too, in a more straightforward way
-- when an avatar stands on the podium, they get the chance to write messages in the sky above it
-- this is an example of a script that would be better presented as a furniture script, once we have
-- furniture scripting user-facing. 
local podium_print = {
    -- feel free to change the furniture_pid and furniture_seat to what you have handy!
    furniture_pid = 14973461,
    furniture_seat = 1,
    placement_node = 'furniture.Floor.187',
    current_speaker = 0,
    commentary = '',
    number_of_lines = 3,
    max_line_length = 38,
    max_word_length = 20,
    event_begin_execution = function(self)
        imvu.place_furniture({label="podium_print", pid=self.furniture_pid, node=self.placement_node, x=0, y=0, z=0, yaw=0, pitch=0, roll=0, scale=1})
    end,
    event_state_change_received = function(self, context, actor_cid, actor_name, seat_number, seat_furni_id, seat_furni_pid, actor_outfit)
        if seat_furni_pid == self.furniture_pid and seat_number == self.furniture_seat then
            self.current_speaker = actor_cid
            self.commentary = ''
            imvu.message_audience("Everyone, please welcome our next speaker, " .. (actor_name or "MISSING_NAME") .. " to the Skyramble Podium")
        elseif actor_cid == self.current_speaker then
            if self.commentary:len() > 0 then
                imvu.message_audience(self.commentary)
            end
            self.current_speaker = 0
        end
    end,
    event_message_received = function(self, context, message, sender_cid, sender_name)
        if sender_cid == self.current_speaker then
            self:process_remarks(trim(message):lower(), sender_name)
        end
    end,
    process_remarks = function(self, message, sender_name)
        local words = split(message, ' ')
        local output_lines = {}
        local current_line = ''
        local line_number = self.number_of_lines
        local final_word = ''
        for key, word in pairs(words) do
            if word:len() > self.max_word_length then
                final_word = 'blah blah blah'
                self.commentary = 'Than you for your remarks, but... is ' .. word .. ' even a word, ' .. sender_name .. '?'
            else
                final_word = word
            end
            if final_word:len() > 0 then
                if current_line:len() + final_word:len() >= self.max_line_length then
                    output_lines['skyramble_' .. line_number] = current_line
                    line_number = line_number - 1
                    if line_number == 0 then
                        self.commentary = 'Thank you for your entirely too lengthy remarks, ' .. sender_name
                        current_line = ''
                        break
                    else
                        current_line = final_word
                    end
                else
                    current_line = current_line .. ' ' .. final_word
                end
            end
        end
        if current_line:len() > 0 then
            output_lines['skyramble_' .. line_number] = current_line
        end
        if self.commentary:len() == 0 and #output_lines > 0 then
            self.commentary = 'Thank you for your remarks, ' .. sender_name
        end
        for i = self.number_of_lines, 1, -1 do
            local label = 'skyramble_' .. i
            if output_lines[label] == nil then
                scene_print:furni_clear(label)
            else
                scene_print:furni_print(label, output_lines[label], 3 + i * 2.8, self.placement_node)
            end
        end
    end
}

-- ken wrote a simple script to allow dice rolling in a scene.
-- thanks, ken!
local ken_dice = {
    version = "0.1.0.0",
    event_message_received = function(self, context, message, sender_cid, sender_name)
        if starts_with(message, "roll:") then
            local input = message:sub(6)
            local result = self:roll(input)
            local output = sender_name .. " (" .. input .. "): " .. result
            imvu.message_audience(output)
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

-- ken wrote a simple script to add a help file to what the rest of this file can do. Thanks, Ken!
local ken_help = {
    basic_message = "Try \"help TOPIC\". You can ask for help about the following topics: echo, print, vote, roll, joke, zoltar, togethertris",
    topics = {  ["echo"] = "HELP ECHO: any message that is prefixed with \"echo: \" will prompt this script to repeat whatever else is said.",
                ["print"] = "HELP PRINT: the owner of this script can print to the scene with \"print: \" and clear what was printed with \"clear\"",
                ["vote"] = "HELP VOTE: the owner can start a vote with the command \"vote: X or Y or Z or ...\" with two to five options. Once a vote is started, anyone can vote with \"vote OPTION\". \"vote: stop\" will end a vote, and \"vote: clear\" will erase the text from the scene.",
                ["roll"] = "HELP ROLL: anyone can roll dice with the command \"roll: \", specifying the dice in standard \"2d6+5\" format. For example: \"roll: 4d10+7\"",
                ["zoltar"] = "HELP ZOLTAR: When the Zoltar fortune telling machine is in the scene, you can have your fortune told by entering the scene and standing in front of him. One at a time, please!",
                ["togethertris"] = "HELP TOGETHERTRIS: Togethertris is a game played in the audience chat. Valid commands are l (left), r (right), u (up, s, spin, r, rotate), d (down), drop. The most popular move is made every half-second"
            },
    event_message_received = 
        function(self, context, message, sender_cid, sender_name)
            local a = trim(message):lower()
            if a == "help" then
                imvu.message_audience(self.basic_message)
            elseif starts_with(a, "help") then
                local b = self.topics[a:sub(6)]
                if b ~= nil then
                    imvu.message_audience(b)
                end
            end
        end
}

-- this is an example of interactive furniture control
-- our current furniture system is _very bad_ at moving furniture smoothly
-- this demo is largely to demonstrate the need, internally, for a better prop management system.
-- it is titled 'snail_rider' becuase you have to move very slowly for it to appear even halfway smooth.
local snail_rider = {
    version = "0.0.0.1",
    draw_every = 1, -- every 50ms
    -- our snail is a vespa product, selected arbitrarily from the product catalog
    -- as always, this is not an endorsement, personally or collectively, for the product or its creator.
    pid_snail = 23642237,
    base_node = "furniture.Floor.13",
    snail_label = "snail_rider_label",
    state = { x = 0.0, z = 0.0, heading = math.pi, speed = 0.0, rider_cid = nil, iteration = 0, last_draw = 0 },
    two_pi = math.pi * 2,
    turn = math.pi * 0.125, 
    max_speed = 0.08,
    speed_increment = 0.005,
    is_rider = 
        function(self, context, seat_number, seat_furni_pid)
            if context == "scene_move" and seat_number == 1 and self.pid_snail == seat_furni_pid then
                return true
            else
                return false
            end
        end,  
    event_state_change_received = 
        function(self, context, actor_cid, actor_name, seat_number, seat_furni_id, seat_furni_pid)
            if self:is_rider(context, seat_number, seat_furni_pid) then
                self.state.rider_cid = actor_cid
                imvu.message_audience("VROOM VROOM, " .. actor_name .. " this vespa is yours to ride! Use go, stop, fast, slow, left, right, reset to steer this beast!")
            elseif context == "scene_move" and actor_cid == self.rider_cid then
                self.state = { x = 0.0, z = 0.0, heading = 0.0, speed = 0.0, rider_cid = nil, iteration = 0, last_draw = 0 }
            end
        end,
    event_begin_execution =
        function(self)
            imvu.place_furniture({label=self.snail_label, pid=self.pid_snail, node=self.base_node, x=self.state.x, y=0, z=self.state.z, yaw=self.two_pi * 3 / 4, pitch=0, roll=0, scale=1})
        end,
    event_end_execution =
        function(self)
        end,
    event_begin_iteration =
        function(self)
            self.state.iteration = self.state.iteration + 1
        end,
    event_end_iteration =
        function(self)
            if self.state.last_draw + self.draw_every >= self.state.iteration then
                self.state.x = self.state.x + math.sin(self.state.heading) * self.state.speed
                self.state.z = self.state.z + math.cos(self.state.heading) * self.state.speed
                local yaw = self.state.heading
                imvu.place_furniture({label=self.snail_label, pid=self.pid_snail, node=self.base_node, x=self.state.x, y=0, z=self.state.z, yaw=yaw, pitch=0, roll=0, scale=1})
                self.state.last_draw = self.state.iteration
            end
        end,
    event_message_received =
        function(self, context, message, sender_cid, sender_name)
            if self.state.rider_cid == sender_cid then
                local msg = trim(message):lower()
                if msg == "reset" then
                    self.state.x = 0.0 
                    self.state.z = 0.0
                    self.state.heading = 0.0
                    self.state.speed = 0.0
                elseif msg == "right" then
                    self.state.heading = self.state.heading - self.turn
                    if self.state.heading < 0 then
                        self.state.heading = self.two_pi + self.state.heading
                    end
                elseif msg == "left" then
                    self.state.heading = self.state.heading + self.turn
                    if self.state.heading > self.two_pi then
                        self.state.heading = self.state.heading - self.two_pi
                    end
                elseif msg == "go" and self.state.speed == 0 then
                    self.state.speed = self.speed_increment * 4
                elseif msg == "stop" then
                    self.state.speed = 0.0
                elseif msg == "fast" and self.state.speed < self.max_speed then
                    self.state.speed = self.state.speed + self.speed_increment
                elseif msg == "slow" and self.state.speed > 0.0 then
                    self.state.speed = self.state.speed - self.speed_increment
                end
            end
        end
}

-- finally, we combine all these scripts by calling into them with our final return table
local final = {}
  
function final.event_begin_iteration()
    audience_vote:event_begin_iteration()
    snail_rider:event_begin_iteration()
end

function final.event_message_received(context, user, message)
    if starts_with(message, "[Script]") then
        return
    end
    trivial_echo:event_message_received(context, message, user.cid, user.name)
    ken_dice:event_message_received(context, message, user.cid, user.name)
    ken_help:event_message_received(context, message, user.cid, user.name)
    scene_print:event_message_received(context, message, user.cid, user.name)
    audience_vote:event_message_received(context, message, user.cid, user.name)
    snail_rider:event_message_received(context, message, user.cid, user.name)
    podium_print:event_message_received(context, message, user.cid, user.name)
end

function final.event_state_changed(context, user)
    zoltar:event_state_change_received(context, user.cid, user.name, user.seat_number, user.seat_furni_id, user.seat_furni_pid)
    snail_rider:event_state_change_received(context, user.cid, user.name, user.seat_number, user.seat_furni_id, user.seat_furni_pid)
    podium_print:event_state_change_received(context, user.cid, user.name, user.seat_number, user.seat_furni_id, user.seat_furni_pid, user.outfit)
end

function final.event_end_iteration()
    zoltar:event_end_iteration()
    audience_vote:event_end_iteration()
    snail_rider:event_end_iteration()
end

function final.event_stop()
    scene_print:event_end_execution()
    audience_vote:event_end_execution()
    snail_rider:event_end_execution()
end

function final.event_start()
    math.randomseed(os.time())
    scene_print:event_begin_execution()
    audience_vote:event_begin_execution()
    snail_rider:event_begin_execution()
    zoltar:event_begin_execution()
    podium_print:event_begin_execution()
end

function final.event_tip_received(sender, recipient, credits_sent, is_private)
    tip_thanker:event_tip_received(sender.cid, sender.name, recipient.cid, recipient.name, credits_sent, is_private)
end

imvu.debug("Loaded script!")

return final