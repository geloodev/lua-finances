local M = {}

function love.load()
	x = 100
end

function love.update(dt)
	if love.keyboard.isDown("right") then
		x = x + 150 * dt
	elseif love.keyboard.isDown("left") then
		x = x - 150 * dt
	end
end

function love.draw()
	love.graphics.rectangle("line", x, 50, 100, 150)
end

--[[
function M.start_menu()
	figlet("gelo finances")
	print("CHOOSE AN OPTION: ")
	print("1 - ACCOUNTS")
	print("0 - EXIT")
	return io.read("n")
end

function figlet(text, font)
	font = font or "standard"
	local command = string.format('figlet -f %s "%s"', font, text)
	local handle = io.popen(command, "r")

	if handle then
		local output = handle:read("*all")
		handle:close()
		print(output)
	else
		io.stderr:write("Error: Could not execute figlet.")
		io.stderr:write(string.format("Attempted command: %s\n", command))
	end
end
--]]

return M
