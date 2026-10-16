-- Shared vector dice artwork for the composer and its contextual roll menu.
local gui = require("gui.lua");
local M = {};
M.faces = {4, 6, 8, 10, 12, 20, 100, "F"};
M.paths = {
    [4] = "M10 0 L20 20 L0 20 Z M10 0 L10 13 L20 20 M10 13 L0 20",
    [6] = "M10 0 L20 5 L20 15 L10 20 L0 15 L0 5 Z M0 5 L10 10 L20 5 M10 10 L10 20",
    [8] = "M10 0 L20 10 L10 20 L0 10 Z M0 10 L20 10 M10 0 L10 20",
    [10] = "M10 0 L20 8 L16 20 L4 20 L0 8 Z M10 0 L10 13 L20 8 M10 13 L16 20 M10 13 L4 20 M10 13 L0 8",
    [12] = "M10 0 L20 7 L16 20 L4 20 L0 7 Z M10 5 L16 9 L14 15 L6 15 L4 9 Z M10 0 L10 5 M20 7 L16 9 M16 20 L14 15 M4 20 L6 15 M0 7 L4 9",
    [20] = "M10 0 L20 5 L20 15 L10 20 L0 15 L0 5 Z M10 0 L5 12 L15 12 Z M5 12 L0 5 M5 12 L0 15 M15 12 L20 5 M15 12 L20 15 M5 12 L10 20 L15 12",
    [100] = "M10 0 C16 0 20 4 20 10 C20 16 16 20 10 20 C4 20 0 16 0 10 C0 4 4 0 10 0 Z M10 0 L5 5 L0 10 L5 15 L10 20 L15 15 L20 10 L15 5 Z M5 5 L15 5 L15 15 L5 15 Z M0 10 L20 10 M10 0 L10 20"
};
function M.draw(parent, face, x, y, size, color)
    local path = gui.newPath();
    path.parent, path.align = parent, "none";
    path.left, path.top, path.width, path.height = x, y, size, size;
    path.mode, path.data = "stretch", M.paths[face] or M.paths[6];
    path.color, path.strokeColor, path.strokeSize, path.hitTest = "transparent", color or "#BDBDBD", 1, false;
    return path;
end
return M;
