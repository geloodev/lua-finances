local M = {}

function M.setColorTheme(theme)
	local theme = require("modules.ui.themes." .. theme)
	local r, g, b = love.math.colorFromBytes(theme.getBackground())
	love.graphics.setBackgroundColor(r, g, b)
end

return M
