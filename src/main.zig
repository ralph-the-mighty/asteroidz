const std = @import("std");
const c = @cImport({
    @cInclude("SDL.h");
    @cInclude("SDL_ttf.h");
});

const SCREEN_WIDTH = 640;
const SCREEN_HEIGHT = 480;

// values in pixels (or radians) per second
const TURN_RATE: f32 = std.math.pi * 2.0;
const THRUST_VEL = 500;
const PLAYER_MAX_VEL = 400;
const PLAYER_MIN_VEL = 0;
const BULLET_VEL = 500;
const BULLET_LIFETIME = 1;


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

var keys: [1024]KeyState = .{.{.is_down = false, .was_down = false}} ** 1024;

pub fn is_down(key: c.SDL_Scancode) bool {
  return keys[key].is_down;
}

pub fn was_down(key: c.SDL_Scancode) bool {
  return keys[key].was_down;
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
    running: bool,
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



pub fn point_in_polygon(p: Point, vertices: []const Point) bool {
    var odd = false;
    var j: usize = vertices.len - 1;
    var i: usize = 0;
    // TODO(JOSH): check for and skip points that are colinear with a side?
    //check for horizontal cast intersection
    while(i < vertices.len) : (i += 1) {
        if((vertices[i].y < p.y and vertices[j].y >= p.y) or (vertices[j].y < p.y and vertices[i].y >= p.y)) {
            // calculate intersection
            if (vertices[i].x + (p.y - vertices[i].y) / (vertices[j].y - vertices[i].y) * (vertices[j].x - vertices[i].x) < p.x) {
                odd = !odd;
            } 
        }
        j = i;
    }
    return odd;
}


pub fn wrap_position(pos: *Point) void {
    if(pos.x < 0) {
        pos.*.x += SCREEN_WIDTH;
    }
    if(pos.y < 0) {
        pos.*.y += SCREEN_HEIGHT;
    }

    if(pos.x >= SCREEN_WIDTH) {
        pos.x -= SCREEN_WIDTH;
    }
    if(pos.y >= SCREEN_HEIGHT) {
        pos.y -= SCREEN_HEIGHT;
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


pub fn update(dt: f32) !void {
       
    if(is_down(c.SDL_SCANCODE_ESCAPE)) {
        running = false;
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
    wrap_position(&game.player.pos);


    if(came_down(c.SDL_SCANCODE_SPACE)){
        var new_bullet: Bullet = .{
            .pos = add(game.player.pos, scale(game.player.rotation, 15)),
            .vel = scale(game.player.rotation, BULLET_VEL),
            .lifetime = BULLET_LIFETIME,
        };
        try game.bullets.append(new_bullet);
    }

    //update bullets
    {
        var i = game.bullets.items.len;
        while(i > 0 ) {
            i -= 1;
            var b = game.bullets.items[i];
            game.bullets.items[i].pos = add(b.pos, scale(b.vel, dt));
            wrap_position(&game.bullets.items[i].pos);
            game.bullets.items[i].lifetime -= dt;

            if (b.lifetime <= 0) {
                _ = game.bullets.swapRemove(i);
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


    //update asteroids
    for(game.asteroids.items) |*a| {
        a.*.pos = add(a.pos, scale(a.vel, dt));
        wrap_position(&a.*.pos);

        a.*.rot += a.rot_vel * dt;
        if (a.rot >= 2 * std.math.pi) {
            a.*.rot -= 2 * std.math.pi;
        }
    }

     //collision detection
    //TODO: fix bug where two bullets destroy the same asteroid at the same time
    var a_index = game.asteroids.items.len;
    while (a_index > 0) {
        a_index -= 1;
        var a = game.asteroids.items[a_index];
        var transformed_points: [a.vertices.len]Point = undefined;
        for(a.vertices) |vertex, i| {
            transformed_points[i] = transform(a.rot, a.pos, vertex);
        }
        var b_index = game.bullets.items.len;
        while (b_index > 0) {
            b_index -= 1;
            var b = game.bullets.items[b_index];
            if (point_in_polygon(b.pos, transformed_points[0..transformed_points.len])) {
            if (a.gen > 0) {
                try gen_asteroid(a.pos, a.size * 0.75, a.gen - 1);
                try gen_asteroid(a.pos, a.size * 0.75, a.gen - 1);
            }
            // explosion(b.pos);
            _ = game.asteroids.swapRemove(a_index);
            _ = game.bullets.swapRemove(b_index);
            // game.score += 10;
            // play_sound_effect(1, 5);
            break;
          }
        }
      }
}


pub fn process_events() void {
    //update keymap
    for (keys) |*key| {
        key.*.was_down = key.is_down;
    }

    var sdl_event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&sdl_event) != 0) {
        switch (sdl_event.type) {
            c.SDL_QUIT => {
                running = false;
                return;
            },
            c.SDL_KEYDOWN => {
                var scancode = sdl_event.key.keysym.scancode;
                keys[scancode].was_down = keys[scancode].is_down;
                keys[scancode].is_down = true;
            },
            c.SDL_KEYUP => {
                var scancode = sdl_event.key.keysym.scancode;
                keys[scancode].was_down = keys[scancode].is_down;
                keys[scancode].is_down = false;
            },
            else => {},
        }
    }
}


var game: Game = Game{
    .frame = 0,
    .running = true,
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
var running = true;

var minecraft: ?*c.TTF_Font = null;
var arial: ?*c.TTF_Font = null;


pub fn render_text(renderer: *c.SDL_Renderer, text: [*:0]const u8, x: i32, y: i32) !void {

    var text_surface = c.TTF_RenderUTF8_Solid(minecraft, text, c.SDL_Color{.r=255, .g=255, .b=255, .a=255});
    defer c.SDL_FreeSurface(text_surface);
    
    var text_texture = c.SDL_CreateTextureFromSurface(renderer, text_surface);
    defer c.SDL_DestroyTexture(text_texture);
    //free the text texture!!

    var destination_rect: c.SDL_Rect = .{
        .x = @mod(x, SCREEN_WIDTH),
        .y = @mod(y, SCREEN_HEIGHT),
        .w = 0,
        .h = 0,
    };


    _ = c.SDL_QueryTexture(text_texture, null, null, &destination_rect.w, &destination_rect.h);

    var res = c.SDL_RenderCopy(renderer, text_texture, null, &destination_rect);
    if(res < 0) {
        std.debug.print("failed to render copy! {s}\n", .{c.SDL_GetError()});
    }
}


pub fn main() anyerror!void {
    _ = c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_EVENTS);
    defer c.SDL_Quit();

    var window = c.SDL_CreateWindow("asteroidz", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, SCREEN_WIDTH, SCREEN_HEIGHT, 0);
    defer c.SDL_DestroyWindow(window);

    var renderer = c.SDL_CreateRenderer(window, 0, c.SDL_RENDERER_PRESENTVSYNC);
    defer c.SDL_DestroyRenderer(renderer);

    if(c.TTF_Init() == -1) {
        std.debug.print("TTF failed to init!\n", .{});
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer {
        _ = gpa.deinit();
    }
    game.bullets = std.ArrayList(Bullet).init(gpa.allocator());
    defer game.bullets.deinit();

    game.asteroids = std.ArrayList(Asteroid).init(gpa.allocator());
    defer game.asteroids.deinit();

    rand = std.rand.DefaultPrng.init(0).random();

    try gen_asteroids(10);




    minecraft = c.TTF_OpenFont("C:\\Users\\JoshPC\\projects\\Random_Projects\\zig\\asteroidz\\minecraft.ttf\x00", 16);
    arial = c.TTF_OpenFont("C:\\Users\\JoshPC\\projects\\Random_Projects\\zig\\asteroidz\\arial.ttf\x00", 16);

    if(minecraft == null) {
        std.debug.print("Could not open font!\n", .{});
        std.debug.print("{s}\n", .{c.SDL_GetError()});
    }

    try render_text(renderer.?, "Ai! Laurie lantar lassi surinen!", 100, 200);


    const seconds_per_tick = 1.0 / @intToFloat(f32, c.SDL_GetPerformanceFrequency());
    const dt: f32 = 1.0 / 144.0;
    var current_time: f32 = @intToFloat(f32, c.SDL_GetPerformanceCounter()) * seconds_per_tick;
    var accumulator: f32 = 0.0;

    while (running) {
        var new_time: f32 = @intToFloat(f32, c.SDL_GetPerformanceCounter()) * seconds_per_tick;
        var frame_time = new_time - current_time;
        current_time = new_time;
        accumulator += frame_time;
 
        while(accumulator >= dt) {
            process_events();
            try update(dt);
            accumulator -= dt;
        }

        _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
        _ = c.SDL_RenderClear(renderer);
        

        draw_player(renderer.?);
        try render_text(renderer.?, "Player One", @floatToInt(i32, game.player.pos.x - 40), @floatToInt(i32, game.player.pos.y - 30));
        draw_bullets(renderer.?);
        draw_asteroids(renderer.?);

        c.SDL_RenderPresent(renderer);

        game.frame += 1;
    }
}