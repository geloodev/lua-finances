local M = {}
local sqlite3 = require("lsqlite3")
local db_file_path = "db/db.sqlite3"
local create_tables_query_path = "db/create_tables_query.txt"

function M.start()
	db, code, err = sqlite3.open(db_file_path)
	if not db then
		return "Error opening database. Code: " .. tostring(code) .. " Error: " .. tostring(err)
	end

	local query = love.filesystem.read(create_tables_query_path)
	local result = db:exec(query)
	if result ~= sqlite3.OK then
		return "Error creating tables. Code: " .. tostring(result)
	end

	return "Database started successfully."
end

function M.close()
	local result = db:close()
	if result ~= sqlite3.OK then
		return "Error closing database. Code: " .. tostring(result)
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
