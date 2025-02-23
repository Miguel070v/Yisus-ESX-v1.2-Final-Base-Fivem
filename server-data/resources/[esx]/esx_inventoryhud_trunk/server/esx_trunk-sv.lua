ESX = nil
local arrayWeight = Config.localWeight
local VehicleList = {}
local VehicleInventory = {}

TriggerEvent(
  "esx:getSharedObject",
  function(obj)
    ESX = obj
  end
)

AddEventHandler(
  "onMySQLReady",
  function()
    MySQL.Async.execute("DELETE FROM `trunk_inventory` WHERE `owned` = 0", {})
  end
)

RegisterServerEvent("esx_trunk_inventory:getOwnedVehicule")
AddEventHandler(
  "esx_trunk_inventory:getOwnedVehicule",
  function()
    local vehicules = {}
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if xPlayer then
      MySQL.Async.fetchAll(
        "SELECT * FROM owned_vehicles WHERE owner = @owner",
        {
          ["@owner"] = xPlayer.identifier
        },
        function(result)
          if result ~= nil and #result > 0 then
            for _, v in pairs(result) do
              local vehicle = json.decode(v.vehicle)
              table.insert(vehicules, {plate = vehicle.plate})
            end
          end
          TriggerClientEvent("esx_trunk_inventory:setOwnedVehicule", _source, vehicules)
        end
      )
    end
  end
)

function getItemWeight(item)
  local weight = 0
  local itemWeight = 0
  if item ~= nil then
    itemWeight = ESX.Items[item].weight
  end
  return itemWeight
end

function getInventoryWeight(inventory)
  local weight = 0
  local itemWeight = 0
  if inventory ~= nil then
    for i = 1, #inventory, 1 do
      if inventory[i] ~= nil then
        itemWeight = ESX.GetItemWeight(inventory[i].name)
        weight = weight + (itemWeight * (inventory[i].count or 1))
      end
    end
  end
  return weight
end

function getTotalInventoryWeight(plate)
  local total
  TriggerEvent(
    "esx_trunk:getSharedDataStore",
    plate,
    function(store)
      --local W_weapons = getInventoryWeight(store.get("weapons") or {})
      local W_coffre = getInventoryWeight(store.get("coffre") or {})
      --[[local W_blackMoney = 0
      local blackAccount = (store.get("black_money")) or 0
      if blackAccount ~= 0 then
        W_blackMoney = blackAccount[1].amount / 10
      end]]
      --total = W_weapons + W_coffre + W_blackMoney
      total = W_coffre
    end
  )
  return total
end

ESX.RegisterServerCallback(
  "esx_trunk:getInventoryV",
  function(source, cb, plate)
    TriggerEvent(
      "esx_trunk:getSharedDataStore",
      plate,
      function(store)
        local blackMoney = 0
        local items = {}
        local weapons = {}
        weapons = (store.get("weapons") or {})

        local blackAccount = (store.get("black_money")) or 0
        if blackAccount ~= 0 then
          blackMoney = blackAccount[1].amount
        end

        local coffre = (store.get("coffre") or {})
        for i = 1, #coffre, 1 do
          table.insert(
            items,
            {name = coffre[i].name, count = coffre[i].count, label = ESX.GetItemLabel(coffre[i].name)}
          )
        end

        local weight = getTotalInventoryWeight(plate)
        cb(
          {
            blackMoney = blackMoney,
            items = items,
            weapons = weapons,
            weight = weight
          }
        )
      end
    )
  end
)

