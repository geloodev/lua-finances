local M = {}
local Database = require("modules.database_manager")

function M.get_all_accounts()
	return Database.execute_query("SELECT * FROM accounts")
end

function M.get_account_by_name(name)
	local query = "SELECT name FROM accounts WHERE name = " .. name
	--local values = { name = name }
	return Database.execute_query(query)
end

function M.create_account(name)
	local query = "INSERT INTO accounts (name) values (?)"
	local values = { name = name }
	Database.execute_query(query, values)
end

function M.delete_account(name)
	local query = "DELETE FROM accounts WHERE name = ?"
	local values = { name = name }
	Database.execute_query(query, values)
end

return M
