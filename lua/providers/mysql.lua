require("mysqloo")

-- Configuration
-- MySQL connnection settings
local mysql_host		= '127.0.0.1'
local mysql_port		= 3306
local mysql_user		= 'username'
local mysql_pass		= 'password'
local mysql_database	= 'database'
-- Table settings
local mysql_pointstable	= 'PlayerPSPoints'
local mysql_itemstable	= 'PlayerPSItems'




-- END OF CONFIGURATION. DO NOT CHANGE ANYTHING BELOW UNLESS YOU KNOW WHAT YOU'RE DOING.
-- Connect to database using configuration
local db = mysqloo.connect(mysql_host, mysql_user, mysql_pass, mysql_database, mysql_port)
-- Create our queue variable. Used to queue up queries when connection fails.
-- Each item is a table with two items- the query string and callback to run on success with returned data
local queue = {}

-- The 64-bit Steam ID which bots start from. Each additional bot adds 1 to the Steam ID.
local bot_starting_steamid = 90071996842377216

-- When we connect to the database
function db:onConnected()
	print("[MySQL] INFO: PointShop- Connected to database!")
	-- Iterate through queued queries in correct order
	for key, value in ipairs(queue) do
		query(value[1], value[2])
	end
	-- Empty queue
	queue = {}
end

-- When connection to the database fails. err is a string containing the error message.
function db:onConnectionFailed(err)
	print("[MySQL] ERROR: PointShop- Failed to connect to database.")
	print("[MySQL] ERROR: " .. err)
end

-- Now that our database response functions have been made, connect to the database.
db:connect()


--[[
	Our query function. Two arguments:
		sql_string- string containing the query to run
		success_callback- the function to run when the query successfully runs. 
			Passes returned data to it.
			Optional
	Data returned is a table. 
		Each index is a row (numeric). Starts from 1
		Each value is a sub-table.
			Each index is the column name (e.g. playerID)
			Each value is the column value (e.g. 1234)
--]]
function query(sql_string, success_callback)
	-- Create a query object by running our query
	local q = db:query(sql_string)
	
	-- Queue early bird queries which try to run before the database object is made
	if q == nil then
		table.insert(queue, {sql_string, success_callback})
		return
	end
	
	-- Function to run if query runs successfully
	function q:onSuccess(data)
		if success_callback ~= nil then
			success_callback(data)
		end
	end
	
	-- Function to run if query throws error
	function q:onError(err)
		-- If we've disconnected from the database
		if db:status() == mysqloo.DATABASE_NOT_CONNECTED then
			-- Add the query to the queue and try to connect
			table.insert(queue, {sql_string, success_callback})
			db:connect()
		end
		print("[MySQL] ERROR: PointShop- Query produced error.")
		print("[MySQL] ERROR: PointShop- " .. sql_string)
		print("[MySQL] ERROR: PointShop- " .. err)
	end
	
	q:start()
end



-- Pointshop functions
-- Create our PointShop Tables if they don't already exist

query(
	"CREATE TABLE IF NOT EXISTS " .. mysql_pointstable .. " (" ..
		"playerSteam64 BIGINT UNSIGNED NOT NULL, " .. 
		"playerPoints INT UNSIGNED NOT NULL DEFAULT 0, " ..
		"CONSTRAINT pk_playerpspoints_steam64 PRIMARY KEY(playerSteam64)" .. 
	")ENGINE=INNODB CHARACTER SET utf8 COLLATE utf8_general_ci"
, nil)

query(
	"CREATE TABLE IF NOT EXISTS " .. mysql_itemstable ..  " (" .. 
		"playerSteam64 BIGINT UNSIGNED NOT NULL, " ..
		"itemName VARCHAR(50) NOT NULL, " ..
		"itemEquipped BOOLEAN NOT NULL DEFAULT FALSE, " ..
		"itemModifications VARCHAR(512), " ..
		"CONSTRAINT pk_playerpsitems UNIQUE(playerSteam64, itemName), " ..
		"CONSTRAINT fk_playerpsitems_steam64 FOREIGN KEY(playerSteam64) " ..
			"REFERENCES PlayerPSPoints(playerSteam64) " .. 
			"ON UPDATE CASCADE ON DELETE CASCADE " .. 
	")ENGINE=INNODB CHARACTER SET utf8 COLLATE utf8_general_ci"
, nil)

PROVIDER.Fallback = 'FuckOff'

