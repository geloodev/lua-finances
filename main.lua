--local db = require("db/db")
local ui = require("ui")
local account_controller = require("account_controller")

account, err = account_controller.get_account_by_name("picpay")
if account then
	print("Type: " .. type(account))
	print(string.format("Id: %s | Name: %s", account.id, account.name))
else
	print("Account not found, error: ", err)
end

--[[
while input ~= 0 do
	input = ui.start_menu()
	if input == 1 then
		local data, error = account_controller.get_all_accounts()
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