RegisterServerEvent("esx_trunk:getItem")
AddEventHandler(
  "esx_trunk:getItem",
  function(plate, type, item, count, max, owned)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if type == "item_standard" then
      local targetItem = xPlayer.getInventoryItem(item)
      --if targetItem.limit == -1 or ((targetItem.count + count) <= targetItem.limit) then
      if xPlayer.canCarryItem(item, count) then
        TriggerEvent(
          "esx_trunk:getSharedDataStore",
          plate,
          function(store)
            local coffre = (store.get("coffre") or {})
            for i = 1, #coffre, 1 do
              if coffre[i].name == item then
                if (coffre[i].count >= count and count > 0) then
                  xPlayer.addInventoryItem(item, count)
                  if (coffre[i].count - count) == 0 then
                    table.remove(coffre, i)
                  else
                    coffre[i].count = coffre[i].count - count
                  end

                  break
                else
                  xPlayer.showNotification(_U("invalid_quantity"))
                end
              end
            end

            store.set("coffre", coffre)

            local blackMoney = 0
            local items = {}
            local weapons = {}
            weapons = (store.get("weapons") or {})

            local blackAccount = (store.get("black_money")) or 0
            if blackAccount ~= 0 then
              blackMoney = blackAccount[1].amount
            end

            local coffre = (store.get("coffre") or {})
            for i = 1, #coffre, 1 do
              table.insert(
                items,
                {name = coffre[i].name, count = coffre[i].count, label = ESX.GetItemLabel(coffre[i].name)}
              )
            end

            local weight = getTotalInventoryWeight(plate)

            text = _U("trunk_info", plate, (weight), (max))
            data = {plate = plate, max = max, myVeh = owned, text = text}
            TriggerClientEvent("esx_inventoryhud:refreshTrunkInventory", _source, data, blackMoney, items, weapons)
          end
        )
      else
        xPlayer.showNotification(_U("player_inv_no_space"))
      end
    end

    if type == "item_account" then
      TriggerEvent(
        "esx_trunk:getSharedDataStore",
        plate,
        function(store)
          local blackMoney = store.get("black_money")
          if (blackMoney[1].amount >= count and count > 0) then
            blackMoney[1].amount = blackMoney[1].amount - count
            store.set("black_money", blackMoney)
            xPlayer.addAccountMoney(item, count)

            local blackMoney = 0
            local items = {}
            local weapons = {}
            weapons = (store.get("weapons") or {})

            local blackAccount = (store.get("black_money")) or 0
            if blackAccount ~= 0 then
              blackMoney = blackAccount[1].amount
            end

            local coffre = (store.get("coffre") or {})
            for i = 1, #coffre, 1 do
              table.insert(
                items,
                {name = coffre[i].name, count = coffre[i].count, label = ESX.GetItemLabel(coffre[i].name)}
              )
            end

            local weight = getTotalInventoryWeight(plate)

            text = _U("trunk_info", plate, (weight), (max))
            data = {plate = plate, max = max, myVeh = owned, text = text}
            TriggerClientEvent("esx_inventoryhud:refreshTrunkInventory", _source, data, blackMoney, items, weapons)
          else
            xPlayer.showNotification(_U("invalid_amount"))
          end
        end
      )
    end

    if type == "item_weapon" then
      TriggerEvent(
        "esx_trunk:getSharedDataStore",
        plate,
        function(store)
          local storeWeapons = store.get("weapons")

          if storeWeapons == nil then
            storeWeapons = {}
          end

          local weaponName = nil
          local ammo = nil

          for i = 1, #storeWeapons, 1 do
            if storeWeapons[i].name == item then
              weaponName = storeWeapons[i].name
              ammo = storeWeapons[i].ammo

              table.remove(storeWeapons, i)

              break
            end
          end

          store.set("weapons", storeWeapons)

          xPlayer.addWeapon(weaponName, ammo)

          local blackMoney = 0
          local items = {}
          local weapons = {}
          weapons = (store.get("weapons") or {})

          local blackAccount = (store.get("black_money")) or 0
          if blackAccount ~= 0 then
            blackMoney = blackAccount[1].amount
          end

          local coffre = (store.get("coffre") or {})
          for i = 1, #coffre, 1 do
            table.insert(
              items,
              {name = coffre[i].name, count = coffre[i].count, label = ESX.GetItemLabel(coffre[i].name)}
            )
          end

          local weight = getTotalInventoryWeight(plate)

          text = _U("trunk_info", plate, (weight), (max))
          data = {plate = plate, max = max, myVeh = owned, text = text}
          TriggerClientEvent("esx_inventoryhud:refreshTrunkInventory", _source, data, blackMoney, items, weapons)
        end
      )
    end
  end
)

