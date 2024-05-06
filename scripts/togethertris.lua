-- This is togethertris, a puzzle game that is played by everyone in the audience, simultaneously.
-- It places furniture in the scene to build a game grid, and moves pieces once every second or so.
-- Everyone votes on the next move to make by typing in chat or by moving in the scene, and the
-- script will make the move that got the most votes.

-- This was written partially for fun but also as an illustration of the limitations of our 
-- furniture system. While scripts operate at 20 frames per second in theory, the client 
-- implementations for moving furniture are clunky, and the architecture limits us to an effective
-- frames per second of 1 / (ping * 3 / 2). In other words, with 200 millisecond pings, the client
-- has a frames per second of around 3. That's not great, but it can facilitate slow-paced puzzle
-- games and other toys. Hopefully, we can replace or supplement furniture with another system 
-- better suited for interactivity.

-- These are basic constants for what furniture items to use and where to put them.
-- I pulled these block pieces from the product catalog arbitrarily, and inclusion in this script
-- does not qualify as a personal or corporate endorsement for the products or their creators.
-- Feel free to replace these pids with whatever furniture items you like!
local WALL_PID = 10256273
local BLOCK_PID = 52130062
local BLOCK_WIDTH = 1
local LOCATION_NODE = "furniture.Floor.213"

