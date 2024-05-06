--[[
This script implements the popular party game, "Fuck, Marry, Kill"

Currently, the game can be invoked by anyone in the room by typing "fmk" into chat.

When that's done, a series of polls will be presented to people in the room, asking them
to pick an option for each of the three names (selected at random from the names table).

Once all three names have been presented, the results are dropped into chat.

]]--


script = {}

local function starts_with(str, start)
    return str:sub(1, #start) == start
end

-- these names are shuffled upon script start, and again if enough rounds have been player to 
-- exhaust the list
local names = {"Leonardo DiCaprio","Beyoncé","Priyanka Chopra","Chris Hemsworth","Lupita Nyong'o","Ryan Reynolds","Zendaya","Tom Hanks","Jennifer Lopez","Mahershala Ali","Scarlett Johansson","Idris Elba","Emma Watson","Will Smith","Gal Gadot","Denzel Washington","Charlize Theron","Shah Rukh Khan","Margot Robbie","Michael B. Jordan","Angelina Jolie","John Boyega","Natalie Portman","Eddie Redmayne","Rihanna","Jason Momoa","Viola Davis","Dwayne Johnson","Priyamani","Cate Blanchett","Chris Evans","Mindy Kaling","Matthew McConaughey","Salma Hayek","Chris Pratt","Halle Berry","Hugh Jackman","Deepika Padukone","Jake Gyllenhaal","Kerry Washington","Robert Downey Jr.","Zoe Saldana","Keanu Reeves","Charlize Theron","Dev Patel","Emma Stone","Idris Elba","Reese Witherspoon","Chiwetel Ejiofor","Jennifer Aniston","Riz Ahmed","Sandra Bullock","Mahira Khan","Tom Hardy","Priyanka Chopra Jonas","Brad Pitt","Aishwarya Rai Bachchan","Chris Pine","Julia Roberts","Devika Bhise","Michael Fassbender","Meryl Streep","Naseeruddin Shah","Charlize Theron","Tom Holland","Oprah Winfrey","Jude Law","Shabana Azmi","Daniel Radcliffe","Selena Gomez","Adam Driver","Mindy Kaling","Kit Harington","Priyanka Bose","Mark Ruffalo","Hrithik Roshan","Emily Blunt","Irrfan Khan","Cameron Diaz","Daniel Kaluuya","Kate Winslet","Rajkummar Rao","Kate Beckinsale","Omar Sy","Salma Hayek","Awkwafina","Gerard Butler","Taraji P. Henson","Viggo Mortensen","Rachel McAdams","Nawazuddin Siddiqui","Diane Kruger","Abhishek Bachchan","Anne Hathaway","Ranbir Kapoor","Natalie Dormer","Huma Qureshi","Tom Cruise","Freida Pinto","Daniel Craig","Taika Waititi","Aamir Khan"}

local function shuffleNames()
    for i = #names, 2, -1 do
        local j = math.random(i)
        names[i], names[j] = names[j], names[i]
    end
end

local fmk_game = {
    state = {
        start_every = 3,
        poll_duration = 10,
        poll_counter = 0,
        poll_item_counter = 0,
        people_index = 0,
        person_index = 1,
        answers = {
            { b = 0, m = 0, k = 0},
            { b = 0, m = 0, k = 0},
            { b = 0, m = 0, k = 0},
        },
        names = {"Alice", "Bob", "Carol"}
    },

    get_question = function(self)
        if (self.state.people_index > 3) then
            return
        end
        local question = 'Boink, Marry, Kill: ' .. self.state.names[self.state.person_index]
        return question
    end,

    get_max_as_string = function(self, b, m, k) 
        if (b > m) and (b > k) then return 'Boink' end
        if (m > b) and (m > k) then return 'Marry' end
        if (k > b) and (k > m) then return 'Kill' end

        return 'Tied'
    end,

    print_results = function(self)
        local output
        local res 

        for i=1,3 do
            res = self:get_max_as_string(self.state.answers[i].b, self.state.answers[i].m, self.state.answers[i].k)
            output = (self.state.names[i]) .. ': ' .. res .. '\n'
            imvu.message_audience(output)
        end
    end,

    add_to_tally = function(self, person_idx, answer, count)
        
        if (self.state.answers[person_idx] == nil) then
            return
        end

        if (answer == 'Marry') then
            self.state.answers[person_idx].m = self.state.answers[person_idx].m + count
        elseif (answer == 'Boink') then
            self.state.answers[person_idx]['b'] = self.state.answers[person_idx].b + count
        else 
            self.state.answers[person_idx].k = self.state.answers[person_idx].k + count
        end
    end,

    init = function(self)
        shuffleNames()
        self.state.people_index = 0
    end,

    start_game = function(self)
        self.state.person_index = 1
        self.state.answers = {
            { b = 0, m = 0, k = 0},
            { b = 0, m = 0, k = 0},
            { b = 0, m = 0, k = 0},
        }
        for i=1,3 do
            self.state.names[i] = names[i + self.state.people_index]
        end

        self:ask_question()
    end,

    ask_question = function(self)
        imvu.debug('asking question: ' .. self.state.person_index)
        -- imvu.message_audience('asking question: ' .. self.state.person_index)
        local poll = { 
            type = 'custom',
            content = self:get_question(),
            duration = self.state.poll_duration,
            options = { "Boink", "Marry", "Kill" }
        }
        imvu.create_poll(poll, function(results)
            if (results) then
                for k, v in ipairs(results.tallies) do
                    self:add_to_tally(self.state.person_index, v.content, v.tally)
                end

            end

            self.state.person_index = self.state.person_index + 1
            if (self.state.person_index > 3) then 
                self:print_results()
                self.state.person_index = 1
                self.state.people_index = self.state.people_index + 3
                if ((self.state.people_index + 3) > #names) then
                    shuffleNames()
                    self.state.people_index = 0
                end
            else
                self:ask_question()
            end            
            
            
            
        end, imvu.debug)
    end,


    event_begin_iteration = function(self)
        local now = os.time()
        if self.state_next_poll and self.state.next_poll < now then
            self:ask_question()
        end
    end,

    event_message_received = function(self, context, sender, message)
        if starts_with(message, 'fmk') then
            self.state.start_every = 3
            self.state.poll_duration = 10
            self:start_game()
        end
    end,
}

return {
    event_begin_iteration = function() 
        fmk_game:event_begin_iteration()
    end,
    event_message_received = function(context, sender, message) 
        fmk_game:event_message_received(context, sender, message)
    end,
    event_start = function() 
        fmk_game:init()
    end
}

