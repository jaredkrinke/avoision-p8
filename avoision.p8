pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

-- Constants
function map_names_to_table(names)
    local table = {}
    for i = 1, #names do table[names[i]] = i - 1 end
    return table
end
colors = map_names_to_table({ "black", "dark_blue", "dark_purple", "dark_green", "brown", "dark_gray", "light_gray", "white", "red", "orange", "yellow", "green", "blue", "indigo", "pink", "peach" })
buttons = map_names_to_table({ "left", "right", "up", "down", "z", "x" })

system = {
    width = 128,
    height = 128,
}

-- Object orientation
class = {}
function class.create(base_class)
    local new_class = {}
    function new_class.new()
        local c = {}
        setmetatable(c, { __index = new_class })
        return c
    end

    if base_class then
        setmetatable(new_class, { __index = base_class })
    end

    return new_class
end

-- Object model
entity = class.create()
function entity:init(x, y, width, height)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
end
function entity:update() end

-- Debugging
local debug = false
local debug_lines = {}

-- Player
local player_size = 3
local player_speed = 2
player = class.create(entity)
player.color = colors.green
function player.create(x, y)
    local p = player.new()
    entity.init(p, x, y, player_size, player_size)
    p.v = { 0, 0, 0, 0 }
    return p
end
function player:update()
    if btn(buttons.up) then self.v[1] = 1 else self.v[1] = 0 end
    if btn(buttons.down) then self.v[2] = 1 else self.v[2] = 0 end
    if btn(buttons.left) then self.v[3] = 1 else self.v[3] = 0 end
    if btn(buttons.right) then self.v[4] = 1 else self.v[4] = 0 end

    local dx = self.v[4] - self.v[3]
    local dy = self.v[1] - self.v[2]
    if dx ~= 0 or dy ~= 0 then
        local direction = atan2(dx, dy)
        self.x = self.x + player_speed * cos(direction)
        self.y = self.y + player_speed * sin(direction)

        if abs(self.x) + self.width / 2 >= 50 then
            if self.x > 0 then
                self.x = 50 - self.width / 2
            else
                self.x = -50 + self.width / 2
            end
        end

        if abs(self.y) + self.height / 2 >= 50 then
            if self.y > 0 then
                self.y = 50 - self.height / 2
            else
                self.y = -50 + self.height / 2
            end
        end
    end
end

-- Goal
local goal_size = player_size
goal = class.create(entity)
goal.color = colors.red
function goal.create()
    local g = goal.new()
    entity.init(g, 0, 0, goal_size, goal_size)
    return g
end

-- Enemy
local enemy_size = player_size
local enemy_speed = 1.5
enemy = class.create(entity)
enemy.color = colors.white
function enemy.create(vx, vy)
    local e = enemy.new()
    entity.init(e, 0, 0, enemy_size, enemy_size)
    e.speed = { x = vx, y = vy }
    return e
end
function enemy:update_axis(axis, axis_size)
    local axis_speed = self.speed[axis]
    local axis_position = self[axis] + axis_speed
    if abs(axis_position) + axis_size / 2 > 50 then
        if axis_speed > 0 then
            axis_position = 50 - axis_size / 2 - 1
        else
            axis_position = -50 + axis_size / 2 + 1
        end

        self.speed[axis] = -axis_speed

        -- TODO: Bounce sound
    end

    self[axis] = axis_position
end
function enemy:update()
    self:update_axis("x", self.width)
    self:update_axis("y", self.height)
end

-- Game logic
game = {}
game.player = player.create(0, 0)
game.goal = goal.create()
game.enemies = {}
game.done = false

function coin_flip()
    return (rnd(100) > 50)
end

function round(x)
    return flr(x + 0.5)
end

function check_collision(a, b)
    local ax1 = round(a.x - a.width / 2)
    local ax2 = round(a.x + a.width / 2)
    local ay1 = round(a.y - a.height / 2)
    local ay2 = round(a.y + a.height / 2)
    local bx1 = round(b.x - b.width / 2)
    local bx2 = round(b.x + b.width / 2)
    local by1 = round(b.y - b.height / 2)
    local by2 = round(b.y + b.height / 2)

    return ((ax1 >= bx1 and ax1 <= bx2) or (ax2 >= bx1 and ax2 <= bx2) or (bx1 >= ax1 and bx1 <= ax2) or (bx2 >= ax1 and bx2 <= ax2))
        and ((ay1 >= by1 and ay1 <= by2) or (ay2 >= by1 and ay2 <= by2) or (by1 >= ay1 and by1 <= ay2) or (by2 >= ay1 and by2 <= ay2))
end

function move_to_clear_position(e)
    repeat
        e.x = rnd(100 - e.width) - 50 + e.width / 2
        e.y = rnd(100 - e.height) - 50 + e.height / 2
        local valid = not check_collision(game.player, e)
    until valid
end

function _init()
    move_to_clear_position(game.goal)
end

function _update()
    local player = game.player
    if not game.done then
        player:update()
    end

    local enemies = game.enemies
    for i=1, #enemies do
        enemies[i]:update()
    end

    -- Check for collisions
    for i = 1, #enemies do
        local enemy = game.enemies[i]
        if check_collision(player, enemy) then
            game.done = true
        end
    end

    if not game.done then
        local goal = game.goal
        if check_collision(player, goal) then
            move_to_clear_position(goal)

            -- Add an enemy
            local horizontal = coin_flip()
            local vx = horizontal and 1 or 0
            local vy = (not horizontal) and 1 or 0
            local direction = coin_flip() and 1 or -1
            local enemy = enemy.create(vx * direction, vy * direction)
            move_to_clear_position(enemy)
            enemies[#enemies + 1] = enemy
        end
    end
end

-- Rendering
function draw_object(e)
    local x = e.x
    local y = -e.y
    local dx = e.width / 2
    local dy = e.height / 2
    rectfill(round(x - dx), round(y - dy), round(x + dx), round(y + dy), e.color)
end

function _draw()
    cls()

    -- Background
    camera(-system.width / 2, -system.height / 2)
    rectfill(-50, -50, 50, 50, colors.dark_blue)

    -- Entities
    local enemies = game.enemies
    for i = 1, #enemies do
        draw_object(enemies[i])
    end

    draw_object(game.goal)

    -- TODO: Ghost
    if not game.done then
        draw_object(game.player)
    end

    camera()
    color(colors.white)
    print("score: " .. #game.enemies)

    if debug then
        color(colors.white)
        for i = 1, #debug_lines do print(debug_lines[i]) end
    end
end
