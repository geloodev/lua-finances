--local Database = require("modules/database")
local UI = require("modules/ui")
--local AccountController = require("modules/account_controller")

--[[
while input ~= 0 do
	input = UI.start_menu()
	if input == 1 then
		local data, error = AccountController.get_all_accounts()
		if data then
			for _, account in ipairs(data) do
				print(account.name)
			end
		else 
			print("Error: ", error)
		end
	elseif input == 0 then
		print("BYE BYE...")
	end
end
--]]