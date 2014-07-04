-- net hooks

net.Receive('PS_BuyItem', function(length, ply)
	ply:PS_BuyItem(net.ReadString())
end)

net.Receive('PS_SellItem', function(length, ply)
	ply:PS_SellItem(net.ReadString())
end)

net.Receive('PS_EquipItem', function(length, ply)
	ply:PS_EquipItem(net.ReadString())
end)

net.Receive('PS_HolsterItem', function(length, ply)
	ply:PS_HolsterItem(net.ReadString())
end)

net.Receive('PS_ModifyItem', function(length, ply)
	ply:PS_ModifyItem(net.ReadString(), net.ReadTable())
end)

-- player to player

net.Receive('PS_SendPoints', function(length, ply)
	local other = net.ReadEntity()
	local points = math.Clamp(net.ReadInt(32), 0, 1000000)
	
	if PS.Config.CanPlayersGivePoints and other and points and IsValid(other) and other:IsPlayer() and ply and IsValid(ply) and ply:IsPlayer() and ply:PS_HasPoints(points) then
		ply:PS_TakePoints(points)
		ply:PS_Notify('You gave ', other:Nick(), ' ', points, ' of your ', PS.Config.PointsName, '.')
		
		other:PS_GivePoints(points)
		other:PS_Notify(ply:Nick(), ' gave you ', points, ' of their ', PS.Config.PointsName, '.')
	end
end)

-- admin points

net.Receive('PS_GivePoints', function(length, ply)
	local other = net.ReadEntity()
	local points = net.ReadInt(32)
	
	if not PS.Config.AdminCanAccessAdminTab and not PS.Config.SuperAdminCanAccessAdminTab then return end
	
	local admin_allowed = PS.Config.AdminCanAccessAdminTab and ply:IsAdmin()
	local super_admin_allowed = PS.Config.SuperAdminCanAccessAdminTab and ply:IsSuperAdmin()
	
	if (admin_allowed or super_admin_allowed) and other and points and IsValid(other) and other:IsPlayer() then
		other:PS_GivePoints(points)
		other:PS_Notify(ply:Nick(), ' gave you ', points, ' ', PS.Config.PointsName, '.')
	end
end)

net.Receive('PS_TakePoints', function(length, ply)
	local other = net.ReadEntity()
	local points = net.ReadInt(32)
	
	if not PS.Config.AdminCanAccessAdminTab and not PS.Config.SuperAdminCanAccessAdminTab then return end
	
	local admin_allowed = PS.Config.AdminCanAccessAdminTab and ply:IsAdmin()
	local super_admin_allowed = PS.Config.SuperAdminCanAccessAdminTab and ply:IsSuperAdmin()
	
	if (admin_allowed or super_admin_allowed) and other and points and IsValid(other) and other:IsPlayer() then
		other:PS_TakePoints(points)
		other:PS_Notify(ply:Nick(), ' took ', points, ' ', PS.Config.PointsName, ' from you.')
	end
end)

net.Receive('PS_SetPoints', function(length, ply)
	local other = net.ReadEntity()
	local points = net.ReadInt(32)
	
	if not PS.Config.AdminCanAccessAdminTab and not PS.Config.SuperAdminCanAccessAdminTab then return end
	
	local admin_allowed = PS.Config.AdminCanAccessAdminTab and ply:IsAdmin()
	local super_admin_allowed = PS.Config.SuperAdminCanAccessAdminTab and ply:IsSuperAdmin()
	
	if (admin_allowed or super_admin_allowed) and other and points and IsValid(other) and other:IsPlayer() then
		other:PS_SetPoints(points)
		other:PS_Notify(ply:Nick(), ' set your ', PS.Config.PointsName, ' to ', points, '.')
	end
end)

-- admin items

net.Receive('PS_GiveItem', function(length, ply)
	local other = net.ReadEntity()
	local item_id = net.ReadString()
	
	if not PS.Config.AdminCanAccessAdminTab and not PS.Config.SuperAdminCanAccessAdminTab then return end
	
	local admin_allowed = PS.Config.AdminCanAccessAdminTab and ply:IsAdmin()
	local super_admin_allowed = PS.Config.SuperAdminCanAccessAdminTab and ply:IsSuperAdmin()
	
	if (admin_allowed or super_admin_allowed) and other and item_id and PS.Items[item_id] and IsValid(other) and other:IsPlayer() and not other:PS_HasItem(item_id) then
		other:PS_GiveItem(item_id)
	end
end)

