local M = {}

local pallete = {
    background = {31, 31, 40},
    foreground = {220, 215, 186}
}

function M.getBackground()
    return pallete.background
end

function M.getForeground()
    return pallete.foreground
end

return M