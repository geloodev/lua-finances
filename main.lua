-- libs
Tick = require("lib.tick")
Object = require("lib.classic")

--ui
UIManager = require("modules.ui.ui_manager")
require("modules.ui.components.shape")
require("modules.ui.components.rectangle")
require("modules.ui.components.circle")

function love.load()
	UIManager.setColorTheme("kanagawa")
	print("BackgroundColor: ", love.graphics.getBackgroundColor())
	objList = {}
end

function love.update(dt)
	table.insert(
		objList,
		Circle(math.random(0, love.graphics.getWidth()), 0, 4)
	)

	for _, obj in ipairs(objList) do
		obj:update(dt)
	end
end

function love.draw()
	for _, obj in ipairs(objList) do
		obj:draw()
	end
end