RegisterServerEvent("esx_trunk:putItem")
AddEventHandler(
  "esx_trunk:putItem",
  function(plate, type, item, count, max, owned, label)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    local xPlayerOwner = ESX.GetPlayerFromIdentifier(owner)

    if type == "item_standard" then
      local playerItemCount = xPlayer.getInventoryItem(item).count

      
      if (playerItemCount >= count and count > 0) then
        TriggerEvent(
          "esx_trunk:getSharedDataStore",
          plate,
          function(store)
            local found = false
            local coffre = (store.get("coffre") or {})

            for i = 1, #coffre, 1 do
              if coffre[i].name == item then
                coffre[i].count = coffre[i].count + count
                found = true
              end
            end
            if not found then
              table.insert(
                coffre,
                {
                  name = item,
                  count = count
                }
              )
            end
            local itemWeight = ESX.GetItemWeight(item)
            if (getTotalInventoryWeight(plate) + (itemWeight * count)) > max then
              xPlayer.showNotification(_U("insufficient_space"))
            else
              -- Checks passed, storing the item.
              store.set("coffre", coffre)
              xPlayer.removeInventoryItem(item, count)

              MySQL.Async.execute(
                "UPDATE trunk_inventory SET owned = @owned WHERE plate = @plate",
                {
                  ["@plate"] = plate,
                  ["@owned"] = owned
                }
              )
            end
          end
        )
      else
        xPlayer.showNotification(_U("invalid_quantity"))
      end
    end

    if type == "item_account" then
      if item == "money" then
        xPlayer.showNotification("No puedes guardar dinero en el maletero")
      else
        local playerAccountMoney = xPlayer.getAccount(item).money

        if (playerAccountMoney >= count and count > 0) then
          TriggerEvent(
            "esx_trunk:getSharedDataStore",
            plate,
            function(store)
              local blackMoney = (store.get("black_money") or nil)
              if blackMoney ~= nil then
                blackMoney[1].amount = blackMoney[1].amount + count
              else
                blackMoney = {}
                table.insert(blackMoney, {amount = count})
              end

              if (getTotalInventoryWeight(plate)) > max then
                xPlayer.showNotification(_U("insufficient_space"))
              else
                -- Checks passed. Storing the item.
                xPlayer.removeAccountMoney(item, count)
                store.set("black_money", blackMoney)

                MySQL.Async.execute(
                  "UPDATE trunk_inventory SET owned = @owned WHERE plate = @plate",
                  {
                    ["@plate"] = plate,
                    ["@owned"] = owned
                  }
                )
              end
            end
          )
        else
          xPlayer.showNotification(_U("invalid_amount"))
        end
      end
    end

    if type == "item_weapon" then
      xPlayer.showNotification("No puedes guardar armas sin desmontar")
      return
      TriggerEvent(
        "esx_trunk:getSharedDataStore",
        plate,
        function(store)
          local storeWeapons = store.get("weapons")

          if storeWeapons == nil then
            storeWeapons = {}
          end

          table.insert(
            storeWeapons,
            {
              name = item,
              label = label,
              ammo = count
            }
          )
          if (getTotalInventoryWeight(plate)) > max then
            TriggerClientEvent("mythic_notify:client:SendAlert", source, {type = "error", text = _U("invalid_amount")})
          else
            store.set("weapons", storeWeapons)
            xPlayer.removeWeapon(item)

            MySQL.Async.execute(
              "UPDATE trunk_inventory SET owned = @owned WHERE plate = @plate",
              {
                ["@plate"] = plate,
                ["@owned"] = owned
              }
            )
          end
        end
      )
    end

    TriggerEvent(
      "esx_trunk:getSharedDataStore",
      plate,
      function(store)
        local blackMoney = 0
        local items = {}
        local weapons = {}
        weapons = (store.get("weapons") or {})

        local blackAccount = (store.get("black_money")) or 0
        if blackAccount ~= 0 then
          blackMoney = blackAccount[1].amount
        end

        local coffre = (store.get("coffre") or {})
        for i = 1, #coffre, 1 do
          table.insert(
            items,
            {name = coffre[i].name, count = coffre[i].count, label = ESX.GetItemLabel(coffre[i].name)}
          )
        end

        local weight = getTotalInventoryWeight(plate)

        text = _U("trunk_info", plate, (weight), (max))
        data = {plate = plate, max = max, myVeh = owned, text = text}
        TriggerClientEvent("esx_inventoryhud:refreshTrunkInventory", _source, data, blackMoney, items, weapons)
      end
    )
  end
)

ESX.RegisterServerCallback(
  "esx_trunk:getPlayerInventory",
  function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    local blackMoney = xPlayer.getAccount("black_money").money
    local items = xPlayer.inventory

    cb(
      {
        blackMoney = blackMoney,
        items = items
      }
    )
  end
)

function all_trim(s)
  if s then
    return s:match "^%s*(.*)":match "(.-)%s*$"
  else
    return "noTagProvided"
  end
end
