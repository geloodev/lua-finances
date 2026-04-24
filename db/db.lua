local M = {}
local sqlite3 = require("lsqlite3")
local db_file_path = "db/db.sqlite3"

db, err = sqlite3.open(db_file_path)
if not db then
	print("Error opening database: ", tostring(err))
end

function M.close()
	db:close()
end

function M.create_tables()
	local sql = [[
        CREATE TABLE IF NOT EXISTS accounts (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL
        );
    ]]
	db:exec(sql)
end

function M.delete_db_file()
	local success, err = os.remove(db_file_path)
	if success then
		print("Database file '" .. db_file_path .. "' deleted successfully.")
	else
		print("Error on deletion of database file '" .. db_file_path .. "': " .. tostring(err))
	end
end

function M.execute_query(query, values)
	local stmt = db:prepare(query)
	local err

	if values then
		local bind_result = stmt:bind_names(values)
		if bind_result ~= sqlite3.OK then
			err = "Error running bind_names."
		end
	end

	local result = {}
	for row in stmt:nrows() do
		table.insert(result, row)
	end

	if #result == 0 then
		result = nil
	elseif result[1] == nil then
		result = result[0]
	end

	stmt:finalize()
	return result, err
end

return M
