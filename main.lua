local ui = require("ui")
local account_controller = require("account/account_controller")

while input ~= 0 do
	input = ui.start_menu()
	if input == 1 then
		for account in account_controller.get_all_accounts() do
			print(account.name)
		end
		print("accounts type: " .. type(accounts))
	elseif input == 0 then
		print("BYE BYE...")
	end
end
