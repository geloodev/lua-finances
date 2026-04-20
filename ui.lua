local M = {}

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

return M
