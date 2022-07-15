const std = @import("std");
const c = @cImport({
    @cInclude("SDL.h");
});


const TURN_RATE: f32 = std.math.pi * 2.0;
const THRUST_VEL = 500;
const PLAYER_MAX_VEL = 400;
const PLAYER_MIN_VEL = 0;
const BULLET_VEL = 500;

const dt = 1.0 / 60.0;



const Point = struct {
    x: f32,
    y: f32,
};


const Player = struct {
    pos: Point,
    rotation: Point,
    vel: Point,
};

var player = Player{
    .pos = .{
        .x = 200,
        .y = 200
    },
    .rotation = .{
        .x = 1,
        .y = 0
    },
    .vel = .{
        .x = 0,
        .y = 0
    }
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

//TODO: figure out if this is dot product or the other one
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






pub fn draw_player(renderer: c.SDL_Renderer) void {
    _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, c.SDL_ALPHA_OPAQUE);
    _ = c.SDL_RenderDrawLine(renderer, 0, 0, 100, 100);

    var p1 = Point;
    var p2 = Point;
    var p3 = Point;
    var perp_rotation = Point;

    perp_rotation.x = player.rotation.y;
    perp_rotation.y = player.rotation.y;

    p1 = add(player.pos, sub(scale(perp_rotation, 6), scale(perp_rotation * 5)));
    p2 = sub(player.pos, sub(scale(perp_rotation, 6), scale(perp_rotation * 5)));
    p3 = add(player.pos, scale(perp_rotation, 15));


    // const c.SDL_Point
    // _ = c.SDL_RenderDrawLines(renderer, points, POINTS_COUNT);

    _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, c.SDL_ALPHA_OPAQUE);
    _ = c.SDL_RenderDrawLine(renderer, p1.x, p1.y, p2.x, p2.y);
    _ = c.SDL_RenderDrawLine(renderer, p2.x, p2.y, p3.x, p3.y);
    _ = c.SDL_RenderDrawLine(renderer, p3.x, p3.y, p1.x, p1.y);
}



pub fn main() anyerror!void {
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    var window = c.SDL_CreateWindow("hello gamedev", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, 640, 400, 0);
    defer c.SDL_DestroyWindow(window);

    var renderer = c.SDL_CreateRenderer(window, 0, c.SDL_RENDERER_PRESENTVSYNC);
    defer c.SDL_DestroyRenderer(renderer);



    var frame: usize = 0;
    mainloop: while (true) {
        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :mainloop,
                c.SDL_KEYDOWN => {
                    var scancode = sdl_event.key.keysym.scancode;
                    std.debug.print("KEYDOWN: {d}!\n", .{scancode});
                    Keys[scancode].was_down = Keys[scancode].is_down;
                    Keys[scancode].is_down = true; 
                },
                c.SDL_KEYUP => {
                    var scancode = sdl_event.key.keysym.scancode;
                    std.debug.print("KEYUP: {d}!\n", .{scancode});
                    Keys[scancode].was_down = Keys[scancode].is_down;
                    Keys[scancode].is_down = false; 
                },
                else => {},
            }
        }


        if(is_down(79)) { //right
            std.debug.print("Right!\n", .{});
            player.rotation = Point {
                .x = player.rotation.x * std.math.cos(TURN_RATE * dt) - player.rotation.y * std.math.sin(TURN_RATE * dt),
                .y = player.rotation.x * std.math.sin(TURN_RATE * dt) + player.rotation.y * std.math.cos(TURN_RATE * dt),
            };
        }

        if(is_down(80)) { //left
            std.debug.print("Left!\n", .{});
            player.rotation = Point {
                .x = player.rotation.x * std.math.cos(-TURN_RATE * dt) - player.rotation.y * std.math.sin(-TURN_RATE * dt),
                .y = player.rotation.x * std.math.sin(-TURN_RATE * dt) + player.rotation.y * std.math.cos(-TURN_RATE * dt),
            };
        }

        if(is_down(81)) { //down
      
        
        // if linalg.length(game.player.vel) > PLAYER_MAX_VEL {
        //   game.player.vel = linalg.normalize(game.player.vel) * PLAYER_MAX_VEL;
        // }
      
            std.debug.print("Down!\n", .{});
        }

        if(is_down(82)) { //up
            player.vel = add(player.vel, scale(player.rotation, THRUST_VEL * dt));
            std.debug.print("Up!\n", .{});
        }

        player.pos = add(player.pos, scale(player.vel, dt));



        _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
        _ = c.SDL_RenderClear(renderer);

        var p1: Point = .{.x=0, .y=0};
        var p2: Point = .{.x=0, .y=0};
        var p3: Point = .{.x=0, .y=0};
        var perp_rotation: Point = .{.x=0, .y=0};

        perp_rotation.x = player.rotation.y;
        perp_rotation.y = -player.rotation.x;

        p1 = add(player.pos, sub(scale(perp_rotation, 6), scale(perp_rotation, 5)));
        p2 = sub(sub(player.pos, scale(perp_rotation, 6)), scale(perp_rotation, 5));
        p3 = add(player.pos, scale(player.rotation, 15));



        _ = c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, c.SDL_ALPHA_OPAQUE);
        _ = c.SDL_RenderDrawLine(renderer, @floatToInt(c_int, p1.x), @floatToInt(c_int, p1.y), @floatToInt(c_int, p2.x), @floatToInt(c_int, p2.y));
        _ = c.SDL_RenderDrawLine(renderer, @floatToInt(c_int, p2.x), @floatToInt(c_int, p2.y), @floatToInt(c_int, p3.x), @floatToInt(c_int, p3.y));
        _ = c.SDL_RenderDrawLine(renderer, @floatToInt(c_int, p3.x), @floatToInt(c_int, p3.y), @floatToInt(c_int, p1.x), @floatToInt(c_int, p1.y));

        // _ = c.SDL_RenderDrawLine(renderer, 200, 200, 250, 250);
        // _ = c.SDL_RenderDrawLine(renderer, 250, 250, 300, 200);
        // _ = c.SDL_RenderDrawLine(renderer, 300, 200, 200, 200);


        c.SDL_RenderPresent(renderer);
        frame += 1;
    }
}
