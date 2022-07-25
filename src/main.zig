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


pub fn rotate(angle: f32, point: Point) Point {
    return Point{
        .x = (point.x * std.math.cos(angle)) - (point.y * std.math.sin(angle)),
        .y = (point.x * std.math.sin(angle)) + (point.y * std.math.cos(angle)),
    };
}


pub fn transform(angle: f32, origin: Point, point: Point) Point {
    return add(origin, rotate(angle, point));
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

const Asteroid = struct {
    pos: Point,
    vertices: [5]Point,
    vel: Point,

    size: f32,
    rot: f32,
    rot_vel: f32,
    gen: i32,
};

const Game = struct {
    frame: usize,
    player: Player,
    bullets: std.ArrayList(Bullet),
    asteroids: std.ArrayList(Asteroid),
};

pub fn float_range(min: f32, max: f32) f32 {
    return min + ((max - min) * rand.float(f32));
}

pub fn gen_asteroid(pos: Point, size: f32, gen: i32) !void {
    var a: Asteroid = .{
        .pos = pos,
        .size = size,
        .gen = gen,
        .vel = .{
            .x = float_range(-50, 50),
            .y = float_range(-50, 50),
        },
        .rot_vel = float_range(-5, 5),
        .rot = 0,
        .vertices = undefined,
    };

    var i: usize = 0;
    while(i < 5) : (i += 1) {
        var angle = @intToFloat(f32, i) * (2 * std.math.pi) / 5;
        var distance = float_range(a.size / 4, a.size);
        a.vertices[i] = .{
            .x = std.math.cos(angle) * distance,
            .y = std.math.sin(angle) * distance
        };
    }

    // adjust vertices so that the center of gravity 
    // lies on the origin of the asteroid's coordinate system
    var sum: Point = .{.x = 0, .y = 0};
    var f: f32 = 0;
    var twicearea: f32 = 0;
    var j: usize = 0;
    while (j < 5) : (j += 1) {
        var p1 = a.vertices[j];
        var p2 = a.vertices[(j + 1) % 5];
        f = (p1.x * p2.y) - (p2.x * p1.y);
        sum.x += (p1.x + p2.x) * f;
        sum.y += (p1.y + p2.y) * f;
        twicearea += f;
    }


    var center: Point = .{
        .x = sum.x / (twicearea * 3),
        .y = sum.y / (twicearea * 3),
    };
    var k: usize = 0;
    while (k < 5) : (k += 1) {
        a.vertices[k] = sub(a.vertices[k], center);
    }

    try game.asteroids.append(a);

}


pub fn gen_asteroids(count: usize) !void {
  var i: usize = 0;
  while (i < count) : (i += 1) {
    try gen_asteroid(.{
        .x = @intToFloat(f32, i) * 50, 
        .y = @intToFloat(f32, i) * 50
    }, 50, 2);
  }
}

pub fn draw_marker(renderer: *c.SDL_Renderer, x: c_int, y: c_int) void {
            _ = c.SDL_RenderDrawPoint(renderer, x, y); 
            _ = c.SDL_RenderDrawPoint(renderer, x, y + 1); 
            _ = c.SDL_RenderDrawPoint(renderer, x, y - 1); 
            _ = c.SDL_RenderDrawPoint(renderer, x + 1, y); 
            _ = c.SDL_RenderDrawPoint(renderer, x - 1, y);
}

pub fn draw_asteroids(renderer: *c.SDL_Renderer) void {

    for (game.asteroids.items) |a| {
        _ = c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, c.SDL_ALPHA_OPAQUE);
        var j: usize = 0;
        while (j < 5 - 1) : (j += 1) {
            var start = transform(a.rot, a.pos, a.vertices[j]);
            var end = transform(a.rot, a.pos, a.vertices[j + 1]);
            _ = c.SDL_RenderDrawLine(renderer, 
                                    @floatToInt(c_int, start.x),
                                    @floatToInt(c_int, start.y),
                                    @floatToInt(c_int, end.x),
                                    @floatToInt(c_int, end.y));
        }
        var start = transform(a.rot, a.pos, a.vertices[j]);
        var end = transform(a.rot, a.pos, a.vertices[0]);
        _ = c.SDL_RenderDrawLine(renderer, 
            @floatToInt(c_int, start.x),
            @floatToInt(c_int, start.y),
            @floatToInt(c_int, end.x),
            @floatToInt(c_int, end.y));
            
        if(debug_mode) {
            _ = c.SDL_SetRenderDrawColor(renderer, 0xff, 0x00, 0x00, c.SDL_ALPHA_OPAQUE);
            var x = @floatToInt(c_int, a.pos.x);
            var y = @floatToInt(c_int, a.pos.y);
            draw_marker(renderer, x, y);
        }
    }
}

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


    if((is_down(c.SDL_SCANCODE_UP) or is_down(c.SDL_SCANCODE_K)) and ((game.frame >> 1) & 0x1) == 1) {

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
    .asteroids = undefined,
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

var rand: std.rand.Random = undefined;
var debug_mode = false;


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

    game.asteroids = std.ArrayList(Asteroid).init(gpa.allocator());
    defer game.asteroids.deinit();


    rand = std.rand.DefaultPrng.init(0).random();

    // try gen_asteroids(10);


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

        if(is_down(c.SDL_SCANCODE_RIGHT) or is_down(c.SDL_SCANCODE_L)) {
            var new_rotation = Point {
                .x = (game.player.rotation.x * std.math.cos(TURN_RATE * dt)) - (game.player.rotation.y * std.math.sin(TURN_RATE * dt)),
                .y = (game.player.rotation.x * std.math.sin(TURN_RATE * dt)) + (game.player.rotation.y * std.math.cos(TURN_RATE * dt)),
            };

            game.player.rotation = new_rotation;
        }

        if(is_down(c.SDL_SCANCODE_LEFT) or is_down(c.SDL_SCANCODE_H)) {
            var new_rotation = Point {
                .x = (game.player.rotation.x * std.math.cos(-TURN_RATE * dt)) - (game.player.rotation.y * std.math.sin(-TURN_RATE * dt)),
                .y = (game.player.rotation.x * std.math.sin(-TURN_RATE * dt)) + (game.player.rotation.y * std.math.cos(-TURN_RATE * dt)),
            };
            game.player.rotation = new_rotation;
            // const normal = std.math.sqrt(player.rotation.x * player.rotation.x + player.rotation.y * player.rotation.y);
        }


        if(is_down(c.SDL_SCANCODE_UP) or is_down(c.SDL_SCANCODE_K)) {
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

        {
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
        }


        if(came_down(c.SDL_SCANCODE_G)) {
            try gen_asteroid(.{
                .x = rand.float(f32) * 640, 
                .y = rand.float(f32) * 400,
            }, 50, 2);
        }


        if(came_down(c.SDL_SCANCODE_D)) {
            debug_mode = !debug_mode;
        }



        for(game.asteroids.items) |*a| {
            a.*.pos = add(a.pos, scale(a.vel, dt));
            a.*.rot += a.rot_vel * dt;
            if (a.rot >= 2 * std.math.pi) {
                a.*.rot -= 2 * std.math.pi;
            }
        }

        _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
        _ = c.SDL_RenderClear(renderer);

        draw_player(renderer.?);
        draw_bullets(renderer.?);
        draw_asteroids(renderer.?);

        c.SDL_RenderPresent(renderer);
        game.frame += 1;
    }
}