--[[
	Checks if a given 64-bit Steam ID is invalid
	If it is nil, we are in singleplayer.
	If it is greater than or equal to bot_starting_steamid, the player is a bot.
--]]
function IsInvalidSteamID64(steam64id)
	if steam64id == nil then return true end
	steam64id = tonumber(steam64id) 
	if steam64id == nil or steam64id >= bot_starting_steamid then return true end
	return false
end


--[[
	Gets the player's points and items, then sends them to the callback
 		ply = the player to get points & items for
		callback = the function to send the points and items to
	After successful retrieval of player data, callback function is sent points and items table
--]]
function PROVIDER:GetData(ply, callback)
	local playerid = ply:SteamID64()
	if IsInvalidSteamID64(playerid) then callback(0, {}) return end
	
	-- Query the player's points first
	local sql_string = "SELECT playerPoints FROM " .. mysql_pointstable .. " WHERE playerSteam64 = " .. playerid
	query(sql_string, function(data)
		-- If no rows are returned, this is a new player
		if data[1] == nil then
			-- Add the player to the player points table
			local sql_string = "INSERT INTO " .. mysql_pointstable .. "(playerSteam64, playerPoints) VALUES(" .. playerid .. ",0)"
			query(sql_string, function(data)
				-- Once the player has been successfully added to the table, run the callback with no points or items
				callback(0, {})
			end)
			return 
		end
		
		local points = data[1].playerPoints
		
		-- Now get the player's items
		local sql_string = "SELECT itemName, itemEquipped, itemModifications FROM " .. mysql_itemstable .. " WHERE playerSteam64 = " .. playerid
		query(sql_string, function(data)
			local items = {}
			-- Loop through returned rows and extract item data from each row
			for key, row in pairs(data) do
				-- Check if modifications is nil. If not, it's a JSON string.
				local modifications = {}
				if row.itemModifications != nil then modifications = util.JSONToTable(row.itemModifications) end
				-- Add the item to the player's items table, along with modifications and if it's equipped
				items[row.itemName] = {Modifiers = modifications, Equipped = row.itemEquipped}
			end
			
			-- Run the passed function with the player's points and items
			callback(points, items)
		end)
	end)
end


--[[
	Updates all of a player's items and their points. Really inefficient.
		Points- must be a positive number. Floats will be truncated.
		Items- must be a table. Empty tables can be sent (no items).
		Callback- callback to run on success or failure of saving item
--]]
function PROVIDER:SetData(ply, points, items, callback)
	print("[POINTSHOP] DEBUG: Saving data for " .. ply:GetName() .. ", points: " .. points .. ", items: " .. util.TableToJSON(items))
	local playerid = ply:SteamID64()
	if IsInvalidSteamID64(playerid) then callback(ply) return end
	
	-- Validate points
	points = math.floor(tonumber(points))
	if points == nil or points < 0 then callback(ply) return end
	
	-- Enforce items being a table. If no items, an empty table should be sent (doesn't equate to nil)
	if type(items) != "table" then callback(ply) return end
	
	-- Update points first. We should only update items if the first query was successful.
	-- Otherwise, a player could end up losing an item, but not gaining the points from selling it.
	local sql_string = "UPDATE " .. mysql_pointstable .. " SET playerPoints = " .. points .. " WHERE playerSteam64 = " .. playerid
	query(sql_string, function(data)
		-- Now remove all stored items for the player
		local sql_string = "DELETE FROM " .. mysql_itemstable .. " WHERE playerSteam64 = " .. playerid
		query(sql_string, function(data)
			-- Check if the player has any items to insert
			if next(items) == nil then callback(ply) return end
			
			-- Create the base string for the query
			local sql_string = "INSERT INTO " .. mysql_itemstable .. "(playerSteam64, itemName, itemEquipped, itemModifications) VALUES "
			
			-- Iterate through the items in the table and append them to the query
			local previous_items = false
			for item, properties in pairs(items) do
				-- Add a comma at the end of the previous item
				if previous_items then sql_string = sql_string .. ", "
				else previous_items = true end
				
				local equipped = "FALSE"
				if properties.Equipped then equipped = "TRUE" end
				
				local modifications = "NULL"
				if type(properties.Modifiers) == "table" and next(properties.Modifiers) ~= nil then 
					modifications = "'" .. util.TableToJSON(properties.Modifiers) .. "'" 
				end
				
				-- Append the item to the query
				sql_string = sql_string .. "(" .. playerid .. ", '" .. item .. "', " .. equipped .. ", " .. modifications .. ")"
			end
			
			-- Run the insert query to add the items
			query(sql_string, function(data)
				callback(ply)
			end)
		end)
	end)
end