net.Receive('PS_TakeItem', function(length, ply)
	local other = net.ReadEntity()
	local item_id = net.ReadString()
	
	if not PS.Config.AdminCanAccessAdminTab and not PS.Config.SuperAdminCanAccessAdminTab then return end
	
	local admin_allowed = PS.Config.AdminCanAccessAdminTab and ply:IsAdmin()
	local super_admin_allowed = PS.Config.SuperAdminCanAccessAdminTab and ply:IsSuperAdmin()
	
	if (admin_allowed or super_admin_allowed) and other and item_id and PS.Items[item_id] and IsValid(other) and other:IsPlayer() and other:PS_HasItem(item_id) then
		-- holster it first without notificaiton
		other.PS_Items[item_id].Equipped = false
	
		local ITEM = PS.Items[item_id]
		ITEM:OnHolster(other)
		other:PS_TakeItem(item_id)
	end
end)

-- hooks

local KeyToHook = {
	F1 = "ShowHelp",
	F2 = "ShowTeam",
	F3 = "ShowSpare1",
	F4 = "ShowSpare2",
	None = "ThisHookDoesNotExist"
}

hook.Add(KeyToHook[PS.Config.ShopKey], "PS_ShopKey", function(ply)
	ply:PS_ToggleMenu()
end)

hook.Add('PlayerSpawn', 'PS_PlayerSpawn', function(ply) ply:PS_PlayerSpawn() end)
hook.Add('PlayerDeath', 'PS_PlayerDeath', function(ply) ply:PS_PlayerDeath() end)
hook.Add('PlayerInitialSpawn', 'PS_PlayerInitialSpawn', function(ply) ply:PS_PlayerInitialSpawn() end)
hook.Add('PlayerDisconnected', 'PS_PlayerDisconnected', function(ply) ply:PS_PlayerDisconnected() end)

hook.Add('PlayerSay', 'PS_PlayerSay', function(ply, text)
	if string.len(PS.Config.ShopChatCommand) > 0 then
		if string.sub(text, 0, string.len(PS.Config.ShopChatCommand)) == PS.Config.ShopChatCommand then
			ply:PS_ToggleMenu()
			return ''
		end
	end
end)

-- ugly networked strings

util.AddNetworkString('PS_Items')
util.AddNetworkString('PS_Points')
util.AddNetworkString('PS_BuyItem')
util.AddNetworkString('PS_SellItem')
util.AddNetworkString('PS_EquipItem')
util.AddNetworkString('PS_HolsterItem')
util.AddNetworkString('PS_ModifyItem')
util.AddNetworkString('PS_SendPoints')
util.AddNetworkString('PS_GivePoints')
util.AddNetworkString('PS_TakePoints')
util.AddNetworkString('PS_SetPoints')
util.AddNetworkString('PS_GiveItem')
util.AddNetworkString('PS_TakeItem')
util.AddNetworkString('PS_AddClientsideModel')
util.AddNetworkString('PS_RemoveClientsideModel')
util.AddNetworkString('PS_SendClientsideModels')
util.AddNetworkString('PS_SendNotification')
util.AddNetworkString('PS_ToggleMenu')

-- console commands

concommand.Add(PS.Config.ShopCommand, function(ply, cmd, args)
	ply:PS_ToggleMenu()
end)

concommand.Add('ps_clear_points', function(ply, cmd, args)
	if IsValid(ply) then return end -- only allowed from server console
	
	for _, ply in pairs(player.GetAll()) do
		ply:PS_SetPoints(0)
	end
	
	sql.Query("DELETE FROM playerpdata WHERE infoid LIKE '%PS_Points%'")
end)

concommand.Add('ps_clear_items', function(ply, cmd, args)
	if IsValid(ply) then return end -- only allowed from server console
	
	for _, ply in pairs(player.GetAll()) do
		ply.PS_Items = {}
		ply:PS_SendItems()
	end
	
	sql.Query("DELETE FROM playerpdata WHERE infoid LIKE '%PS_Items%'")
end)

