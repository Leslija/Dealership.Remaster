Framework 					= nil
TriggerEvent(Config.Framework.SHAREDOBJECT, function(obj) Framework = obj end)

local cooldown = {}
local vrp_ready = true
function SendWebhookMessage(webhook,message)
	if webhook ~= nil and webhook ~= "" then
		PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({content = message}), { ['Content-Type'] = 'application/json' })
	end
end

Citizen.CreateThread(function()
	Wait(5000)
	if Config.createTable == true then
		MySQL.Async.execute([[
			CREATE TABLE IF NOT EXISTS `dealership_balance` (
				`id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
				`dealership_id` VARCHAR(50) NOT NULL COLLATE 'latin1_swedish_ci',
				`user_id` VARCHAR(50) NOT NULL COLLATE 'latin1_swedish_ci',
				`description` VARCHAR(255) NOT NULL COLLATE 'latin1_swedish_ci',
				`name` VARCHAR(50) NOT NULL COLLATE 'latin1_swedish_ci',
				`amount` INT(11) UNSIGNED NOT NULL,
				`type` BIT(1) NOT NULL COMMENT '0 = income | 1 = expense',
				`isbuy` BIT(1) NOT NULL,
				`date` INT(11) UNSIGNED NOT NULL,
				PRIMARY KEY (`id`) USING BTREE
			)
			COLLATE='latin1_swedish_ci'
			ENGINE=InnoDB;			

			CREATE TABLE IF NOT EXISTS `dealership_hired_players` (
				`dealership_id` VARCHAR(50) NOT NULL COLLATE 'utf8mb4_general_ci',
				`user_id` VARCHAR(50) NOT NULL COLLATE 'utf8mb4_general_ci',
				`profile_img` VARCHAR(255) NOT NULL DEFAULT 'https://amar.amr.org.br/packages/trustir/exclusiva/img/user_placeholder.png' COLLATE 'utf8mb4_general_ci',
				`banner_img` VARCHAR(255) NOT NULL DEFAULT 'https://www.bossecurity.com/wp-content/uploads/2018/10/night-time-drive-bys-1024x683.jpg' COLLATE 'utf8mb4_general_ci',
				`name` VARCHAR(50) NOT NULL COLLATE 'utf8mb4_general_ci',
				`jobs_done` INT(11) UNSIGNED NOT NULL DEFAULT '0',
				`timer` INT(11) UNSIGNED NOT NULL,
				PRIMARY KEY (`dealership_id`, `user_id`) USING BTREE
			)
			COLLATE='utf8mb4_general_ci'
			ENGINE=InnoDB;


			CREATE TABLE IF NOT EXISTS `dealership_owner` (
				`dealership_id` VARCHAR(50) NOT NULL COLLATE 'utf8mb4_general_ci',
				`user_id` VARCHAR(50) NOT NULL COLLATE 'utf8mb4_general_ci',
				`name` VARCHAR(50) NOT NULL COLLATE 'utf8mb4_general_ci',
				`profile_img` VARCHAR(255) NOT NULL DEFAULT 'https://amar.amr.org.br/packages/trustir/exclusiva/img/user_placeholder.png' COLLATE 'utf8mb4_general_ci',
				`banner_img` VARCHAR(255) NOT NULL DEFAULT 'https://www.bossecurity.com/wp-content/uploads/2018/10/night-time-drive-bys-1024x683.jpg' COLLATE 'utf8mb4_general_ci',
				`stock` TEXT NOT NULL COLLATE 'utf8mb4_general_ci',
				`stock_prices` LONGTEXT NOT NULL COLLATE 'utf8mb4_general_ci',
				`stock_sold` TEXT NOT NULL COLLATE 'utf8mb4_unicode_ci',
				`money` INT(11) UNSIGNED NOT NULL DEFAULT '0',
				`total_money_spent` INT(11) UNSIGNED NOT NULL DEFAULT '0',
				`total_money_earned` INT(11) UNSIGNED NOT NULL DEFAULT '0',
				`timer` INT(11) UNSIGNED NOT NULL,
				PRIMARY KEY (`dealership_id`) USING BTREE
			)
			COLLATE='utf8mb4_general_ci'
			ENGINE=InnoDB;			

			CREATE TABLE IF NOT EXISTS `dealership_requests` (
				`id` INT(11) NOT NULL AUTO_INCREMENT,
				`dealership_id` VARCHAR(50) NOT NULL COLLATE 'utf8mb4_general_ci',
				`user_id` VARCHAR(50) NOT NULL COLLATE 'utf8mb4_general_ci',
				`vehicle` VARCHAR(50) NOT NULL COLLATE 'utf8mb4_general_ci',
				`plate` VARCHAR(50) NOT NULL COLLATE 'utf8mb4_general_ci',
				`request_type` INT(1) UNSIGNED NOT NULL DEFAULT '0' COMMENT '0 = sell reques t| 1 = buy request',
				`name` VARCHAR(50) NOT NULL COLLATE 'utf8mb4_general_ci',
				`price` INT(11) UNSIGNED NOT NULL,
				`status` INT(2) UNSIGNED NOT NULL DEFAULT '0' COMMENT '0 = waiting | 1 = in progress | 2 = finished | 3 = cancelled',
				PRIMARY KEY (`id`) USING BTREE,
				UNIQUE INDEX `request` (`user_id`, `vehicle`, `request_type`, `plate`) USING BTREE
			)
			COLLATE='utf8mb4_general_ci'
			ENGINE=InnoDB;			

			CREATE TABLE IF NOT EXISTS `dealership_stock` (
				`vehicle` VARCHAR(100) NOT NULL COLLATE 'latin1_swedish_ci',
				`amount` INT(11) UNSIGNED NOT NULL DEFAULT '0',
				PRIMARY KEY (`vehicle`) USING BTREE
			)
			COLLATE='latin1_swedish_ci'
			ENGINE=InnoDB;			
		]])
	end
	local sql = "UPDATE `dealership_requests` SET status = 0 WHERE status = 1";
	MySQL.Sync.execute(sql, {});
end)

-- Check low stocks
Citizen.CreateThread(function()
	Citizen.Wait(10000)
	while Config.clear_dealerships.active do
		local sql = "SELECT dealership_id, user_id, stock, timer FROM dealership_owner";
		local data = MySQL.Sync.fetchAll(sql, {});
		for k,v in pairs(data) do
			local arr_stock = json.decode(v.stock)
			local count_stock = tablelength(arr_stock)
			local count_items = tablelength(Config.dealership_types[Config.dealership_locations[v.dealership_id].type].vehicles)
			if count_stock < count_items*(Config.clear_dealerships.min_stock_variety/100) or getStockAmount(v.stock) < (Config.dealership_types[Config.dealership_locations[v.dealership_id].type].stock_capacity)*(Config.clear_dealerships.min_stock_amount/100) then
				if v.timer + (Config.clear_dealerships.cooldown*60*60) < os.time() then
					local sql = "DELETE FROM `dealership_owner` WHERE dealership_id = @dealership_id;DELETE FROM `dealership_requests` WHERE dealership_id = @dealership_id;DELETE FROM `dealership_hired_players` WHERE dealership_id = @dealership_id;DELETE FROM `dealership_balance` WHERE dealership_id = @dealership_id;";
					MySQL.Sync.execute(sql, {['@dealership_id'] = v.dealership_id});
					SendWebhookMessage(Config.webhook,Lang[Config.lang]['logs_lost_low_stock']:format(v.dealership_id,v.stock,os.date("%d/%m/%Y %H:%M:%S", v.timer),v.user_id..os.date("\n["..Lang[Config.lang]['logs_date'].."]: %d/%m/%Y ["..Lang[Config.lang]['logs_hour'].."]: %H:%M:%S")))
				end
			else
				local sql = "UPDATE `dealership_owner` SET timer = @timer WHERE dealership_id = @dealership_id";
				MySQL.Sync.execute(sql, {['timer'] = os.time(), ['@dealership_id'] = v.dealership_id});
			end
			Citizen.Wait(100)	
		end
		Citizen.Wait(1000*60*60) -- 60 minutos
	end
end)

-- Event to open the interface or open the buy request if no one own this dealership
RegisterServerEvent("lc_dealership:getData")
AddEventHandler("lc_dealership:getData",function(key)
	if vrp_ready then
		local source = source
        local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid
		if user_id then
			local owner_id = getDealershipOwner(key)
			if owner_id then
				-- Check if he is a owner
				if owner_id == user_id then
					openUI(source,key,false) -- Open UI as owner
				else
					local sql = "SELECT user_id FROM `dealership_hired_players` WHERE dealership_id = @dealership_id AND user_id = @user_id";
					local query = MySQL.Sync.fetchAll(sql, {['@dealership_id'] = key, ['@user_id'] = user_id});
					-- Check if he is a employee
					if query and query[1] then
						openUI(source,key,false) -- Open UI as employee
					else
						--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['already_has_owner'])
						TriggerClientEvent("Framework:Notify", source, "Cửa hàng xe này đã có chủ.", "error", 5000)

					end
				end
			else
				local sql = "SELECT dealership_id FROM `dealership_owner` WHERE user_id = @user_id";
				local query = MySQL.Sync.fetchAll(sql, {['@user_id'] = user_id});
				-- Check if he can buy this dealership
				if query and query[1] and #query >= Config.max_dealerships_per_player then
					--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['already_has_business'])
					TriggerClientEvent("Framework:Notify", source, "Bạn đã có một cửa hàng khác rồi !", "error", 5000)

				else
					TriggerClientEvent("lc_dealership:openRequest",source, Config.dealership_locations[key].buy_price) -- Open the interface buy request
				end
			end
		end
	end
end)

-- Return from interface buy request when player accept to buy the dealership
RegisterServerEvent("lc_dealership:buyDealership")
AddEventHandler("lc_dealership:buyDealership",function(key)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid
		local price = Config.dealership_locations[key].buy_price
		if tryPayment(source,price,Config.Framework.account_dealership) then
			local sql = "INSERT INTO `dealership_owner` (user_id,dealership_id,name,stock,stock_sold,stock_prices,timer) VALUES (@user_id,@dealership_id,@name,@stock,@stock_sold,@stock_prices,@timer);";
			MySQL.Sync.execute(sql, {['@dealership_id'] = key, ['@user_id'] = user_id, ['@name'] = getPlayerName(user_id), ['@stock'] = json.encode({}), ['@stock_sold'] = json.encode({}), ['@stock_prices'] = json.encode({}), ['@timer'] = os.time()});
			--TriggerClientEvent("lc_dealership:Notify",source,"sucesso",Lang[Config.lang]['businnes_bougth'])
			TriggerClientEvent("Framework:Notify", source, "Đã mua thành công", "success", 5000)

			SendWebhookMessage(Config.webhook,Lang[Config.lang]['logs_bought']:format(key,user_id..os.date("\n["..Lang[Config.lang]['logs_date'].."]: %d/%m/%Y ["..Lang[Config.lang]['logs_hour'].."]: %H:%M:%S")))
		else
			--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['insufficient_funds'])
			TriggerClientEvent("Framework:Notify", source, "Không đủ tiền", "error", 5000)

		end
	end
end)

RegisterServerEvent("lc_dealership:sellDealership")
AddEventHandler("lc_dealership:sellDealership",function(key)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid
		if isOwner(key,user_id) then
			TriggerClientEvent("lc_dealership:closeUI",source)
			giveMoney(source,Config.dealership_locations[key].sell_price,Config.Framework.account_dealership)
			local sql = "DELETE FROM `dealership_owner` WHERE dealership_id = @dealership_id;DELETE FROM `dealership_requests` WHERE dealership_id = @dealership_id;DELETE FROM `dealership_hired_players` WHERE dealership_id = @dealership_id;DELETE FROM `dealership_balance` WHERE dealership_id = @dealership_id;";
			MySQL.Sync.execute(sql, {['@dealership_id'] = key});
			--TriggerClientEvent("lc_dealership:Notify",source,"sucesso",Lang[Config.lang]['dealer_sold'])
			TriggerClientEvent("Framework:Notify", source, "Đã bán cửa hàng thành công", "success", 5000)

			SendWebhookMessage(Config.webhook,Lang[Config.lang]['logs_close']:format(key,user_id..os.date("\n["..Lang[Config.lang]['logs_date'].."]: %d/%m/%Y ["..Lang[Config.lang]['logs_hour'].."]: %H:%M:%S")))
		else
			--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['no_own_dealer'])
			TriggerClientEvent("Framework:Notify", source, "Bạn không phải chủ cửa hàng", "error", 5000)

		end
	end
end)

-- Open dealership as a customer
RegisterServerEvent("lc_dealership:openDealership")
AddEventHandler("lc_dealership:openDealership",function(key)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid
		if user_id then
			openUI(source,key,false,true)
		end
	end
end)

-- Owner clicked to start a vehicle import
local started_import = {}
RegisterServerEvent("lc_dealership:importVehicle")
AddEventHandler("lc_dealership:importVehicle",function(key,vehicle,amount)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid
		if user_id then
			local price = Config.dealership_types[Config.dealership_locations[key].type].vehicles[vehicle].price_to_owner
			local max_amount = Config.dealership_types[Config.dealership_locations[key].type].vehicles[vehicle].amount_to_owner
			local max_stock_vehicle = Config.dealership_types[Config.dealership_locations[key].type].vehicles[vehicle].max_stock
			local sql = "SELECT stock FROM `dealership_owner` WHERE dealership_id = @dealership_id";
			local query = MySQL.Sync.fetchAll(sql, {['@dealership_id'] = key});
			amount = tonumber(amount) or 0
			if hasStockSlots(query,key,amount) then
				if amount <= max_amount then
					local arr_stock = json.decode(query[1].stock)
					if not arr_stock[vehicle] then arr_stock[vehicle] = 0 end
					if arr_stock[vehicle] < max_stock_vehicle then
						if tryGetDealershipMoney(key,price*amount) then
							local veh_name = Config.dealership_types[Config.dealership_locations[key].type].vehicles[vehicle].name
							insertBalanceHistory(key,user_id,Lang[Config.lang]['balance_vehicle_import']:format(veh_name),price*amount,1,0)
							started_import[source] = true
							TriggerClientEvent("lc_dealership:startContract",source,vehicle,amount,false)
						else
							--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['insufficient_funds'])
							TriggerClientEvent("Framework:Notify", source, "Không đủ tiền", "error", 5000)

						end
					else
						---TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['max_stock_vehicle'])
						TriggerClientEvent("Framework:Notify", source, "Bạn đã đạt đến số lượng tối đa của chiếc xe này trong kho của mình", "error", 5000)

					end
				else
					TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['max_amount']:format(max_amount))
				end
			else
				TriggerClientEvent("Framework:Notify", source, "Hàng của đại lý đã đầy", "error", 5000)

				--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['stock_full'])
			end
		end
	end
end)

RegisterServerEvent("lc_dealership:finishImportVehicle")
AddEventHandler("lc_dealership:finishImportVehicle",function(key,vehicle,amount)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid
		if user_id then
			if started_import[source] then
				started_import[source] = nil
				local sql = "SELECT stock FROM `dealership_owner` WHERE dealership_id = @dealership_id";
				local query = MySQL.Sync.fetchAll(sql, {['@dealership_id'] = key});

				local arr_stock = json.decode(query[1].stock)
				if not arr_stock[vehicle] then arr_stock[vehicle] = 0 end
				arr_stock[vehicle] = arr_stock[vehicle] + amount

				local sql = "UPDATE `dealership_owner` SET stock = @stock WHERE dealership_id = @dealership_id";
				MySQL.Sync.execute(sql, {['@stock'] = json.encode(arr_stock), ['@dealership_id'] = key});

				local sql = "UPDATE `dealership_hired_players` SET jobs_done = jobs_done + 1 WHERE dealership_id = @dealership_id AND user_id = @user_id";
				MySQL.Sync.execute(sql, {['@dealership_id'] = key, ['@user_id'] = user_id});

				local price = Config.dealership_types[Config.dealership_locations[key].type].vehicles[vehicle].price_to_owner
				SendWebhookMessage(Config.webhook,Lang[Config.lang]['logs_finish_import']:format(key,vehicle,amount,price*amount,json.encode(arr_stock),user_id..os.date("\n["..Lang[Config.lang]['logs_date'].."]: %d/%m/%Y ["..Lang[Config.lang]['logs_hour'].."]: %H:%M:%S")))
			end
		end
	end
end)

-- Owner clicked to start a vehicle export
local started_export = {}
RegisterServerEvent("lc_dealership:exportVehicle")
AddEventHandler("lc_dealership:exportVehicle",function(key,vehicle,amount)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid
		if user_id then
			local max_amount = Config.dealership_types[Config.dealership_locations[key].type].vehicles[vehicle].amount_to_owner
			local sql = "SELECT stock FROM `dealership_owner` WHERE dealership_id = @dealership_id";
			local query = MySQL.Sync.fetchAll(sql, {['@dealership_id'] = key});
			amount = tonumber(amount) or 0
			if amount <= max_amount then
				local arr_stock = json.decode(query[1].stock)
				if not arr_stock[vehicle] then arr_stock[vehicle] = 0 end
				if arr_stock[vehicle] >= amount then
					started_export[source] = true
					TriggerClientEvent("lc_dealership:startContract",source,vehicle,amount,true)
				else
					--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['insufficient_stock'])
					TriggerClientEvent("Framework:Notify", source, "Không đủ hàng cho chiếc xe này", "error", 5000)

				end
			else
				TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['max_amount']:format(max_amount))
			end
		end
	end
end)

RegisterServerEvent("lc_dealership:finishExportVehicle")
AddEventHandler("lc_dealership:finishExportVehicle",function(key,vehicle,amount)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid
		if user_id then
			if started_export[source] then
				started_export[source] = nil
				local sql = "SELECT stock FROM `dealership_owner` WHERE dealership_id = @dealership_id";
				local query = MySQL.Sync.fetchAll(sql, {['@dealership_id'] = key});

				local arr_stock = json.decode(query[1].stock)
				if not arr_stock[vehicle] then arr_stock[vehicle] = 0 end
				arr_stock[vehicle] = arr_stock[vehicle] - amount
				if arr_stock[vehicle] == 0 then arr_stock[vehicle] = nil end -- Clear empty stock
				
				local sql = "UPDATE `dealership_owner` SET stock = @stock WHERE dealership_id = @dealership_id";
				MySQL.Sync.execute(sql, {['@stock'] = json.encode(arr_stock), ['@dealership_id'] = key});
				
				local price = Config.dealership_types[Config.dealership_locations[key].type].vehicles[vehicle].price_to_export
				local total_price = price*amount
				giveDealershipMoney(key,total_price)

				local sql = "UPDATE `dealership_hired_players` SET jobs_done = jobs_done + 1 WHERE dealership_id = @dealership_id AND user_id = @user_id";
				MySQL.Sync.execute(sql, {['@dealership_id'] = key, ['@user_id'] = user_id});

				local veh_name = Config.dealership_types[Config.dealership_locations[key].type].vehicles[vehicle].name
				insertBalanceHistory(key,user_id,Lang[Config.lang]['balance_vehicle_export']:format(veh_name),total_price,0,0)
				SendWebhookMessage(Config.webhook,Lang[Config.lang]['logs_finish_export']:format(key,vehicle,amount,total_price,json.encode(arr_stock),user_id..os.date("\n["..Lang[Config.lang]['logs_date'].."]: %d/%m/%Y ["..Lang[Config.lang]['logs_hour'].."]: %H:%M:%S")))
			end
		end
	end
end)

-- Set a custom price for a vehicle
RegisterServerEvent("lc_dealership:setPrice")
AddEventHandler("lc_dealership:setPrice",function(key,vehicle,price)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid
		if user_id then
			price = tonumber(price) or 0
			price = math.floor(price)
			if price > 0 and price < 99999999 then
				local sql = "SELECT stock_prices FROM `dealership_owner` WHERE dealership_id = @dealership_id AND user_id = @user_id";
				local query = MySQL.Sync.fetchAll(sql, {['@dealership_id'] = key, ['@user_id'] = user_id});
				if query and query[1] then
					local arr_stock = json.decode(query[1].stock_prices)
					arr_stock[vehicle] = price
					local sql = "UPDATE `dealership_owner` SET stock_prices = @stock_prices WHERE dealership_id = @dealership_id";
					MySQL.Sync.execute(sql, {['@dealership_id'] = key, ['@stock_prices'] = json.encode(arr_stock)});
					--TriggerClientEvent("lc_dealership:Notify",source,"sucesso",Lang[Config.lang]['stock_price_changed'])
					TriggerClientEvent("Framework:Notify", source, "Đã thay đổi giá bán", "success", 5000)

				else
					--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['must_be_owner'])
					TriggerClientEvent("Framework:Notify", source, "Bạn phải là chủ sở hữu để làm điều đó", "error", 5000)
	
				end
			else
				TriggerClientEvent("Framework:Notify", source, "Giá trị không hợp lệ", "error", 5000)
				--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['invalid_value'])
			end
		end
	end
end)

function hasStockSlots(query,dealership_id,amount)
	local stock_capacity = Config.dealership_types[Config.dealership_locations[dealership_id].type].stock_capacity
	if query and query[1] and getStockAmount(query[1].stock) + amount <= stock_capacity then
		return true
	else
		return false
	end
end

function getStockAmount(stock)
	local arr_stock = json.decode(stock)
	local count = 0
	for k,v in pairs(arr_stock) do
		count = count + v
	end
	return count
end

local paid_vehicle = {}
-- Event called when customer click to buy a vehicle
RegisterServerEvent("lc_dealership:buyVehicle")
AddEventHandler("lc_dealership:buyVehicle",function(key,vehicle)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid
		if user_id then
			local sql = "SELECT stock, stock_sold, stock_prices FROM `dealership_owner` WHERE dealership_id = @dealership_id";
			local query = MySQL.Sync.fetchAll(sql, {['@dealership_id'] = key});
			
			local arr_stock = {}
			local arr_stock_prices = {}
			local arr_stock_sold = {}
			local query_dealership_stock  = {}
			if not query or not query[1] then 
				-- If does not have a owner, get the stock from dealership_stock
				if Config.default_stock == false then
					local sql = "SELECT amount FROM `dealership_stock` WHERE vehicle = @vehicle";
					query_dealership_stock = MySQL.Sync.fetchAll(sql, {['@vehicle'] = vehicle});
					if query_dealership_stock and query_dealership_stock[1] then
						arr_stock[vehicle] = query_dealership_stock[1].amount
					else
						arr_stock[vehicle] = 0
					end
				else
					arr_stock[vehicle] = Config.default_stock
				end
				arr_stock_prices[vehicle] = Config.dealership_types[Config.dealership_locations[key].type].vehicles[vehicle].price_to_customer
			else
				-- Else, get the stock from database dealership_owner.stock
				arr_stock = json.decode(query[1].stock)
				arr_stock_sold = json.decode(query[1].stock_sold)
				arr_stock_prices = json.decode(query[1].stock_prices)
				if arr_stock and not arr_stock[vehicle] then arr_stock[vehicle] = 0 end
				if arr_stock_sold and not arr_stock_sold[vehicle] then arr_stock_sold[vehicle] = 0 end
				if arr_stock_prices and not arr_stock_prices[vehicle] then arr_stock_prices[vehicle] = Config.dealership_types[Config.dealership_locations[key].type].vehicles[vehicle].price_to_customer end
			end
			if arr_stock and arr_stock[vehicle] > 0 then
				local price = arr_stock_prices[vehicle]
				local veh_name = Config.dealership_types[Config.dealership_locations[key].type].vehicles[vehicle].name
				if tryPayment(source,price,Config.Framework.account_customers) then
					if query and query[1] then 
						-- Remove the vehicle from stock and update de table if has owner
						arr_stock[vehicle] = arr_stock[vehicle] - 1
						arr_stock_sold[vehicle] = arr_stock_sold[vehicle] + 1
						if arr_stock[vehicle] == 0 then arr_stock[vehicle] = nil end -- Clear empty stock
						local sql = "UPDATE `dealership_owner` SET stock = @stock, stock_sold = @stock_sold WHERE dealership_id = @dealership_id";
						MySQL.Sync.execute(sql, {['@stock'] = json.encode(arr_stock), ['@stock_sold'] = json.encode(arr_stock_sold), ['@dealership_id'] = key});
						giveDealershipMoney(key,price)
					end
					
					if query_dealership_stock and query_dealership_stock[1] then
						-- Remove from default stock when doesnt have owner
						arr_stock[vehicle] = arr_stock[vehicle] - 1
						local sql = "UPDATE `dealership_stock` SET amount = @amount WHERE vehicle = @vehicle";
						MySQL.Sync.execute(sql, {['@amount'] = arr_stock[vehicle], ['@vehicle'] = vehicle});
					end

					paid_vehicle[source] = true
					TriggerClientEvent("lc_dealership:spawnVehicle",source,vehicle,GeneratePlate())
					TriggerClientEvent("lc_dealership:Notify",source,"sucesso",Lang[Config.lang]['bought_vehicle']:format(veh_name))
					insertBalanceHistory(key,user_id,Lang[Config.lang]['balance_vehicle_bought']:format(veh_name),price,0,1)
					SendWebhookMessage(Config.webhook,Lang[Config.lang]['logs_vehicle_bought']:format(key,vehicle,price,user_id..os.date("\n["..Lang[Config.lang]['logs_date'].."]: %d/%m/%Y ["..Lang[Config.lang]['logs_hour'].."]: %H:%M:%S")))
				else
					--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['insufficient_funds'])
					TriggerClientEvent("Framework:Notify", source, "Không đủ tiền", "error", 5000)

				end
			else
				TriggerClientEvent("Framework:Notify", source, "Cửa hàng không có đủ hàng chiếc xe này", "error", 5000)

				--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['insufficient_stock'])
			end
		end
	end
end)

RegisterServerEvent("lc_dealership:setVehicleOwned")
AddEventHandler("lc_dealership:setVehicleOwned",function(vehicleProps, vehicle_model)
	local source = source
	if paid_vehicle[source] then
		paid_vehicle[source] = nil
		insertVehicleOnGarage(source,vehicleProps,vehicle_model)
	end
end)

-- Customer click to sell a vehicle. Insert the vehicle on the request table and the dealer owner must accept the buy
RegisterServerEvent("lc_dealership:sellVehicle")
AddEventHandler("lc_dealership:sellVehicle",function(key,vehicle,plate,price)
	local source = source
	local xPlayer = Framework.Functions.GetPlayer(source)
	local user_id = xPlayer.PlayerData.citizenid
	price = math.floor(tonumber(price) or 0)
	
	local owner_id = getDealershipOwner(key)
	if owner_id then
		if price > 0 then
			local sql = "INSERT INTO `dealership_requests` (`dealership_id`, `user_id`, `vehicle`, `request_type`, `plate`, `name`, `price`) VALUES (@dealership_id, @user_id, @vehicle, @request_type, @plate, @name, @price);";
			MySQL.Sync.execute(sql, {['@dealership_id'] = key, ['@user_id'] = user_id, ['@vehicle'] = vehicle, ['@request_type'] = 0, ['@plate'] = plate, ['@name'] = getPlayerName(user_id), ['@price'] = price});
			TriggerClientEvent("lc_dealership:Notify",source,"sucesso",Lang[Config.lang]['sell_request_created']:format(price))
			local tPlayer = Framework.Functions.GetPlayerByCitizenId(owner_id)
			if tPlayer then
				TriggerClientEvent("Framework:Notify", source, "Yêu cầu bán đã được tạo", "success", 5000)

				--TriggerClientEvent("lc_dealership:Notify",tPlayer.PlayerData.source,"sucesso",Lang[Config.lang]['sell_request_created_owner'])
			end
			openUI(source,key,true,true)
			SendWebhookMessage(Config.webhook,Lang[Config.lang]['logs_sell_used_vehicle_request']:format(key,vehicle,plate,price,user_id..os.date("\n["..Lang[Config.lang]['logs_date'].."]: %d/%m/%Y ["..Lang[Config.lang]['logs_hour'].."]: %H:%M:%S")))
		else
			TriggerClientEvent("Framework:Notify", source, "Giá trị không hợp lệ", "error", 5000)

			--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['invalid_value'])
		end
	else
		if Config.sell_vehicles.sell_without_owner then
			local sell_price = Config.dealership_types[Config.dealership_locations[key].type].vehicles[vehicle].price_to_customer * Config.sell_vehicles.percentage
			if hasVehicle(user_id,vehicle) then
				deleteSoldVehicle(user_id,plate)
				giveMoney(source,sell_price,Config.Framework.account_customers)
				TriggerClientEvent("lc_dealership:Notify",source,"sucesso",Lang[Config.lang]['sold_vehicle']:format(sell_price))
				openUI(source,key,true,true)
				SendWebhookMessage(Config.webhook,Lang[Config.lang]['logs_sell_used_vehicle_without_owner']:format(key,vehicle,plate,sell_price,user_id..os.date("\n["..Lang[Config.lang]['logs_date'].."]: %d/%m/%Y ["..Lang[Config.lang]['logs_hour'].."]: %H:%M:%S")))
			else
				TriggerClientEvent("lc_dealership:closeUI",source)
				TriggerClientEvent("Framework:Notify", source, "Bạn không sở hữu chiếc xe này", "error", 5000)

				--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['not_own_this_vehicle_2'])
			end
		else
			TriggerClientEvent("Framework:Notify", source, "Cửa hàng này không có chủ sỡ hữu", "error", 5000)

			--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['no_owner'])
		end
	end
end)

-- Customer cancel the pending request to sell vehicle
RegisterServerEvent("lc_dealership:cancelSellVehicle")
AddEventHandler("lc_dealership:cancelSellVehicle",function(key,id)
	local source = source
	local xPlayer = Framework.Functions.GetPlayer(source)
	local user_id = xPlayer.PlayerData.citizenid

	local sql = "SELECT request_type, status FROM `dealership_requests` WHERE id = @id";
	local query = MySQL.Sync.fetchAll(sql, {['@id'] = id});

	if query and query[1] and query[1].request_type == 0 and (query[1].status == 0 or query[1].status == 3) then
		local sql = "DELETE FROM `dealership_requests` WHERE id = @id";
		MySQL.Sync.execute(sql, {['@id'] = id});
		TriggerClientEvent("Framework:Notify", source, "Yêu cầu của bạn đã bị hủy", "success", 5000)

		--TriggerClientEvent("lc_dealership:Notify",source,"sucesso",Lang[Config.lang]['buy_request_cancelled'])
		openUI(source,key,true,true)
	else
		TriggerClientEvent("Framework:Notify", source, "Bạn không thể hủy yêu cầu này", "error", 5000)

		--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['cant_cancel_request'])
	end
end)

-- Customer get the money from a sold used vehicle if the owner accepted
RegisterServerEvent("lc_dealership:finishSellVehicle")
AddEventHandler("lc_dealership:finishSellVehicle",function(key,id)
	local source = source
	local xPlayer = Framework.Functions.GetPlayer(source)
	local user_id = xPlayer.PlayerData.citizenid

	local sql = "SELECT request_type, status, price, vehicle, plate FROM `dealership_requests` WHERE id = @id";
	local query = MySQL.Sync.fetchAll(sql, {['@id'] = id});

	if query and query[1] and query[1].request_type == 0 and query[1].status == 2 then
		local sql = "DELETE FROM `dealership_requests` WHERE id = @id";
		MySQL.Sync.execute(sql, {['@id'] = id});

		giveMoney(source,query[1].price,Config.Framework.account_customers)
		TriggerClientEvent("Framework:Notify", source, "Đã bán xe", "success", 5000)
		--TriggerClientEvent("lc_dealership:Notify",source,"sucesso",Lang[Config.lang]['sold_vehicle'])
		openUI(source,key,true,true)
		SendWebhookMessage(Config.webhook,Lang[Config.lang]['logs_sell_used_vehicle_finish']:format(key,query[1].vehicle,query[1].plate,query[1].price,user_id..os.date("\n["..Lang[Config.lang]['logs_date'].."]: %d/%m/%Y ["..Lang[Config.lang]['logs_hour'].."]: %H:%M:%S")))
	else
		TriggerClientEvent("Framework:Notify", source, "Bạn không thể hủy yêu cầu này", "error", 5000)

		--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['cant_cancel_request'])
	end
end)

-- Event called when owner click to hire a player
RegisterServerEvent("lc_dealership:hirePlayer")
AddEventHandler("lc_dealership:hirePlayer",function(key,user)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid
		if user_id then
			if isOwner(key,user_id) then
				-- Check if reached the max employee amount
				local sql = "SELECT COUNT(user_id) as qtd FROM `dealership_hired_players` WHERE dealership_id = @dealership_id";
				local query = MySQL.Sync.fetchAll(sql,{['@dealership_id'] = key});
				local max_employees = Config.dealership_types[Config.dealership_locations[key].type].max_employees
				if query[1].qtd < max_employees then
					local name = getPlayerName(user)
					if name then
						-- Check if player is not already a employee
						local sql = "SELECT user_id FROM `dealership_hired_players` WHERE user_id = @user_id";
						local query = MySQL.Sync.fetchAll(sql,{['@user_id'] = user});
						if not query or not query[1] then
							-- Insert new employee
							local sql = "INSERT INTO `dealership_hired_players` (`user_id`, `dealership_id`, `name`, `timer`) VALUES (@user_id, @dealership_id, @name, @timer);";
							MySQL.Sync.execute(sql, {['@user_id'] = user, ['@dealership_id'] = key, ['@name'] = name, ['@timer'] = os.time()});
							openUI(source,key,true)
							
							TriggerClientEvent("lc_dealership:Notify",source,"sucesso",Lang[Config.lang]['hired_user']:format(name))
						else
							TriggerClientEvent("Framework:Notify", source, "Đã tuyển dụng nhân viên", "success", 5000)

							--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['user_employed'])
						end
					else
						TriggerClientEvent("Framework:Notify", source, "Không tìm thấy người chơi", "error", 5000)

						--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['user_not_found'])
					end
				else
					TriggerClientEvent("Framework:Notify", source, "Đã đạt số lượng nhân viên tối đa", "error", 5000)

					--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['max_employees'])
				end
			else
				TriggerClientEvent("Framework:Notify", source, "Bạn không phải là chủ của cửa hàng này", "error", 5000)

				--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['must_be_owner'])
			end
		end
	end
end)

-- Event called when owner click to fire a player
RegisterServerEvent("lc_dealership:firePlayer")
AddEventHandler("lc_dealership:firePlayer",function(key,user)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid
		if user_id then
			if isOwner(key,user_id) then
				local sql = "DELETE FROM `dealership_hired_players` WHERE user_id = @user_id AND dealership_id = @dealership_id";
				MySQL.Sync.execute(sql, {['@user_id'] = user, ['@dealership_id'] = key});
				TriggerClientEvent("Framework:Notify", source, "Đã đuổi việc nhân viên", "success", 5000)

				--TriggerClientEvent("lc_dealership:Notify",source,"sucesso",Lang[Config.lang]['fired_user'])
				openUI(source,key,true)
			else
				TriggerClientEvent("Framework:Notify", source, "Bạn không phải là chủ của cửa hàng này", "error", 5000)

				--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['must_be_owner'])
			end
		end
	end
end)

-- Owner give commision amount to hired employee
RegisterServerEvent("lc_dealership:giveComission")
AddEventHandler("lc_dealership:giveComission",function(key,user,amount)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid
		amount = tonumber(amount) or 0
		amount = math.floor(amount)
		if user_id then
			if amount > 0 then
				if isOwner(key,user_id) then
					local tPlayer = Framework.Functions.GetPlayerByCitizenId(user)
					if tPlayer and tPlayer.PlayerData.source then
						if tryGetDealershipMoney(key,amount) then
							giveMoney(tPlayer.PlayerData.source,amount,Config.Framework.account_dealership)
							openUI(source,key,true)
							TriggerClientEvent("Framework:Notify", tPlayer.PlayerData.source, "Bạn đã nhận được hoa hồng, hãy kiểm tra tài khoản của bạn", "success", 5000)

							--TriggerClientEvent("lc_dealership:Notify",tPlayer.PlayerData.source,"sucesso",Lang[Config.lang]['comission_received'])
							TriggerClientEvent("Framework:Notify", source, "Đã gửi tiền cho nhân viên", "success", 5000)

							--TriggerClientEvent("lc_dealership:Notify",source,"sucesso",Lang[Config.lang]['comission_sent'])
						else
							TriggerClientEvent("Framework:Notify", source, "Không đủ tiền", "error", 5000)

							--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['insufficient_funds'])
						end
					else
						TriggerClientEvent("Framework:Notify", source, "Không tìm thấy người chơi", "error", 5000)

						--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['cant_find_user'])
					end
				else
					TriggerClientEvent("Framework:Notify", source, "Bạn không phải là chủ của cửa hàng này", "error", 5000)

					--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['must_be_owner'])
				end
			else
				TriggerClientEvent("Framework:Notify", source, "Giá trị không hợp lệ", "error", 5000)

				--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['invalid_value'])
			end
		end
	end
end)

-- Change profile employee img
RegisterServerEvent("lc_dealership:changeProfile")
AddEventHandler("lc_dealership:changeProfile",function(key,nuser_id,banner_img,profile_img)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid
		if user_id  == nuser_id then
			local sql = "UPDATE `dealership_hired_players` SET banner_img = @banner_img, profile_img = @profile_img WHERE dealership_id = @dealership_id AND user_id = @user_id";
			MySQL.Sync.execute(sql, {['@dealership_id'] = key, ['@user_id'] = nuser_id, ['@profile_img'] = profile_img, ['@banner_img'] = banner_img});
		end
	end
end)

-- Change profile owner img
RegisterServerEvent("lc_dealership:changeProfileOwner")
AddEventHandler("lc_dealership:changeProfileOwner",function(key,nuser_id,banner_img,profile_img)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid
		if user_id  == nuser_id then
			local sql = "UPDATE `dealership_owner` SET banner_img = @banner_img, profile_img = @profile_img WHERE dealership_id = @dealership_id";
			MySQL.Sync.execute(sql, {['@dealership_id'] = key, ['@profile_img'] = profile_img, ['@banner_img'] = banner_img});
		end
	end
end)

-- Customer start a request, he pays and have to wait the owner does any action
RegisterServerEvent("lc_dealership:requestVehicle")
AddEventHandler("lc_dealership:requestVehicle",function(key,vehicle,price)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid

		local sql = "SELECT user_id, vehicle FROM `dealership_requests` WHERE user_id = @user_id AND vehicle = @vehicle AND request_type = 1";
		local query = MySQL.Sync.fetchAll(sql, {['@user_id'] = user_id, ['vehicle'] = vehicle});
		if getDealershipOwner(key) then
			if not query or not query[1] then
				price = tonumber(price)
				if price and price > 0 then
					price = math.floor(price)
					if tryPayment(source,price,Config.Framework.account_customers) then
						local sql = "INSERT INTO `dealership_requests` (`user_id`, `dealership_id`, `vehicle`, `plate`, `request_type`, `name`, `price`, `status`) VALUES (@user_id, @dealership_id, @vehicle, @plate, @request_type, @name, @price, @status);";
						MySQL.Sync.execute(sql, {['@dealership_id'] = key, ['@user_id'] = user_id, ['@vehicle'] = vehicle, ['@plate'] = '', ['@request_type'] = 1, ['@name'] = getPlayerName(user_id), ['@price'] = price, ['@status'] = 0});

						--TriggerClientEvent("lc_dealership:Notify",source,"sucesso",Lang[Config.lang]['request_created'])
						TriggerClientEvent("Framework:Notify", source, "Đã tạo yêu cầu thành công", "error", 5000)


						openUI(source,key,true,true)
						SendWebhookMessage(Config.webhook,Lang[Config.lang]['logs_buy_vehicle_request']:format(key,vehicle,price,user_id..os.date("\n["..Lang[Config.lang]['logs_date'].."]: %d/%m/%Y ["..Lang[Config.lang]['logs_hour'].."]: %H:%M:%S")))
					else
						TriggerClientEvent("Framework:Notify", source, "Không đủ tiền", "error", 5000)

						--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['insufficient_funds'])
					end
				else
					TriggerClientEvent("Framework:Notify", source, "Giá trị không hợp lệ", "error", 5000)

					--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['invalid_value'])
				end
			else
				TriggerClientEvent("Framework:Notify", source, "Bạn đã tạo yêu cầu rồi!", "error", 5000)

				--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['already_requested'])
			end
		else
			TriggerClientEvent("Framework:Notify", source, "Cửa hàng này không có chủ!", "error", 5000)

			--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['no_owner'])
		end
	end
end)

-- Customer cancel his request and receive his money back
RegisterServerEvent("lc_dealership:cancelRequest")
AddEventHandler("lc_dealership:cancelRequest",function(key,id)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid

		local sql = "SELECT price, status, request_type FROM `dealership_requests` WHERE id = @id";
		local query = MySQL.Sync.fetchAll(sql, {['@id'] = id});
		
		if query and query[1] then
			if (query[1].status == 0 or query[1].status == 3) and query[1].request_type == 1 then
				local sql = "DELETE FROM `dealership_requests` WHERE id = @id";
				MySQL.Sync.execute(sql, {['@id'] = id});

				giveMoney(source,query[1].price,Config.Framework.account_customers)
				TriggerClientEvent("Framework:Notify", source, "Đã hủy yêu cầu!", "success", 5000)

				--TriggerClientEvent("lc_dealership:Notify",source,"sucesso",Lang[Config.lang]['request_cancelled'])

				openUI(source,key,true,true)
			else
				TriggerClientEvent("Framework:Notify", source, "Không thể hủy yêu cầu này!", "error", 5000)

				--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['cant_cancel_request'])
			end
		end
	end
end)

-- When a request is complete and customer is getting his car
RegisterServerEvent("lc_dealership:finishRequest")
AddEventHandler("lc_dealership:finishRequest",function(key,id)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid

		local sql = "SELECT vehicle, status, request_type, price, user_id FROM `dealership_requests` WHERE id = @id";
		local query = MySQL.Sync.fetchAll(sql, {['@id'] = id});
		if query and query[1] then
			if query[1].status == 2 and query[1].request_type == 1 and user_id == query[1].user_id then
				local sql = "DELETE FROM `dealership_requests` WHERE id = @id";
				MySQL.Sync.execute(sql, {['@id'] = id});
				paid_vehicle[source] = true
				TriggerClientEvent("lc_dealership:spawnVehicle",source,query[1].vehicle,GeneratePlate())
				local veh_name = Config.dealership_types[Config.dealership_locations[key].type].vehicles[query[1].vehicle].name
				TriggerClientEvent("lc_dealership:Notify",source,"sucesso",Lang[Config.lang]['bought_vehicle']:format(veh_name))
				SendWebhookMessage(Config.webhook,Lang[Config.lang]['logs_buy_vehicle_finish']:format(key,query[1].vehicle,query[1].price,user_id..os.date("\n["..Lang[Config.lang]['logs_date'].."]: %d/%m/%Y ["..Lang[Config.lang]['logs_hour'].."]: %H:%M:%S")))
			else
				TriggerClientEvent("Framework:Notify", source, "Không thể chấp nhận yêu cầu này!", "error", 5000)
				--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['cant_accept_request'])
			end
		end
	end
end)

-- Owner accept the request, if it is a buy request, he pay and the stock increase, if it is a sell request, he goes to import the vehicle
local started_import_request = {}
RegisterServerEvent("lc_dealership:acceptRequest")
AddEventHandler("lc_dealership:acceptRequest",function(key,id)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid

		local sql = "SELECT * FROM `dealership_requests` WHERE id = @id";
		local query = MySQL.Sync.fetchAll(sql, {['@id'] = id});
		if query and query[1] then
			if query[1].status == 0 then
				if query[1].request_type == 1 then -- Owner import vehicle
					local price = Config.dealership_types[Config.dealership_locations[key].type].vehicles[query[1].vehicle].price_to_owner
					if tryGetDealershipMoney(key,price) then
						local sql = "UPDATE `dealership_requests` SET status = 1 WHERE id = @id";
						MySQL.Sync.execute(sql, {['@id'] = id});
						local veh_name = Config.dealership_types[Config.dealership_locations[key].type].vehicles[query[1].vehicle].name
						insertBalanceHistory(key,user_id,Lang[Config.lang]['balance_request_started']:format(veh_name),price,1,0)
						started_import_request[source] = true
						TriggerClientEvent("lc_dealership:startContract",source,query[1].vehicle,1,false,id)
					else
						TriggerClientEvent("Framework:Notify", source, "Không đủ tiền!", "error", 5000)

						--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['insufficient_funds'])
					end
				else -- Owner buy the vehicle
					-- Check if vehicle is owned by the same person
					if hasVehicle(query[1].user_id,query[1].plate) then
						if tryGetDealershipMoney(key,query[1].price) then
							-- Increase the stock by 1
							local sql = "SELECT stock FROM `dealership_owner` WHERE dealership_id = @dealership_id";
							local stock = MySQL.Sync.fetchAll(sql, {['@dealership_id'] = key})[1].stock;
							local arr_stock = json.decode(stock)
							if not arr_stock[query[1].vehicle] then arr_stock[query[1].vehicle] = 0 end
							arr_stock[query[1].vehicle] = arr_stock[query[1].vehicle] + 1
							local sql = "UPDATE `dealership_owner` SET stock = @stock WHERE dealership_id = @dealership_id";
							MySQL.Sync.execute(sql, {['@stock'] = json.encode(arr_stock), ['@dealership_id'] = key});

							-- Change the status to finished
							local sql = "UPDATE `dealership_requests` SET status = 2 WHERE id = @id";
							MySQL.Sync.execute(sql, {['@id'] = id});
							
							-- Remove the vehicle from owner
							deleteSoldVehicle(query[1].user_id,query[1].plate)

							-- Insert in balance
							local veh_name = Config.dealership_types[Config.dealership_locations[key].type].vehicles[query[1].vehicle].name
							insertBalanceHistory(key,user_id,Lang[Config.lang]['balance_used_vehicle_bought']:format(veh_name),query[1].price,1,0)
							TriggerClientEvent("Framework:Notify", source, "Bạn đã mua chiếc xe này!", "success", 5000)

							--TriggerClientEvent("lc_dealership:Notify",source,"sucesso",Lang[Config.lang]['o_bought_vehicle'])
						else
							TriggerClientEvent("Framework:Notify", source, "Không đủ tiền!", "error", 5000)

							--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['insufficient_funds'])
						end
					else
						-- Change the status to cancelled
						local sql = "UPDATE `dealership_requests` SET status = 3 WHERE id = @id";
						MySQL.Sync.execute(sql, {['@id'] = id});
						TriggerClientEvent("Framework:Notify", source, "Bạn không sở hữu chiếc xe này!", "error", 5000)

						--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['not_own_this_vehicle'])
					end
				end
			else
				TriggerClientEvent("Framework:Notify", source, "Không thể chấp nhận yêu cầu này!", "error", 5000)

				--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['cant_accept_request'])
			end
		end
	end
end)

RegisterServerEvent("lc_dealership:finishImportRequestVehicle")
AddEventHandler("lc_dealership:finishImportRequestVehicle",function(key,vehicle,id)
	local source = source
	local xPlayer = Framework.Functions.GetPlayer(source)
	local user_id = xPlayer.PlayerData.citizenid
	if started_import_request[source] then
		started_import_request[source] = nil
		local sql = "SELECT * FROM `dealership_requests` WHERE id = @id";
		local query = MySQL.Sync.fetchAll(sql, {['@id'] = id});

		local sql = "UPDATE `dealership_requests` SET status = 2 WHERE id = @id";
		MySQL.Sync.execute(sql, {['@id'] = id});
		giveDealershipMoney(key,query[1].price)

		local sql = "UPDATE `dealership_hired_players` SET jobs_done = jobs_done + 1 WHERE dealership_id = @dealership_id AND user_id = @user_id";
		MySQL.Sync.execute(sql, {['@dealership_id'] = key, ['@user_id'] = user_id});

		local veh_name = Config.dealership_types[Config.dealership_locations[key].type].vehicles[query[1].vehicle].name
		insertBalanceHistory(key,user_id,Lang[Config.lang]['balance_request_finished']:format(veh_name),query[1].price,0,1)
		TriggerClientEvent("Framework:Notify", source, "Bạn đã hoàn thành yêu cầu này!", "success", 5000)

		--TriggerClientEvent("lc_dealership:Notify",source,"sucesso",Lang[Config.lang]['request_finished'])
	end
end)

RegisterServerEvent("lc_dealership:cancelImportRequestVehicle")
AddEventHandler("lc_dealership:cancelImportRequestVehicle",function(id)
	local source = source
	if started_import_request[source] then
		started_import_request[source] = nil
		local sql = "UPDATE `dealership_requests` SET status = 0 WHERE id = @id";
		MySQL.Sync.execute(sql, {['@id'] = id});
	end
end)

-- Owner declines the request
RegisterServerEvent("lc_dealership:declineRequest")
AddEventHandler("lc_dealership:declineRequest",function(key,id)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid

		local sql = "SELECT price, status FROM `dealership_requests` WHERE id = @id";
		local query = MySQL.Sync.fetchAll(sql, {['@id'] = id});
		if query and query[1] then
			if query[1].status == 0 then
				local sql = "UPDATE `dealership_requests` SET status = 3 WHERE id = @id";
				MySQL.Sync.execute(sql, {['@id'] = id});
				TriggerClientEvent("Framework:Notify", source, "Bạn đã từ chối yêu cầu", "success", 5000)

				--TriggerClientEvent("lc_dealership:Notify",source,"sucesso",Lang[Config.lang]['request_declined'])
			else
				TriggerClientEvent("Framework:Notify", source, "Bạn không thể từ chối yêu cầu này", "error", 5000)

				--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['cant_decline_request'])
			end
		end
	end
end)

RegisterServerEvent("lc_dealership:depositMoney")
AddEventHandler("lc_dealership:depositMoney",function(key,amount)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid
		if user_id then
			local amount = tonumber(amount)
			if amount and amount > 0 then
				amount = math.floor(amount)
				if tryPayment(source,amount,Config.Framework.account_dealership) then
					giveDealershipMoney(key,amount)
					TriggerClientEvent("Framework:Notify", source, "Đã rút tiền thành công", "success", 5000)

					--TriggerClientEvent("lc_dealership:Notify",source,"sucesso",Lang[Config.lang]['money_deposited'])
					-- insertBalanceHistory(key,user_id,Lang[Config.lang]['money_deposited'],amount,0,0)
					openUI(source,key,true)
				else
					TriggerClientEvent("Framework:Notify", source, "Không đủ tiền", "error", 5000)

					TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['insufficient_funds'])
				end
			else
				TriggerClientEvent("Framework:Notify", source, "Không đúng giá trị", "error", 5000)

				--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['invalid_value'])
			end
		end
	end
end)

RegisterServerEvent("lc_dealership:withdrawMoney")
AddEventHandler("lc_dealership:withdrawMoney",function(key)
	if vrp_ready then
		local source = source
		local xPlayer = Framework.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid
		if user_id then
			if isOwner(key,user_id) then
				local sql = "SELECT money FROM `dealership_owner` WHERE dealership_id = @dealership_id";
				local query = MySQL.Sync.fetchAll(sql,{['@dealership_id'] = key})[1];
				local amount = tonumber(query.money)
				if amount and amount > 0 then
					local sql = "UPDATE `dealership_owner` SET money = 0 WHERE dealership_id = @dealership_id";
					MySQL.Sync.execute(sql, {['@dealership_id'] = key});
					giveMoney(source,amount,Config.Framework.account_dealership)
					TriggerClientEvent("Framework:Notify", source, "Đã gửi tiền thành công", "success", 5000)

					TriggerClientEvent("lc_dealership:Notify",source,"sucesso",Lang[Config.lang]['money_withdrawn'])
					-- insertBalanceHistory(key,user_id,Lang[Config.lang]['money_withdrawn'],amount,1,0)
					openUI(source,key,true)
				end
			else
				TriggerClientEvent("Framework:Notify", source, "Bạn không phải là chủ", "error", 5000)

				--TriggerClientEvent("lc_dealership:Notify",source,"negado",Lang[Config.lang]['must_be_owner'])
			end
		end
	end
end)

-- Saves all vehicles spawned over dealership
local spawned_vehicles = {}
RegisterServerEvent("lc_dealership:setSpawnedVehicles")
AddEventHandler("lc_dealership:setSpawnedVehicles",function(key,loc,vehicle)
	if not spawned_vehicles[key] then spawned_vehicles[key] = {} end
	spawned_vehicles[key][loc] = vehicle
end)
RegisterServerEvent("lc_dealership:getSpawnedVehicles")
AddEventHandler("lc_dealership:getSpawnedVehicles",function(key,loc,vehicle)
	if not spawned_vehicles[key] then spawned_vehicles[key] = {} end
	TriggerClientEvent("lc_dealership:getSpawnedVehicles",source,key,loc,spawned_vehicles[key][loc],vehicle)
end)

RegisterServerEvent("lc_dealership:vehicleLock")
AddEventHandler("lc_dealership:vehicleLock",function()
	local source = source
	TriggerClientEvent("lc_dealership:vehicleClientLock",source)
end)

-- This file was generated using Luraph Obfuscator v13.6.4

return(function(DI,QI,uI,ZI,AI,FI,HI,XI,gI,LI,PI,fI,CI,lI,pI,rI,tI,wI,NI,iI,MI,jI,xI,OI,zI,KI,GI,vI,WI,U,e,a)local q,mI,JI,V=pcall,0,nil,(nil);local o=(ZI);repeat if mI==0 then JI=function(...)do return(...)();end;end;do mI=0x00001;end;else V=XI;break;do break;end;end;until(false);mI=9;local I,b,G,u,x,X,p,M,E,Z=nil,nil,nil,nil,nil,nil,nil,nil,nil,(nil);do while mI<=9 do if mI<=0X4 then do if mI<=0X0001 then do if mI==0 then do u=function(...)return(...)[...];end;end;mI=5;else G=rI.unpack;do mI=0x0;end;end;end;else if mI<=0X2 then b=function(y2,I2)return y2~I2;end;mI=1;else if mI~=3 then Z=AI;mI=10;else p=4294967296;mI=0X006;end;end;end;end;else if not(mI<=0X06)then do if mI<=0X007 then do X=WI.char;end;mI=3;else if mI~=0x008 then I=string.sub;mI=2;else E={0X3,6,1};mI=4;end;end;end;else if mI~=5 then do M=lI;end;mI=8;else x=_ENV;do mI=7;end;end;end;end;end;end;local W,UI,A,z=nil,nil,nil,(nil);local T=tonumber;goto _310066248_0;::_310066248_0::;do W=vI;end;goto _310066248_1;::_310066248_3::;z=KI;goto _310066248_4;::_310066248_2::;A=zI;goto _310066248_3;::_310066248_1::;UI={};goto _310066248_2;::_310066248_4::;local m=(function(q_,R_,y_)return q_>>R_&~(~0X0<<y_);end);local Q,r=QI,(gI);do mI=5;end;local D,g,H,i,w=nil,nil,nil,nil,(nil);repeat if mI<=0x2 then if not(mI<=0)then if mI~=0x00001 then H=HI;do mI=0X00004;end;else g=MI;mI=0x0002;end;else i=function(BJ,gJ,bJ)do if not(gJ>bJ)then else return;end;end;local CJ=(bJ-gJ+1);if CJ>=8 then return BJ[gJ],BJ[gJ+0X01],BJ[gJ+2],BJ[gJ+0x0003],BJ[gJ+4],BJ[gJ+0X5],BJ[gJ+6],BJ[gJ+0x0007],i(BJ,gJ+8,bJ);elseif CJ>=7 then do return BJ[gJ],BJ[gJ+0x01],BJ[gJ+GI],BJ[gJ+iI],BJ[gJ+0X4],BJ[gJ+0x0005],BJ[gJ+6],i(BJ,gJ+7,bJ);end;elseif CJ>=6 then return BJ[gJ],BJ[gJ+1],BJ[gJ+0X2],BJ[gJ+0x3],BJ[gJ+4],BJ[gJ+5],i(BJ,gJ+0X6,bJ);elseif CJ>=5 then return BJ[gJ],BJ[gJ+0X1],BJ[gJ+0x2],BJ[gJ+0x3],BJ[gJ+0x00004],i(BJ,gJ+0X00005,bJ);elseif CJ>=0X00004 then return BJ[gJ],BJ[gJ+1],BJ[gJ+2],BJ[gJ+0x3],i(BJ,gJ+4,bJ);elseif CJ>=3 then return BJ[gJ],BJ[gJ+0X1],BJ[gJ+2],i(BJ,gJ+3,bJ);else if CJ>=2 then do return BJ[gJ],BJ[gJ+1],i(BJ,gJ+2,bJ);end;else do return BJ[gJ],i(BJ,gJ+tI,bJ);end;end;end;end;mI=3;end;else if mI<=4 then if mI~=0X00003 then mI=0;else w=wI;do mI=6;end;end;else do if mI~=0X5 then do break;end;do break;end;break;else D=nil;do mI=0X001;end;end;end;end;end;until(false);local K,C=rawget,(0x1);local N=W(I("LPH]3079E2023064BD54E05F2H002500155A398C4C4H0015B4AFC2444CC3070015724F2H27E3512H00159A952A4D4H0015017H0015CD8DA800821E0600AB093H0030F085C14BCF5074C851AB113H0055DFC81244EC541424E19DE4C6B5849D2115067H0015BE40BC712A4CF6FFAB093H0066880A0F0D8818333E15787F08054A170E00154D8555C5BFD8050015EAC775AACD8605001560F080C133C3F9FF1545F7871A4H00AB083H0063DBFCFE384D5B6015D87H00150B7AB2609A3DF3FF15DBB47DB5ABDBF0FF15ADC1CD8B4H00AB093H009B46F538E18B55E5D3AB0D3H00ECFA5FBB3540B26A7060F0EB9515437DE079B73D050015DD296H0015D2C862A385CC0C00AB033H001DEE2AAB053H001C0E985EF8158176F11E53C10300AB063H00151B1A40922AAB093H00F766411EFD0838F7E515A7974731CBC2080015B0C1CD8B4H00158B4FF3EAE7500A00AB0D3H00B862439F09848606242H9C4F1915261A2210846B030015C0B33E301F370A00154B32AB604H00155C64273BC2DEF8FF1582BACA8179B70100151F9D9C044H0015F42ACB7468390800151B0C4E9B3DDE0F0015072CD16B4H00154FDFEF2C0AF3F7FF159FF987924H0015EE1548ECCB780A00AB0B3H0059236C8496BA34E7A4D0B2AB053H008099D7E3C915037H0015982A0999E2A6FAFF15057H001529816DDA656001001537C157E97E03F5FF1501AE6H0015BE709702EC71F9FF154FF752AAFA5D0E00AB073H004988EE6F82E3BFAB043H00C4FD3B7F15A7F3DEA144B00300AB093H00B0B3C583D5192AFE481541246D2B2D00F1FF154CF1E73093AA0A0015001681FB06042H00151F347132160F0B00AB103H00D5455E80C363C08DA87A12784838031D15087H0015DF591D83EE540500AB0C3H00C595DF56C8DC403EDACD965EAB073H00196CB0DAD8F76F153C0D12BC872A0200AB053H0054FD0DF624AB063H00AD0B211E66C8151BD96H00AB713H004FF8D723FFF1F37C2703F86AA5F9971C976EE02H98C018AD1988A3E01DE5C9684A4CF0D405C44401CFFE53508ADCBCA4FB445525BE603C472361194F7140AC5274B83E246E37638FE70D7DF0AD72995753E82E96E42B58EC530535AECEACCEBF9B9E20085D8C091C89BE141743C1B0A37F1558DE156D83FFF0FFAB0A3H00285679E9BB64967EAE481527F96H00AB0D3H00EEA78DEB56AA7650A87B6562F9AB093H0087AEB49DCDC25DED3F1525C09F6EB4F90300AB103H0088671308409E3092467820D03800F5C1156360C86A74340F00AB0E3H00B87652990D8F954937909F571F3115000924878D4407001504527FEE17A22H00151B5B59E0277B0400AB0E3H004A6C9C87BF35F3FFC4B8F280CFE71531B0EB26B6880F00AB073H00AC3A9FE37D86F2154B285B51C5030200157762CF888BCBF0FF1558398C4C4H00AB113H00CBA7AE2028C5A9376DB917C98D2DB4425E157756D38CF943FDFF15D1E7F4C2F8FBF2FFAB093H00F4C56DC494BF671D6B15097H001592D39EB1BEA7FAFF1551A08BD61B830D0015B097E53D4H00AB043H002H292H1AAB0B3H00C58AC445C5C15362D4D084AB0E3H003C7A66B0C6D0F06E3AF216FE2FC3158B4DE125F5450600AB053H006E350567DE15773060F7F4020500AB0B3H004FABD134E2EAE63C7405FFAB053H001EA4FD940FAB103H00BF6FF08289D506AF12D4ECBA52AE857FAB093H002F1CD9D6E4760B7BE7157E24A1E16EFCFAFFAB053H00D01E1BCA90AB093H00D961900335A1FF155115233A60BA1EECF5FFAB073H00223E6E1E4B6158AB093H00C9B5692D05150E4A41AB093H00D2845B7750B2E6BF2A15884EDE260F690B00157D7H0015FE19F1E5A4F4F7FFAB073H007FBD3BC6DA175AAB0D3H008244143FE79DEB87B78E8C260E1581A926DB96C6050015196ABE310023020015A2D793C6160FFAFF1519456D9A0FBA050015E8EAC52A507F0500AB063H002BC24D5DC8E21504D0028878A00C00AB093H003D4A0CD2ECE73D4D47AB053H0016F5B16996158BB349E0405C090015D8296H0015E94E06BBF096F4FF15A1566H001513B1F202835C050015CB3CB43BBFA3F6FF15B05725CDF4D50F00AB043H0017B2489EABD9092H00D3C1A461945205E62B2421B2A7D03DBE633C59CA1FA835583B11D96DDD0C23609D6247B481982506CB44C1DC497ED1D2095371693ACEB596759EF182F7A0CD8EB38C69DAAF38C5AEE1E4E1726B9FF57D26F91F8CBF0895761DD1992A98CFE2215B2401794C5DE6C5880C899D0D3A9192CD1C392AFF8899B9347CB74C9D608D4E734C299A6FF88566A4AEA13C2230DD5E83DCB92AFF2DB9D6DB9A59E437E0CDE815EACF3C0978C5E62BA42154C4F857528DD2F7E4B1465B78F13111621728430E3300EA5405B845266B6461F2E71077F1A3729F6A3F8815F6FB341BA2174868A2D3AC89F0C7DE63266BE4617281B515144F92B9AA7F081536BBF431C237E00DC0FFC6A119EA700F864B222BB2A7DA3194633C59CA1FA835565818D16DB7604D0EF30C43BA859E2D06C742C7DD497CD2DD065A7F0A5FA8D3FE7DD491E297C0ADEED3EC09BACF3BCFAAE5EAEF7C699CF278439C79EABF08957613D49F27BDC0ED2E532C097A4C58E5C5EB64E1F2673A92FEC61C3729FA869ABE377ABD4DBD6C82417940279660F08F06CBC4C1524730DD5E83DCB94FFF48D5B6BBF431823783A3ED738CA95A6F78A3884BC16B52C7F05D5E83D3F9EAB92835169B5411621728486E300CE35C29B243460B0401F1E8161D9EC31C960F5AE67993FB3471C277200DABDCCCE9FCC7D4654607880D1C89BE1D1E4999D9CA1F0B153C91F431C237E30DCEFDCAC97A8F1865864B4441D2C7DC35B6665C39AA7FC836585B14D162DB064D0E900C29BC85982B00AB24A1B22776D1D0003C190A5FC7D3961BB1F9E297C0CB86BC8061DCA338CAAAC1E4E97D6790FD7643FA1F8CDA6E95767BD29E2E97CC8D2D5B4C691A2F54E5C68B04819207309EFEA313352C9F8E95B95B14D122D76C884D762C49FA0F988D66ABA4A1322D30DD5E83DCDF469A2DBBD6D5BE5EE25783A2E2108CA95A091BAD8944C72132A7FF5D5BE3BC99ECDF28357EF5347102772C4B6E5304E75020B245266E0401F8E7107DFBC31CF96A3F8870969B5411A2174065CEB3AA81F0C1D66B430D8A2B1288BF127E239AB5AA7F001356DBF73DC237E002AEFCCCA510E91865864B2H27D2C7D53EBB6B345CAA19A235593B74B102B7602B60936F29DAEF9B2366AB24C7D74210BDBE633C196C33C7DDFC1BBBF2A8F2A5C388D38F69D4A958A5C6E8E4EE1207F09D7B259C79EAD967FB161BD49D2D9FC8E2245F2C0974405E85A6EB64E1F26750FDFECF163F22F18790D65B77BB44D700ED467044279461F68960A8AEC13D0D30B830E5BAD9449948D5B6DD9E51E25780A2E8738CA95A6F78C5E62BA42132A7903D3E85BC99E9B04050169B54116217402D6E530AE55A2FB025460B04019287701D9EC31C96063F8815F6FB571FA41D6A6BA8DFA98CFAC1DE6F460B84011DE7D07D164D9CB9A677687556DB9437CD3FEF02C1FCCFA11AE07E65864B4441D2C7B05DDE035C39AA7FA035565712B102B7604D0EF30C4FB68F904566CD4ECEB24F7FF7D006567A0A37C8DA961BD4918AF7AAADEED3EC09BAA038C5A6EBE4EB7707F09D1E439C798CD16495101BD8922E97CEEB4E334C691A2F5BE5C8880E8494083C9EFEA37C5920FF8895BC5B14B74DBD66876473422F9561FBE506CBC4C152475CBD3EE3B6DF2AFF2DBBDADDF431E45F8CADEE13ECC5320A78A0802BA42132A7903D3EE3D4F7E0B34855799B54116217402D6E530AE55A2FB845266B610192877073F0891C930A51ED15F6FB3471C2772065AED3AC89FACFD86B460B840972E7D07D7E23FCD9A27F081536BBF431CC3DE808C893ACC97A8F1865864B4441D2A1D831BE633256C415C830565B14DE02B7052D609C4649BAEF922508CD24A1B22710BDD80D5C796A3FC8D5F67BB4F182F7A0C381B5EC09BAA536C3C68B84811207F0FB7223F01380D366F5161BD49F2E9DC8EB265D29691A4C58E0A68104819E6750989ECF1F132AFF8895B03774BE22D700ED2E1346299A6FF88566ABA4A1322750BD3EE3BCD94A9F28BBD5BBF4318237E0CD8E19E2CC5A6F78C5E643C82132A7903D3E85DCF5EFB7465576FB34710279262D0B3300EA702FB845266B646EF2ED701D9EC31C9A0A5FE875969B5411A217406DAED3AC89FACFD865460B84011287B01D1E439CB9AA7F081536BBF431C237E00DCEF3CCA91AEF7805E62B2421B2A7D038DE653255C935A835565B14D16ADF002368F30C29DA85982506CB44C1D24770DDDE035C796A3FC8D5F67BB4F182F7A0CD8EB38C69DAAF38C5A6EBE4E1726790FD7E23FC198ADF68F5161BD4912297C0ED2D332A07764C72E5C68B048192073E9B90C3103F4A9FE899B63B74B142B7608D4E734C299A6FF88566ABA4A1322750BD3EE3BCD94A9F28B5D6DB9451E25780ADEE13ECC93A0F18A5864BC44152C7F05D5E8BBCFFE4B34B7F76FB34710277204D0E330FE75A21BD254661646E92871F7DFEA37C990A5FE875969B5411A217406DAED3AC89FACFD865460B84011287B01D1E439CB9AA7F081536BBF431C237E00DCEF3C3C91CE1740DCC2B2421B2A7D03DBE633C59CA11A735565874D46CD7054D689F604AB68F982506CB44C1D24770DDDE035C796A3FC8D5F67BB4F182F7A0CD8EB38C69DAAF38C5A6EBE4E1726790FD7E23FC16EABF64FB1931D4912297C0ED2E532C097A4F58E5CC830481916735939ECD1C314A9FE8F5D63E7BBD42B7608D4E734C299A6FF88566ABA4A1322750BD3EE3BCD94A9F28B5D6DB9451E25780ADEE13ECC9356F78A98841EE4152C7F05D5E83DCF9EABF485576FB347E0D7720486E3500E9504FD825460B040192EF10759EA673970A5FE875969B5411A217406DAED3AC89FACFD865460B84011287B01D1E439CB9AA7C68753ABBFC1BC237E00DCEF3CCA91AEF7805E62B2421B2A7D337BE6D3A39AA1CA6355E3B74B102D10E270EF30C29DAEFF84503C544CBDD4970DDDE035C796A3FC8D5F67BB4F182F7A0CD84BD826CD0A13EA5C6E7E4EE586790FD7E23FC198ADF68F5161BD4912297C0ED2E332609744A3885A68E08819E083093FEA37C594A9FE8F5D65B78BF47D700ED2E134929946998E506A1A4A252215EB33883B6D5409F2DD5B6DD9A51E87D80ADEE13ECC93A0F18A5864BC44152C7F05D5E83DCF9EAB048557CFD5411621725410E330CE35229D825460B626FF2E4701D9EC31C930A5C8815F69E5419C2774A6DA2DDAC89FAC0B805266B8E011AADB01D1E439CB9AA7F081536BBF431C237E00DCEF3CCA91AEF7865E525242FB1C7B05DDE035C5FC213A635565B14D162D7002D6E936C49BA8F982506CB44C1D2497CD7D6065A190A5FA8B5F075BAF9A8F7A0CD8EB38C69DAAF38C5A6EBE4E1726790FD7E23FC198ADF68F5161BD2992C97C0ED205C29691A2F3885A6EB64E1F26750FDFEA37C594A9FE8F5D65B14D122D700ED2E132C49FA67F6856EA38EA1322750BD3EE3BCD94A9F28B5D6DB9451E25780ADEE13ECC93A0F18A5864BC44152CBF352548DDCF9EABF485576F53A7D0E7B2C41023F00E75421B645266B6461F2E7107DFEAF739A202295789BB1159AA185188E04FBFFAB083H00746EDD5E0E29EB8B15CF0F904590210900AB083H008CCEBF9B8A20085D158H00150904C06DF6830600AB073H00A44240C2F1495B1500016H00156FB06H0015E582416CF50C08001544B6503AF545060015965F42A687480200AB073H0063DFF6E43C4941AB0C3H0016E8A0638B79A70388BA82ED15ABF3F50CA686F6FF15D2655DDA559E0900AB073H003ABC2C57AF6563AB053H0001F1EF916F1546B7877C7ED00700AB0B3H009E2A6F1A8953E766030951AB043H00F1239553AB073H000D36C32F08F6C3156997C4D7F7A1F1FFAB0D3H00B87147890884DC0E3E8E9B510815AEC6EEACE9D5070015E5AA488AE8140E0015C4D3093BFCA8FCFFAB0D3H00593E7E8A99B375F7BECCB4E19915BE6DDF92C759030015D75A622B41580500AB0C3H00AEE0D83B93E17FCBE2BEA9B1AB053H00522AD1A936AB053H0003BB4ADF9DAB093H00480BC32F645528B7E0AB093H00CD842F1D8456357CC515047H001538052C22E062F1FF15077H0015A3CF69D10823FEFFAB093H00E60455545ED4872HBEAB0C3H00E34F6D78B6C6D2B8783CF010AB043H00972DC400AB0B3H00531F7DC826B6C268F9E1F115027H0015FCA7FD7571FB0400AB073H00127511EA6DA6E81589EB3C163B6D0100AB093H00F90EE1B78A15BBB07115BC381C32610CFDFFAB083H00C210C5F9BD56A29FAB0C3H001A5C4CF7CF05834F109EA418AB053H007ECE93BDAC1508A399104H001566A36B58AEA00200156BB6C6AD68390800AB093H009F7E12277726102057AB074H000A437258AA121562E941541F370A0015D9B3C27C84A7FEFFAB063H000FE80667272815619EBB5E78B7FDFF15FF7H0015E668695H00AB093H0041B4B25E3EAAEA33D7AB093H002AA72DFD31158A3582157CF693E2CCD50700AB093H0037C79133E6FE24DFEF1516FF80C88F2109001538019EC41FBB0C001523EDEB97760A0B001504825100A32F0B0015033D863A4H00AB053H00F8211346D4AB043H00215FC6E81523336H00153AC5D9624177060015257H0015182A0BB23C332H007C00AB063H003D4A02DEF5EF1538718B6178A00C0015C2110B87F9E70700AB073H005F5C4C66FEBB77152903895AC05CF9FF1529FAB1CF16AAFEFFAB0D3H00E27FAF4285B599E759BB314AA8AB053H000B6678E6E21568D67FBC54B9F3FF006D1901000F4C00E253B356FB5E2H008D005102003C004A59190100F1F353836800BD62BD484462751E24044H00D5E72H005B342H025B302H025B2C2H025A132H023B052H025E092H024682072H0246A2072H02188E01DE07D2025BBE01BA02EE06380246E20521B602BE06960416E2049A05A60137AA019601F601370C2H025B0C2H0269060A026E020A0145BE03BA03D206690206025B042H023B050602502H06025B042H023B050602100C06025B242H0237D86HFF0F06025B102H021E062H02692H0602502H06025BE86HFF0F2H025BB86HFF0F2H021E0206025BE46HFF0F2H025BF46HFF0F2H022H01830074A19850FA5E2H00BD00020039003C591901006A03E10D7B00140E8F396B6AAF1234054H00D9E72H005B90012H025B8C012H025B88012H025A172H023B012H025E052H02468E072H0246B6072H02238203B20496024FA204BE03CE0625CE02A6048603608A039201EA0161FE07FA05BA0626E202A6036222C20166A6070B820372C6074FD2030EFA055B4C2H021E02060203BE06BA06AE05690206025B042H023B0106021E020A025B202H021E060A025B202H0269060A025B042H023B010A021E020E025F060A0E5BE06HFF0F2H02700206025BE06HFF0F2H0210BA01BA01FA035BBC6HFF0F2H026902060237AC6HFF0F06025BF06HFF0F2H02033H020156CB008AC2E208FE5E2H00D9005115047H0015057H0015027H000300580055002H59190100AB1D6FBF2900F6C30FAC710F932D5A074H00E3E72H005B84012H025B80012H025B7C2H025A0F2H023B012H025E112H024696072H0246A2072H023EAA05FE076622F207A604BA0434FA01FE05AA060E9A02F606E60638DA05E601960748CE05A603E6070EFE014A8A0334CE01EE018E041DA2059E02C6015BCA06E60486075B3C2H0210BA01C601FA03690612025B042H023B011202502H120E5B002H026E0A02015B002H02690A16025B042H023B0116021E121A025C021602500216065BC46HFF0F2H025D061C0D5B342H021C92038E03960250020E0A5B042H023B010E0237EC6HFF0F0E025B102H0269020A025B002H02502H0A065BDC6HFF0F2H025B946HFF0F2H025106D06HFF0F055BE46HFF0F2H025D06E06HFF0F095BF06HFF0F3H027B3C2H00DAF03FFF5E2H00B5000E2H00C03HFFDF41AB023H00F03D158H00AB033H00EE9DC30E6H003041063H0041001A00260029001559190100E6B0C2997E00DB28974054F34C360C074H00EFE72H005BDC012H025BD8012H025BD4012H025A172H023B052H025E152H02468E072H0246AE072H022BEA06D205E2064FAE01D601A60216CE01DA058E064CF207E603D60110BA069E069A0719D203AE07A6070BEA058A03BA065BA0012H026C3H02033H025E0D16025E111A0241120E025B502H0227120A025B042H021D8A010A02690A0E02692H12025BD86HFF0F2H02690A2H025B042H023B052H02690E06025B042H023B050602692H0A0269120E025E0512025E1116025BBC6HFF0F2H0244020A025E090E025B4C2H023C3H025B042H021DAA3H02690A2H025B042H023B052H02691606025BD46HFF0F2H02363H0253162H025B042H021DBA072H0269062H025BE86HFF0F2H0269062H025B042H023B052H020C3H025BFCFE5HFF0F2H025E0112025BD06HFF0F2H0200231D032EF26F1AFC5E2H00BD007C017C0002001A00465919010067E8A44C4200248D4BF7602C513744094H00E4E72H005B682H025B642H025B602H025A172H023B092H025E0D2H02468A072H0246AA072H0223CE069A01B60205DE06EE04E20623B604DE06A20437CE04E207C601379606BE07CA0361CE078E03860630F2010A860365E207B206A60708960186029E075B242H0269061A021E121E021E0222025B002H0231021A025B042H021D2A1A025B602H025BDC6HFF0F2H0269020E025B042H023B090E021E061202567A8E01FE0341022H0E5B042H021DAA040E02690616025B042H023B09160269061A025B042H023B091A021E0E1E025E05220231021A025B042H021D92061A02370C1A025BA86HFF0F2H021C92038E0396026C0216025E011E02300E162H0276D607D9350E56FA5E2H00212H005919010015ED6FF107000C7106415A99CD8955034H00C3E72H005B402H025B3C2H025B382H025A0F2H023B012H025E052H024686072H0246B2072H0237C601FA05A201305ED2029A02218607EE07F6033FB205C601C60565DE01860296021E820546EA045E8A020ABE065B042H0245F605F2055E37F86HFF0F2H025BF46HFF0F2H020104360097BC0D4A3D5F2H0069001508AD6E094H00157DCD365E01922HFF15A5F4F639AAFA0D0015E70D9CFAC6E50C00AB093H00997BE3478DC5D09C2115C0FFAA4AC7E50C001595E495AEFC362H001560735EB8EE19F9FF15027H00152F85938C1F290A00158C6554CF9CE7F9FF1510BD38D13A15F9FF15C5F5222HFF770B00150BF8414A336706001506D822A952C1F6FFAB093H00F657EBC505D783A1BE15D8C117323074F2FF15A79C1EE6F6692HFF151911F8584H00156AF6E941BC8FF1FF15563E344EA7020C00155BB3A1DE22EC0900155342C8A3015E090015017H00159181328CC8D20F001527C1E7A971420500157696059322EC0900AB063H005BA6418D7056151BB0F7F6EEDB0800150A0F01E35CC72HFF1544609DBEBBEF0F001546D9027AD175020015C7582A9C16450B0015F94F5ADF257CF4FF15D9238E9D09CC0B0015D2A56EEAEECB0900AB043H0031EB0A66156482DD46652HF2FFAB093H00B5156BD9A2CFF75A3D156B3A45575F3AF2FF1520AA949763E30E0015D32HC3CD00352HFFAB043H007242D53915E6B2792BA6640F0015F4923EAC4744FCFFAB053H00161EF7A15C155F1ECBF669D8F3FFAB043H0037C0A0E6157A26FA57DF0AFCFF151F0E1BE41AE82HFF156H001000159A1BAD726462F2FF15EF7795B107C70B001554D7FDB710220400158A057AA120C0F5FFAB043H007B812F7115857B9AAB0091030015681584194D32F5FFAB073H003F313FD6E24BBEAB033H00CA37E5AB053H00D90DEE193115FF036H00AB093H00926D9D1540910EEE5A15B93305998C30FCFF15AFB3CF3BDE13FEFF156F5D033CFC6CF0FF1534A7776F0C17FDFF02001F001D59190100FDA7479E2C0049199AE8580284E13A184H00B1EA2H005BB0072H025BAC072H025BA8072H025A0F2H023B152H025E8D3H024696072H0246B2072H0249FE06BE06BE024F16BA02E6055BCE06FA02A2063ACA019202CA0165F206A2029A0426F205B205AE01418E06C206F2055BF4062H02202H226137EC0F22025B8C062H021A2H461A202H4689025B002H0237D80A46025BF40F2H02112H2ACD0137BC0F2A025BD80F2H0210E40A2A025B8C172H02108C1346025BF8132H02690232025B042H023B153202662H32ED015B042H023B15320270022E025B002H02732H2A2E37980A2A025B102H02662H2EF1015BCC6HFF0F2H0269022E025BF06HFF0F2H025BD0092H025BCC052H022H1E2A025BFC042H02700246025B042H021DA60246025BDC092H02690246025B042H023B154602662H46F1015B042H023B15460269024A02662H4AED015BCC6HFF0F2H021E0E22025BB80A2H021E0E3A025BF0092H021E063E02310236025B002H02700232025B042H021DB20232020E2H320E602H320E5B002H0237C00432025BAC122H0210FC1326025BBC042H021C92038E0396025BE8112H025EFD014E025BE43H0270025A025B042H021DCE035A025EC5015E025BE43H0269024A02662H4AA9015B042H023B154A0269024E025B042H023B154E02662H4EA9015B042H023B154E02690252025B042H023B155202662H5291015B042H023B155202690256025B042H023B155602662H56A9015B042H023B15560269025A025B042H023B155A02662H5ADD0154395E0E5BFCFE5HFF0F2H02662H3A6D5B042H023B153A0269023E025B042H023B153E02662H3E6D5B042H023B153E02690242025B042H023B154202662H42A901690246025B042H023B154602662H4691015BC8FE5HFF0F2H022H1E32025BD8012H02662H2EDD015B042H023B152E02690232025B042H023B153202662H32B5015B042H023B15320269023602662H36A9015B042H023B15360269023A025BF4FE5HFF0F2H02310232025B042H021D4E3202142H327D70022E025BA46HFF0F2H025E71460231023E0270023A022D2H3A050E2H3A125E85013E025B002H02310236025B082H02700242025BD46HFF0F2H02582H3689012D2H36591E0E3A025BAC6HFF0F2H0231024602202H469D015B002H0237A00146025B502H02310256021E265A025B082H0269022E025BC8FE5HFF0F2H02310252025B042H021D8A0752025E09560231024E025EB901520231024A025BCCFC5HFF0F2H0231022A025B042H021D8E052A026D2H2A316D2H2AF5010D212H2A5BBC6HFF0F2H025B382H0269064E025B042H023B154E02662H4EE9015EBD0152025E3D560231024E025B002H025BD40F2H025BCC0E2H0210980A2A025BD0102H0210C40F4E025BDC092H025BAC0E2H025EA50122025BD4092H025B880E2H0210E00A46025B88112H025E6926025BC8092H0210AC0E32025BE80E2H021E0226025BB40F2H025E990132025B202H0269062A025B042H025BE40D2H02662H2AE9015B042H023B152A025EBD012E025BD86HFF0F2H0231022A025BE06HFF0F2H0269021602662H16A9015B042H023B15160269021A025B042H023B151A02662H1A910169021E02662H1EB5015B042H023B151E0269022202662H22B50169022602662H266D5B042H023B15260269022A025B042H023B152A02662H2AA90169022E025B042H023B152E02662H2E6D69023202662H32ED015B042H023B15320270022E02142H2E1D69023202662H326D5B042H023B15320269023602662H36ED015B042H023B153602700232025B042H021D9A023202482H2E325EC101320231022A02700226025B042H021D82052602700222025B042H021DA607220270021E021B2H1E1269022202662H22F1015B042H023B152202690226025B042H023B152602662H26ED01700222025B042H021DBE0322021A2H1E225E2D220231021A025B042H021D221A025E151E02310216025B042H021DE60116026D2H160D69021A02662H1A910169021E02662H1EA9015B042H023B151E02690222025B042H023B152202662H22A901690226025B042H023B152602662H26A9015B042H023B15260269022A025B042H023B152A02662H2A6D5B042H023B152A0269022E025B042H023B152E02662H2E91011E0232021E16360231022E025B042H021DE6032E0270022A02052H2A063784F65HFF0F2A025BF4FB5HFF0F2H02662H2AE9015B002H025EBD012E025EF901320231022A025B042H021DAA012A025B302H0269062A025BD86HFF0F2H0269022A02662H2AF10169022E02662H2EED0170022A025BB4F55HFF0F2H021E0E2A025BE43H0210E4F95HFF0F46025BDC092H0210D8022A025BE86HFF0F2H02378C0A22025B242H02602H22165BF06HFF0F2H025E292E02310226025B042H021DEA0426025E452A02310222025BDC6HFF0F2H025B9C0B2H021E023A025B90F65HFF0F2H02108CF65HFF0F3A025BF06HFF0F2H0254810136125B642H0269021E02662H1EA9015B042H023B151E02690222025B042H023B152202662H226D5B042H023B152202690226025B80012H02612H220A5B142H02690232025B042H023B153202662H32DD015BAC6HFF0F2H021E06260231021E021E1222025B302H02582H1A015B9C6HFF0F2H02700232025B042H021DB607320270022E025B1C2H0231022A025B042H021DFA062A02700226025B102H0231021A025BC86HFF0F2H021E0232025BDC6HFF0F2H02482H261A222H26165B002H023780F55HFF0F26025B202H02662H26F10169022A02662H2AA9015B042H023B152A0269022E02662H2EF1015BE8FE5HFF0F2H025BCC3H025B880A2H025B9CF45HFF0F2H025B80F95HFF0F2H0210DCF25HFF0F46025B80042H02582H22E101690226025B042H023B152602662H26A9015B042H023B15260269022A025BA8012H02482H2A1A5B0C2H02142H2A85025E81022E025B702H0269022E025B042H023B152E02662H2E6D5B042H023B152E02690232025B042H023B153202662H32ED015B042H023B15320270022E025B042H021DAA052E02482H2A2E5BB06HFF0F2H02662H2E91015B042H023B152E02690232025B042H023B153202662H3291015B042H023B1532021E0236025B2C2H02310226025B042H021DA60426025E752A02310222025B042H021D162202142H22515BB4FE5HFF0F2H02662H2A6D5B102H025EA1013A0231023202482H320E5B082H0269022E025B906HFF0F2H025E3536025B002H0231022E025B042H021DF6042E021B2H2E0270022A025B042H021DEA032A02732H2A063794062A025B382H021E0646025BDCF05HFF0F2H02732H2A1237A4F65HFF0F2A025B9CF15HFF0F2H021088F15HFF0F2A025BF8062H025BFC062H025BE8F55HFF0F2H021084FC5HFF0F22025BC0F15HFF0F2H0210FC0126025B082H025BB4012H025B98072H025E1926025BE8012H025B80F15HFF0F2H02310226025B082H021E122E025BF06HFF0F2H02112H26B1015B002H0237C86HFF0F26025BF0FC5HFF0F2H025B98FA5HFF0F2H0237FCFA5HFF0F3A025B6C2H02142H42D9015B442H02310242025BF06HFF0F2H0269024A02662H4A6D5B042H023B154A0269024E02662H4EED015B042H023B154E0270024A025B042H021DA2064A021B2H464A5B202H02482H460E5BC46HFF0F2H0270023E025B042H021DBA053E0270023A02672H3AAD015B946HFF0F2H022H1E4A025B9C6HFF0F2H025BF0FB5HFF0F2H022H1E46025BD0EE5HFF0F2H025E4D2A025BA0FE5HFF0F2H02662H3A6D5B042H023B153A0269023E025B042H023B153E02662H3E91015B042H023B153E02690242025B84012H02050E4E123794F45HFF0F4E025BAC012H0269022A025B042H023B152A02662H2A6D5B042H023B152A0269022E025B042H023B152E02662H2EED0170022A025B702H0269022A02662H2AA9015B042H023B152A0269022E025B042H023B152E02662H2EDD015B042H023B152E0269023202662H32A901690236025B042H023B153602662H36910169023A025BD0FE5HFF0F2H02662H42F10169024602662H46F1015B042H023B15460269024A025B042H023B154A02662H4AA9015BD4FE5HFF0F2H020E2H262A6D2H26555B846HFF0F2H025BF4F95HFF0F2H0270024A020E2H464A5B002H024A2H46D10137ECF95HFF0F46025B282H0269024A025B042H023B154A02662H4AF1015B002H0269024E025B042H023B154E02662H4EED015BC06HFF0F2H025BF8012H02690622025B042H023B152202662H22E9015B042H023B1522025EBD0126025E112A025B002H02310222025B042H021DFA0622025BDCEB5HFF0F2H021E0A32025B88F25HFF0F2H025E95012A025BF8EB5HFF0F2H025EE50146025B886HFF0F2H0210E0EB5HFF0F2A025BF4FB5HFF0F2H025ED50146025BD8F15HFF0F2H025B80FB5HFF0F2H021E062A025B80FB5HFF0F2H025B302H022B2H2A2E5B202H0270022E025B042H021DA2072E026D2H2E655B002H021F2H2EC901582H2E5D5BD86HFF0F2H024D5D2H2A03BE06DE06AE051E2246025BC8EF5HFF0F2H0210E8EA5HFF0F22025BE8EC5HFF0F2H025E2546025BE4FB5HFF0F2H025E6532025BB86HFF0F2H0231024A025B042H021D6A4A02700246025B042H021DE6054602122H468D015B002H0237E4EA5HFF0F46025B082H021E2252025BD06HFF0F2H025BECFE5HFF0F2H0210F4F95HFF0F2A025B98F05HFF0F2H022H1E46025BBCF75HFF0F2H0237C8FE5HFF0F2A025B542H02700222025B042H021DFA0422021E0626025B182H02662H2691015B042H023B1526021A0A2A1E672H2A415BCC6HFF0F2H0231021E025B042H021D9A051E026D2H1E49690222025B042H023B152202662H229101690226025BC06HFF0F2H025BACEA5HFF0F2H025B002H021E0622025BB8FE5HFF0F2H021E162A025BBCF95HFF0F2H021E0A2A025B84EA5HFF0F2H02690226025B042H023B152602662H26F10169022A025B042H023B152A02662H2AED015B042H023B152A02700226025B042H021DB60526025BD4EA5HFF0F2H021E162A025BB4FE5HFF0F2H025E794E025BD8EE5HFF0F2H025BE4FD5HFF0F2H021E0A2A025BD4F35HFF0F2H025BF46HFF0F2H0205867A00D8ED7C45005F2H004900AB033H005755E6AB063H007E2C12A496BAAB053H0004E5BF934DAB093H00D55E08BFED7C029EBAAB063H00729FE6C83887AB093H00B891D51929C4FC1EF202004B004D59190100B866EDD816006AF7B56A4B3BE3CC36044H00EFE72H005BBC012H025BB8012H025BB4012H025A132H023B192H025E1D2H024692072H0246A6072H025B8E0672AE075F8A0196058A070ED601D204CE0628FA06C602FA032F8203D603FA0548FA019201A60541C6028E07EA01730E1A92065B7C2H0244020A025B3C2H025C0206025B042H021D320602033H02090206025B042H021DDA030602690206025B042H023B19060266020A0D5C0206025B2C2H025E090E025BD46HFF0F2H02662H0A055B042H023B190A025C0206025B042H021D9A030602692H060266020A095BD46HFF0F2H02690206025B042H023B19060266020A155B8C6HFF0F2H02690206025B042H023B19060266020A115B042H023B190A025C0206025B042H021D922H06026902060266020A015B042H023B190A0210906HFF0F0A025BC8FE5HFF0F2H0201655A00330E4D60305F2H008900154CE0742515C8050015A4EABF0A9302FAFF1525A40AB639990B0015E54C748AAF4DFAFF15F1223FD593060D001500DEF7F5FDFF1B001537E9088F4H001595CA83F873C6040015685ABB034H001568397C078C39FBFF15FF036H0015A328ED969AB7F1FF154C5117982558F5FFAB063H00ED24D3CB5ED4AB093H00438509D3F171A0EFCB15F805DFE8CE38F5FF153FC279FF668A050015F57D62154H0015561BA5ECB920F6FF15797B039C1D93F8FF151613F83B6AB3FCFF1572666E7172E62H0015889AA3400B10F3FF156H00100015AB3688B4B3D90500AB043H00109CB0BC15AEEB7C1C85D20C001545863C204H00153EDC8FE9C9D52H00AB053H00342C5937BE15BA7F54AC3456F7FFAB043H0005263EC415027H00158A0EF67CFE690F0015017H00AB033H00490EB21550AB129AA034F4FF157F23FA0B63DDFDFF15ACC48B72E1F30D0015ECCBDDDC383CFAFF1584D72DB3E8E4F0FF15F29B5F508D192HFFAB043H00A06003A71525989B4399AEFBFFAB073H00C424A8130976C11580A774983BC4F2FF159B37E86B19000200AB043H0067E13060AB053H00EB53789B8315B1F692EB165C0C0015CA182H98DEE42H00157D18D9984BC6FBFF150FCB2ACA8CE001001535C72F948FBA080002001F001D59190100044DCB721A00DA09CA8E129BA80A6F164H0083EA2H005B84012H025B80012H025B7C2H025A0F2H023B152H025ED9012H024692072H0246B6072H0221FE05F6049E035EC607BA07AA0338F602EA01FA0569F206CE2H02229A02BE029A045B502H025B202H021E1632025BE0102H0210F4103A025BD4072H021E022E025BD8102H0210980F2A025BE43H021E263A025BE06HFF0F2H0210800C2E025BD8012H021E0236025BB4072H025BC46HFF0F2H021E0232025B8C122H021E1A26025BC80A2H02690216025B042H023B151602662H163569021A025B042H023B151A02662H1AC10169021E025B002H02662H1E755B042H023B151E02690222025B042H023B152202662H22C1015B042H023B152202690226025B042H023B152602662H26BD015B042H023B152602730E2A0E5B002H023788032A025B8C0E2H02700236025B042H021DCA02360270023202402H3212378C0E32025B082H021E122E025B9C062H025E7932025BF80D2H02662H328D015B042H023B15320270022E025B042H021DDA052E025BA40A2H0269022E025B042H023B152E02662H2EC101690232025BCC6HFF0F2H025BE40A2H021B2H32125B082H021F2H2E5D5B242H023H32055B002H021E22360231022E025B042H021DCE012E02322H2E9501582H2E155BD46HFF0F2H02582H2E89012B2H2A2E4D89012H2A5B002H024FFA059A06E6051E162E025BB4FD5HFF0F2H025BB80A2H025E2D32025BD4042H025B8CFD5HFF0F2H025BE4012H021E1A32025B8C3H021E162E025BC4042H025BA40A2H021E0A2A025B880E2H025BFC072H0270021602582H162169021A025B042H023B151A02662H1ABD015B082H0237A80D2E025B402H0269021E02662H1EBD015B042H023B151E0269022202662H227569022602662H26355B042H023B15260269022A025B042H023B152A02662H2ABD01110A2EB9015BB86HFF0F2H025BF0FE5HFF0F2H02662H1AC1015B042H023B151A0269021E02662H1E8D015B042H023B151E0270021A025B042H021DB6051A025BBC032H0269021A025BCC6HFF0F2H0210E40C2A025BD0FE5HFF0F2H025BCC062H021E1A3A025BE8FC5HFF0F2H025BE06HFF0F2H0210CC0342025B8C0B2H0210900842025BD0032H025ED5012A025BC00A2H022H1E2A025B9CFB5HFF0F2H02310246025B042H021DDE074602700242021A2H420E052H421637E00A42025BB03H021A2H32025BA8012H02662H42C1015B002H02690246025B042H023B154602662H46BD015B782H020E1E2H4A5B9C012H02662H4E8D015B042H023B154E0270024A025BE46HFF0F2H0269023202662H328D015B042H023B15320270022E025B042H021D9A012E02612H2A2E5B002H02582H2A1D6D2H2A290D81012H2A5B5C2H0231022A025B042H021D96022A0269022E025B042H023B152E02662H2EC1015BAC6HFF0F2H0269024E025B906HFF0F2H0269024A025B042H023B154A02662H4AC1015BE46HFF0F2H021E1A360231022E025B042H021DC2012E025E2532025BAC6HFF0F2H025E614E025B90FE5HFF0F2H0269022E02662H2EBD015B042H023B152E02690232025B042H023B153202662H32A901690236025B042H023B153602662H36A90169023A025B042H023B153A02662H3AC1015B042H023B153A0269023E02662H3EBD015B042H023B153E02690242025BD8FD5HFF0F2H025BC8FB5HFF0F2H025B98FB5HFF0F2H0210CCFA5HFF0F32025BF0FC5HFF0F2H0210880E2E025B8C052H025EC5013A025B94092H0210C00836025BE8072H025BCCF85HFF0F2H0210ACFB5HFF0F1A025BF8082H02052H2E0E37A0F85HFF0F2E025BC46HFF0F2H0231023E025B042H021DF6033E0270023A025B042H021D1A3A02732H3A0E5B082H025EA10146025BD86HFF0F2H0237D0F75HFF0F3A025BC0F75HFF0F2H025E0942025BB4042H02662H3A755B042H023B153A0269023E02662H3E355B8C012H0270023E025B042H021D9E043E0270023A025B042H021DA6073A02612H3A0E602H3A1237B8043A025B8C3H026D2H264569022A025B042H023B152A02662H2ABD015B042H023B152A0269022E025B042H023B152E02662H2EA9015B002H02690232025B002H02662H32355B042H023B153202690236025B042H023B153602662H36355B042H023B15360269023A025BDCFE5HFF0F2H02690242025B042H023B154202662H4235690246025B042H023B154602662H46C10169024A025B042H023B154A02662H4A655B042H023B154A0269024E02662H4E755B042H023B154E02690252025B042H023B155202662H52755B042H023B155202179D015685017002520270024E025B042H021DCA064E020E2H4E1670024A025B042H021DCA064A02700246025B042H021DE2024602700242025B042H021D860142026D2H420D0E2H421A5BCCFD5HFF0F2H025B90F85HFF0F2H0210ECFD5HFF0F26025B84F75HFF0F2H025ECD0132025B80F75HFF0F2H025E513A025B8C3H0269021E025B4C2H02582H1A555BF06HFF0F2H0231022A025B702H0231021A025BE86HFF0F2H02662H2EA9015B042H023B152E026006320A5B88012H02662H267569022A025B042H023B152A02662H2AA9015B002H0269022E025BCC6HFF0F2H02662H1EBD015B042H023B151E02690222025B042H023B152202662H22355B042H023B152202690226025BB46HFF0F2H025E3132025B886HFF0F2H02700226025B042H021DE2022602612H2602700222025B042H021D8E0622021E12260231021E02582H1EB5011B2H1E025EA50122025BDCFE5HFF0F2H0237FC0332025BC8F35HFF0F2H021E0E2E025BF0082H02202H421137DCF75HFF0F42025BF0F55HFF0F2H021C92038E039602690226025B042H023B152602662H26C1015B042H023B15260269022A02662H2A8D01700226025BD4FB5HFF0F2H025E990142025BA4F75HFF0F2H021084F45HFF0F3A025B90F75HFF0F2H021E1A42025BB03H021E0A3E02310236025B042H021DFE0236021E1A3A02310232025B042H021DA606320270022E025B042H021DC2052E0270022A025B042H021DBE012A021E222E025B682H026D2H226D690226025B042H023B152602662H26BD015B042H023B15260269022A025B042H023B152A02662H2AC10169022E02662H2E755B042H023B152E02690232025B042H023B153202662H32A9015B042H023B15320269023602662H36BD015B382H02310222025B986HFF0F2H02310226025B042H021D7E2602582H2669612H2616602H261E3788FC5HFF0F26025B382H021E123E0270023A02482H3A225BA8FE5HFF0F2H0269023A025B042H023B153A02662H3AC1015BDC6HFF0F2H02700226025B042H021DBE0726021E0A2A025BA06HFF0F2H025BA8F85HFF0F2H021E0E2A025BF0F45HFF0F2H025E4142025B7C2H022H1E36025B4C2H0210B4F55HFF0F32025B9CF35HFF0F2H025B88F35HFF0F2H025EAD0142025BB4F85HFF0F2H02105C42025B8C062H024A2H323D37CCF75HFF0F32025B382H0269023E02662H3E8D0170023A025B042H021D82073A021A2H363A1E1A3A02310232025BD06HFF0F2H0269023A025B042H023B153A02662H3A355BC86HFF0F2H025BA46HFF0F2H021E0642025B94F45HFF0F2H023790F45HFF0F42025B0C2H02612H421E632H42595BEC6HFF0F2H025BE06HFF0F2H0210E40132025BCCEF5HFF0F2H02108CF75HFF0F2E025BE4F05HFF0F2H025E491A025BA8F25HFF0F2H021E0A3E025B002H02310236025B042H021DA20736024A2H36D1015B002H0237CCF65HFF0F36025B8CEF5HFF0F2H0237D0F65HFF0F1A025BA0012H0269022E025B80012H0270021A025B042H021DD2051A020E2H1A025B002H02402H1A0E5BD46HFF0F2H02690232025B042H023B153202662H328D015B002H0270022E025B042H021D92022E020E2H2A2E69022E02662H2EC1015B042H023B152E02690232025B042H023B153202662H328D015B042H023B15320270022E025B042H021D7A2E0231022602700222025B082H02662H2EC1015B946HFF0F2H0270021E025B002H02322H1EC9015BE8FE5HFF0F2H025B88F25HFF0F2H02612H32061E12360231022E025B042H021DC6072E02112H2E7137F0F45HFF0F2E025BA0F05HFF0F2H025B80F25HFF0F2H02662H36C10169023A025B282H025E393A025BB4012H02482H2E325E4D320231022A025B042H021DB2062A02602H2A0637F4EC5HFF0F2A025BE03H02662H3A8D015BAC3H02662H2AA90169022E02662H2EBD015B502H02690236025B042H023B153602662H363569023A02662H3A8D015B042H023B153A02700236025B042H021DA207360231022E025B042H021DD2052E0269063202662H32B1015B042H023B1532025E7D36025BF0FE5HFF0F2H02690232025B042H023B153202662H32A9015B402H02700236025B042H021DE2063602482H361A1E163A025BB4012H02310232025BC4FE5HFF0F2H02700222025B042H021D1622021E0226025B302H026D2H2E91011E1A32025B382H02690236025B042H023B153602662H36C1015B042H023B15360269023A02662H3A8D015B9C6HFF0F2H0231021E025B042H021DDA031E02582H1E195B142H0231022A025B042H021DEA052A02700226025B946HFF0F2H02690222025B042H023B152202662H22BD015B042H023B152202690226025B002H02662H26C10169022A025BD4FD5HFF0F2H02700236020E2H32365BD8FD5HFF0F2H021B2H2E0E5BE8FE5HFF0F2H02310232025B042H021D82053202142H3201690236025BECFC5HFF0F2H025BE4FC5HFF0F2H025BC4F95HFF0F2H020568C600212F2A42FB5E2H000900AB7C3H005438B9868A05F6827D497B15B64470108A1C036DFC152E68C90A8EE53F49B2FC01F1867C6A31FA7B53E85ABB8F3F02F36BF0E250DC270349ABB5EEDF1838C0CAF2CE6456181C95427CC82CDE20182CDE46DDC363BC1AAA329FDCCE87E50FB3BFDCE645737FC94A1F2387318475DD349E08848330CFB5C7066FAB61C501001959190100815EF3B552002HB1D1F011C7F4D620024H00CAE72H005B442H025B402H025B3C2H025A0F2H023B052H025E092H02468A072H0246B2072H020E8A03CE07B20622FA02CA04FA0318EA07CA058605739201F202CE0241B607BE07A20645EE06FE05860205F601A204920135D206FA018A011D9A05BA068E03505ADE07E205693H025B042H023B052H025E0106025C3H025B042H021D9A3H02033H02005FE0009E34672H385F2H007D00156FB31995330E05001533885B25EB230500152A1EB091EE94FCFF15126FB5D9D5C1F3FF1572B65548AD2501001594486167E72A0600156E1263B6F8480D001564EBA426420AF7FFAB063H00B03BBA84439B15077570F6B588F2FFAB093H00329956527F8C2B452A15FF6754F604B5F9FF157A8BFB384H00AB043H00EF416FB51533769CF079CA2HFF15B45B0F7EE8B2F3FF15D8B8626B4A770D00AB043H001BA0F01A156H00100015D6F7825DB531F8FF157D9DBC0823BAF9FF157D72D0184H0015950B737E078FF5FF15B9EFA75B92C3FCFF15347E6B492F8BFAFF15FF37972DFB4A06001567D9783AF6800A0015B01B130E21B10B0015C51AD620AF05F0FF15AA877F3D4H0015F6245474BD3D0F00AB093H00070B4EEB1C23AF1C1FAB043H0090D0DF25157718BB324365F9FF154A95206341F3FEFFAB093H000CBE1EC5D8D6ABE644AB053H00A16720640B1516C85F7014B6F7FF150E6E6B09B006F0FF151E49BB70948F060015DE09B419EBD30E0015A2D7782E54B7F5FFAB093H00A62B8F23C47AB3441E15F8062H251B980600AB043H0013D9308215486251033ECE0A001562B63FAC06990F00159647D2A0DE4EF4FFAB033H007F0074AB093H00966E70A0913988F30E15D3107138538AF9FFAB053H0043476483C3158CA4AAC237080C00AB073H00E0B8E8AB3D3A8915017H0015027H0015A6106DB5B2A5F3FF15F14BF2D182560700AB093H00C7A28B3CF1927ED1DF15B76829C48CF7F3FF15FF036H0015FA0A2H251B98060002001F001D591901007EE77A400D007111D1CC26990BFD271B4H00E6EA2H005B9C182H025B98182H025B94182H025A132H023B1D2H025EF9012H024686072H0246BA072H0248AE04E2019202379E02D201AE063A428606A6041CCA03C207960110B2039607FA05219A05F606BE010BAE06F603F6065F9E068A07EE0365C6049603DE035BD8172H021E0656025BC8062H025B082H021E0636025B402H025E4D62025B840E2H0210E01656025BF0062H021E1236025BF8042H023H66C1015B102H02662H6221690266025BEC6HFF0F2H025BFC162H02700262025BF46HFF0F2H02690262025BE06HFF0F2H02112H367137D80636025BB8162H02690262025B042H023B1D6202662H62215BCC3H021E0E420231023A025B90032H0269025A025B042H023B1D5A02662H5A81015B84032H0269022E025B042H023B1D2E02662H2E35690232025B042H023B1D3202662H3221690236025B582H02662H3A81015B042H023B1D3A0269023E02662H3E8101690242025B042H023B1D4202662H42355B102H0269023A025BD06HFF0F2H021A2H36265BC03H02690246025B042H023B1D4602662H4681015B042H023B1D46022A514A1E5BF4012H02662H3691015BC86HFF0F2H0269023A025B042H023B1D3A02662H3A81015B042H023B1D3A0269023E025B042H023B1D3E02662H3E215B042H023B1D3E0269024202662H42B1015B042H023B1D420269024602662H46CD0169024A025B042H023B1D4A02662H4A2169024E025B102H0237C01462025BD0012H0231023E025BE8FD5HFF0F2H02662H4E910169025202662H523569025602662H56CD015BDCFD5HFF0F2H022H1E4E0231024602700242025B042H021DEA0742025E2D46025BC46HFF0F2H02690266023H66C1015B042H023B1D66027002620260162H625BA06HFF0F2H02690232025B042H023B1D3202662H32B1015B042H023B1D3202690236025B042H023B1D3602662H36355B94FE5HFF0F2H021B2H4A0E5B946HFF0F2H02700236025BD4FD5HFF0F2H0269025E025B042H023B1D5E02662H5E81015BB4FC5HFF0F2H02582H2A6D5BE0FC5HFF0F2H02700232025B042H021DDA01320270022E025B042H021D86072E026D2H2E655B886HFF0F2H025BA4122H0210E01046025B983H0210F0FB5HFF0F36025BA4FB5HFF0F2H021E0E56025BACFB5HFF0F2H0231022A025B042H021D86022A0270022602700222025B042H021D622202582H2275690226025B042H023B1D2602662H26215B88012H0270023202612H32061E0A36025B242H0269023A025B042H023B1D3A02662H3AC101700236025B042H021DC6063602612H32365B342H0231022E025B042H021D9A012E025E890132025B846HFF0F2H02662H2ECD015B042H023B1D2E02690232025B042H023B1D3202662H32CD015B0C2H02042H320E37C01232025B342H022D0A36157002320269023602662H36215B886HFF0F2H0269022A025B042H023B1D2A02662H2AB1015B042H023B1D2A0269022E025BA06HFF0F2H025BBC0C2H02222H560E37F40F56025B402H025B88FE5HFF0F2H025B6C2H025EBD012A025BC0FD5HFF0F2H025BD8032H0210DC0526025B082H021E0246025BBC0E2H025BC00F2H025E6956025B80092H021E062A025BF4052H021E0656025BE40F2H025E7956025BA80F2H021E022A025B90042H021E062E025BFC0B2H0210ECFD5HFF0F36025BE8F85HFF0F2H02402H3206372432025B482H0210E0FC5HFF0F2A025B482H021E1232025BE46HFF0F2H021E1632025BF4102H021E022A025BE06HFF0F2H0210A80B32021E0A32025BA00B2H0237E8FC5HFF0F36025B102H020E2H360A5B002H02202H36A1015BE86HFF0F2H025B800E2H021E0232025BD06HFF0F2H025BC8FE5HFF0F2H0210DC0942025BB0032H025EE9013A02310232025B602H0270022A025B042H021D4A2A026D2H2A11402H2A265B88012H025E4536025BD46HFF0F2H02700226025B042H021DEA072602582H26555B542H02662H2E81015B042H023B1D2E02690232025B042H023B1D3202662H32CD015EB9013602700232021A2H320E5B102H02482H2E325B986HFF0F2H02662H32D5015BA86HFF0F2H021E22360231022E025B042H021D8A042E02690632025BE06HFF0F2H0269022A02662H2A355B042H023B1D2A0269022E025B946HFF0F2H02378C092A025B84092H025BEC0D2H025B582H025E1D32025B302H0210C40A56025BA00D2H0269023602662H36215B042H023B1D360269023A02662H3AC1015B042H023B1D3A02700236025BD0082H0270022E021E06320231022A025B042H021DCE062A02052H2A0237F0082A025BB0032H025E0D42025BDCFD5HFF0F2H025E092A025BDC082H025E990156025BA0082H021E022A025BAC082H025E95012E02310226025B042H021D1E260269022A02662H2A2169022E025B082H02402H262A5B142H02662H2EC1015B042H023B1D2E0270022A025BE46HFF0F2H0237D8FB5HFF0F26025B0C2H021A2H2E1270022A025BB06HFF0F2H025BF4072H025EED012E025BE86HFF0F2H025E1932025BC0072H026D2H2AD1015B002H02122H2A5937FCFB5HFF0F2A025B90FC5HFF0F2H025BA8062H02690242025B042H023B1D4202662H42215B042H023B1D4202690246025B042H023B1D4602662H46C1015B042H023B1D4602700242025BC46HFF0F2H02222H562237D4FD5HFF0F56025BC0FD5HFF0F2H0269022A02662H2AB1015B042H023B1D2A0269022E025B082H02582H1E415B202H02662H2EB10169023202662H322102B501361E379C0636025B342H021E1A2A025B242H0269022202662H2235690226025B042H023B1D2602662H26215BA46HFF0F2H0270021E025BB46HFF0F2H02310222025BF06HFF0F2H025BAC0A2H02052H2A0E37F4052A025BBCFD5HFF0F2H02690632025B042H023B1D3202662H32D5015B042H023B1D32025E4536025B282H026D2H2E5D5BD86HFF0F2H02310232025B042H021D4E32021A2H2E325B002H02052H2E1A37D8052E025B082H025E7D3A025BD86HFF0F2H025B90052H025BD4FC5HFF0F2H02662H5A215B042H023B1D5A0269025E02662H5EC1015B042H023B1D5E0270025A025B042H021D96045A02042H565A37D40456025B2C2H025E39660231025E021E0E620231025A025B042H021D96045A02700256025B042H021DCE02560269025A025BA06HFF0F2H025B9CF85HFF0F2H02662H562143E5015AA5015B883H02690642025B9C012H02310242025B042H021DA60742020E2H3E425BA4012H021E26420231023A025B042H021DD2023A02700236025B042H021D9E073602482H360E5B9C3H02662H4291015B042H023B1D420269024602662H4681015B042H023B1D460269024A025B042H023B1D4A02662H4AB1015B042H023B1D4A0269024E02662H4E355B042H023B1D4E0269025202662H528101690256025BE0FE5HFF0F2H0237A8F05HFF0F56025BE0012H026D2H32F1015B242H02662H42D5015E4546025B082H02482H56065BB0012H025E8D014A025BC8FE5HFF0F2H02582H3E9D015BD4FE5HFF0F2H020DDD012H325B002H0269023602662H362169023A02662H3A81015B042H023B1D3A0269023E025B042H023B1D3E02662H3ECD015B042H023B1D3E02690242025BB8FE5HFF0F2H02700256025B042H021D8A035602202H56615BF8FE5HFF0F2H02322H520170024E025B042H021D364E0270024A025B042H021DFA044A02700246025B042H021D8E0746021E224A02310242025B042H021D8E06420270023E025BA4FD5HFF0F2H025EF5013A02310232025B0C2H0270025202612H52165BA86HFF0F2H026D2H32AD015BA0FE5HFF0F2H025B80F55HFF0F2H0210BA01E201FA031F2H36495B0C2H022B2H32364DD9012H325BE86HFF0F2H02582H36D9015BEC6HFF0F2H0270023E025B042H021DE2053E02690242025B002H02662H42CD01690246025B042H023B1D4602662H46C1015B042H023B1D46027002420231023A025B042H021DA6063A020E2H3A0A700236025B042H021D3236026D2H36315B8C6HFF0F2H021E2E56025BB0F95HFF0F2H025BC03H0210A4FA5HFF0F2A025BA4F45HFF0F2H021090F55HFF0F36025BE0042H021098FD5HFF0F56025B94032H025BB0F45HFF0F2H021098F75HFF0F32025BDCF65HFF0F2H0210B4F85HFF0F2A025B98F45HFF0F2H025BC8F45HFF0F2H025B98042H02222H320637E06HFF0F32025B94F85HFF0F2H025BE03H0210A8F55HFF0F2A025B883H0245BE03BA03D20610E8F75HFF0F2E025BF4F75HFF0F2H02662H4ACD015B042H023B1D4A0269024E025B042H023B1D4E02662H4EC10170024A021A2H464A69064A02662H4AD5015B142H0231024A025B042H021D8E024A02222H464A5B2C2H025E454E025B1C2H0269024A025BAC6HFF0F2H02310246025B042H021DB20146021A2H46225BE46HFF0F2H025EA90152025BC06HFF0F2H0237ACF05HFF0F46025B4C2H0269025A02662H5A215B042H023B1D5A0269025E02662H5EC1015B042H023B1D5E0270025A02310252025B042H021DD602520270024E025B042H021D96064E025E8501520231024A025EC9014E025B906HFF0F2H025BA03H02662H2EC1015B042H023B1D2E0270022A025B082H0269022E025BE46HFF0F2H025BC0FD5HFF0F2H0269022A025B042H023B1D2A02662H2ACD015BE06HFF0F2H021E0A2A025B94F35HFF0F2H027002420269024602662H46CD015B042H023B1D460269024A025B042H023B1D4A02662H4AC1015B042H023B1D4A0270024602612H42465B002H02052H42165B002H02379CF25HFF0F42025BD8F35HFF0F2H025E2526025BE4F05HFF0F2H025BF4F05HFF0F2H02690236025B002H02662H36215B042H023B1D360269023A02662H3AC1015B042H023B1D3A02700236025B042H021DE60136025B9CEE5HFF0F2H021E1A26025B84F65HFF0F2H0210BCF55HFF0F56025B80FC5HFF0F2H02690646025B102H025E454A025EC5014E025B0C2H025BECED5HFF0F2H02662H46D5015BE86HFF0F2H02310246025BEC6HFF0F2H025BCCE95HFF0F2H02042H5616371C56025E0556025B142H021E2A56025B98FD5HFF0F2H025EE10136025B94F05HFF0F2H025BB06HFF0F2H0210A8EF5HFF0F56025BD4E85HFF0F2H025E3D2E025B042H025BB8F25HFF0F2H0210F8F55HFF0F2E025B9C012H0210DCF65HFF0F62025BC0E85HFF0F2H021E2256025B98F25HFF0F2H021E0636025BA4F05HFF0F2H0269021E025B042H023B1D1E02662H1ECD0169022202662H2281015B042H023B1D2202690226025B142H0231022E025B042H021D82042E02732H2E1A5B382H02662H26B10169022A025B042H023B1D2A02662H2A910169062E025B042H023B1D2E02662H2ED5015B042H023B1D2E025E4532025E2936025BB46HFF0F2H0237E8FE5HFF0F2E025BBCFA5HFF0F2H0210E4EE5HFF0F32025B84EE5HFF0F2H0269022E025B042H023B1D2E02662H2ECD01690232025B042H023B1D3202662H32C1015B042H023B1D320270022E025B002H025BA4F45HFF0F2H0207526903163B6A35FD5E2H00C100AB023H00509E15017H007C01020016004259190100A033C6BE2F00C3E9D193020AA1B61A094H00DAE72H005B442H025B402H025B3C2H025A132H023B012H025E0D2H024682072H0246A2072H023E4AAE01DA010EEE06F604A20726E6018E06920761F603D207A2022F5E9E07A2031DB206AA01A20173CA018207B6055B082H025E091E024FFA058E06E60544020A020A020E0200020A065B102H02567A9201FE03240212025E0516025B182H025E050E02690212025B042H023B0112025E0116025BD86HFF0F2H02550C0E02500A1E1A2502041E5BB06HFF0F2H0228F06HFF0F0E0269060E025B042H023B010E0239020E02033H02014833008297F754025F2H005D00AB0B3H00EA309F59A928082H0B699FAB0B3H0085E12C5A34ADF65EB9D3F315017H00AB083H00EC760D5E0651CBDBAB053H00A45E95AAD17C00AB073H008DF9E43FB82E0BAB0C3H00D8BAC1BE71C5DB8B715FFA8E020042004359190100F68C33741E0035C185A7658D3BC37F054H00D8E72H005B302H025B2C2H025B282H025A132H023B1D2H025E212H02469A072H0246A2072H024FCE03AE04920573C60262CE0738B2069605DA0250CA049202A2021B82062EAA01443H02690206025B042H023B1D0602470D02066902060247050206690206025B042H023B1D060247110206690206024719020669020602470102063D1D0215692H06025B042H023B1D060269060A020ADA06DA06CA03582H0A091E020E025F0A060E1E02060210BA01B601FA0345BE03BA03D20600AAA8007F258606FA5E2H008900020010004459190100419A92A3630027A486405B1892D373054H00D3E72H005B3C2H025B382H025B342H025A132H023B012H025E052H02468A072H0246AE072H02263266E2065BE607AE059E0719D204B605EA0765DA036AC60561B207A20392031B9E01EA04B2023ACE07C2019A053AEE039A0212693H025B042H023B012H024402060269020A025B042H023B010A0269060E0271020E025B042H021DDA070E0269061202410612025B042H021DA604120241020A02423H026C3H0245F605F2055E005FB60088CBC204FE5E2H00450015017H00AB083H00CC5392AA9C6E2F3151158H00090028002700260042002400210022002300465A190100169D000FBF9D69FA5E2H00B90001000759190100C567A1967A009108C9E7192AC8D355034H00C0E72H005B302H025B2C2H025B282H025A0F2H023B012H025E052H024686072H0246AA072H024CDE01E602CE0421429A07B60240D203B604A60246D603EA03E2042B228E01AA051E0206020C0206021C92038E03960201D9FB6E8F150070B075456E5B18905F104H0085E82H005B90062H025B8C062H025B88062H025A1B2H023B052H025E112H024696072H0246BA072H0223C205FE068A045F52BE079E01728604EE058A053AB207BE069A0362AE05BE06D20461CE02F601CE035BD206C602FE0335D207960486045BD0052H0210581E025B94042H025BE4042H0210E40212025BAC042H02090236025B042H021DBA053602692236025B042H023B0536021E163A025B682H021E2A3A021E2E3E02090236025BC4012H02090236025B002H02692236021E263A021E2A3E025BA0012H025806220D5B642H02090236025B042H021D8A0336021E2236025B3C2H02090236025B042H021DCA053602692236025B042H023B0536021E0A3A021E163E025BF8FE5HFF0F2H021E1A3E025B302H021E2E3A025B142H02581E320D5B5C2H0210BA01E601FA031E263E025B846HFF0F2H021E323E025B9C6HFF0F2H02580A260D58162A0D5B642H02090236025B042H021DEE033602692236025B042H023B0536021E1A3A022H1E3E02090236025B282H0209023602692236025BACFE5HFF0F2H02692236025B946HFF0F2H02692236025B002H021E063A021E0A3E025BD4FE5HFF0F2H02692236025B042H023B0536021E223A025B806HFF0F2H02581A2E0D5BECFE5HFF0F2H0245BE03BA03D2065312220210BC0106025B88012H021E021A025B502H022712160269161A025B042H023B051A02691A1E021E0222025B5C2H02691216025BD46HFF0F2H026D122A0141121E025B042H021DC2061E0224021A025B042H021D221A025E091E025B1C2H025E052A025B0C2H02580E1E016D1222015BA46HFF0F2H025A032E025B886HFF0F2H02691E22025B042H023B0522021E0226025BD06HFF0F2H02580E26015BA46HFF0F2H025BA8012H02690E22025B042H023B052202390222025B042H021DFA0122025B88FC5HFF0F2H02690E22025B042H023B052202390222021084010A025B182H02390222025B002H025BC0FC5HFF0F2H02690E22025BEC6HFF0F2H025B342H02690E22025B002H02390222025B042H021D9A0122025B502H02690E16025B042H023B051602390216025B042H021DEE0116025B98FE5HFF0F2H02690E22025B042H023B052202390222025B182H02690E1602390216025B042H021D9A0416025B88FB5HFF0F2H025BF0FE5HFF0F2H0210F4FA5HFF0F1A025BCCFE5HFF0F2H0210F46HFF0F16025B8C6HFF0F2H025E05120231020A025B042H021D4A0A0271020A025B042H021D82030A02690A0E025B082H0210CCFA5HFF0F0E025B482H021E0212025E0516025B1C2H02690206025B042H023B0506021E020A025B002H025E050E025B082H02413H0E5BC86HFF0F2H02310206025B042H021D56060269060A021E020E025B8C6HFF0F2H025BF8F95HFF0F2H0201D31B0031358738FD5E2H0041000E8H000E6H00F03F0E7H0040005A190100B81C02AE260E25005F2H003100AB043H0064E32H4B15087H00AB073H00B8D676BD65D7B1AB023H00634015017H00AB053H00CDC88EC084005E190100A5FE007F51322C025F2H00150015207H00153H00014H0015037H0015407H001500016H0015107H0015087H00152H00015H00043H0003000200045919010024E76975220033DC410310FB649255084H00F7E72H005B88012H025B84012H025B80012H025A172H023B012H025E212H024692072H0246A2072H02086A1EB606627E8A02D20421C206EE04061E9E0212FA073F8E07DA03FA073EAE048A01C20304AE05DE0782025B4C2H0245BE03BA03D206310216025B142H02690E16021E061A025B102H021E0A1A025B742H021A2H12164FFA058206E6055E151E02310216025B042H021D2A1602072H16111A2H12165B682H02690E16025BCC6HFF0F2H02693H025B042H023B012H02692H06025B042H023B010602692H0A025B042H023B010A02690A0E025B042H023B010E02582H0E095B002H0241120216690E12021E0E16025B302H025E011E0231021602072H161D5B002H021A2H12165BE0FE5HFF0F2H02690E16025B042H023B0116021E021A025E191E025BC0FE5HFF0F2H025E0D1A02310212025B042H021DB2011202072H12055BE8FE5HFF0F2H02006C36004688406A055F2H00610015147H000E6H00F0410E6H00304315FF036H0015017H0015207H0015027H002H157H00158H0015FF076H00151F7H0002000600055919010085ADAEEB59001053CA883D392B8A64094H000AE82H005B602H025B5C2H025B582H025A0F2H023B012H025E2D2H024692072H0246B2072H0249CE0692057A4CEA01C604CE0118BE07228E0708D603AA043E5EBA069205CA061AEA03B6048E0740FE06D204C2031D4AD602DA0722D60796040A15BA0296069A025B182H025E111A021E1A12025E211A021E1A0A025B002H025BC0012H02693H025B042H023B012H02713H025B042H021DEE3H0269020602710206025E110A0269060E021E0612025E1116025E011A0227120E02072H0E051A2H0E02690612021E0616025E1D1A025E291E02272H1202690616025B042H023B0116021E061A025E151E02310216020D112H164FFA04FA04F20651128401215B582H0207161A211F2H1A215B082H0207161A214FFA058A06E60510BA01CA01FA035B282H025B4C2H020D192H1A5B082H022B2H1A1E03BE06CE06AE052B162H1A1F0E1E095B002H021A0A2H1E5BE46HFF0F2H026D121A0D5BD46HFF0F2H0210C46HFF0F1A025BAC6HFF0F2H021C92038E0396025B1C2H0207161A115B002H021F2H1A215BE06HFF0F2H02630E1A2137D86HFF0F1A025BE46HFF0F2H02510EF0FD5HFF0F215B8C6HFF0F2H025112C06HFF0F255B946HFF0F2H020001A600EC81705CFD5E2H005D0015017H00158H0015FF7H0004000600040007000559190100B8A552056C0037DB0BE11714C1911E124H0088E82H005BBC062H025BB8062H025BB4062H025A172H023B012H025E0D2H024692072H0246B2072H023B9604FE04DA0149F601C605AE0322B203D201E20650AA038E04A204629E07EA07CA06259A0166A606608A03B206AE043B9205FE05C604729A034AAA03348A06EA029A0125E603860692055BF0052H0271023A025B042H021DBA063A025BF0042H02690A3A025BE86HFF0F2H025BF46HFF0F2H025F36123A5B082H0237D8043A025B1C2H0269023602710236025B042H021DFA073602690A3A0271023A025BDC6HFF0F2H025BCC6HFF0F2H025BD0042H0269023602710236025BF06HFF0F2H02440212025E0516025E091A025E011E0255F40216025E092A025B082H025E0526025BF06HFF0F2H025E012E02550426025BB4042H0228B40226025BFC032H025B042H025BC06HFF0F2H0269063A025B042H023B013A02690A3E0271023E025B042H021D0A3E02690A42025B042H023B014202410642025B042H021DDE07420224023A025BC4FE5HFF0F2H026906260269022A025B042H023B012A0271022A0269022E0241062E025B042H021DC2032E022402260269062A0269022E0271022E025B042H021D86072E0269023202410632025B042H021DDE05320224022A025B042H021DA2042A025F26122A6906260269022A025B042H023B012A0271022A025B042H021DCE032A0269022E025B042H023B012E0241062E025B042H021DA2052E02240226025B042H021DD206260269062A025B042H023B012A0269022E025B042H023B012E0271022E02690232025B042H023B013202410632025B042H021DEA02320224022A025B042H021DEE012A025F26122A5B282H02289CFD5HFF0F2H025BC4FD5HFF0F2H02690A36025B042H023B013602710236025B042H021DFE01360237C00136025BECFC5HFF0F2H0228F0FD5HFF0F16025B182H025E0116025B002H0269021A0271021A025E011E02558C0116025BE46HFF0F2H024106420200023A065B742H02690E36025B042H023B013602690A3A025B042H023B013A0271023A025B042H021DAA013A0269023E025B042H023B013E0241063E025B042H021DDE033E02240236025B042H021DDE07360246063A02690A3E025B042H023B013E0271023E025B042H021DE6033E02690242025B886HFF0F2H025F36123A5B8C6HFF0F2H025F36123A5BFCFB5HFF0F2H0228E4FB5HFF0F16025B80FC5HFF0F2H021080FB5HFF0F3A025B182H02690A3A025B042H023B013A0271023A0250122H3A5BE06HFF0F2H025BD8FB5HFF0F2H026C3H0269062H02690A06025B042H023B0106027102060269020A025B042H023B010A0241060A025B042H021DFE020A02423H025E012H02690206025B042H023B010602710206025E010A0255B0FD5HFF0F2H0245BE03BA03D20600992100F9D4BA1FFD5E2H002D00158H0015017H0015028H00591901000FA487C6110032A62DD440672DC455074H00E9E72H005B742H025B702H025B6C2H025A132H023B012H025E0D2H024686072H0246BA072H0238D201B6021A4CF2049E03DE0216FE02F603E2031E8E05AE04AA0116D2068603BA0465EE079E07CE0719BA01AA041A5B382H025B9C012H025E0112025B282H023A022H125B002H02042H120E377C12025B102H026D060E050D092H0E1A0E120E5BDC6HFF0F2H025B0C2H0203BE06C606AE0537E46HFF0F0A025B1C2H025E0512025B502H0226022H0E5B1C2H020D092H123A2H0E125B282H026D060E055B002H020D092H0E5BDC6HFF0F2H026D0A12055B002H026D0616055B102H022H0E2H1203BE06C606AE05330E12055BF06HFF0F2H020E2H1216582H12055BB86HFF0F2H0210986HFF0F12025BE4FE5HFF0F2H0245BE03BA03D20603333500F4F0892CFD5E2H00A500158H0015017H0015028H0059190100A7E943A235009236EFD746C1AA9E560A4H00F9E72H005B84012H025B80012H025B7C2H025A0F2H023B012H025E0D2H02468E072H0246A6072H0249E606DA06FE046B9606E206B20319AE012E0629AE02A6019A050B9E018605FE0225D205C201FE065B4C2H021F2H1E09070A22091E220A025B002H022H1E06021E1A2H025BB8012H020E061E165BDC6HFF0F2H020E021A121F2H1A095BEC6HFF0F2H025B94012H0259012C065B202H025BF46HFF0F2H025B90012H025E010E025BF46HFF0F2H025E050A025BF06HFF0F2H021E0E12024B0212025B182H025B2C2H02210274065BC46HFF0F2H0233021209590128125BE86HFF0F2H0233021209330616095B002H0249129C6HFF0F165B582H021C92038E0396021A0E160A1E160E025B002H020E0216121F2H1609070A1A091E1A0A021E162H025B282H025BECFE5HFF0F2H021A0E1A0A5B002H021E1A0E025BEC6HFF0F2H021E0612021E122H025B082H0259018C6HFF0F025BE0FE5HFF0F2H025901F4FE5HFF0F025B886HFF0F2H025BD06HFF0F3H0233AC0409570063B577AB38A92A33780A4H00E5E72H005B702H025B6C2H025B682H025A2B2H023B0D2H025E192H024686072H0246A2072H0273FA02F6059E065FF201BA05D6064CA605DA015A5BEE07E202CE035EF204AE06EA0226C603FE06DA04190A8207A6013B5EBA04EE015B302H025B102H02390226025BF46HFF0F2H021E2226025BF06HFF0F2H021E222602710226025B042H021DD2042602370426025BE06HFF0F2H021C92038E0396023B092H02662H02153B090602662H06015B042H023B0D06025E110A021E060E025B242H025A0F16025B282H0231020E025B042H021DAE010E025A1312025BE46HFF0F2H025A0B22025B9C6HFF0F2H025E0D12025E0516025BD86HFF0F2H025A031A025A071E025BE06HFF0F2H020057EBD7AE2F008EECCF0C376A1E7234024H00DBE72H005B742H025B702H025B6C2H025A132H023B052H025E112H02469A072H0246B6072H021EAA02A605A60455AA051EAA0621CE0416F6075FE607A60182013BD6028E05DE0338EA05C207CE0519D602B606DE0205F604D601EA051CA203CA018E075B302H0245BE03BA03D206502H02065B002H02440206025E010A025B202H0241062H025B042H0255280A022CA2059A05DA016B0A2H025B142H025A032H025BE06HFF0F2H0245020E025E0512025BDC6HFF0F2H025E0906025BB86HFF0F2H0228040A025B0C2H025F1602065BF06HFF0F2H026C3H025BFC6HFF0F2H0200F7C103E31A8917FA5E2H00DD0003004A0048004B5919010001F2CC4B41007EC41EF873ABD91251054H00DAE72H005B782H025B742H025B702H025A172H023B012H025E052H024682072H0246B2072H0210D20622CE0115DE059607EA0361E606B60396064896059206B20426B203A206960305CA01CE06AE0330E603B607FE025B3C2H0269060A021E020E02567A8A01FE035B002H023C020A025B042H021DFE060A02692H0A025B042H023B010A021E020E025C020A025B042H021DCA020A025B242H0237202H025B202H025BB86HFF0F2H0210140A025B0C2H0269020A02502H0A025BEC6HFF0F2H025BE46HFF0F2H021C92038E0396025BE86HFF0F2H0201632900B358D2090E5F2H007100AB053H007E541759B7AB053H001F43964A47AB063H00F0022526A095AB053H00CE04C7E053AB063H006F334606EC37AB083H00AD95C87D2F7ACE90AB073H00D52DE0DF08AABFAB4H00AB063H0090A2458A11FDAB063H006EA46756B76D7C017C00AB023H000C8851AB093H00167CBF2E0559D780CAAB0C3H004BD72A7F3A28682H1252F1DFAB063H00875B6E63F4BCAB0B3H00C53DF0D836C5B7F28464B0AB063H0054DE018F4163AB0B3H00B2A0A3C76364B9533E42DC030042001000465C19010002E600934CDA3DFC5E2H00F1007C007C0100591901006B42AF9D3D00F90D25510C87D29A16044H00CBE72H005B482H025B442H025B402H025A0F2H023B092H025E0D2H024686072H0246A6072H025006A203D2041DD602EA04F20255628204BA0225AA07E601960157EA01F60592074FFE05FE015249CE02AA04FA0245DA07AE05BE034FDE079606C20255C206DA026A19EA05FE01F20544020A026E020A016E060A05502H0A025B042H023B090A0216C606C606E2051C92038E03962H02F59903A401131FFA5E2H00310001000359190100229FB6485D003EE84DA5562BC0D45D054H00C9E72H005B482H025B442H025B402H025A0F2H023B012H025E052H02469A072H0246AE072H025EBA0306C20226FA02AE04FA2H044AA601B60148D602B2029E033E029A047A3B4AAA078A0305C607CE025A18A201BE06B602609E02E203D2071AB205C204DA0265CA03CA049E0719A602A602CE0469020E025B042H023B010E0203C206BE06AE0545BE03BA03D20601A43F035A8BDA0BFA5E2H00ED2H005919010010D57C9A76006F611B117A53A47C10034H00C2E72H005B3C2H025B382H025B342H025A0F2H023B012H025E052H024682072H0246A6072H020BB603B205AE071BAA03BE05CE0722E604BA06A2026BCE07CE01CA0522F202D603C605559A03FA07225B042H0245F605F2055E567A7EFE036C020602001DF7CCC10A00154AA6C328C0F27258194H009AE82H005BD0032H025BCC032H025BC8032H025A1B2H023B512H025E452H024696072H0246A6072H022126A603DE0257C607BA077A654EB606B6010EFE0586031A5EEE078E028E0230AE06BE0586045BF605C2039A035B94032H022H1E3A022H1E3E025B983H02041E323H1E36025BC8012H02622H3E4A5BC83H025F2H0E1E690A1E025B042H023B511E021E0622025B382H020E1E4E1E5B94012H025E2926025B5C2H022H1E4A025BC86HFF0F2H02601E2A1E5B3C2H021E0E2A02310222025E29260231021E025F2H0E1E5BCC012H021E0E26025A072A021E0E2E021E0E3202410E2A025B042H021DB6072A02240222025BAC6HFF0F2H02221E2E1E5BF0FE5HFF0F2H025E1D1E025B8C012H0209021E025BF06HFF0F2H025E1D4602132H42025E1D46025B2C2H022H1E42025BE86HFF0F2H021E0E26025B8C6HFF0F2H02132H36025BACFE5HFF0F2H022B1E521E261E561E5B3C2H022H1E3A025BE46HFF0F2H022H1E4A025B082H022H1E3E025B182H02132H46025B002H025E314A021E4A1E021A1E4A1E5BA8FE5HFF0F2H022H1E42022H1E46025BACFE5HFF0F2H02571E5A1E5B642H022H1E4202622H3A425BC06HFF0F2H02051E221E731E261E5B94FE5HFF0F2H02690A1E021E062202500E260E5B042H023B5126021E0E2A02310222025E2926025B002H0231021E025BB8FD5HFF0F2H02500E421E5F1E0E425BC8FE5HFF0F2H02690A1E025B042H023B511E021E0622025BBCFE5HFF0F2H023A1E5E1E3D450A35033H025A0B2H025A03060244020A0269020E0247450A0E47190A0247090A0247250A0247210A0247490A0247410A0247110A02470D0A0247050A0247010A0247390A0247150A02474D0A022H3D0A2D69060E025B042H023B510E02440212021E0A160231020E02690A12021E0616021E0E1A021E0E1E021E0E22021E0E26021E0E2A021E0E2E0270022A025B042H021D1A2A021E0E2E0241062E0241021E025B042H021D2A1E02240216025E291A02090212025B042H021DCA051202690A12025B042H023B5112021E0616021E0E1A021E0E1E021E0E22021E0E2602132H22021E0E26025E1D2A02132H26025E1D2A021E0E2E02132H2A0241121E025B042H021D5E1E02240216025B042H021D8E0516025E291A0209021202690A12021E0616021E0E1A021A0E1E0E2B0E220E262H220E570E260E3A2H22260E2H1E22310216025E291A02090212025B042H021DF6071202690A12021E0616021E0E1A021E0E1E021E0E22021E0E26021E0E2A0271022A025B042H021DBE062A021E0E2E021E0E320270022E021E0E32021E0E36021E0E3A02410E320241021E02240216025E291A0209021202050E120E37201202400E120E5B182H02220E1A0E37A8FC5HFF0F1A02040E1A0E5BA0FC5HFF0F2H02730E160E5BE86HFF0F2H02600E160E37E06HFF0F16025BEC6HFF0F2H020082CA00548C922FFA5E2H00D50002003C004A591901001C2627792100411FE51B199C2E8712054H00DEE72H005B682H025B642H025B602H025A0F2H023B012H025E052H02468E072H0246AE072H022BCE0752DA04464AE606AE066BF6078202EA066AAE03F604D201378A01DA03F2070EF604AA05D6061BD206BA06860329A601C603AE07378605E201BA025B242H02502H0602106406025B0C2H021E062H02692H06025BE86HFF0F2H025B042H025B0C2H025B3C2H0237442H025B082H021E0206025BD86HFF0F2H02690206025B042H023B010602502H06025B002H0210C06HFF0F06025BCC6HFF0F2H025F020A0E5B142H021E060E025BF06HFF0F2H024402060269060A025BEC6HFF0F2H0245BE03BA03D206016D3C003AB9740D035F2H002100158H00AB4H00AB073H00D12DFF2AACBC1815017H00AB073H00CCD7331E222HC81500016H005115027H00AB083H0067D6CE41374DF4CC07001B0022005100530056001C0058591901007A79FDD72500D77BB3632B5D17A87B0F4H003BE82H005B8C012H025B88012H025B84012H025A0F2H023B012H025E152H024696072H0246A2072H021A52EE03D2020EDE028E07FE0535FE03AE026A5FB2037AE60330B6028601EE056282037ADE045B542H025B102H025106C02H015B2C2H021E1A06025B082H021E161A025BF06HFF0F2H025BC8032H025B88032H025BB43H0228C8011A025BD06HFF0F2H021E0612025B482H025BF46HFF0F2H021E06120270020E025B042H021D92030E02510E28215B202H026602060D5B042H023B01060266020A1D5B042H023B010A0269020E025BC86HFF0F2H025BE0012H02510E64095BA06HFF0F2H021E1206025BE03H02661A1E0D5B042H023B011E02661A221D5B042H023B012202691A26025B042H023B012602502H26225B002H021E062A025F221E2A6E261E195B002H025B883H024FEA04F604F2065BB06HFF0F2H025B943H026C424EEA011E1206025BF06HFF0F2H02510E8402115B9CFE5HFF0F2H02690A2A022B2H2A125B1C2H021E162A025B002H0269122E025B242H025BA0FE5HFF0F2H021E2A12025BF46HFF0F2H02690E2E025B042H023B012E021A2H2A2E332H2A155BE06HFF0F2H02690632025B042H023B0132021E0636021E263A02310232021B2H3212502H2E325B042H023B012E02132A16025B906HFF0F2H025BF8FE5HFF0F2H0245F605F2052H5E0D1E02272H12025B2C2H02690E1A025B042H023B011A021A2H161A5B402H021E1612025E0516025E1D1A0245061E025E0D22025590FD5HFF0F1A02690A16025B042H023B0116022B2H16125BC06HFF0F2H02690612025B042H023B0112021E0616025B082H02332H16155BB86HFF0F2H025E0D1A025B906HFF0F2H0268B4FD5HFF0F12025BCCFC5HFF0F2H021E0A16025B002H0219FE04FE04BE0564E86HFF0F1202691612025BE86HFF0F2H02013CF570A40E001CB89CCA391BF31104694H003BEF2H005B80072H025BFC062H025BF8062H025A632H023B012H025EA5072H02468A072H0246B2072H0221CE049605FA024FA6038E06F60126860656CA061DAA05E207B2053FF604C204C60448D20696019E05169A02FA05321CA602769A0546BA04EA050E5BBC062H025EC906E62H025BC0312H026DC202C2029904501EC202C2025B042H023B01C22H025DC2028C17015B082H0210AC1FC22H025B90312H025BF4152H02108835DA2H025BF0192H025EFD03DE2H025BFC0E2H02661ECA02255B042H023B01CA2H025BD8202H021E1AD22H023902D22H025BB82F2H025E9105CE2H025BD8322H0210BC11DE2H025BC0152H0210B820CA2H025B302H02667EC202DD055B042H023B01C22H02667EC60285065B042H023B01C62H02667ECA02C5035B042H023B01CA2H02667ECE026D7002CA2H025BC86HFF0F2H025BC4242H021E8A02C22H023602C22H021EF202F62H022E06F62H021EC202EE2H024FFA05DE08E605661EC202C9015BC4FE5HFF0F2H022870E22H025BDC2B2H02667EC602C5035B042H023B01C62H02667ECA02C5035B042H023B01CA2H02667ECE0285065B1C2H027002CA2H027002C62H02661ECA02C90105C602C602CA025B002H0237F82AC62H025B1C2H02661ED202115B042H023B01D22H027002CE2H025BD06HFF0F2H02667EC202DD055BA86HFF0F2H025BFC2D2H025BDC352H0233F202F202D5041EF202DE2H025B8C6HFF0F2H021BDE02F202CA021E8601F62H021EDE02FA2H027002F62H025B042H021D8A03F62H025FF202DA02F6025B002H022BC602F202DE021AF202F202CE025BC86HFF0F2H02667EC20285065B042H023B01C22H02667EC602DD055B042H023B01C62H02667ECA028504661ECE02C5055B042H023B01CE2H02661ED2022560CE02CE02D20237EC15CE2H025BCC242H02661EC602E5055BAC2F2H021E6ACA2H021E0ECE2H02410ACA020E5B042H021D1ECA2H0237F82BBA2H025B202H021E06BE2H02410ABA020E1E6AC22H021E0AC62H02410AC2020E5BCC6HFF0F2H021E6ABA2H025BE06HFF0F2H025BEC212H025EE10626025BF8082H025ED104AE2H025BF8012H025ED906AE2H025BDC3H025EE105B22H025BB40A2H025E9906AE2H025ED102B22H025BD4012H025E9104AE2H020902A62H025B042H021DE207A62H021EA202A62H025BA0062H020902A62H025BA0032H025EC50522025BAC6HFF0F2H0266769A01A9035BB8042H025A0F8A2H025BB8032H025A139E2H025BB0082H021EA202A62H021E8A01AA2H025BCC072H021E8601AA2H025B88082H021EA202A62H021E3EAA2H025E8D01AE2H025BE43H025EED03B22H025BA4012H025EE902AE2H020902A62H025B042H021DCE01A62H021EA202A62H021E5EAA2H025E8D05AE2H020902A62H025B042H021DD204A62H021EA202A62H021E62AA2H025BE4012H023BB502BA01025B042H023B01BA010266BA01BA01D1045B042H023B01BA01023BB502BE01025B042H023B01BE010266BE01BE01715BB03H021EA202A62H025BDC082H025312A62H025BD4052H025EF902B22H025312A62H025BC0062H023BA103E601025BA8042H020902A62H025B042H021D8A03A62H021EA202A62H021E72AA2H025BF8FD5HFF0F2H021EBA01AA2H025BCCFD5HFF0F2H025312A62H025B9C3H020902A62H021EA202A62H025B80072H025EA1042E025BB43H0219C2029E02CE045BECFD5HFF0F2H02667AB201D103667AB601E9035BE0FE5HFF0F2H0237F00EA62H025BC8082H025EB105B22H025312A62H025B042H021D9E04A62H021EA202A62H025B88062H025EB90236025EA9023A025BA8012H023B85034A023BED054E025B042H023B014E023BE90152025BF8012H025E8107AE2H020902A62H025B042H021D8A03A62H021EA202A62H021E66AA2H025BB8042H025EE903AE2H025BDC3H025EBD02B22H025312A62H025B042H021DEE01A62H021EA202A62H025BC8FE5HFF0F2H021EA202A62H025BC83H020902A62H021EA202A62H021E42AA2H025E5DAE2H020902A62H025B042H021DD604A62H021EA202A62H021E46AA2H025B80042H0244028E2H025A33922H025B442H023B8505C201025BA8052H025E9505B22H025312A62H021EA202A62H025BD03H023B8D013E025B042H023B013E023B5D42025B042H023B0142023B8D0446025BB8FE5HFF0F2H021EA202A62H021EA601AA2H025B9C062H025A37962H025A2F9A2H025BECFB5HFF0F2H020902A62H021EA202A62H021E4EAA2H025EED05AE2H025BB8FB5HFF0F2H025ED90432025BF8FD5HFF0F2H0266769E0199065B042H023B019E01026676A201795BC8012H023BE90356023BE9025A025B042H023B015A023B8D055E025B042H023B015E023B810762025B042H023B0162023BA50266025B042H023B0166023BA5066A025B042H023B016A023BC5016E025B042H023B016E023B910472025BD8012H023BF5067A025B042H023B017A023BB5057E025B042H023B017E023BA1028201025B042H023B0182010266768601FD045BFC3H021E9E01AA2H025BF0F95HFF0F2H020902A62H021EA202A62H025BF8042H021E52AA2H025BF8012H023B8D07EA01025B042H023B01EA01023BB503EE01025B042H023B01EE01024402F201025BE8032H021E6EAA2H025EC501AE2H025B803H026676A601B1045B042H023B01A601026676AA01D906667AAE01E9045BD8FB5HFF0F2H025312A62H025BDCF95HFF0F2H021EB601AA2H025EE903AE2H025BB8FC5HFF0F2H025EE904AE2H025EA505B22H025312A62H025B042H021DB603A62H021EA202A62H021EB201AA2H025ED103AE2H025BF0FC5HFF0F2H025312A62H025B042H021D9E04A62H021EA202A62H025BE03H023BF90476025BA0FE5HFF0F2H021EA202A62H021EA201AA2H025E79AE2H025BA4F95HFF0F2H025312A62H021EA202A62H021E9601AA2H025E9902AE2H025EE102B22H025BBC6HFF0F2H025EA502AE2H020902A62H021EA202A62H021E6AAA2H025EA506AE2H025B80FA5HFF0F2H025E8D04AE2H020902A62H025B042H021DC605A62H021EA202A62H021E4AAA2H025E8503AE2H025BBCFC5HFF0F2H025EE901AE2H025B80FA5HFF0F2H025E9107AE2H025E8106B22H025312A62H025BA4F95HFF0F2H021EA202A62H021EBE01AA2H025E71AE2H025EF902B22H025312A62H026B06A62H025BFCF95HFF0F2H020902A62H025BA83H025EF106FA01025B903H025EDD012A025BC8F95HFF0F2H025EFD04AE2H025ED905B22H025BF4FD5HFF0F2H021EAE01AA2H025B80FE5HFF0F2H025A17A22H025BDCF75HFF0F2H0266768A0191075B042H023B018A010266768E01B9055B042H023B018E01026676920199035B042H023B019201026676960199025B84F75HFF0F2H021E56AA2H025BF4F95HFF0F2H023BC101C601025B042H023B01C601023BC504CA01025B042H023B01CA01023B45CE01025B042H023B01CE01023BFD05D201025B042H023B01D201023BB903D601025B042H023B01D601023B8902DA01025B042H023B01DA01023B21DE01025B042H023B01DE01023BC902E201025BE0F75HFF0F2H021E9A01AA2H025EA903AE2H025EED04B22H025312A62H021EA202A62H025BDCFB5HFF0F2H025A07F601025BA4FE5HFF0F2H025312A62H025B4C2H021E8E01AA2H025EB905AE2H025E9502B22H025312A62H025B042H021DD206A62H021EA202A62H021E9201AA2H025E9903AE2H025EB103B22H025BE4FC5HFF0F2H025EB104AE2H025B88F55HFF0F2H025EF106FE01025EF106822H025A3F862H025BBCF55HFF0F2H021EA202A62H025BD0F55HFF0F2H021EA202A62H021EAA01AA2H025BDCF45HFF0F2H021E5AAA2H025BDCF55HFF0F2H025BF8292H025BEC032H0232DA02DA0291025B242H0237DC22DE2H025B5C2H025E9507E22H023102DA2H025BE46HFF0F2H023102E22H025B402H025ED503EA2H025BF06HFF0F2H026DDA02DA028102667EDE0285065EF101E22H027002DE2H025B042H021D9A02DE2H026676E202E9035B042H023B01E22H025EED01E62H025BCC6HFF0F2H0214DE02DE02C50212DE02DE02CD065BA46HFF0F2H020EDE02DE02E2025BEC6HFF0F2H025B980F2H02661ECE028D025B042H023B01CE2H025B98082H021E8A02D22H023902D22H025B801F2H02661ECA02255B042H023B01CA2H023102C22H026DC202C20255501EC202C2025B042H023B01C22H025DC202C0210D5BFC1A2H0252FC1AEE2H025BF8262H026C02C22H0245F605F2055E5BD4272H025BB8052H021090EF5HFF0FC22H025BC0F05HFF0F2H021ED602EA2H020902E22H025B042H021DB201E22H025BD80B2H021ECE02E22H027002DE2H021E9A02E22H021ED602E62H021EDA02EA2H020902E22H021E9A02E22H025B082H021ED202DE2H025BD86HFF0F2H021EDA02E62H021EDE02EA2H020902E22H025B002H021E9A02E22H025B1C2H021EBE02DA2H025B002H027002D62H021ED202DA2H021EC602DE2H027002DA2H025BC46HFF0F2H021EDE02E62H025B886HFF0F2H025A3BD22H021ED202D62H025BD06HFF0F2H02109C07DA2H025B881F2H0268DC208603025BBC152H02667EEA02C5035B002H025EF103EE2H025B542H0258DE02DE02AD05667EE202DD065B042H023B01E22H02667EE60289055BD86HFF0F2H026DE202E202B1015B482H02667EEA0285045B042H023B01EA2H02667EEE026D5B042H023B01EE2H027002EA2H0248E602E602EA025EE503EA2H023102E22H0232E202E202155BC86HFF0F2H02559C1DC22H027002EA2H025B042H021DA205EA2H027002E62H025BB86HFF0F2H022722C62H025E11CA2H025BDC6HFF0F2H025EDD02C62H025BDC202H0273CE02CE02D2025B002H02379C04CE2H025B182H02667ED202C5035B042H023B01D22H02667ED6026D7002D22H025BD86HFF0F2H025B80142H021E9601FA2H025EAD02FE2H025E7D8203025B2C2H021E8201F22H021EBA02F62H025BE46HFF0F2H0213F602F62H02410EEE020E5B042H021D8E04EE2H0237D823EE2H025B142H021E6AEE2H025BD46HFF0F2H025E7D8603022712FA2H025BD46HFF0F2H025BAC172H025BD0092H02518203C003C9045B0C2H0250D602FE02FA0233DE028203C5055BEC6HFF0F2H025BC8092H026C02C22H026EFE02F6021D5BE80A2H026DD202D2029106667ED602C503667EDA02DD055B042H023B01DA2H02667EDE02DD055B042H023B01DE2H020161E2029D01378419E22H025B742H02501EC202C2025DC2028017B1065B3C2H02661EC602CD055B042H023B01C62H0258C602C60289017002C22H02661EC602C90148C202C202C602661EC602CD051AC202C202C6025B082H02667EC20285065BD06HFF0F2H022DC202C202E1046DC202C202A5035BB86HFF0F2H025BFC1D2H024ADE02DE02BD0137A4EB5HFF0FDE2H025B981C2H025BF80F2H021E8A02AA2H023902AA2H025BF06HFF0F2H025BC41E2H0210B00AD22H025BEC0C2H025BA8092H027002C62H025B042H021DAA07C62H025EB904CA2H023102C22H025B042H021D8A03C22H02661EC602C5055B042H023B01C62H021BC202C202C6025B002H0258C202C202E905501EC202C2025DC202C81F655BEC1A2H021E8A02C22H023602C22H025BAC252H021E8A02C22H023902C22H025B042H021DDE04C22H025BA4EC5HFF0F2H02667EDE028504667EE2026D7002DE2H025B042H021D8202DE2H025BB81B2H0228BC0AC22H025BDC102H027102C22H025B042H021D26C22H025EE906C62H025E11CA2H025EE103CE2H025E49D22H026F0AD62H025B042H023B01D62H024402DA2H022BC602DE02D2025B002H021ADE02DE02CE025B142H025EAD06E62H025E11EA2H02559CEA5HFF0FE22H021E02C22H025BB06HFF0F2H0233DE02DE02D5045EC904E22H025BE06HFF0F2H02379020F22H025B94212H0210A41ACE2H025B9C042H02661EC602CD055BAC212H025E9D02D22H025BEC1A2H0266FE028203E5055B042H023B018203021E728603025B002H021E82038A030256028E0302648CFA5HFF0F8603024402E22H023DE505E202253DD101E202113DC505E202C9015A4FE62H024402EA2H025A0BEE2H0247BD04EA02EE025E11EE2H02039208AE08B2065E11F62H0255AC0CEE2H02661ECE02D1013102C62H025B002H027002C22H025B282H027002CA2H025B042H021D8E04CA2H02661ECE02C5055B042H023B01CE2H0261CA02CA02CE025BCC6HFF0F2H025DC202B8FC5HFF0F85015B0C2H026DC202C202F502501EC202C2025BEC6HFF0F2H025BF4F75HFF0F2H0210C414C62H025BF40B2H025B8C062H0210B86HFF0FCE2H025B8CF75HFF0F2H025BC41C2H027002D62H0214D602D602A90558D602D602D9025B502H022DDA02DA02F9055BE86HFF0F2H025EED06EA2H025B2C2H02667EE202DD055B042H023B01E22H025EA504E62H025BE46HFF0F2H023102DE2H025B042H021DFA02DE2H024ADE02DE02D9013740DE2H025B202H023102E22H025B042H021DAA03E22H025E8907E62H025BD46HFF0F2H02667EDA02DD06667EDE02DD065BB46HFF0F2H025BB8052H025BD01C2H025B881E2H023902C22H025BC41F2H021E8A02C22H025BF06HFF0F2H0210BC15DE2H025BB00A2H025B801E2H02667EDA02C503667EDE026D5B042H023B01DE2H027002DA2H025BFC1A2H02667ECE02C503667ED2026D5B042H023B01D22H027002CE2H025B042H021D9602CE2H020ECA02CA02CE0258CA02CA02DD04667ECE02DD06667ED202C503667ED6028905667EDA028506667EDE02C5035B042H023B01DE2H02667EE2026D5B042H023B01E22H027002DE2H0254A904DE02DE027002DA2H027002D62H027002D22H026676D602E9035EED01DA2H025EF501DE2H023102D62H023102CE2H026DCE02CE029504667ED202DD05667ED602DD05667EDA02C503667EDE026D5B042H023B01DE2H027002DA2H0211DA02DA02810137D4E45HFF0FDA2H025BA8112H025BBCE75HFF0F2H025E3DCE2H025BDCFB5HFF0F2H025EED02CE2H025BFC152H0210A011C22H025BD00F2H02661ECA02D1015BE0F95HFF0F2H025EF102D22H025BA40D2H02661EC202115BE4F45HFF0F2H024402BE2H025B002H021EAE02C22H021E6EC62H025B202H021E8201C22H025E9D03C62H025B8C012H025C02C22H025B042H021D66C22H021EA602C22H025B80012H025C02C22H021EAE02C22H025B642H0237E416CE2H025B8C012H021EA202BE2H025BC46HFF0F2H025312BE2H025BA86HFF0F2H025A1FBA2H021EBA02BE2H020F02C22H025B582H025A1BC62H02667ECA0285065B042H023B01CA2H02667ECE0285045B042H023B01CE2H02667ED2026D5B042H023B01D22H027002CE2H025B042H021DD204CE2H0263CE02CE02395B9C6HFF0F2H021E62C62H025BF4FE5HFF0F2H025EA102CA2H025B9C6HFF0F2H023902C22H025E11C22H025BA86HFF0F2H025C02BE2H025B042H021DBA07BE2H025EB504BA2H025BF4FE5HFF0F2H025BB81B2H02661EC202D1015B042H023B01C22H025BF8FD5HFF0F2H021EE6028203021EFE028603025C028203025BC4092H026C02C22H0228E00FC22H025BBC1B2H025BB8132H0237C018DE2H025B642H027002D62H0258D602D6028906667EDA02DD06667EDE0285045B042H023B01DE2H02667EE202DD055B002H025ED502E62H025B002H02667EEA02C503667EEE026D5B042H023B01EE2H027002EA2H025B042H021DAE02EA2H023102E22H025B042H021DC201E22H027002DE2H025B042H021DCA04DE2H0267DE02DE02F5045B946HFF0F2H025BD8122H025EF104E22H025BD80E2H021E8A02D22H023902D22H025B042H021DD203D22H025BD0F25HFF0F2H02528CF55HFF0FFA2H025BB0162H025BA4F85HFF0F2H025B8CF75HFF0F2H025B88142H025BF0102H02501EC202C2025B042H023B01C22H025DC202D0E25HFF0FD5065B082H0258C202C202255BE46HFF0F2H025BC8E15HFF0F2H025BF4102H025EB501CA2H025BB4102H025BC4182H0264EC15EE2H021E72EE2H025B002H021E8E02F22H025B002H0219DA07DA07BE055BE46HFF0F2H026676D602E9035B042H023B01D62H025EED01DA2H025ED505DE2H023102D62H025B042H021DFE06D62H021BD202D202D6025E09D62H023102CE2H025B042H021D9E01CE2H026DCE02CE029103667ED2028905667ED6028905667EDA02DD06667EDE028504667EE2026D7002DE2H024ECD01DE02DE025E9101E22H023102DA2H027002D62H027002D22H025B042H021DDE05D22H02667ED602C5035B042H023B01D62H02667EDA026D7002D62H0260D202D202D60237E017D22H025BCC032H025BC0F55HFF0F2H021E12D22H023902D22H025BF06HFF0F2H02661ECE0289035B042H023B01CE2H0205CA02CA02CE0237FC19CA2H025BB0062H0210E0FC5HFF0FDA2H025BE4E05HFF0F2H02667ECE0289055B042H023B01CE2H025E75D22H025B002H027002CE2H025B042H021DA604CE2H027002CA2H025B042H021DD206CA2H02661ECE02C5055B042H023B01CE2H023102C62H025B042H021D1AC62H027002C22H025B042H021DFA04C22H02667EC602C503667ECA026D5B042H023B01CA2H027002C62H0240C202C202C60237C4EE5HFF0FC22H025B102H02667EC2028504667EC602DD05667ECA0285065B806HFF0F2H025BA0142H025BE0112H027002D62H025B042H021DB204D62H0222D202D202D60237F4F25HFF0FD22H025BE8012H023102DA2H025BAC012H02667ECA02DD06667ECE02DD055B042H023B01CE2H02667ED202C5035B442H025A2BC62H025BE06HFF0F2H023102CA2H026DCA02CA0295015B4C2H025E11C22H025BE46HFF0F2H027002D62H025B042H021D3AD62H025E4DDA2H023102D22H025B042H021DD605D22H02667ED602C503667EDA026D5B846HFF0F2H02667ED602C503667EDA026D7002D62H025B042H021D9206D62H022DD602D602FD025B582H02667ECE02DD06667ED202DD06667ED60285045B042H023B01D62H026676DA02E9035B042H023B01DA2H025EED01DE2H025B002H025E19E22H023102DA2H025B886HFF0F2H021BD602D602DA027002D22H025B042H021D8601D22H025EC905D62H023102CE2H025B002H025E9D06D22H025BD0FE5HFF0F2H026676DA02E9035EED01DE2H025EB906E22H025B98FE5HFF0F2H025BC4F95HFF0F2H025EA101DE2H025B800B2H0228C4EF5HFF0FEE2H025BCC0E2H025B840C2H025EAD01E62H025BE8092H025E8D03DE2H025BECDB5HFF0F2H02661EC6028D025BC4082H025A47A62H021EA602AA2H023902AA2H025B042H021DEE06AA2H024402AA2H025A4BAE2H025B282H021EA602AE2H025E1DB22H020902AA2H025BD06HFF0F2H0210B8F75HFF0FFE01025B182H025A43B62H025BF06HFF0F2H021E42AA2H025BD86HFF0F2H025A03B22H025BE86HFF0F2H025BC80A2H025BD4EA5HFF0F2H025ED106CE2H025BA8F35HFF0F2H023794EC5HFF0FCA2H025B9CF35HFF0F2H025B880A2H025BD0DA5HFF0F2H023102D62H025B582H02667ED2026D7002CE2H025B382H0237C40CD22H025BBC012H027002DE2H027002DA2H025B302H025A23C62H02667ECA02DD065B042H023B01CA2H02667ECE02C5035B042H023B01CE2H025EAD04D22H025B6C2H0248CA02CA02CE0214CA02CA02C5065B302H025ECD04DE2H025BA06HFF0F2H025E9905DA2H023102D22H025B042H021DBA02D22H0263D202D202055B9C6HFF0F2H022DCA02CA0281055B002H02667ECE0285045B806HFF0F2H026DCA02CA02C104667ECE028506667ED202DD06667ED602DD05667EDA0285045B042H023B01DA2H02667EDE02C5035B042H023B01DE2H02667EE2026D5BE4FE5HFF0F2H027002CE2H025B042H021DD607CE2H025E8103D22H023102CA2H025BA86HFF0F2H025E11C22H025BD0FE5HFF0F2H025BE4F75HFF0F2H025B94F45HFF0F2H022BC6028203DE025B002H021A82038203CE023382038203D5045B002H021E8203DE2H025BF0FC5HFF0F2H025BE8FD5HFF0F2H025BDC0E2H0237D409E62H025BBC032H023102D62H025B042H021DC602D62H025E8904DA2H025B642H025EED01EE2H025B542H027002DA2H025B042H021DB605DA2H025EB102DE2H025BD06HFF0F2H027002E62H025B042H021D9A06E62H02667EEA02C5035B042H023B01EA2H02667EEE026D5B042H023B01EE2H027002EA2H025B9C012H025EED01E62H025EC105EA2H023102E22H027002DE2H025BF8012H025EC106F22H025B302H023102D22H026DD202D202F9065B002H02667ED6028506667EDA02DD055B042H023B01DA2H02667EDE02DD065B042H023B01DE2H02667EE202DD055BAC012H023102EA2H0240E602E602EA025BC4FE5HFF0F2H027002CE2H025B042H021DA602CE2H0258CE02CE02CD02667ED202DD06667ED602DD055B042H023B01D62H02667EDA0289055B282H02667EEE026D5B042H023B01EE2H027002EA2H025B1C2H025EE506EA2H025BA4012H0261E602E602EA02667EEA02C5035BD86HFF0F2H02667EDE0285045BA8012H023102E22H025B042H021DBA07E22H02667EE602C5035B042H023B01E62H02667EEA026D5B042H023B01EA2H027002E62H023102DE2H025E31E22H023102DA2H025B042H021DE207DA2H027002D62H026DD602D60299015B1C2H02667EE60285045B042H023B01E62H02667EEA026D5BC8FD5HFF0F2H0232DE02DE02CD035BACFD5HFF0F2H02667EDA0289055B042H023B01DA2H02667EDE02DD055B042H023B01DE2H02667EE20285065B042H023B01E22H02667EE602DD065BD4FE5HFF0F2H025EC103EE2H023102E62H025B042H021DCA04E62H026676EA02E9035BE0FC5HFF0F2H026676E202E9035BA0FD5HFF0F2H025BAC0B2H021E8A02C22H023602C22H025BF8EB5HFF0F2H025B9CF95HFF0F2H02661EC202C9015B042H023B01C22H025BBC012H025B880C2H021EB202F62H025B002H021EF202FA2H025C02F62H025BECE45HFF0F2H02667EC20285065B042H023B01C22H02667EC60285065B042H023B01C62H02667ECA02DD05661ECE028D026676D202E9035B042H023B01D22H025EED01D62H025E9506DA2H023102D22H025B042H021D9205D22H023102CA2H0258CA02CA02292DCA02CA0281047002C62H027002C22H0258C202C20269501EC202C2025B042H023B01C22H025DC202CC0C415BB0EC5HFF0F2H021E6EAA2H025B002H021EA602AE2H027002AA2H025B042H021D8206AA2H0251AA02CCE85HFF0FF5065BECF25HFF0F2H0210F806C62H025BA0E25HFF0F2H025BA0012H0240C202C202C6023790D35HFF0FC22H025B102H02661EC602C90161C202C202C602661EC602D1015BE46HFF0F2H025B843H025BD0EA5HFF0F2H0210D00BC62H025B98EA5HFF0F2H02501EC202C2025DC202F8F45HFF0FA5015B242H02661ECA0289033102C22H02661EC602255B042H023B01C62H0261C202C202C6026DC202C202A9066DC202C202E5045BD06HFF0F2H025B98EC5HFF0F2H0210AC09E22H025B90042H021E16D22H025B002H023902D22H025B042H021DEA02D22H025B84F05HFF0F2H025EF903DE2H025BCC082H025EBD03E22H025B002H023102DA2H025B042H021D1ADA2H025B84D25HFF0F2H026676DA02E9035EED01DE2H025BDC6HFF0F2H025BCC052H025E1DEE2H022E0AEE2H021E72EE2H021EAA02F22H0219DA07DA07BE055B002H020688E25HFF0FEE2H027002E22H025B042H021DDE05E22H02667EE6028504667EEA026D5B042H023B01EA2H027002E62H023102DE2H027002DA2H025B042H021D9A04DA2H0258DA02DA029503271AC62H025E11CA2H0255F8EE5HFF0FC22H02667EC6026D5B042H023B01C62H027002C22H025B002H025BF4D05HFF0F2H02667EC20285045BE06HFF0F2H0237A4F65HFF0FC22H025BE4EA5HFF0F2H0258DA02DA02F5035B002H02271AC62H025B042H021DD601C62H025E11CA2H025580E75HFF0FC22H025E35E22H023102DA2H025B042H021D46DA2H0214DA02DA0285075BCC6HFF0F2H02667EDA02C5035B042H023B01DA2H02667EDE026D5B042H023B01DE2H027002DA2H025BACF15HFF0F2H0228B8D05HFF0FC22H025B940B2H025BBCD35HFF0F2H02109CEA5HFF0FCA2H025BACE55HFF0F2H025ED501C62H025BD0FC5HFF0F2H026676DE02E9035B042H023B01DE2H025EED01E22H025B002H025EF505E62H023102DE2H025B042H021DBE01DE2H025BC4E95HFF0F2H02661EC602C9015B042H023B01C62H025B94E85HFF0F2H025B88082H026676D202E9035B042H023B01D22H025EED01D62H025B082H023102D22H025BE06HFF0F2H025E59DA2H025BF06HFF0F2H025BFC3H02667EDA02C503667EDE026D5B042H023B01DE2H027002DA2H025B042H021DD606DA2H025BF0E75HFF0F2H025B9C0A2H026C02C22H02661EC2028D025B042H023B01C22H025B88EE5HFF0F2H021088FD5HFF0FE62H025BF4F95HFF0F2H025E8502D22H025BFCE35HFF0F2H025B90F35HFF0F2H026C02C22H025BA4FC5HFF0F2H025EE501C62H025BC8DE5HFF0F2H027002CA2H025B002H0220CA02CA02D10537A0FE5HFF0FCA2H025B943H025EE101E22H025B90052H025EFD01CE2H025B9CE15HFF0F2H0210A0E35HFF0FDE2H025B9CFC5HFF0F2H02667EC202DD05661EC602255B042H023B01C62H02661ECA02111BC602C602CA02661ECA02CD055B042H023B01CA2H0205C602C602CA0237B4E65HFF0FC62H025B94ED5HFF0F2H0210E0F65HFF0FD22H025BB0E95HFF0F2H0210E0DD5HFF0FC62H025B8C6HFF0F2H026E960392031D5B382H0209029A03025B2C2H02668E039203115B002H02668E039603E5055B042H023B0196030250E2029A0396035B042H023B019A03021EFA029E03025F9A0392039E035BC46HFF0F2H025BF0DE5HFF0F2H021E429A03025B002H021E92039E03021EEA02A203025BB46HFF0F2H025B88FB5HFF0F2H025B84F85HFF0F2H026C02C22H0210F0DF5HFF0FCE2H025BC8FE5HFF0F2H021E8A02C22H023602C22H02667ECE026D5B042H023B01CE2H027002CA2H025B042H021DB602CA2H023102C22H025B042H021DEE04C22H02501EC202C2025DC202FCCC5HFF0FB9015B082H02667ECA02C5035BC86HFF0F2H025BB0EB5HFF0F2H025EF901DE2H025BA8E15HFF0F2H021E8A02C22H023602C22H025BC8EB5HFF0F2H026676CA02E9035EED01CE2H025EBD05D22H023102CA2H025B90E65HFF0F2H025E9D05D22H025BD4EB5HFF0F2H025EC102E22H023102DA2H025B042H021D76DA2H022AA105DA02DA0263DA02DA025137B0DD5HFF0FDA2H025B7C2H02667ED60285045B042H023B01D62H026676DA02E9035B042H023B01DA2H025EED01DE2H025BC06HFF0F2H023102D22H0258D202D202DD035BD46HFF0F2H026676DE02E9035B1C2H023102D62H025B042H021DBE03D62H025E9D04DA2H025BD86HFF0F2H023102DE2H025BE46HFF0F2H025EED01E22H025E2DE62H025BEC6HFF0F2H0258DA02DA02A1065BC86HFF0F2H026676DE02E9035EED01E22H025ED903E62H023102DE2H0261DA02DA02DE025BE06HFF0F2H025BB0E45HFF0F2H021E8A02C22H023602C22H0268DC05EE2H025B98DE5HFF0F2H02667EC202DD065B042H023B01C22H02667EC6028504667ECA0285045B042H023B01CA2H02667ECE0289055B042H023B01CE2H02661ED202D1015B282H027002C62H025B042H021DC201C62H02661ECA02D1015B042H023B01CA2H0222C602C602CA025B002H023798FC5HFF0FC62H025B0C2H027002CE2H027002CA2H025BCC6HFF0F2H025B90E55HFF0F2H025EFD06CA2H025BE0042H021E8A02C22H023602C22H02102HD85HFF0FDE2H025BD0C95HFF0F2H025B98C95HFF0F2H025B9CE55HFF0F2H025EE502E22H025B482H02667EDE0285045B002H02667EE2026D7002DE2H025B042H021DFE01DE2H0240DA02DA02DE0237A8EA5HFF0FDA2H025B2C2H02667EE602C5035B042H023B01E62H02667EEA026D5B042H023B01EA2H027002E62H023102DE2H025BB06HFF0F2H023102DA2H025BB06HFF0F2H025B9CEE5HFF0F2H021EF602F22H025B082H025A27F62H025BF06HFF0F2H025BD0C95HFF0F2H025B90E85HFF0F2H026C02C22H021E8A02C22H023602C22H025EC903E22H023102DA2H025B042H021DD204DA2H025BA0E65HFF0F2H025EED01DE2H025BE46HFF0F2H026676DA02E9035BF06HFF0F2H025EBD06DA2H025BE8D95HFF0F2H025BA8DD5HFF0F2H02661EC602255B88F55HFF0F2H021E8A02D22H023902D22H025BACED5HFF0F2H021E3EAE2H021EA602B22H027002AE2H025DAE02FCEC5HFF0F1D5BD46HFF0F2H021E8A02C22H023602C22H026C02C22H025DF602D8C85HFF0FB5065B142H021E6EF62H021EF202FA2H025B002H027002F62H025BE46HFF0F2H025BE0FE5HFF0F2H0210C8DB5HFF0FD22H025BB8F85HFF0F2H0237F4E25HFF0FC22H025B182H027002C22H02661EC60289035B042H023B01C62H0204C202C202C6025BE06HFF0F2H025BF8DA5HFF0F2H025BBCF35HFF0F2H025BB4C75HFF0F2H02667EC20285045B002H02661EC602255B042H023B01C62H02661ECA02255B042H023B01CA2H0273C602C602CA0237E0F35HFF0FC62H025BCCFE5HFF0F2H025BC4E95HFF0F2H020AEE069209CA03667EC602DD055B042H023B01C62H02667ECA0285065B042H023B01CA2H02667ECE028905667ED202DD065B1C2H0258C602C60289035BA0012H02661ECA02D1011BC602C602CA025BEC6HFF0F2H023102C62H025BEC6HFF0F2H02667ED602DD055B042H023B01D62H02667EDA02C5035B042H023B01DA2H02667EDE028506667EE202DD065B042H023B01E22H02661EE60225661EEA02C5055B002H023102E22H027002DE2H025B042H021DCA07DE2H027002DA2H02661EDE022548DA02DA02DE025B002H025E8D06DE2H023102D62H025B042H021DEA07D62H02661EDA02D1013102D22H025B042H021DD203D22H027002CE2H027002CA2H025B042H021DA602CA2H025EF105CE2H025BECFE5HFF0F2H0249C202BCC75HFF0FC6025BC4D55HFF0F2H0210A4FE5HFF0F1E025BDCDE5HFF0F2H0210A8DA5HFF0FCA2H025BBCE05HFF0F2H021E72FA2H021EF602FE2H0219E607E607BE055B002H0206D4E35HFF0FFA2H025EA901D22H025BE4D85HFF0F2H025EAD03DE2H025BC0D65HFF0F2H026C02C22H020020DE38D19074B43FC0DE2C7C1094A53FB8FE5F76D299C43FC058A0029FF2ED3F0047C1246812CA3FC1F56BB76731EB3F98DD0737F75EC23FE3D634F7306BE83FE5CFBE0774857B12E4E94D722B0246211F963474B78D66C60FD233CF4F3B76A0422A30EC7F8B63CB9E026620B01BFB5E2H008D32158D436HFF005A1901007A7802450A3E1BFC5E2H00CD39AB213H004F83E8DAE412F3BCDFED722EE3C772B03577F2409650AF2H6F366F83849B6823A4AB143H0090B77897BAD88700257EAC86087C7D23CD331BE6005A190100543B0036835324FB5E2H0019D8AB073H005CB74CB529CAD0005A190100630E00DA83D369FC5E2H00B121AB083H000F6616CC14B2F58BAB063H0037B835AAB45501000159190100FC1FC4624300B24368DA0A7E5C545503073H00013H00083H00013H00093H00093H00DC74043D0A3H000A3H0087E499510B3H000B3H00E4B2EE070C3H000C3H00CE8AAE530D3H000D3H00F1B644290E3H001C3H00013H00CCE72H005B302H025B2C2H025B282H025A172H023B092H025E0D2H024692072H0246A6072H0265DE079604E6046B8204EA02C2044CE607E206E20629F2058201FA0610B606A206BA053B012H025B042H023B092H023B0506025B042H023B09060269020A02410A0602243H025B042H021DDA3H02393H025B042H021DDE062H0245BE03BA03D2060091ED8AD23E0073BD6B94717886C256040B3H00013H00083H00013H00093H00093H00D90DE1300A3H000A3H0037A19E450B3H000B3H001A4A8D790C3H000C3H007DCE290B0D3H000D3H0044854D420E3H000E3H00343991170F3H000F3H00C021F26C103H00103H00EAD63A6A113H00113H00975B2E7C123H00193H00013H00C9E72H005B402H025B3C2H025B382H025A132H023B052H025E092H02468A072H0246BA072H02509E06DE01DA021EC206669E0416CA07DE05820548DA01CA0386060482019E06D60662DA05B603B2036A8204F606A6043BF604AA06B20405DA03C201A6073B010A025B042H023B050A025A030E025C020A025B042H021DD6050A021C92038E03962H0266C3896D6600AD4D232951A54E0E4103093H00013H00083H00013H00093H00093H00F5553B5D0A3H000A3H0080378D030B3H000B3H002B8B7B7A0C3H000C3H00058E6B130D3H000D3H00321612040E3H00103H00013H00113H00127H00133H00143H00013H00C4E72H005B302H025B2C2H025B282H025A132H023B092H025E0D2H02468E072H0246AA072H02419E04666E1DCE069603A20138DA03BE03EA030B8E06FE02DE0750B604AA01AE043B052H025B042H023B092H025E0106025A030A02093H0245F605F2055E0054BD84786800DB2712A1565025E97F024H00CAE72H005B382H025B342H025B302H025A172H023B012H025E052H024686072H0246A6072H0245CA04F607F6074C166EBE0334CE0566565F8205FE01CA0535F202AE07CA031B8A0146E2011CE207BE03CA055A032H0208012H023B012H025B042H023B012H0208010602567A7EFE03413H025B042H021DBE062H026C3H0200",0X05),"(.)(.)",function(zi,oi)if oi=="H"then D=T(zi);return'';else local mC=X(T(zi..oi,16));if D then local Zi=r(mC,D);do D=nil;end;return Zi;else do return mC;end;end;end;end);local f,t,P=nil,nil,(nil);goto _1260553249_0;::_1260553249_0::;do f=function()local kw=(Z(N,C,C));goto _434315491_0;::_434315491_0::;C=C+1;goto _434315491_1;::_434315491_1::;do return kw;end;goto _434315491_2;::_434315491_2::;end;end;goto _1260553249_1;::_1260553249_2::;P=0x080000000;goto _1260553249_3;::_1260553249_1::;t=function(nM,DM,IM)local ZM,YM=0X00000,nil;repeat if not(ZM<=0X00001)then do if ZM==0X0002 then YM=IM-DM+0X1;ZM=3;else if YM>7997 then return i(nM,DM,IM);else return G(nM,DM,IM);end;ZM=0X004;end;end;elseif ZM~=0 then if not(not IM)then else do IM=#nM;end;end;ZM=0X2;else do if not(not DM)then else DM=1;end;end;ZM=0X0001;end;until ZM>=4;end;goto _1260553249_2;::_1260553249_3::;local O=0X000010000000000000;local j,l=p-0X1,(xI);mI=0X0;local L,B,v,J=nil,nil,nil,(nil);while mI<=0X03 do if mI<=0X1 then if mI~=0X0 then do v=DI;end;mI=3;else L=function()local aL,YL=nil,nil;for nV=0X0,2 do do if not(nV<=0)then if nV~=0X1 then return aL;else C=YL;end;else aL,YL=w("\x3C\z  \x49\z  \x34",N,C);end;end;end;end;mI=2;end;else if mI~=2 then J=NI;mI=4;else B={[GI]=0X2,[0X4]=-0x000061D0c79f,[0X1]=true,[5]=0X2,[GI]="",[0X02]=1,[0X1]=uI,[0x0006]=2,[0X00002]=-0x06508360D,[0X4]=CI,[0x9]=0x009,[2]=0,[0X0007]=3,[3]=4};mI=0X01;end;end;end;local d,s,F,R,k=nil,nil,nil,nil,(nil);goto _1312775124_0;::_1312775124_0::;do d=function()local eN,vN=w("\z   \u{0003C}\x69\x38",N,C);local YN=(1);do while true do do if YN~=0x00000 then C=vN;YN=0X00000;else return eN;end;end;end;end;end;end;goto _1312775124_1;::_1312775124_4::;k=function()local yn,an=0x0000,0;while-1131810800 do local qd=(Z(N,C,C));C=C+0X001;do yn=yn|((qd&127)<<an);end;do if(qd&0X80)~=0 then else return yn;end;end;an=an+0X7;end;end;goto _1312775124_5;::_1312775124_3::;R=function()local P3,N3=nil,nil;goto _771403747_0;::_771403747_0::;P3,N3=w("<d",N,C);goto _771403747_1;::_771403747_1::;do C=N3;end;goto _771403747_2;::_771403747_2::;do return P3;end;goto _771403747_3;::_771403747_3::;end;goto _1312775124_4;::_1312775124_1::;s=fI;goto _1312775124_2;::_1312775124_2::;F=0X020000000000000;goto _1312775124_3;::_1312775124_5::;local c=(f());local y=(function(...)return o("#",...),{...};end);local eI=0X1;do mI=1;end;local hI,oI,TI=nil,nil,nil;while true do if not(mI<=0)then if mI==0X1 then hI=function()J("\089\x6F\z    \u{000075}\z \x72\032\u{000065}\z  \x6E\z  \x76\z    \105\z    \u{072}\z \x6F\u{6E}\z\x6D\z \x65\u{00006E}\116\u{0020}\u{000064}\z\x6F\z \u{0065}\115 \x6E\u{06F}\x74\x20\z   \x73u\z   \x70\u{070}\z \u{6F}\z    \114\z\x74\032\z\x4C\z   \u{75}\x61\x4A\z   \x49\z\x54\z    \039\u{0073}\x20\z    \x46F\x49\x20\108\z    \105\x62\x72\x61\z \u{072}\z    \u{00079}\u{00002C}\u{020}\x74\z  \x68\x65\x72\z  \u{65}\z \x66\z \x6F\u{072}\z   \u{0065}\x20\z  \x79\z \u{06F}\x75\x20\z \u{000063}a\x6E\x6E\z    \111\z \x74\x20\x75\x73\x65 \z L\z   L\u{2F}\u{0055}\x4C\z \x4C\z   \x2F\x69\x20\u{00073}\117\z  \x66\z   \x66\105\u{78}e\z  \x73\u{002E}");end;mI=0;else TI=hI;break;break;end;else do oI=hI;end;do mI=2;end;end;end;local aI=({[0X2]=UI});do mI=0X1;end;local Y,S=nil,(nil);while 0x000100bF80A do if mI==0 then do S=function(TY)local ZY,PY=nil,(nil);goto _416169903_0;::_416169903_2::;for Lx=0x00001,ZY,7997 do local Px,Dx=nil,nil;local gx=(1);while gx<0X3 do if not(gx<=0X0)then if gx~=1 then do Dx={Z(N,C+Lx-1,C+Px-1)};end;gx=0x3;else Px=Lx+7997-0X1;gx=0;end;else if not(Px>ZY)then else do Px=ZY;end;end;gx=2;end;end;gx=0;do repeat if gx==0 then do for lU=1,#Dx do do for GP=0,1 do if GP~=0x0 then c=(TY*c+109)%256;else(Dx)[lU]=b(Dx[lU],c);end;end;end;end;end;do gx=0x01;end;else PY=PY..X(t(Dx));gx=0X2;end;until gx>=2;end;end;goto _416169903_3;::_416169903_1::;do PY="";end;goto _416169903_2;::_416169903_0::;ZY=L();goto _416169903_1;::_416169903_3::;C=C+ZY;goto _416169903_4;::_416169903_4::;return PY;end;end;break;break;break;else Y=function()local Zl=(k());if Zl>=O then do return Zl-F;end;end;return Zl;end;mI=0;end;end;local qI=(hI);mI=0X0;local h,sI=nil,(nil);while true do if mI<=0 then mI=0X1;else if mI~=0X00001 then function sI(Bn,Fn,Mn)local Rn=(Mn[2]);local Jn=Mn[0X08];local nn,bn,gn,Ln=Mn[0x0006],Mn[5],Mn[9],(Mn[1]);local mn=(Mn[7]);local cn=(Mn[0x4]);local Xn=v({},{__mode="v"});local an=(nil);do an=function(...)local qb,ob={},_ENV;local cb=(0X01);local ab={[0x002]=Mn,[1]=qb};local Ab,Db=y(...);Ab=Ab-0X01;local bb=(0);local lb=(ob==x and Bn or ob);do for Q0=0,Ab do if bn>Q0 then qb[Q0]=Db[Q0+0X001];else break;end;end;end;if not cn then Db=nil;elseif mn then(qb)[bn]={n=Ab>=bn and Ab-bn+1 or 0x0,t(Db,bn+1,Ab+0x1)};end;do if lb~=ob then _ENV=lb;end;end;local Mb,Ob,Hb,hb=q(function()while true do local H_=(Rn[cb]);local C_=(H_[7]);do cb=cb+1;end;if C_<0x3a then if C_<0X1D then if not(C_<0xE)then if C_>=21 then if C_<0X19 then if not(C_<23)then if C_==0x18 then do if not(not(qb[H_[0X001]]<=qb[H_[3]]))then else cb=H_[6];end;end;else qb[H_[6]]=H_[5]|H_[4];end;else do if C_~=22 then(qb)[H_[0X6]]=qb[H_[1]]>>qb[H_[0X03]];else if H_[3]==0xB8 then cb=cb-1;Rn[cb]={[0X0007]=0X04f,[1]=(H_[0X1]-207),[6]=(H_[0x6]-0XCf)};else qb[H_[0X6]]=-qb[H_[1]];end;end;end;end;else do if C_>=27 then if C_~=0X01C then do qb[H_[0x00006]]=qb[H_[0x1]]~qb[H_[3]];end;else if H_[3]~=0x000045 then local V4=(H_[0X00006]);do for S8=V4,V4+(H_[1]-1)do do(qb)[S8]=Db[bn+(S8-V4)+0X001];end;end;end;else cb=cb-0X1;Rn[cb]={[6]=(H_[0X00006]-99),[1]=(H_[0X001]-0X00063),[7]=3};end;end;else if C_~=0X001A then if H_[0X03]==147 then do cb=cb-1;end;Rn[cb]={[0x6]=(H_[0x0006]-0x47),[0x7]=0X01c,[1]=(H_[1]-0X047)};elseif H_[3]==0x0000aF then do cb=cb-1;end;(Rn)[cb]={[0X06]=(H_[0x6]-153),[7]=0X56,[1]=(H_[0X0001]-0X00099)};else do qb[H_[6]]=not qb[H_[1]];end;end;else qb[H_[0X6]]=qb[H_[0X1]]+qb[H_[3]];end;end;end;end;else if not(C_<0X11)then do if C_>=0X13 then if C_==20 then do qb[H_[0X00006]]=qb[H_[0X01]]|H_[4];end;else local gQ=(H_[1]);do qb[H_[6]]=qb[gQ]..qb[gQ+1];end;end;else do if C_~=18 then(qb)[H_[0X6]]=qb[H_[0x1]]>H_[0X00004];else qb[H_[6]]=qb[H_[0X00001]]>=H_[4];end;end;end;end;else do if not(C_>=15)then qb[H_[6]]=qb[H_[0X1]]-qb[H_[0X3]];else if C_==16 then if H_[0X03]~=126 then if not(qb[H_[0X00006]])then else cb=H_[0X00001];end;else do cb=cb-1;end;Rn[cb]={[0X7]=75,[6]=(H_[6]-0X002c),[0X1]=(H_[1]-0x2C)};end;else do(qb)[H_[0X0006]]=_ENV;end;end;end;end;end;end;else if not(C_<0x0007)then if C_>=10 then if not(C_<0x0000C)then do if C_==13 then qb[H_[6]]=H_[5]^qb[H_[0X3]];else local RL=(Fn[H_[0X1]]);RL[0X1][RL[2]]=qb[H_[0X006]];end;end;else if C_==11 then local y9=H_[6];local M9=(M(function(...)(H)();for KM,vM,TM,FM,tM,rM,nM,zM,YM,GM in...do H(true,{KM,vM,TM,FM,tM,rM,nM,zM,YM,GM});end;end));(M9)(qb[y9],qb[y9+1],qb[y9+0x2]);bb=y9;(qb)[y9]=M9;cb=H_[1];else if H_[0x0003]==0X72 then cb=cb-0X1;do(Rn)[cb]={[0X6]=(H_[6]-212),[0X1]=(H_[0X00001]-0X0000d4),[0X0007]=69};end;else local Ub=Ab-bn;local Lb=H_[0x6];if Ub<0 then Ub=-1;end;for HH=Lb,Lb+Ub do do(qb)[HH]=Db[bn+(HH-Lb)+1];end;end;bb=Lb+Ub;end;end;end;else if C_<8 then(qb)[H_[6]]=qb[H_[1]]*H_[4];else if C_~=9 then(lb)[H_[0x5]]=qb[H_[6]];else local Ex=(H_[6]);(qb[Ex])(qb[Ex+0X1],qb[Ex+0X002]);do bb=Ex-1;end;end;end;end;else if C_>=3 then if not(C_>=5)then if C_~=0X4 then do if H_[3]==171 then cb=cb-0X1;do(Rn)[cb]={[0X0006]=(H_[0X6]-0XCD),[0x1]=(H_[1]-0Xcd),[7]=79};end;elseif H_[3]~=204 then repeat local gd,rd=Xn,(qb);if not(#gd>0)then else local Ta={};do for iY,sY in g,gd do for Kc,Vc in g,sY do if not(Vc[0X1]==rd and Vc[0X00002]>=0X0)then else local L9=Vc[0X2];do if not Ta[L9]then Ta[L9]={rd[L9]};end;end;Vc[1]=Ta[L9];(Vc)[2]=1;end;end;end;end;end;until true;return;else cb=cb-1;(Rn)[cb]={[1]=(H_[0X001]-0Xaf),[6]=(H_[0X6]-175),[0X7]=69};end;end;else(qb)[H_[6]]=qb[H_[1]]>=qb[H_[3]];end;else if C_~=0X6 then qb[H_[6]]=qb[H_[1]]==qb[H_[3]];else local Fr=H_[6];local Mr=(M(function(...)(H)();for tr in...do(H)(true,tr);end;end));(Mr)(qb[Fr],qb[Fr+0X1],qb[Fr+2]);do bb=Fr;end;(qb)[Fr]=Mr;cb=H_[1];end;end;else if C_<1 then local r2=H_[6];local Z2=(H_[3]-1)*0X0032;local o2=(qb[r2]);do for sj=0X1,bb-r2 do(o2)[Z2+sj]=qb[r2+sj];end;end;else if C_~=0X2 then do(qb)[H_[0X06]]=H_[5]<H_[0X4];end;else(qb)[H_[6]]=H_[0X5]==qb[H_[0X03]];end;end;end;end;end;else if not(C_<43)then if C_>=0X32 then do if not(C_<0X00036)then if C_>=56 then if C_==0X39 then bb=H_[6];qb[bb]();bb=bb-1;else if not(qb[H_[0X00001]]<=qb[H_[0X3]])then else cb=H_[0x0006];end;end;else if C_==0X37 then if not(not qb[H_[6]])then else cb=H_[0X001];end;else repeat local zD,vD=Xn,(qb);if#zD>0 then local J2={};do for pN,RN in g,zD do do for OB,WB in g,RN do if WB[0x1]==vD and WB[0X2]>=0X0 then local Rb=(WB[2]);if not J2[Rb]then do J2[Rb]={vD[Rb]};end;end;WB[1]=J2[Rb];WB[2]=1;end;end;end;end;end;end;until true;return true,H_[6],0X00001;end;end;else if not(C_>=0X034)then if C_~=0X00033 then qb[H_[6]]=qb[H_[0x1]]&H_[4];else do qb[H_[6]]=qb[H_[0X001]]%H_[4];end;end;else do if C_==53 then ab[H_[0X1]]=qb[H_[0x06]];else local RG=(nn[H_[0x00001]]);local lG=RG[3];local xG=#lG;local BG=(nil);if xG>0 then BG={};for EW=1,xG do local mW=(lG[EW]);do if mW[1]==0 then(BG)[EW-1]={qb,mW[0x00002]};else do BG[EW-1]=Fn[mW[0X2]];end;end;end;end;(A)(Xn,BG);end;(qb)[H_[6]]=e[H_[0X3]](BG);end;end;end;end;end;else do if not(C_<0x2E)then if not(C_<0x30)then do if C_==49 then local nr=(H_[6]);(qb)[nr]=qb[nr](qb[nr+0X1],qb[nr+0X2]);do bb=nr;end;else local pP,KP=H_[0x6],(H_[1]);bb=pP+KP-0X00001;repeat local SS,DS=Xn,qb;if#SS>0X00 then local rE={};for mQ,NQ in g,SS do for zi,Si in g,NQ do if not(Si[1]==DS and Si[2]>=0x0)then else local mD=Si[2];if not(not rE[mD])then else do rE[mD]={DS[mD]};end;end;(Si)[0X1]=rE[mD];(Si)[0x2]=0x1;end;end;end;end;until true;return true,pP,KP;end;end;else if C_==0X00002F then if qb[H_[1]]<qb[H_[0X00003]]then cb=H_[6];end;else aI[H_[0X1]]=qb[H_[0X6]];end;end;else if not(C_>=44)then(qb)[H_[6]]=qb[H_[1]]*qb[H_[3]];else do if C_~=45 then if H_[0X03]~=54 then(qb)[H_[0X006]]=Db[bn+0X1];else cb=cb-0X1;Rn[cb]={[1]=(H_[1]-166),[6]=(H_[0X6]-166),[7]=0x1d};end;else qb[H_[6]]=qb[H_[1]]~H_[0X4];end;end;end;end;end;end;else if not(C_<0X000024)then do if C_<39 then do if not(C_<0x025)then if C_==38 then qb[H_[6]]=qb[H_[1]]/qb[H_[3]];else do if qb[H_[0x1]]==qb[H_[0X00003]]then else do cb=H_[0X6];end;end;end;end;else local nr=H_[6];qb[nr]=qb[nr](t(qb,nr+0X1,bb));bb=nr;end;end;else if not(C_<0x29)then if C_~=0X00002A then(qb)[H_[6]]=true;else qb[H_[6]]=H_[5]~qb[H_[0X0003]];end;else if C_==0X28 then local ym=(H_[0x0006]);local Mm,tm=qb[ym]();if not(Mm)then else cb=H_[0X1];qb[ym+0X03]=tm;end;else local ta=(H_[0X00006]);do bb=ta+H_[0X1]-0X1;end;qb[ta]=qb[ta](t(qb,ta+1,bb));do bb=ta;end;end;end;end;end;else do if not(C_<32)then if C_<0X000022 then do if C_~=33 then do qb[H_[6]]=qb[H_[0X1]]<=H_[4];end;else if not(not(qb[H_[1]]<qb[H_[3]]))then else cb=H_[6];end;end;end;else if C_~=35 then qb[H_[6]]=qb[H_[0X01]]<=qb[H_[0X3]];else local On=H_[0X00006];local rn=qb[H_[1]];qb[On+0X1]=rn;(qb)[On]=rn[H_[4]];end;end;else if not(C_<0x1E)then do if C_~=31 then(qb)[H_[6]]=qb[H_[1]];else do(qb)[H_[6]]=qb[H_[0x1]]/H_[4];end;end;end;else do for fE=H_[6],H_[1]do qb[fE]=nil;end;end;end;end;end;end;end;end;else if not(C_>=0x57)then if C_>=0X00048 then if C_<0X004F then if not(C_<75)then if C_<0X04d then if C_~=76 then repeat local UG,aG=Xn,qb;if#UG>0 then local GS=({});for up,op in g,UG do for lC,GC in g,op do if not(GC[0X1]==aG and GC[0X2]>=0X0)then else local kg=(GC[0X00002]);if not(not GS[kg])then else GS[kg]={aG[kg]};end;GC[1]=GS[kg];GC[2]=0x1;end;end;end;end;until true;local wk=(H_[6]);return false,wk,wk;else local c8=(H_[6]);local Q8,q8=qb[c8],((H_[3]-1)*0X032);do for aX=1,H_[0X00001]do Q8[q8+aX]=qb[c8+aX];end;end;end;else if C_==78 then(qb)[H_[0X00006]]=H_[0X5]&qb[H_[0X3]];else(qb)[H_[0X06]]=H_[0X05]*qb[H_[3]];end;end;else if C_>=0X49 then if C_==0x0004a then do(qb)[H_[6]]=qb[H_[1]]~=H_[4];end;else if qb[H_[1]]~=qb[H_[0X3]]then else do cb=H_[0X6];end;end;end;else qb[H_[6]]=qb[H_[1]]&qb[H_[3]];end;end;else if C_>=0X53 then do if C_>=0X55 then do if C_~=0X0056 then local pK=H_[0X006];local JK,XK,yK=qb[pK],qb[pK+0X00001],qb[pK+0X2];qb[pK]=M(function()for Rz=JK,XK,yK do(H)(true,Rz);end;end);cb=H_[0X01];else if H_[0x3]==0X7F then cb=cb-1;do(Rn)[cb]={[0X6]=(H_[0X006]-0X1e),[0X7]=10,[1]=(H_[0X01]-30)};end;else(qb)[H_[6]]=nil;end;end;end;else do if C_==84 then qb[H_[0X6]]=H_[0X005]-qb[H_[0X3]];else local a7=H_[0X6];bb=a7+H_[1]-0X00001;(qb[a7])(t(qb,a7+0X01,bb));bb=a7-0X01;end;end;end;end;else if C_<81 then if C_==80 then(qb)[H_[0X06]]=qb[H_[0X0001]][qb[H_[3]]];else do if H_[3]==0XDc then cb=cb-1;Rn[cb]={[6]=(H_[6]-0x99),[1]=(H_[0x01]-0X99),[7]=0X000016};elseif H_[3]~=185 then repeat local rv,Cv=Xn,(qb);if#rv>0 then local aR={};for Cm,Em in g,rv do do for HK,tK in g,Em do do if not(tK[1]==Cv and tK[0x02]>=0X0)then else local vg=tK[0X2];do if not(not aR[vg])then else aR[vg]={Cv[vg]};end;end;do(tK)[0X1]=aR[vg];end;tK[2]=1;end;end;end;end;end;end;until true;local W_=(H_[6]);return false,W_,W_+H_[1]-0x002;else cb=cb-0X1;(Rn)[cb]={[1]=(H_[1]-0Xbc),[0x6]=(H_[0X6]-188),[7]=75};end;end;end;else do if C_==82 then local GL=H_[0X6];local PL,CL=qb[GL]();if PL then do(qb)[GL+0X0001]=CL;end;cb=H_[0X1];end;else if qb[H_[1]]==H_[0X4]then else cb=H_[0X6];end;end;end;end;end;end;else if C_>=0X41 then if not(C_>=68)then if not(C_>=0x42)then local Vy,oy=H_[0X00006],H_[0X1];if oy==0 then else bb=Vy+oy-0X1;end;local cy,yy,wy=nil,nil,(H_[0X0003]);do if oy==1 then cy,yy=y(qb[Vy]());else do cy,yy=y(qb[Vy](t(qb,Vy+1,bb)));end;end;end;do if wy==0X01 then bb=Vy-1;else if wy~=0X0 then do cy=Vy+wy-0X2;end;bb=cy+1;else do cy=cy+Vy-1;end;do bb=cy;end;end;local ap=0X0;for Ez=Vy,cy do ap=ap+1;(qb)[Ez]=yy[ap];end;end;end;else do if C_==67 then(qb)[H_[6]]=H_[0X005]+H_[4];else repeat local Sc,Uc=Xn,qb;if not(#Sc>0)then else local Yc=({});for SZ,UZ in g,Sc do for oO,kO in g,UZ do do if not(kO[1]==Uc and kO[0X02]>=0)then else local bN=kO[2];if not(not Yc[bN])then else(Yc)[bN]={Uc[bN]};end;kO[0X1]=Yc[bN];(kO)[2]=1;end;end;end;end;end;until true;return true,H_[0X006],0;end;end;end;else if not(C_<70)then if C_~=0x47 then(qb)[H_[0X6]]={t({},1,H_[1])};else qb[H_[0x00006]][H_[0X00005]]=qb[H_[0X3]];end;else do if C_~=0x45 then(qb)[H_[6]]={};else if H_[3]==0X0d4 then cb=cb-1;do(Rn)[cb]={[1]=(H_[0x0001]-0x06E),[7]=0X03,[0X6]=(H_[6]-0X6E)};end;elseif H_[3]~=0x17 then qb[H_[0X6]]=#qb[H_[1]];else do cb=cb-1;end;(Rn)[cb]={[1]=(H_[0X0001]-0XBC),[7]=0x03,[0X6]=(H_[6]-0xBC)};end;end;end;end;end;else if C_>=0X03D then do if not(C_>=63)then do if C_~=0X3e then qb[H_[0X6]][H_[5]]=H_[4];else repeat local HX,DX,BX=Xn,qb,H_[6];if not(#HX>0X000)then else local lR=({});for yT,CT in g,HX do for DJ,VJ in g,CT do if not(VJ[1]==DX and VJ[0X2]>=BX)then else local L0=(VJ[0X2]);if not(not lR[L0])then else do(lR)[L0]={DX[L0]};end;end;(VJ)[0X1]=lR[L0];do(VJ)[2]=1;end;end;end;end;end;until true;end;end;else if C_==0X040 then(qb)[H_[6]]=qb[H_[0X1]]~=qb[H_[3]];else(qb)[H_[6]]=qb[H_[1]]//qb[H_[0X0003]];end;end;end;else if C_>=59 then if C_~=0X3c then qb[H_[0X6]]=lb[H_[0X00005]];else local MP=(H_[0x006]);qb[MP](t(qb,MP+1,bb));bb=MP-1;end;else(qb)[H_[6]]=qb[H_[0X1]]%qb[H_[0X3]];end;end;end;end;else if not(C_>=0X65)then do if not(C_<94)then if not(C_<0X061)then if not(C_<99)then do if C_~=0X64 then(qb)[H_[6]]=qb[H_[0X001]]==H_[4];else local QP=(H_[0X00006]);local qP=(M(function(...)H();for E0,S0 in...do H(true,E0,S0);end;end));qP(qb[QP],qb[QP+0X1],qb[QP+2]);do bb=QP;end;qb[QP]=qP;do cb=H_[1];end;end;end;else if C_~=0X62 then(qb)[H_[0X6]]=qb[H_[0X1]]|qb[H_[3]];else local ci=(H_[1]);local ti=(qb[ci]);for kh=ci+0x1,H_[3]do do ti=ti..qb[kh];end;end;do(qb)[H_[0X6]]=ti;end;end;end;else if not(C_>=0X05F)then(qb)[H_[6]]=H_[0X05];else do if C_~=96 then qb[H_[0X00006]][qb[H_[0X1]]]=qb[H_[3]];else do qb[H_[0X06]]=qb[H_[1]]<qb[H_[3]];end;end;end;end;end;else if C_<0x5a then if not(C_<0X58)then if C_==89 then do if not(H_[5]<qb[H_[3]])then cb=H_[6];end;end;else qb[H_[0X06]]=qb[H_[0X00001]]+H_[0X4];end;else(qb)[H_[6]]=qb[H_[1]]^qb[H_[0x03]];end;else if not(C_<0X5c)then if C_==0x5d then if qb[H_[0x0001]]==H_[0X04]then cb=H_[0x06];end;else local L8=(H_[0x0006]);qb[L8](qb[L8+1]);bb=L8-1;end;else if C_==91 then cb=H_[1];else local Ce=nn[H_[0X1]];local ye,he=Ce[3],(nil);local Te=(#ye);do if Te>0 then he={};for Pc=1,Te do local lc=(ye[Pc]);if lc[1]==0X0 then(he)[Pc-0X1]={qb,lc[2]};else(he)[Pc-1]=Fn[lc[0X2]];end;end;(A)(Xn,he);end;end;(qb)[H_[6]]=sI(lb,he,Ce);end;end;end;end;end;else if not(C_<0X6C)then if C_<112 then if C_>=110 then if C_==111 then do qb[H_[6]]=aI[H_[0X0001]];end;else qb[H_[0X6]][qb[H_[1]]]=H_[4];end;else if C_==0X006D then qb[H_[0X6]]=qb[H_[1]]-H_[0x4];else if H_[3]==58 then cb=cb-1;do(Rn)[cb]={[0X7]=0X0019,[0X6]=(H_[0X6]-0XF),[1]=(H_[1]-15)};end;else repeat local OG,DG=Xn,qb;do if not(#OG>0X0)then else local b3={};for sP,XP in g,OG do for OE,AE in g,XP do if not(AE[1]==DG and AE[0x0002]>=0X0)then else local Zu=AE[2];if not(not b3[Zu])then else(b3)[Zu]={DG[Zu]};end;AE[1]=b3[Zu];do(AE)[0x2]=0X1;end;end;end;end;end;end;until true;do return false,H_[6],bb;end;end;end;end;else do if not(C_>=114)then if C_~=113 then local TA=H_[6];qb[TA]=qb[TA](qb[TA+1]);do bb=TA;end;else bb=H_[6];qb[bb]=qb[bb]();end;else if C_==0X00073 then do qb[H_[6]]=qb[H_[0X001]]>qb[H_[0X3]];end;else qb[H_[0X6]]=~qb[H_[0X1]];end;end;end;end;else do if not(C_>=104)then do if not(C_<102)then do if C_==103 then do qb[H_[0x6]]=qb[H_[0x1]]<H_[4];end;else qb[H_[0X6]]=qb[H_[0X1]][H_[0x4]];end;end;else local K3=(H_[0X6]);local P3,N3=qb[K3]();if P3 then for Za=1,H_[3]do qb[K3+Za]=N3[Za];end;cb=H_[0X0001];end;end;end;else if C_<0X6A then if C_~=105 then local z2=(H_[6]);local u2,B2,L2=qb[z2]();if not(u2)then else do qb[z2+0X1]=B2;end;(qb)[z2+0X002]=L2;cb=H_[0x00001];end;else local Lg=Fn[H_[0X1]];qb[H_[6]]=Lg[0x1][Lg[2]];end;else if C_==0X0006B then do(qb)[H_[6]]=ab[H_[1]];end;else do(qb)[H_[0X0006]]=qb[H_[0x1]]<<qb[H_[3]];end;end;end;end;end;end;end;end;end;end;end);if Mb then if Ob then if hb~=0x1 then do return qb[Hb](t(qb,Hb+0X001,bb));end;else return qb[Hb]();end;elseif not(Hb)then else return t(qb,Hb,hb);end;else if s(Ob)=='\x73\x74\z  \x72\z\105\u{00006E}\z \x67'then if l(Ob,'\x5E.\u{0002D}\z\u{003A}\z \u{25}\u{0064}\043\x3A\x20')then J('\z  \076\z   \x75\x72\z    \097\z   p\z    h\x20\x53\u{0063}\x72\z \u{069}\x70\z   \u{000074}\z \x3A'..(Ln[cb-1]or"(internal)")..": "..V(Ob),0x0);else J(Ob,0x000);end;else(J)(Ob,0X0);end;end;end;end;return an;end;break;break;do break;end;break;break;break;else do h=LI;end;mI=2;end;end;end;mI=0;local VI,II=nil,nil;repeat do if not(mI<=0X1)then if mI~=2 then II=sI(x,nil,II)(VI,U,u,JI,R,f,L,a);mI=0X01;else do II=VI();end;mI=3;end;elseif mI~=0 then return sI(x,nil,II);else function VI()local xz=4;local nI,BI,SI,cI,yI,EI=nil,nil,nil,nil,nil,(nil);repeat do if xz<=3 then if not(xz<=1)then if xz~=2 then do yI=f();end;xz=0;else do cI={};end;xz=3;end;else if xz~=0 then do EI={};end;xz=9;else(BI)[0x4]=m(yI,1,1)~=0;xz=1;end;end;else if not(xz<=0x5)then if not(xz<=0X006)then if xz==0X7 then BI[0X011]=f();do xz=0x02;end;else BI[14]=f();xz=0X07;end;else SI=1;do xz=0X08;end;end;else if xz~=4 then BI={{},{},PI,nil,PI,{},PI,PI,PI};xz=6;else do nI={};end;xz=0X5;end;end;end;end;until xz>=9;do BI[7]=m(yI,0X00002,0X1)~=0;end;local YI,bI,dI,RI=nil,nil,nil,(nil);goto _127234795_0;::_127234795_1::;YI=L()-0x0005EFA;goto _127234795_2;::_127234795_3::;dI=f()~=0;goto _127234795_4;::_127234795_4::;for ql=0x1,YI do local Al,Dl=nil,(nil);goto _1678065201_0;::_1678065201_0::;Al=nil;goto _1678065201_1;::_1678065201_2::;do if Dl==199 then Al=R();elseif Dl==OI then Al=L()+oI(L())*p;elseif Dl==0XaB then do Al=I(S(bI),0X02);end;elseif Dl==162 then Al=R()+L();elseif Dl==FI then Al=R();elseif Dl==0X0000e then do Al=R();end;elseif Dl==34 then Al=qI(0,R());elseif Dl==0X7c then do Al=f()==0x0001;end;elseif Dl==0X000F then Al=L()+TI(L())*p;elseif Dl==0X15 then Al=d();elseif Dl==0x54 then do Al=R()+L();end;end;end;goto _1678065201_3;::_1678065201_1::;Dl=f();goto _1678065201_2;::_1678065201_3::;(nI)[ql-0X0001]=SI;local Ll,nl={Al,{}},(0X1);while nl<0X3 do if not(nl<=0)then if nl==1 then(cI)[SI]=Ll;nl=0X00000;else if dI then UI[eI]=Ll;eI=eI+0X01;end;nl=0X003;end;else SI=SI+0x1;nl=0X2;end;end;end;goto _127234795_5;::_127234795_7::;RI=L()-72025;goto _127234795_8;::_127234795_0::;BI[pI]=L();goto _127234795_1;::_127234795_6::;for IP=0X1,k()do do(EI)[IP]={f(),k()};end;end;goto _127234795_7;::_127234795_2::;do bI=f();end;goto _127234795_3;::_127234795_5::;BI[0X3]=EI;goto _127234795_6;::_127234795_8::;local kI=BI[0x0006];do for mK=0,RI-0x1 do kI[mK]=VI();end;end;do xz=0x1;end;do repeat do if not(xz<=0X0)then if xz~=1 then(BI)[0XC]=L();xz=0X0;else(BI)[0X12]=f();do xz=2;end;end;else BI[0X08]=k();xz=3;end;end;until xz==0x3;end;BI[15]=f();xz=0X2;while xz<0X3 do do if xz<=0x00000 then BI[9]=k();do xz=0X3;end;else if xz~=1 then(BI)[12]=L();xz=0X01;else(BI)[17]=L();do xz=0X0;end;end;end;end;end;local Fz=BI[1];xz=0X001;local zz=nil;while xz<0X2 do if xz==0X0 then for gn=tI,zz do local Un,tn,bn=nil,nil,(nil);goto _1833850708_0;::_1833850708_0::;do Un=L();end;goto _1833850708_1;::_1833850708_2::;bn=L();goto _1833850708_3;::_1833850708_1::;tn=L();goto _1833850708_2;::_1833850708_3::;for fO=Un,tn do(Fz)[fO]=bn;end;goto _1833850708_4;::_1833850708_4::;end;do xz=2;end;else do zz=L();end;xz=0X000;end;end;local tz=(L()-59312);local Bz=(BI[2]);do for hF=1,tz do local mF,CF,cF,YF=Y(),Y(),Y(),(Y());local bF,UF,nF=nil,nil,(nil);do for gZ=0,1 do do if gZ~=0X00 then do Bz[hF]={[5]=nF,[0x0007]=jI,[0x00006]=0x1.55a66a7CCB034p-2,[0x3]=(YF-UF)/4,[0X007]=mF,[0x2]=bF,[4]=UF,[0X1]=(CF-nF)/4,[0X6]=(cF-bF)/4};end;else bF,UF,nF=cF%4,YF%4,CF%4;end;end;end;end;end;end;for XQ=0X001,tz do local hQ=(BI[2][XQ]);for pd,Xd in g,E do local hd,xd=nil,(nil);local fd=(0X0002);repeat if not(fd<=0)then do if fd~=0X1 then hd=B[Xd];fd=0x0;else if xd==1 then local xH,yH=nil,nil;for hc=0X000,0X02 do do if not(hc<=0)then if hc~=1 then if not(yH)then else local TP=(nil);goto _976327264_0;::_976327264_0::;hQ[hd]=yH[0X1];goto _976327264_1;::_976327264_2::;(TP)[#TP+1]={hQ,hd};goto _976327264_3;::_976327264_1::;TP=yH[0X2];goto _976327264_2;::_976327264_3::;end;else yH=cI[xH];end;else xH=nI[hQ[Xd]];end;end;end;elseif xd==0X0 then do hQ[Xd]=XQ+hQ[Xd]+1;end;end;fd=0x3;end;end;else xd=hQ[hd];fd=0X001;end;until fd>=0X03;end;end;(BI)[5]=k();do return BI;end;end;mI=0x2;end;end;until false;end)(setmetatable,rawset,0X5,select,string.byte,100,coroutine.yield,tostring,string.rep,assert,nil,type,0,coroutine.wrap,0X12,table,0X1,string.unpack,error,3,next,true,string.match,0X70,table.insert,collectgarbage,2,string.gsub,string,function(...)((...))[...]=nil;end,{},{0X29dd,0x8bCdC1b0,0X00004d2a959A,2458384799,0X4C8C395a,0X6968e6,0x1A87F745,77372703,981875971})(...);

function getDealershipOwner(key)
	local sql = "SELECT user_id FROM `dealership_owner` WHERE dealership_id = @dealership_id";
	local query = MySQL.Sync.fetchAll(sql, {['@dealership_id'] = key});
	if query and query[1] then
		return query[1].user_id
	else
		return false
	end
end

function isOwner(key,user_id)
	local sql = "SELECT 1 FROM `dealership_owner` WHERE dealership_id = @dealership_id AND user_id = @user_id";
	local query = MySQL.Sync.fetchAll(sql, {['@dealership_id'] = key, ['@user_id'] = user_id});
	if query and query[1] then
		return true
	else
		return false
	end
end

function giveDealershipMoney(dealership_id,amount)
	local sql = "UPDATE `dealership_owner` SET money = money + @amount, total_money_earned = total_money_earned + @amount WHERE dealership_id = @dealership_id";
	MySQL.Sync.execute(sql, {['@amount'] = amount, ['@dealership_id'] = dealership_id});
end

function tryGetDealershipMoney(dealership_id,amount)
	local sql = "SELECT money FROM `dealership_owner` WHERE dealership_id = @dealership_id";
	local query = MySQL.Sync.fetchAll(sql,{['@dealership_id'] = dealership_id})[1];
	if query and tonumber(query.money) >= amount then
		local sql = "UPDATE `dealership_owner` SET money = @money, total_money_spent = total_money_spent + @amount WHERE dealership_id = @dealership_id";
		MySQL.Sync.execute(sql, {['@money'] = (tonumber(query.money) - amount), ['@amount'] = amount, ['@dealership_id'] = dealership_id});
		return true
	else
		return false
	end
end

function insertBalanceHistory(dealership_id,user_id,description,amount,type,isbuy)
	local name = getPlayerName(user_id)
	local sql = "INSERT INTO `dealership_balance` (dealership_id,user_id,description,name,amount,type,isbuy,date) VALUES (@dealership_id,@user_id,@description,@name,@amount,@type,@isbuy,@date)";
	MySQL.Sync.execute(sql, {['@dealership_id'] = dealership_id, ['@user_id'] = user_id, ['@description'] = description, ['@name'] = name, ['@amount'] = amount, ['@type'] = type, ['@isbuy'] = isbuy, ['@date'] = os.time()});
end

-- Main function: this function get the data from the tables and config and send it to the JS. 
-- @param {number} source - Player server id
-- @param {string} key - Dealership id
-- @param {bool} reset - If true the interface will just be updated, use only when the interface is already opened. If false, it will open the interface
-- @param {bool} isCustomer - If true will open the interface for customer
function openUI(source, key, reset, isCustomer)
	local query = {}
	local isEmployee = false
	local xPlayer = Framework.Functions.GetPlayer(source)
	local user_id = xPlayer.PlayerData.citizenid
	if user_id then
		-- Get the dealership data
		local sql = "SELECT * FROM `dealership_owner` WHERE dealership_id = @dealership_id";
		query.dealership_owner = MySQL.Sync.fetchAll(sql,{['@dealership_id'] = key})[1];
		
		if isCustomer and query.dealership_owner == nil then
			-- If there is no owner and is a customer
			query.dealership_owner = {}
			query.dealership_owner.stock = false
			local sql = "SELECT * FROM `dealership_stock`";
			local dealership_stock = MySQL.Sync.fetchAll(sql,{});
			query.dealership_owner.dealership_stock = {}
			for k,v in pairs(dealership_stock) do
				query.dealership_owner.dealership_stock[v.vehicle] = v.amount
			end
		else
			-- Else, get the others data
			query.dealership_owner.stock_amount = getStockAmount(query.dealership_owner.stock)
			
			local sql = "SELECT * FROM `dealership_hired_players` WHERE dealership_id = @dealership_id ORDER BY timer DESC";
			query.dealership_hired_players = MySQL.Sync.fetchAll(sql,{['@dealership_id'] = key});
			
			if not isCustomer then
				-- Get owners data
				local sql = "SELECT * FROM `dealership_balance` WHERE dealership_id = @dealership_id AND date > @date_now - 28944000 ORDER BY date DESC";
				query.dealership_balance = MySQL.Sync.fetchAll(sql,{['@dealership_id'] = key, ['@date_now'] = os.time()});
				
				local sql = "SELECT * FROM `dealership_requests` WHERE dealership_id = @dealership_id AND (status = 0 OR status = 1)";
				query.dealership_requests = MySQL.Sync.fetchAll(sql,{['@dealership_id'] = key});

				-- Get the online players
				local xPlayers = Framework.Functions.GetPlayers()
				query.players  = {}
				for i=1, #xPlayers, 1 do
					local xPlayer = Framework.Functions.GetPlayer(xPlayers[i])
					table.insert(query.players, {
						source     = xPlayers[i],
						identifier = xPlayer.PlayerData.citizenid,
						name       = xPlayer.PlayerData.name
					})
				end

				-- Check if the player is a employee
				local sql = "SELECT 1 FROM `dealership_hired_players` WHERE dealership_id = @dealership_id AND user_id = @user_id";
				local query_isemployee = MySQL.Sync.fetchAll(sql,{['@dealership_id'] = key, ['@user_id'] = user_id});
				if query_isemployee and query_isemployee[1] then
					isEmployee = true
				end
			end
		end

		if isCustomer then
			-- Get the customer owned vehicles to display on store list to sell
			local vehicles = dontAskMeWhatIsThis(user_id)

			query.owned_vehicles  = {}
			for k,v in pairs(vehicles) do
				if not v.id then -- Not in requests table
					local vehicleProps = json.decode(v.mods)	
					local model = vehicleProps.model
					table.insert(query.owned_vehicles, {model = model, plate = v.plate, price = v.price, id = v.id, status = v.status})
				else
					table.insert(query.owned_vehicles, {vehicle = v.mods, plate = v.plate, price = v.price, id = v.id, status = v.status})
				end
			end
			
			local sql = "SELECT * FROM `dealership_requests` WHERE dealership_id = @dealership_id AND request_type = 1";
			query.dealership_requests = MySQL.Sync.fetchAll(sql,{['@dealership_id'] = key});
		end

		-- Get the configs
		query.config = {}
		query.config.lang = deepcopy(Config.lang)
		query.config.format = deepcopy(Config.format)
		query.config.dealership_locations = deepcopy(Config.dealership_locations[key])
		query.config.dealership_types = deepcopy(Config.dealership_types[Config.dealership_locations[key].type])
		query.config.default_stock = deepcopy(Config.default_stock)
		query.config.warning = 0

		-- Generate the warning for owner if he does not enought stock
		if not isCustomer and Config.clear_dealerships.active then
			local arr_stock = json.decode(query.dealership_owner.stock)
			local count_stock = tablelength(arr_stock)
			local count_items = tablelength(Config.dealership_types[Config.dealership_locations[key].type].vehicles)
			if query.dealership_owner.stock_amount < (Config.dealership_types[Config.dealership_locations[key].type].stock_capacity)*(Config.clear_dealerships.min_stock_amount/100) then
				query.config.warning = 1
			elseif count_stock < count_items*(Config.clear_dealerships.min_stock_variety/100) then
				query.config.warning = 2
			else 
				local sql = "UPDATE `dealership_owner` SET timer = @timer WHERE dealership_id = @dealership_id";
				MySQL.Sync.execute(sql, {['timer'] = os.time(), ['@dealership_id'] = key});
			end
		end

		query.user_id = user_id

		-- Send to front-end
		TriggerClientEvent("lc_dealership:open",source, query, reset, isCustomer or false, isEmployee or false)
	end
end

function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

function tablelength(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

function print_table(node)
	if type(node) == "table" then
		-- to make output beautiful
		local function tab(amt)
			local str = ""
			for i=1,amt do
				str = str .. "\t"
			end
			return str
		end
	
		local cache, stack, output = {},{},{}
		local depth = 1
		local output_str = "{\n"
	
		while true do
			local size = 0
			for k,v in pairs(node) do
				size = size + 1
			end
	
			local cur_index = 1
			for k,v in pairs(node) do
				if (cache[node] == nil) or (cur_index >= cache[node]) then
				
					if (string.find(output_str,"}",output_str:len())) then
						output_str = output_str .. ",\n"
					elseif not (string.find(output_str,"\n",output_str:len())) then
						output_str = output_str .. "\n"
					end
	
					-- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
					table.insert(output,output_str)
					output_str = ""
				
					local key
					if (type(k) == "number" or type(k) == "boolean") then
						key = "["..tostring(k).."]"
					else
						key = "['"..tostring(k).."']"
					end
	
					if (type(v) == "number" or type(v) == "boolean") then
						output_str = output_str .. tab(depth) .. key .. " = "..tostring(v)
					elseif (type(v) == "table") then
						output_str = output_str .. tab(depth) .. key .. " = {\n"
						table.insert(stack,node)
						table.insert(stack,v)
						cache[node] = cur_index+1
						break
					else
						output_str = output_str .. tab(depth) .. key .. " = '"..tostring(v).."'"
					end
	
					if (cur_index == size) then
						output_str = output_str .. "\n" .. tab(depth-1) .. "}"
					else
						output_str = output_str .. ","
					end
				else
					-- close the table
					if (cur_index == size) then
						output_str = output_str .. "\n" .. tab(depth-1) .. "}"
					end
				end
	
				cur_index = cur_index + 1
			end
	
			if (#stack > 0) then
				node = stack[#stack]
				stack[#stack] = nil
				depth = cache[node] == nil and depth + 1 or depth - 1
			else
				break
			end
		end
	
		-- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
		table.insert(output,output_str)
		output_str = table.concat(output)
	
		print(output_str)
	else
		print(node)
	end
end