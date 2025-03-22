-- Minimalist Prop Counter for chifumas DarkRP HUD
-- Matches dark theme with blue accents
-- Place this file in: garrysmod/addons/prop_counter_addon/lua/autorun/prop_counter_init.lua

-- This module works with both client and server
-- First, set up the network communication
if SERVER then
    -- Create network strings for prop counter updates
    util.AddNetworkString("PropCounter_Update")
    util.AddNetworkString("PropCounter_RequestUpdate")
    
    -- Track props per player on the server
    local playerProps = {}
    
    -- When a player spawns a prop, update their count
    hook.Add("PlayerSpawnedProp", "PropCounter_ServerTrack", function(ply, model, ent)
        if not IsValid(ply) then return end
        
        local steamID = ply:SteamID()
        playerProps[steamID] = playerProps[steamID] or {}
        table.insert(playerProps[steamID], ent)
        
        -- Send updated count to the specific player
        net.Start("PropCounter_Update")
        net.WriteInt(#playerProps[steamID], 16)
        net.Send(ply)
    end)
    
    -- When an entity is removed, check if it was a player's prop
    hook.Add("EntityRemoved", "PropCounter_ServerTrackRemoval", function(ent)
        if not IsValid(ent) or ent:GetClass() != "prop_physics" then return end
        
        -- Find which player owned this prop
        for steamID, props in pairs(playerProps) do
            for i, prop in ipairs(props) do
                if prop == ent then
                    table.remove(props, i)
                    
                    -- Find the player and send them the update
                    for _, ply in ipairs(player.GetAll()) do
                        if ply:SteamID() == steamID then
                            net.Start("PropCounter_Update")
                            net.WriteInt(#props, 16)
                            net.Send(ply)
                            break
                        end
                    end
                    
                    break
                end
            end
        end
    end)
    
    -- When a player requests their prop count
    net.Receive("PropCounter_RequestUpdate", function(len, ply)
        local steamID = ply:SteamID()
        playerProps[steamID] = playerProps[steamID] or {}
        
        -- Clean up invalid props first
        for i = #playerProps[steamID], 1, -1 do
            if not IsValid(playerProps[steamID][i]) then
                table.remove(playerProps[steamID], i)
            end
        end
        
        -- Send current count to player
        net.Start("PropCounter_Update")
        net.WriteInt(#playerProps[steamID], 16)
        net.Send(ply)
    end)
    
    -- When a player disconnects, clean up their prop table
    hook.Add("PlayerDisconnected", "PropCounter_CleanupOnDisconnect", function(ply)
        playerProps[ply:SteamID()] = nil
    end)
end

if CLIENT then
    -- Create a variable to store the player's prop count
    local playerPropCount = 0
    
    -- Create a larger font for the counter
    surface.CreateFont("PropCounterFont", {
        font = "Roboto",
        size = 20,
        weight = 500,
        antialias = true,
        extended = true
    })
    
    -- Colors with fully opaque background
    local colors = {
        background = Color(31, 31, 31, 255),  -- Changed alpha to 255 for fully opaque
        text = Color(255, 255, 255, 255),     -- White text
        accent = Color(30, 120, 255, 255)     -- Blue accent
    }
    
    -- Receive updates from server
    net.Receive("PropCounter_Update", function()
        playerPropCount = net.ReadInt(16)
    end)
    
    -- Request updates from server
    local function RequestPropUpdate()
        net.Start("PropCounter_RequestUpdate")
        net.SendToServer()
    end
    
    -- List of tools/weapons that should show the prop counter
    local allowedWeapons = {
        ["weapon_physgun"] = true,
        ["gmod_tool"] = true,
        ["weapon_physcannon"] = true  -- Gravity gun
    }

    -- Hook into the HUD Paint function to display the minimalist prop counter
    hook.Add("HUDPaint", "PropCounterHUD", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        -- Check current weapon
        local currentWeapon = ply:GetActiveWeapon()
        if not IsValid(currentWeapon) then return end
        
        local weaponClass = currentWeapon:GetClass()
        
        -- Only display when player has allowed weapons out
        if not allowedWeapons[weaponClass] then return end
        
        -- Position the counter in the bottom right of the screen
        local posX = ScrW() - 90
        local posY = ScrH() - 50
        local width = 80
        local height = 40
        
        -- Draw the simple background
        draw.RoundedBox(4, posX - 5, posY - 5, width, height, colors.background)
        
        -- Draw the prop icon (a simple wireframe cube)
        surface.SetDrawColor(colors.accent)
        draw.NoTexture()
        local size = 18
        local iconX = posX + 15
        local iconY = posY + 15
        
        -- Draw a simple cube icon
        local points = {
            {x = iconX - size/3, y = iconY - size/3},           -- Top left front
            {x = iconX + size/3, y = iconY - size/3},           -- Top right front
            {x = iconX + size/3, y = iconY + size/3},           -- Bottom right front
            {x = iconX - size/3, y = iconY + size/3},           -- Bottom left front
            {x = iconX - size/2, y = iconY - size/2},           -- Top left back
            {x = iconX + size/6, y = iconY - size/2},           -- Top right back
            {x = iconX + size/6, y = iconY + size/6},           -- Bottom right back
            {x = iconX - size/2, y = iconY + size/6}            -- Bottom left back
        }
        
        -- Front face
        surface.DrawLine(points[1].x, points[1].y, points[2].x, points[2].y)
        surface.DrawLine(points[2].x, points[2].y, points[3].x, points[3].y)
        surface.DrawLine(points[3].x, points[3].y, points[4].x, points[4].y)
        surface.DrawLine(points[4].x, points[4].y, points[1].x, points[1].y)
        
        -- Back face
        surface.DrawLine(points[5].x, points[5].y, points[6].x, points[6].y)
        surface.DrawLine(points[6].x, points[6].y, points[7].x, points[7].y)
        surface.DrawLine(points[7].x, points[7].y, points[8].x, points[8].y)
        surface.DrawLine(points[8].x, points[8].y, points[5].x, points[5].y)
        
        -- Connecting lines
        surface.DrawLine(points[1].x, points[1].y, points[5].x, points[5].y)
        surface.DrawLine(points[2].x, points[2].y, points[6].x, points[6].y)
        surface.DrawLine(points[3].x, points[3].y, points[7].x, points[7].y)
        surface.DrawLine(points[4].x, points[4].y, points[8].x, points[8].y)
        
        -- Draw the counter value
        draw.SimpleText(playerPropCount, "PropCounterFont", posX + 55, posY + 15, 
            colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)

    -- Initialize the counter when the player spawns
    hook.Add("InitPostEntity", "LoadInitialPropCount", function()
        timer.Simple(3, function()
            RequestPropUpdate()
        end)
    end)
    
    -- Regularly request updates to ensure accuracy
    timer.Create("PropCounterPeriodicUpdate", 1, 0, function()
        RequestPropUpdate()
    end)
    
    print("[Prop Counter] Minimalist counter loaded successfully")
end