-- version checker

PS.CurrentBuild = 0
PS.LatestBuild = 0
PS.BuildOutdated = false

local function CompareVersions()
	if PS.CurrentBuild < PS.LatestBuild then
		MsgN('PointShop is out of date!')
		MsgN('Local version: ' .. PS.CurrentBuild .. ', Latest version: ' .. PS.LatestBuild)

		PS.BuildOutdated = true
	else
		MsgN('PointShop is on the latest version.')
	end
end

function PS:CheckVersion()
	if file.Exists('data/pointshop_build.txt', 'GAME') then
		PS.CurrentBuild = tonumber(file.Read('data/pointshop_build.txt', 'GAME')) or 0
	end

	local url = self.Config.Branch .. 'data/pointshop_build.txt'
	http.Fetch( url,
		function( content ) -- onSuccess
			PS.LatestBuild = tonumber( content ) or 0
			CompareVersions()
		end,
		function(failCode) -- onFailure
			MsgN('PointShop couldn\'t check version.')
			MsgN(url, ' returned ', failCode)
		end
	)
end

-- data providers
PS.Provider = nil
PS.SavingQueue = {} -- used to make sure save requests start/finish in order

function PS:LoadDataProviders()
	local filename = "providers/" .. self.Config.DataProvider .. ".lua"
	if not file.Exists(filename, "LUA") then
		print("[POINTSHOP] Information: The data provider you have chosen in lua/sh_config.lua cannot be found. Change the value of PS.Config.DataProvider.")
		error("[POINTSHOP] CRITICAL ERROR- Failed to find data provider \""..filename.."\". Stopping pointshop.")
	end
	
	PROVIDER = {}
	include(filename)
	PS.Provider = PROVIDER
end

function PS:GetPlayerData(ply, callback)
	if PS.Provider == nil or not self.Config.DataProvider then
		Error('PointShop: Missing provider. Update ALL files when there is an update.')
		return
	end
	
	PS.Provider:GetData(ply, function(points, items)
		callback(PS:ValidatePoints(tonumber(points)), PS:ValidateItems(items))
	end)
end

-- Function to call to save all the player's data at once. REALLY INEFFICIENT.
function PS:SetPlayerData(ply, points, items)
	if PS.Provider == nil or not self.Config.DataProvider then
		Error('PointShop: Missing provider. Update ALL files when there is an update.')
	end
	
	-- If there are no items in the queue, then we need to start running our save queue since it would've stopped
	local emptyqueue = false
	
	if not PS.SavingQueue.ply then
		-- Create the queue if it doesn't exist
		PS.SavingQueue.ply = {}
		emptyqueue = true
	elseif next(PS.SavingQueue.ply) == nil then emptyqueue = true end
	
	-- Add item to queue
	table.insert(PS.SavingQueue.ply, {Points = points, Items = items})
	
	-- Start running queue if it's empty
	if emptyqueue then RunSaveQueue(ply) end
end

-- Tells the provider to try to save the next item in the queue
function RunSaveQueue(ply)
	-- Make sure the player didn't leave between queueing up the save and actually saving it
	-- Will result in the save being lost, but we need the player still connected to get their 64-bit SteamID
	if not ply:IsValid() then PS.SavingQueue.ply = {} return end
	
	local index, value = next(PS.SavingQueue.ply)
	-- If we've reached the end of the queue, stop and wait for another item to be added
	if index == nil then return end
	
	local points = value.Points
	local items = value.Items
	PS.Provider:SetData(ply, points, items, PlayerDataSaved)
end


-- Called when an item in the save queue has been saved or failed to be saved
function PlayerDataSaved(ply)
	-- If the player disconnected then empty the saving queue for them
	if not ply:IsValid() then PS.SavingQueue.ply = {} return end
	
	-- Get the item in the queue we've finished saving
	local index, value = next(PS.SavingQueue.ply)
	if index == nil then 
		Error("[POINTSHOP] Attempted to remove an item from a player's save queue when there are no items in the queue!")
	end
	
	-- Remove the item from the queue and run the next item in the queue
	table.remove(PS.SavingQueue.ply, index)
	RunSaveQueue(ply)
end