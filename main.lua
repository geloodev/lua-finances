-- libs
Tick = require("lib.tick")
Object = require("lib.classic")

-- modules
Database = require("modules.database_manager")
UI = require("modules.ui.ui_manager")
require("modules.ui.components.shape")
require("modules.ui.components.rectangle")
require("modules.ui.components.circle")

function love.load()
	package.cpath = package.cpath .. ";./lib/?.dll"
	database_message = Database.start()
	UI.setColorTheme("kanagawa")
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
	love.graphics.print(database_message, 10, 10)
end