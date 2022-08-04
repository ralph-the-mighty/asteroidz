const std = @import("std");


pub const sdl_path = "C:\\lib\\SDL2-2.0.22\\";
pub const sdl_ttf_lib_path = "C:\\Odin\\vendor\\sdl2\\ttf\\";
pub const sdl_ttf_source_path = "C:\\lib\\SDL_ttf-release-2.20.0";
 

pub const SCREEN_WIDTH = 640;
pub const SCREEN_HEIGHT = 480;

// values in pixels (or radians) per second
pub const TURN_RATE: f32 = std.math.pi * 2.0;
pub const THRUST_VEL = 500;
pub const PLAYER_MAX_VEL = 400;
pub const PLAYER_MIN_VEL = 0;
pub const BULLET_VEL = 500;
pub const BULLET_LIFETIME = 1;

pub const fonts_path = "assets\\fonts\\";

