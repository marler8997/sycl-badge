const std = @import("std");
const cart = @import("cart-api");

const StartMenu = struct {
    seed: u32,
    start_pressed: bool = false,
};
const Play = struct {
    pos: u3,
    grid: [5][2]bool,
    left_pressed: bool = false,
    right_pressed: bool = false,
    a_pressed: bool = false,
    b_pressed: bool = false,
    start_pressed: bool = false,
};
const Win = struct {
    frame: u32 = 0,
    start_pressed: bool = false,
};
const Mode = union(enum) {
    start_menu: StartMenu,
    play: Play,
    win: Win,
};
const global = struct {
    pub var mode = Mode{
        .start_menu = .{ .seed = 0 },
    };
};

const Button = enum {
    start,
    a, b,
    up, down, left, right,
    pub fn isDown(self: Button) bool {
        switch (self) {
            .start => return cart.controls.start,
            .a => return cart.controls.a,
            .b => return cart.controls.b,
            .up => return cart.controls.up,
            .down => return cart.controls.down,
            .left => return cart.controls.left,
            .right => return cart.controls.right,
        }
    }
};

// Used to tell if a button is "triggered".
// Prevents the "down" state from triggering multiple events.
fn isButtonTriggered(
    button: Button,
    released_state_ref: *bool,
) bool {
    const pressed = button.isDown();
    if (released_state_ref.*) {
        if (pressed) released_state_ref.* = false;
        return pressed;
    } else {
        if (!pressed) {
            released_state_ref.* = true;
        }
        return false;
    }
}

fn clear() void {
    cart.neopixels.* =  .{
        .{ .r = 0, .g = 0, .b = 0 },
        .{ .r = 0, .g = 0, .b = 0 },
        .{ .r = 0, .g = 0, .b = 0 },
        .{ .r = 0, .g = 0, .b = 0 },
        .{ .r = 0, .g = 0, .b = 0 },
    };
}

export fn start() void {
    clear();
}

export fn update() void {
    switch (global.mode) {
        .start_menu => updateStartMenu(&global.mode.start_menu),
        .play => updatePlayMode(&global.mode.play),
        .win => updateWinMode(&global.mode.win),
    }
}

const on = cart.NeopixelColor{ .r = 1, .g = 1, .b = 1 };
const off = cart.NeopixelColor{ .r = 0, .g = 0, .b = 0 };

const on_selected = cart.NeopixelColor{ .r = 1, .g = 1, .b = 0 };
const off_selected = cart.NeopixelColor{ .r = 0, .g = 0, .b = 1 };

fn newGame(seed: u32) void {
    clear();
    global.mode = Mode{
        .play = .{
            .pos = 2,
            .grid = [5][2]bool{
                [2]bool{ false, true },
                [2]bool{ false, true },
                [2]bool{ false, true },
                [2]bool{ false, true },
                [2]bool{ false, true },
            },
        },
    };

    var rand = std.rand.DefaultPrng.init(seed);
    for (0 .. 100) |_| {
        var buf: [1]u8 = undefined;
        rand.fill(&buf);
        rotate(&global.mode.play.grid, @intCast(buf[0] % 5));
    }
}

fn updateStartMenu(start_menu: *StartMenu) void {
    start_menu.seed +%= 1;
    if (isButtonTriggered(.start, &start_menu.start_pressed)) {
        const seed = start_menu.seed;
        newGame(seed);
        return;
    }
    cart.neopixels[(start_menu.seed +% 4) % 5] = off;
    cart.neopixels[start_menu.seed % 5] = on;
}

fn updatePlayMode(play: *Play) void {

    if (isButtonTriggered(.a, &play.a_pressed)) {
        rotate(&play.grid, play.pos);
    } else if (isButtonTriggered(.b, &play.b_pressed)) {
        for (0 .. 3) |_| {
            rotate(&play.grid, play.pos);
        }
    } else if (isButtonTriggered(.right, &play.right_pressed)) {
        play.pos = (play.pos + 1) % 5;
    } else if (isButtonTriggered(.left, &play.left_pressed)) {
        play.pos = @intCast((@as(usize, play.pos) + 4) % 5);
    } else if (isButtonTriggered(.start, &play.start_pressed)) {
        clear();
        global.mode = Mode{ .start_menu = .{ .seed = 0 } };
    }

    var win = true;
    for (0 .. 5) |i| {
        if (!play.grid[i][1]) {
            win = false;
            break;
        }
    }

    if (win) {
        clear();
        global.mode = Mode{ .win = .{} };
        return;
    }

    for (0 .. 5) |i| {
        if (play.pos == i or i == ((play.pos + 1) % 5)) {
            cart.neopixels[i] = if (play.grid[i][1]) on_selected else off_selected;
        } else {
            cart.neopixels[i] = if (play.grid[i][1]) on else off;
        }
    }
}

fn updateWinMode(win: *Win) void {
    if (isButtonTriggered(.start, &win.start_pressed)) {
        const seed = win.frame;
        newGame(seed);
        return;
    }

    win.frame +%= 1;
    cart.neopixels[(win.frame +% 4) % 5] = off;
    cart.neopixels[win.frame % 5] = on_selected;
}

fn rotate(grid: *[5][2]bool, pos: u3) void {
    const t = grid[pos][0];
    const pos2 =  (pos + 1) % 5;
    grid[pos][0] = grid[pos][1];
    grid[pos][1] = grid[pos2][1];
    grid[pos2][1] = grid[pos2][0];
    grid[pos2][0] = t;
}
