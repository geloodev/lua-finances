local M = {}
local db = require("db/db")

function M.get_all_accounts()
	local data, err = db.execute_query("SELECT name FROM accounts")
	if data then
		return data
	end
end

function M.create_account(name)
	local query = "INSERT INTO accounts (name) values (?)"
	local values = { name = name }
	db.execute_query(query, values)
end

function M.delete_account(name)
	local query = "DELETE FROM accounts WHERE name = ?"
	local values = { name = name }
	db.execute_query(query, values)
end

return M
