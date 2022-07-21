const std = @import("std");
const c = @cImport({
    @cInclude("SDL.h");
});


const TURN_RATE: f32 = std.math.pi * 2.0;
const THRUST_VEL = 500;
const PLAYER_MAX_VEL = 400;
const PLAYER_MIN_VEL = 0;
const BULLET_VEL = 500;

const dt: f32 = 1.0 / 144.0;

const Renderer = struct {
    sdl_renderer: c.SDL_Renderer,
};

const Point = struct {
    x: f32,
    y: f32,
};


const Player = struct {
    pos: Point,
    rotation: Point,
    vel: Point,
};



pub fn add(a: Point, b: Point) Point {
    return .{
        .x = a.x + b.x,
        .y = a.y + b.y,
    };
}


pub fn sub(a: Point, b: Point) Point {
    return .{
        .x = a.x - b.x,
        .y = a.y - b.y,
    };
}


pub fn scale(p: Point, scalar: f32) Point {
    return .{
        .x = p.x * scalar,
        .y = p.y * scalar,
    };
}


const KeyState = struct {
  is_down: bool,
  was_down: bool,
};

var Keys: [1024]KeyState = .{.{.is_down = false, .was_down = false}} ** 1024;

pub fn is_down(key: c.SDL_Scancode) bool {
  return Keys[key].is_down;
}

pub fn was_down(key: c.SDL_Scancode) bool {
  return Keys[key].was_down;
}

pub fn came_down(key: c.SDL_Scancode) bool {
  return is_down(key) and !was_down(key);
}








const Bullet = struct {
    pos: Point,
    vel: Point,
    lifetime: f32,
};

const Game = struct {
    frame: usize,
    player: Player,
    bullets: std.ArrayList(Bullet),
};


pub fn draw_player(renderer: *c.SDL_Renderer) void {
    var p1: Point = .{.x=0, .y=0};
    var p2: Point = .{.x=0, .y=0};
    var p3: Point = .{.x=0, .y=0};
    var perp_rotation: Point = .{.x=0, .y=0};

    perp_rotation.x = game.player.rotation.y;
    perp_rotation.y = -game.player.rotation.x;

    p1 = add(game.player.pos, sub(scale(perp_rotation, 6), scale(game.player.rotation, 5)));
    p2 = sub(sub(game.player.pos, scale(perp_rotation, 6)), scale(game.player.rotation, 5));
    p3 = add(game.player.pos, scale(game.player.rotation, 15));


    _ = c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, c.SDL_ALPHA_OPAQUE);
    _ = c.SDL_RenderDrawLine(renderer, @floatToInt(c_int, p1.x), @floatToInt(c_int, p1.y), @floatToInt(c_int, p2.x), @floatToInt(c_int, p2.y));
    _ = c.SDL_RenderDrawLine(renderer, @floatToInt(c_int, p2.x), @floatToInt(c_int, p2.y), @floatToInt(c_int, p3.x), @floatToInt(c_int, p3.y));
    _ = c.SDL_RenderDrawLine(renderer, @floatToInt(c_int, p3.x), @floatToInt(c_int, p3.y), @floatToInt(c_int, p1.x), @floatToInt(c_int, p1.y));


    if(is_down(c.SDL_SCANCODE_UP) and ((game.frame >> 1) & 0x1) == 1) {

        var flame_p1 = sub(sub(p1, (scale(game.player.rotation, 2))), scale(perp_rotation, 3));
        var flame_p2 = add(sub(p2, (scale(game.player.rotation, 2))), scale(perp_rotation, 3));
        var flame_p3 = sub(game.player.pos, (scale(game.player.rotation, 10)));
        
        _ = c.SDL_RenderDrawLine(renderer, @floatToInt(c_int, flame_p1.x), @floatToInt(c_int, flame_p1.y), @floatToInt(c_int, flame_p2.x), @floatToInt(c_int, flame_p2.y));
        _ = c.SDL_RenderDrawLine(renderer, @floatToInt(c_int, flame_p2.x), @floatToInt(c_int, flame_p2.y), @floatToInt(c_int, flame_p3.x), @floatToInt(c_int, flame_p3.y));
        _ = c.SDL_RenderDrawLine(renderer, @floatToInt(c_int, flame_p3.x), @floatToInt(c_int, flame_p3.y), @floatToInt(c_int, flame_p1.x), @floatToInt(c_int, flame_p1.y));
    }
}