-- we have some useful common functions up top
-- this returns true if the string starts with a given prefix
local function starts_with(str, start)
    return str:sub(1, #start) == start
end

-- a deep table copy algorithm
local function copy(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return obj end
    local s = seen or {}
    local res = {}
    s[obj] = true
    for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
    return res
end

-- trimming the whitespace on either side of a string
local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- randomizing the entries in a table
local function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end  
    return tbl
end

-- This is the togethertris module, expressed as a local so it can be combined with other scripts.
local togethertris = {
    -- The version string is used for state saving and loading, to verify that what we load is still useful.
    current_version = "0.3.0.0",
    -- Our furniture information, locally stored.
    wall_pid = WALL_PID,
    block_pid = BLOCK_PID,
    block_width = BLOCK_WIDTH,
    location_node = LOCATION_NODE,
    owner = imvu.get_owner_cid(),
    -- The state that is saved and loaded with the data module.
    -- see the reset_state function below.
    state = {},
    -- This is measured in iterations. TODO: change to seconds, now that we have a steady_clock in event_begin_iteration.
    static_speed = { intro_length = 250, game_over_length = 250, save_every = 6000 },
    base_game_speed = { vote_every = 10, drop_every = 50, until_speedup = 80 },
    -- These are arrow furniture products put onto the scene so that avatars can control the game by moving.
    arrow_down = { z = 16, scale = 0.5, label = "arrow_down", pid = 63242806, node = "furniture.Floor.213" },
    arrow_left = { z = 12.8, x = -3.2, scale = 0.5, label = "arrow_left", yaw = 1.5 * math.pi, pid = 63242806, node = "furniture.Floor.213" },
    arrow_right = { z = 12.8, x = 3.2, scale = 0.5, label = "arrow_right", yaw = 0.5 * math.pi, pid = 63242806, node = "furniture.Floor.213" },
    arrow_up = { z = 9.6, scale = 0.5, label = "arrow_up", yaw = math.pi, pid = 63242806, node = "furniture.Floor.213" },
    -- Where our furniture props / game pieces are located, relative to the node.
    next_piece_logical_x = 20,
    next_piece_logical_y = 20,
    base_y = 5,
    base_x = -10,
    -- Our game pieces.
    tetrominos = {
        {{0,0,0,0}, -- bottom, y = 1
            {0,0,0,0},
            {1,1,1,1},
            {0,0,0,0}}, -- top, y = 4
        {{0,0,0},
            {1,1,1},
            {1,0,0}},
        {{0,0,0},
            {1,1,1},
            {0,0,1}},
        {{1,1},
            {1,1}},
        {{0,0,0},
            {1,1,0},
            {0,1,1}},
        {{0,0,0},
            {0,1,1},
            {1,1,0}},
        {{0,0,0},
            {1,1,1},
            {0,1,0}}
    },
    -- This empties the logical game grid.
    empty_grid = function(self)
        local val = {}
        for i=1,22 do
            local row = {}
            for j=1,10 do
                table.insert(row, 0)
            end
            table.insert(val, row)
        end
        return val
    end,
    -- This rotates a piece matrix
    rotate_piece = function(self,tbl)
        local w = #tbl
        local v = math.floor(w / 2)
        local ww = w + 1
        for x = 1, v, 1 do
            for y = x, w - x, 1 do
                local temp = tbl[y][x]
                tbl[y][x] = tbl[x][ww - y]
                tbl[x][ww - y] = tbl[ww - y][ww - x]
                tbl[ww - y][ww - x] = tbl[ww - x][y]
                tbl[ww - x][y] = temp
            end
        end
        return tbl
    end,
    -- This reverse the rotate_piece argument, in case a rotation fails due to collision
    unrotate_piece = function(self,tbl)
        local w = #tbl
        local v = math.floor(w / 2)
        local ww = w + 1
        for x = 1, v, 1 do
            for y = x, w - x, 1 do
                local temp = tbl[ww - x][y]
                tbl[ww - x][y] = tbl[ww - y][ww - x]
                tbl[ww - y][ww - x] = tbl[x][ww - y]
                tbl[x][ww - y] = tbl[y][x]
                tbl[y][x] = temp
            end
        end
        return tbl
    end,
    -- create a new bag of game pieces, whenever we run low
    new_bag = function(self)
        local val = copy(self.tetrominos)
        return shuffle(val)
    end,
    -- save the state to persistent storage
    save_state = function(self)
    end,
    -- reset the state
    reset_state = function(self, existing_furni)
        self.state = { 
            version = self.current_version,
            names = {}, 
            -- this is the logical game grid.
            grid = self:empty_grid(),
            -- we track not only how people vote, but when they win the vote and when they try to vote twice in one turn.
            -- TODO: after the game ends, we can add output shouting out the most active users
            vote = { votes = {}, wins = {}, spams = {} },
            score = 0,
            -- we don't simply select random pieces, we put all the piece types into a bag and pull them out
            -- until the bag is empty. this makes sure we get an even distribution of pieces
            piece_bag = self:new_bag(),
            dropped_count = 0,
            current_piece = nil,
            next_piece = nil,
            -- the cursor tracks where the current game piece is
            cursor_x = 4,
            cursor_y = 21,
            iteration = 0,
            -- we have a primitive state machine to track the game status through intro, gameplay, outtro
            stage = "start",
            game_speed = copy(self.base_game_speed),
            game_time = { last_vote = 0, last_drop = 0, last_save = 0, last_stage = 0 },
            valid_votes = 0,
            -- these are the furniture pieces we know about in the scene
            -- we track them so we can re-use furniture. older clients sometimes react better when you move
            -- existing furniture rather than creating novel furniture, so as a workaround, we do that preferentially
            furni = existing_furni or { block_count = 0, recycled = {}, is_recycled = {}, walls = {} },
            current_sitters = {}
        }
        return self.state
    end,
    -- load the state from persistent storage.
    load_state = function(self)
        self.state = self.state or {}
        if self.state.version ~= self.current_version then
            imvu.debug("Resetting state, after finding " .. (self.state.version or "nothing"))
            self.state = self:reset_state(self.state.furni)
        end
    end,
    -- advance our game stage state machine
    change_stage = function(self, new_stage)
        self.state.game_time.last_stage = self.state.iteration
        self.state.stage = new_stage
    end,
    -- this draws the walls beneath and on either side of the play area.
    -- it's the bucket we play in, built out of furniture items treated as pixels.
    draw_walls = function(self)
        for y = 1, 20, 1 do
            local label_left = "wall_left_" .. y
            local label_right = "wall_right_" .. y
            imvu.place_furniture({label=label_left, pid=self.wall_pid, node=self.location_node, x=self.base_x + 0 * self.block_width, y=self.base_y + y * self.block_width, z=0, yaw=0, pitch=0, roll=0, scale=1})
            imvu.place_furniture({label=label_right, pid=self.wall_pid, node=self.location_node, x=self.base_x + 11 * self.block_width, y=self.base_y + y * self.block_width, z=0, yaw=0, pitch=0, roll=0, scale=1})
            table.insert(self.state.furni.walls, label_left)
            table.insert(self.state.furni.walls, label_right)
        end
        for x = 0, 11, 1 do
            local label_bottom = "wall_bottom_" .. x
            imvu.place_furniture({label=label_bottom, pid=self.wall_pid, node=self.location_node, x=self.base_x + x * self.block_width, y=self.base_y, z=0, yaw=0, pitch=0, roll=0, scale=1})
            table.insert(self.state.furni.walls, label_bottom)
        end
        imvu.place_furniture(self.arrow_up)
        imvu.place_furniture(self.arrow_down)
        imvu.place_furniture(self.arrow_left)
        imvu.place_furniture(self.arrow_right)
    end,

    -- this function is a workaround for some issues we find in practice, when we reset the board.
    hacky_pre_population = function(self)
        self.state.furni.block_count = self.state.furni.block_count or 0
        -- there are two cases where we have problems with placing furniture on demand.
        -- mobile clients, especially older versions of mobile clients, react better to moving furniture than placing it.
        -- if the scripting system faces an inelegant restart, we want to clear the board before starting over.
        -- ideally, with updated clients and with a rock solid state save/load, this will not be necessary.
        while self.state.furni.block_count < 208 do
            self.state.furni.block_count = self.state.furni.block_count + 1
            local block_label = "block_" .. self.state.furni.block_count
            imvu.place_furniture({label=block_label, pid=self.block_pid, node=self.location_node, x=self.base_x + 10, y=self.base_y + 0, z=0, yaw=0, pitch=0, roll=0, scale=0.01})
            table.insert(self.state.furni.recycled, block_label)
            self.state.furni.is_recycled[block_label] = true
        end
    end,

    -- Greet the audience when the game starts, and initialize furniture.
    stage_start = function(self)
        imvu.message_audience("Welcome to Togethertris! In this game, everyone in the audience votes on how to play, and five times a second, the most popular move submitted is made.")
        imvu.message_audience("Valid moves and their aliases are left (l), right (r), spin (s, rotate), down (d), and drop.")
        imvu.message_audience("The game will begin in five seconds!")
        if #self.state.furni.walls == 0 then
            self:draw_walls()
        end
        self:hacky_pre_population()
        self:change_stage("intro")
    end,

    -- find the winning move for this round of voting.
    tally_votes = function(self)
        local candidates = {}
        local top_count = 0
        local top_candidate = nil
        for k, v in pairs(self.state.vote.votes) do
            candidates[v] = (candidates[v] or 0) + 1
        end
        for k, v in pairs(candidates) do
            if v > top_count then
                top_count = v
                top_candidate = k
            end
        end
        for k, v in pairs(self.state.vote.votes) do
            if v == top_candidate then
                self.state.vote.wins[k] = (self.state.vote.wins[k] or 0) + 1
            end
        end
        self.state.vote.votes = {}
        return top_candidate
    end,

    -- This is effectively a wrapper around imvu.place_furniture, which allows us to perform other logic
    -- or debug output if it's necessary (hopefully it isn't! I think it works now!)
    move_block = function(self, label, offset_x, offset_y)
        imvu.place_furniture({label=label, pid=self.block_pid, node=self.location_node, x=self.base_x + (offset_x) * self.block_width, y=self.base_y + (offset_y) * self.block_width, z=0, yaw=0, pitch=0, roll=0, scale=1})
    end,

    -- Move game blocks around to draw a game piece.
    draw_piece = function(self, piece, offset_x, offset_y)
        for y, inner in pairs(piece) do
            for x, v in pairs(inner) do
                if v == 1 then
                    -- if v == 1, we know we want to draw something but we don't have an existing piece of furniture
                    -- place new furniture (or recycle an unused piece of furniture) and record the label for it
                    local label = self:move_recycled_block(offset_x + x - 1, offset_y + y - 1)
                    piece[y][x] = label
                elseif v ~= 0 then
                    -- if v isn't 0 and it isn't 1, it must be the label we recorded earlier. move it.
                    self:move_block(v, offset_x + x - 1, offset_y + y - 1)
                end
            end
        end
    end,

    -- check for collision with the wall or the static game pieces
    collision_detected = function(self)
        for y = 1, #self.state.current_piece, 1 do
            local row = self.state.current_piece[y]
            for x = 1, #row, 1 do
                if row[x] ~= 0 then                 -- the piece has a block here.
                    local grid_x = self.state.cursor_x + x - 1
                    local grid_y = self.state.cursor_y + y - 1
                    if (grid_x < 1 or grid_x > 10)  -- the block is over the limits of the left and right walsl
                        or (grid_y < 1)             -- the block has been rotated or down'd under the floor
                        or ((grid_y <= 20) and (self.state.grid[grid_y][grid_x] ~= 0))-- we're on a valid grid position, and it's occupied.
                    then
                        return true
                    end
                end
                -- note: cursor values of x < 1 are potentially valid so long as they don't push a block over the edge of the wall.
            end
        end
    end,

    -- valid moves: left, right, down, drop, spin
    attempt_move = function(self, move)
        if move == "left" then
            self.state.cursor_x = self.state.cursor_x - 1
            if self:collision_detected() then
                self.state.cursor_x = self.state.cursor_x + 1
                return false
            else
                self:draw_piece(self.state.current_piece, self.state.cursor_x, self.state.cursor_y)
                return true
            end
        elseif move == "right" then
            self.state.cursor_x = self.state.cursor_x + 1
            if self:collision_detected() then
                self.state.cursor_x = self.state.cursor_x - 1
                return false
            else
                self:draw_piece(self.state.current_piece, self.state.cursor_x, self.state.cursor_y)
                return true
            end
        elseif move == "down" then
            self.state.cursor_y = self.state.cursor_y - 1
            if self:collision_detected() then
                self.state.cursor_y = self.state.cursor_y + 1
                return false
            else
                self:draw_piece(self.state.current_piece, self.state.cursor_x, self.state.cursor_y)
                return true
            end
        elseif move == "spin" then
            self.state.current_piece = self:rotate_piece(self.state.current_piece)
            -- TODO: special logic should go here for collision detection.
            -- if you spin the piece while near an obstruction that could "push" the piece left or right into a valid location,
            -- we should automatically move the cursor appropriately and complete the spin.
            -- this will come into play if you move a vertical line piece to one wall or another, then attempt to spin it horizontal
            if self:collision_detected() then
                self.state.current_piece = self:unrotate_piece(self.state.current_piece)
                return false
            else
                self:draw_piece(self.state.current_piece, self.state.cursor_x, self.state.cursor_y)
                return true
            end
        elseif move == "drop" then
            repeat
                self.state.cursor_y = self.state.cursor_y - 1
            until self:collision_detected()
            self.state.cursor_y = self.state.cursor_y + 1
            self:draw_piece(self.state.current_piece, self.state.cursor_x, self.state.cursor_y)
            -- drops never fail, they just take you down as far as you can go
            return true
        end
    end,

    -- make use of furniture we've already placed but don't currently need to draw a pixel
    recycle_block = function(self, block_label)
        if block_label == 0 then
            imvu.debug("recycle_block sanity check failed!")
        end
        if not self.state.furni.is_recycled[block_label] then
            table.insert(self.state.furni.recycled, block_label)
            self.state.furni.is_recycled[block_label] = true -- this index shouldn't be necessary, but I can't track down how pieces are getting double-recycled
        end
        imvu.place_furniture({label=block_label, pid=self.block_pid, node=self.location_node, x=10, y=0, z=0, yaw=0, pitch=0, roll=0, scale=0.01})
    end,

    -- place a new piece of furniture
    create_block = function(self, x, y)
        self.state.furni.block_count = (self.state.furni.block_count or 0) + 1
        local label = "block_" .. self.state.furni.block_count
        imvu.place_furniture({label=label, pid=self.block_pid, node=self.location_node, x=self.base_x + x * self.block_width, y=self.base_y + y * self.block_width, z=0, yaw=0, pitch=0, roll=0, scale=1})
        return label
    end,

    -- Place a presently unused block to draw a pixel.
    move_recycled_block = function(self, x, y)
        local val = nil
        repeat
            val = table.remove(self.state.furni.recycled)
            if val == nil then
                return self:create_block(x, y)
            end
        until self.state.furni.is_recycled[val] == true
        self.state.furni.is_recycled[val] = nil
        imvu.place_furniture({label=val, pid=self.block_pid, node=self.location_node, x=self.base_x + x * self.block_width, y=self.base_y + y * self.block_width, z=0, yaw=0, pitch=0, roll=0, scale=1})
        return val
    end,

    -- note: this algorithm presumes every block is the same color/model/pixel/whatever.
    --       if you wanted to implement colored pieces, eg, red squares and blue lines,
    --       you would have to replace this function.
    -- in order to do as little work as possible, we have to be clever about the clears.
    -- we have to look at the first modified row then work our way up to 22:
    -- (a) find which row should be moved to the row we're at
    -- (b) if a block exists on that row,column, recycle it
    -- (c) if not, recycle the block where we're at and zero the grid
    process_clears = function(self, clears)
        local clears_index = 1
        local min_y = 1
        if self.state.cursor_y > min_y then 
            min_y = self.state.cursor_y
        end
        local dest_y = min_y
        local source_y = min_y
        while dest_y <= 22 do
            -- while there still clears to worry about, keep skipping source_rows until we're past them
            while clears_index <= #clears and source_y == clears[clears_index] do 
                clears_index = clears_index + 1
                source_y = source_y + 1
            end
            local dest_row = self.state.grid[dest_y]
            if source_y > 22 then -- if we're pulling off the top of the grid, zero everything out
                for x = 1, 10, 1 do
                    if dest_row[x] ~= 0 then
                        self:recycle_block(dest_row[x])
                        dest_row[x] = 0
                    end
                end
            elseif source_y ~= dest_y then -- if we're pulling from a valid row, ovewrite the destination row appropriately
                local source_row = self.state.grid[source_y]
                for x = 1, 10, 1 do
                    if dest_row[x] ~= 0 then
                        if source_row[x] == 0 then
                            self:recycle_block(dest_row[x])
                            dest_row[x] = 0
                        end
                    else
                        if source_row[x] ~= 0 then
                            self:move_block(source_row[x], x, dest_y)
                            dest_row[x] = source_row[x]
                            source_row[x] = 0
                        end
                    end
                end
            end
            source_y = source_y + 1
            dest_y = dest_y + 1
        end
        local points = (#clears * #clears * (self.state.valid_votes or 1))
        self.state.score = self.state.score + points
        imvu.message_audience("Score! For " .. self.state.valid_votes .. " valid votes and a " .. #clears .. "x clear, you received " .. points .. " points!")
        self.state.valid_votes = 0
    end,

    -- when the players want to drop the piece, we try to get it as far down as it can go
    attempt_auto_drop = function(self)
        self.state.cursor_y = self.state.cursor_y - 1
        if self:collision_detected() then
            self.state.cursor_y = self.state.cursor_y + 1
            -- we must seal the piece in place and check for game over or clears.
            for y = 1, #self.state.current_piece, 1 do             -- if we did this in descending order, we'd find game overs before drawing them. unsatisfying.
                local grid_y = self.state.cursor_y + y - 1
                local row = self.state.current_piece[y]
                for x = 1, #row, 1 do
                    if row[x] ~= 0 then                 -- a block exists
                        if grid_y > 22 then             -- a block exists on the current_piece that overflows, even after clears
                            return false
                        else                            -- a block exists that should be transfered to the grid
                            self.state.grid[grid_y][self.state.cursor_x + x - 1] = row[x]
                            row[x] = 0                  -- bugfix: we need to transfer it OUT as well as IN, or we'll clean it up twice!
                        end
                    end
                end
            end
            -- we've successfully transfered the current piece to the grid
            -- check for clears
            local clears = {}
            local max_block_found = 0
            for y = 1, #self.state.current_piece, 1 do
                -- it's very possible for grid_y to be 0 or even -1, because the cursor can be on the bottom-right hand corner of a horizontal line tetronimo with blank space.
                local grid_y = self.state.cursor_y + y - 1
                if grid_y >= 1 then
                    local grid_row = self.state.grid[grid_y]
                    local is_clear = true
                    local has_block = false
                    for x = 1, #grid_row, 1 do
                        if grid_row[x] == 0 then
                            is_clear = false
                        else
                            has_block = true
                        end
                    end
                    if is_clear then
                        table.insert(clears, grid_y)
                    elseif has_block then
                        max_block_found = grid_y
                    end
                end
            end
            if max_block_found - #clears > 20 then -- we found a block high enough that the clears won't save us
                return false
            end

            if #clears > 0 then
                self:process_clears(clears)
            end

            -- queue up the next piece
            self.state.current_sitters = {}
            self.state.current_piece = self.state.next_piece
            self.state.cursor_x = 4
            self.state.cursor_y = 21
            self:draw_piece(self.state.current_piece, self.state.cursor_x, self.state.cursor_y)

            if #self.state.piece_bag == 0 then
                self.state.piece_bag = self:new_bag()
            end

            self.state.next_piece = table.remove(self.state.piece_bag)
            self:draw_piece(self.state.next_piece, self.next_piece_logical_x, self.next_piece_logical_y)
        else
            self:draw_piece(self.state.current_piece, self.state.cursor_x, self.state.cursor_y)
        end
        return true 
    end,

    -- remove all known pixels from the scene by recycling them, eg, moving them out of the way and scaling them down
    clean_up = function(self, grid)
        for y = 1, #grid, 1 do
            local row = grid[y]
            for x = 1, #row, 1 do
                if row[x] ~= 0 then
                    self:recycle_block(row[x])
                    row[x] = 0
                end
            end
        end
    end,

    -- the fifth stage of the game, outputting the score
    the_game_is_over = function(self)
        imvu.message_audience("GAME OVER! The final score is: " .. self.state.score)
        -- imvu.message_audience("X voted the most times with X_1, Y won the most votes with Y_1, and Z spammed the audience with repeat votes Z_1 times!")
        self:clean_up(self.state.grid)
        self:clean_up(self.state.current_piece)
        self:clean_up(self.state.next_piece)
    end,

    -- the third stage of the game, when play starts
    the_game_is_on = function(self)
        self.state.current_piece = table.remove(self.state.piece_bag)
        self.state.next_piece = table.remove(self.state.piece_bag)
        self:draw_piece(self.state.current_piece, self.state.cursor_x, self.state.cursor_y)
        self:draw_piece(self.state.next_piece, self.next_piece_logical_x, self.next_piece_logical_y)
        imvu.message_audience("Here we go! The game begins!")
    end,

    -- the second stage of the game, the delay between instructions and gameplay
    stage_intro = function(self)
        if self.state.game_time.last_stage + self.static_speed.intro_length <= self.state.iteration then
            self:the_game_is_on()
            self:change_stage("game")
        end
    end,

    -- check to see if we have an avatar sitting on a falling block.
    has_sitter = function(self)
        for _ in pairs(self.state.current_sitters) do
            return true
        end
        return false
    end,

    -- the fourth stage of the game, active play
    stage_game = function(self)
        if self.state.game_time.last_vote + self.state.game_speed.vote_every <= self.state.iteration then
            local move = self:tally_votes()
            if move ~= nil then
                if self:attempt_move(move) then
                    self:draw_piece(self.state.current_piece, self.state.cursor_x, self.state.cursor_y)
                -- else
                --     imvu.message_audience("Your move, \"" .. move .. "\" failed!")
                end
            end
            self.state.game_time.last_vote = self.state.iteration
        end
        local speed = self.state.game_speed.drop_every
        if self:has_sitter() then
            speed = speed / 10
        end
        if self.state.game_time.last_drop + speed <= self.state.iteration then
            if self:attempt_auto_drop() then
                self.state.game_time.last_drop = self.state.iteration
            else 
                self:the_game_is_over()
                self:change_stage("game_over")
            end
        end
    end,

    -- the sixth and final stage of the game, waiting between score output and starting all over again
    stage_game_over = function(self)
        if self.state.game_time.last_stage + self.static_speed.game_over_length <= self.state.iteration then    
            -- brings us back to stage = start
            self.state = self:reset_state(self.state.furni)
        end
    end,

    -- respond to user input in the chat
    process_vote = function(self, sender_key, message)
        local vote = nil
        -- left (l), right (r), spin (s, u, up, rotate), down (d), and drop
        if     message == "l" or message == "left" then vote = "left"
        elseif message == "r" or message == "right" then vote = "right"
        elseif message == "s" or message == "spin" or message == "u" or message == "up" or message == "rotate" then vote = "spin"
        elseif message == "d" or message == "down" then vote = "down"
        elseif message == "drop" then vote = "drop"
        end

        if vote ~= nil then
            if self.state.vote.votes[sender_key] ~= nil then
                self.state.vote.spams[sender_key] = (self.state.vote.spams[sender_key] or 0) + 1
            else
                self.state.valid_votes = self.state.valid_votes + 1
            end
            self.state.vote.votes[sender_key] = vote
        end
    end,

    -- try to find avatars sitting on falling game pieces
    -- when a scene participant sits on a game piece, it falls faster
    get_piece_seat = function(self, label)
        for y, inner in pairs(self.state.current_piece) do
            for x, v in pairs(inner) do
                if label == v then
                    imvu.debug('Found a sitter on ' .. label)
                    return v
                end
            end
        end
        return nil
    end,

    -- outward-facing event functions
    event_begin_iteration = function(self)
        if self.state == nil then
            imvu.debug("Encountered nil state in event_begin_iteration")
            self.state = {}
        end
        self.state.iteration = (self.state.iteration or 0) + 1
    end,

    -- historical footnote:
    -- note the parameterization of this function differs from what the documentation describes
    -- that's because this script was written in an earlier version which separated out cid and
    -- name as multiple parameters. now, 'sender_cid' and 'sender_name' are combined into 'sender'
    -- the translation from the new, active format, to what this function expects, is below.
    event_message_received = function(self, context, message, sender_cid, sender_name)
        if self.state.stage == "game" then
            local sender_key = "cid" .. sender_cid
            self.state.names[sender_key] = sender_name
            self:process_vote(sender_key, trim(message):lower())
        end
    end,

    -- when someone moves during the game, check to see if they're standing on a control arrow
    -- or sitting on a falling piece. if so, respond accordingly.
    event_state_changed = function(self, context, user)
        if context == "scene_move" and self.state.stage == "game" then
            local sender_key = "cid" .. user.cid
            if user.seat_furni_label == self.arrow_left.label then 
                self:process_vote(sender_key, "left")
                self.state.current_sitters[sender_key] = nil
            elseif user.seat_furni_label == self.arrow_right.label then 
                self:process_vote(sender_key, "right")
                self.state.current_sitters[sender_key] = nil
            elseif user.seat_furni_label == self.arrow_up.label then 
                self:process_vote(sender_key, "spin")
                self.state.current_sitters[sender_key] = nil
            elseif user.seat_furni_label == self.arrow_down.label then 
                self:process_vote(sender_key, "drop")
                self.state.current_sitters[sender_key] = nil
            else
                self.state.current_sitters[sender_key] = self:get_piece_seat(user.seat_furni_label)
            end
        end
    end,

    -- at the end of the iteration, advance the stage
    event_end_iteration = function(self)
        if      self.state.stage == "game"       then self:stage_game()
        elseif  self.state.stage == "intro"      then self:stage_intro()
        elseif  self.state.stage == "game_over"  then self:stage_game_over()
        elseif  self.state.stage == "start"      then self:stage_start()
        else    
            imvu.debug("Unknown stage " .. (self.state.stage or 'BLANK') .. " encountered!")
            self.state = self:reset_state()
        end

        if self.state.game_time.last_save + self.static_speed.save_every <= self.state.iteration then
            self:save_state()
            self.state.game_time.last_save = self.state.iteration
        end
    end,
    
    -- save when the script ends, load when it begins.
    -- historical footnote: the function names here were changed to 'stop' and 'start'
    event_end_execution = function(self)
        self:save_state()
    end,
    event_begin_execution = function(self)
        self:load_state()
    end
}

-- if you are combining togethertris with another script, you can do so here.
-- 'final' is intended to represent a place where singular incoming input can be directed to mulitiple recipients.
local final = {}

-- you do not have to accept parameters you do not need
-- we added the current_iteration and steady_clock parameters to event_begin_iteration after this script was written
-- so the script does not currently make use of them.
function final.event_begin_iteration()
    togethertris:event_begin_iteration()
    -- if you wanted to add another psuedo-module to this script, you could call:
    -- another_module:event_begin_iteration()
end

function final.event_message_received(context, user, message)
    if starts_with(message, "[Script]") then
        return
    end
    -- this is where we translate from the v1 function signature to the old v0 prototype function signature
    togethertris:event_message_received(context, message, user.cid, user.name)

    if (message:lower() == "help") then
        if (context == "audience_whisper") then
            imvu.whisper_audience_member(user.cid, "Togethertris is a game the entire audience plays together.")
            imvu.whisper_audience_member(user.cid, "Once the game begins, type 'left', 'right', 'up', 'spin', 'down', or 'drop' to vote on the next move.")
            imvu.whisper_audience_member(user.cid, "When lines are cleared, the number of votes counts towards the score!")
        else
            imvu.message_audience("Togethertris is a game the entire audience plays together.")
            imvu.message_audience("Once the game begins, type 'left', 'right', 'up', 'spin', 'down', or 'drop' to vote on the next move.")
            imvu.message_audience("When lines are cleared, the number of votes counts towards the score!")
        end
    end
end

function final.state_changed(context, user)
    togethertris:event_state_changed(context, user)
end

function final.event_end_iteration()
    togethertris:event_end_iteration()
end

function final.event_stop()
    togethertris:save_state()
end

function final.event_start()
    -- it's important to seed the RNG here, or selected pieces will be the same every time!
    math.randomseed(os.time())
    togethertris:load_state()
end

imvu.debug("Loaded script!")

return final