pub fn draw_bullets(renderer: *c.SDL_Renderer) void {
    _ = c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, c.SDL_ALPHA_OPAQUE);
    for (game.bullets.items) |b| {
        _ = c.SDL_RenderDrawPoint(renderer, @floatToInt(c_int, b.pos.x), @floatToInt(c_int, b.pos.y));       
    }
}



var game: Game = Game{
    .frame = 0,
    .bullets = undefined,
    .player = Player{
        .pos = .{
            .x = 200,
            .y = 200
        },
        .rotation = .{
            .x = 0,
            .y = 1
        },
        .vel = .{
            .x = 0,
            .y = 0
        }
    }
};


pub fn main() anyerror!void {
    _ = c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_EVENTS);
    defer c.SDL_Quit();

    var window = c.SDL_CreateWindow("asteroidz", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, 640, 400, 0);
    defer c.SDL_DestroyWindow(window);

    var renderer = c.SDL_CreateRenderer(window, 0, c.SDL_RENDERER_PRESENTVSYNC);
    defer c.SDL_DestroyRenderer(renderer);

    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer {
        _ = gpa.deinit();
    }
    game.bullets = std.ArrayList(Bullet).init(gpa.allocator());
    defer game.bullets.deinit();

    mainloop: while (true) {

        // std.debug.print("{d}\r", .{game.frame});
        
        //update keymap
        for (Keys) |*key| {
            key.*.was_down = key.is_down;
        }

        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :mainloop,
                c.SDL_KEYDOWN => {
                    var scancode = sdl_event.key.keysym.scancode;
                    // std.debug.print("{d}", .{scancode});
                    Keys[scancode].was_down = Keys[scancode].is_down;
                    Keys[scancode].is_down = true;
                },
                c.SDL_KEYUP => {
                    var scancode = sdl_event.key.keysym.scancode;
                    Keys[scancode].was_down = Keys[scancode].is_down;
                    Keys[scancode].is_down = false;
                },
                else => {},
            }
        }
        
        
        if(is_down(c.SDL_SCANCODE_ESCAPE)) {
            break :mainloop;
        }

        if(is_down(c.SDL_SCANCODE_RIGHT)) {
            var new_rotation = Point {
                .x = (game.player.rotation.x * std.math.cos(TURN_RATE * dt)) - (game.player.rotation.y * std.math.sin(TURN_RATE * dt)),
                .y = (game.player.rotation.x * std.math.sin(TURN_RATE * dt)) + (game.player.rotation.y * std.math.cos(TURN_RATE * dt)),
            };

            game.player.rotation = new_rotation;
        }

        if(is_down(c.SDL_SCANCODE_LEFT)) {
            var new_rotation = Point {
                .x = (game.player.rotation.x * std.math.cos(-TURN_RATE * dt)) - (game.player.rotation.y * std.math.sin(-TURN_RATE * dt)),
                .y = (game.player.rotation.x * std.math.sin(-TURN_RATE * dt)) + (game.player.rotation.y * std.math.cos(-TURN_RATE * dt)),
            };
            game.player.rotation = new_rotation;
            // const normal = std.math.sqrt(player.rotation.x * player.rotation.x + player.rotation.y * player.rotation.y);
        }


        if(is_down(c.SDL_SCANCODE_UP)) {
            game.player.vel = add(game.player.vel, scale(game.player.rotation, THRUST_VEL * dt));
        }

        game.player.pos = add(game.player.pos, scale(game.player.vel, dt));


        if(came_down(c.SDL_SCANCODE_SPACE)){
            var new_bullet: Bullet = .{
                .pos = add(game.player.pos, scale(game.player.rotation, 15)),
                .vel = scale(game.player.rotation, 7),
                .lifetime = 5.0,
            };
            try game.bullets.append(new_bullet);
        }


        var i: usize = 0;
        while(i < game.bullets.items.len) {
            var b = game.bullets.items[i];
            game.bullets.items[i].pos = add(b.pos, b.vel);
            game.bullets.items[i].lifetime -= 0.1;

            if (b.lifetime <= 0) {
                _ = game.bullets.swapRemove(i);
            } else {
                i += 1;
            }
        }

        _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
        _ = c.SDL_RenderClear(renderer);

        draw_player(renderer.?);
        draw_bullets(renderer.?);

        c.SDL_RenderPresent(renderer);
        game.frame += 1;
    }
}
