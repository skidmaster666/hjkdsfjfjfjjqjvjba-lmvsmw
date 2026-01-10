local ML = {
    version = 1.4, 
    propkills = 0, 
    max_vel = 0, 
    current_vel = 0, 
    aimbot_active = false, 
    aimbot_target = nil,
    KillMessage = "1",
}

local snowflakes = {}

local lethal_active = false

local hitsounds_list = {
    {name = "Skeet", url = "https://files.catbox.moe/575j56.mp3", file = "hitsound_skeet.dat"},
    {name = "Bell", url = "https://files.catbox.moe/8x838s.mp3", file = "hitsound_bell.dat"},
    {name = "Bubble", url = "https://files.catbox.moe/example.mp3", file = "hitsound_bubble.dat"},
    {name = "Rust", url = "https://files.catbox.moe/example2.mp3", file = "hitsound_rust.dat"},
}

local watermark_fps = 0
local watermark_last_update = CurTime()

local last_hitsound_time = 0

local killfeed_entries = {}
local killfeed_lifetime = 5
local killfeed_spacing = 35

RunConsoleCommand("cl_updaterate", "1000")
RunConsoleCommand("cl_cmdrate", "0")
RunConsoleCommand("cl_interp", "0")
RunConsoleCommand("rate", "51200")

CreateMaterial("ML_GLOW", "UnlitGeneric", {
    ["$basetexture"] = "models/debug/debugwhite", 
    ["$nocull"] = 1, 
    ["$model"] = 1,
    ["$ignorez"] = 1
})
local chams_materials = {
    {name = "Flat", mat = "!ML_GLOW"},
    {name = "Wireframe", mat = "models/wireframe"},
    {name = "Plastic", mat = "models/debug/debugwhite"},
}

local config_convars = {
    "ml_enabled", "ml_esp", "ml_chams", "ml_xray", "ml_esp_box", 
    "ml_tracers", "ml_esp_healthbar", "ml_chams_mat", "ml_hitsound_select", 
    "ml_trajectory", "ml_headbeams", "ml_physline", "ml_watermark", 
    "ml_velocity_hud", "ml_bhop", "ml_fov_enable", "ml_fov_value", 
    "ml_3rdperson", "ml_ping_predict", "ml_fps_saver", "ml_aimbot", 
    "ml_aimbot_smooth", "ml_aimbot_fov", "ml_health_ammo", 
    "ml_prop_hitsounds", "ml_silent_aim",
    "ml_custom_crosshair", "ml_draw_fov"
}

CreateClientConVar("ml_enabled", 1, true, false)
CreateClientConVar("ml_esp", 1, true, false)
CreateClientConVar("ml_chams", 1, true, false)
CreateClientConVar("ml_xray", 1, true, false)
CreateClientConVar("ml_esp_box", 1, true, false)
CreateClientConVar("ml_tracers", 1, true, false)
CreateClientConVar("ml_esp_healthbar", 1, true, false)
CreateClientConVar("ml_chams_mat", 1, true, false)
CreateClientConVar("ml_hitsound_select", 1, true, false)
CreateClientConVar("ml_trajectory", 1, true, false)
CreateClientConVar("ml_headbeams", 1, true, false)
CreateClientConVar("ml_physline", 1, true, false)
CreateClientConVar("ml_watermark", 1, true, false)
CreateClientConVar("ml_velocity_hud", 1, true, false)
CreateClientConVar("ml_bhop", 1, true, false)
CreateClientConVar("ml_fov_enable", 1, true, false)
CreateClientConVar("ml_fov_value", 110, true, false)
CreateClientConVar("ml_3rdperson", 0, true, false)
CreateClientConVar("ml_ping_predict", 1, true, false)
CreateClientConVar("ml_fps_saver", 1, true, false)
CreateClientConVar("ml_aimbot", 0, true, false)
CreateClientConVar("ml_aimbot_smooth", 0, true, false, "Aimbot Smoothing") 
CreateClientConVar("ml_aimbot_fov", 20, true, false, "Aimbot FOV")
CreateClientConVar("ml_health_ammo", 1, true, false)
CreateClientConVar("ml_prop_hitsounds", 1, true, false)
CreateClientConVar("ml_silent_aim", 0, true, false)
CreateClientConVar("ml_custom_crosshair", 0, true, false)
CreateClientConVar("ml_draw_fov", 1, true, false)


surface.CreateFont("ML_Title", {font = "Verdana", size = 32, weight = 900, antialias = true})
surface.CreateFont("ML_Title2", {font = "Verdana", size = 14, weight = 900, antialias = true})
surface.CreateFont("ML_Subtitle", {font = "Verdana", size = 14, weight = 700, antialias = true})
surface.CreateFont("ML_Text", {font = "Verdana", size = 12, weight = 500, antialias = true})

local function PulseColor()
    local pulse = math.sin(RealTime() * 2.5) * 0.1 + 0.9
    return Color(255 * pulse, 196 * pulse, 241 * pulse, 255)
end

local function LoadConfig()
    if not file.Exists("matcha_config.json", "DATA") then return end
    local json = file.Read("matcha_config.json", "DATA")
    local data = util.JSONToTable(json)
    
    if data then
        for _, cvar in pairs(config_convars) do
            if data[cvar] != nil then
                RunConsoleCommand(cvar, tostring(data[cvar]))
            end
        end
    end
end

local function SaveConfig()
    local data = {}
    for _, cvar in pairs(config_convars) do
        data[cvar] = GetConVarNumber(cvar)
    end
    file.Write("matcha_config.json", util.TableToJSON(data, true))
end

LoadConfig()

local function PlayEnhanced2DSound()
    if CurTime() - last_hitsound_time < 0.1 then return end
    last_hitsound_time = CurTime()

    local selection = math.Clamp(GetConVarNumber("ml_hitsound_select"), 1, #hitsounds_list)
    local sndData = hitsounds_list[selection]
    local fileName = sndData.file

    if not file.Exists("sound/data/"..fileName, "GAME") and not file.Exists(fileName, "DATA") then 
        surface.PlaySound("physics/wood_box_impact_bullet4.wav")
        return 
    end

    sound.PlayFile("data/" .. fileName, "nopitch mono", function(station)
        if IsValid(station) then
            station:SetVolume(1.0)
            station:Play()
        end
    end)
end


local function InitSnowflakes()
    snowflakes = {}
    for i = 1, 80 do
        table.insert(snowflakes, {
            x = math.random(-500, ScrW()),
            y = math.random(-50, ScrH()),
            size = math.random(2, 6),
            speed = math.random(20, 50) / 10,
            opacity = math.random(100, 255)
        })
    end
end

local function UpdateSnowflakes()
    local dt = FrameTime()
    local angle_rad = math.rad(90)
    
    for _, flake in ipairs(snowflakes) do
        flake.y = flake.y + flake.speed * dt * 60
        flake.x = flake.x + math.cos(angle_rad) * flake.speed * dt * 60
        
        if flake.y > ScrH() + 50 or flake.x > ScrW() + 50 then
            flake.y = -50
            flake.x = math.random(-50, ScrW())
        end
    end
end

local function DrawSnowflakes()
    for _, flake in ipairs(snowflakes) do
        surface.SetDrawColor(255, 255, 255, flake.opacity)
        surface.DrawCircle(flake.x, flake.y, flake.size)
    end
end

InitSnowflakes()

local function IsValidPlayer(ply)
    return IsValid(ply) and ply:Alive() and ply != LocalPlayer() and ply:Team() != TEAM_SPECTATOR and ply:GetObserverMode() == 0
end


local function IsOutOfView(ent)
    if GetConVarNumber("ml_fps_saver") == 0 then return false end
    if LocalPlayer():GetObserverMode() != 0 then return false end
    
    local width = ent:BoundingRadius()
    local disp = ent:GetPos() - LocalPlayer():GetShootPos()
    local dist = disp:Length()
    if dist == 0 then return false end

    local maxcos = math.abs(math.cos(math.acos(dist / math.sqrt(dist * dist + width * width)) + 180 * (math.pi / 180)))
    disp:Normalize()
    return disp:Dot(LocalPlayer():EyeAngles():Forward()) < maxcos
end

local function UnhookMatcha()
    SaveConfig()

    local hooks = {
        {"HUDPaint", "ML_ESP"},
        {"PreDrawEffects", "ML_CHAMS"},
        {"PreDrawHalos", "ML_Halos"},
        {"PreDrawEffects", "ML_XRAY"},
        {"RenderScreenspaceEffects", "ML_Trajectory"},
        {"RenderScreenspaceEffects", "ML_Tracers"},
        {"DrawPhysgunBeam", "ML_Physline_Hook"},
        {"PostDrawTranslucentRenderables", "ML_DrawPhysline"},
        {"Think", "ML_Stats"},
        {"HUDPaint", "ML_VelocityHUD"},
        {"HUDPaint", "ML_Watermark"},
        {"Think", "ML_Bhop"},
        {"CalcView", "ML_MainView"},
        {"ShouldDrawLocalPlayer", "ML_ShouldDrawThirdPerson"},
        {"entity_killed", "ML_PropKills"},
        {"Think", "ML_MenuKeyBind"},
        {"HUDPaint", "ML_SnowflakesBackground"},
        {"HUDPaint", "ML_HealthAmmo"},
        {"HUDShouldDraw", "ML_HideDefaultHUD"},
        {"entity_killed", "ML_PropHitsound"},
        {"HUDPaint", "ML_CustomCrosshair"},
        {"HUDShouldDraw", "ML_HideCrosshair"},
        {"DrawDeathNotice", "ML_DisableDefaultKillfeed"},
        {"PostDrawTranslucentRenderables", "ML_3DBox"},
        {"entity_killed", "ML_Killfeed_Capture"},
        {"HUDPaint", "ML_Killfeed_Render"},
        {"HUDPaint", "ML_DrawFOVCircle"},
        {"CreateMove", "ML_PropkillAim"}
    }

    for _, v in pairs(hooks) do
        hook.Remove(v[1], v[2])
    end

    if IsValid(ml_frame) then ml_frame:Remove() end
    if IsValid(LocalPlayer()) then 
        LocalPlayer():SetFOV(0, 0) 
        LocalPlayer():SetColor(Color(255, 255, 255, 255))
        render.MaterialOverride(nil)
        render.SetColorModulation(1, 1, 1)
    end

    local notify = vgui.Create("DPanel")
    notify:SetSize(350, 40)
    notify:SetPos(ScrW() / 2 - 175, ScrH() - 100)
    notify.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(16, 16, 16))
        draw.RoundedBox(8, 1, 1, w - 2, h - 2, Color(14, 14, 14))
        draw.SimpleText("unhooked.", "ML_Subtitle", w/2, h/2, Color(255, 196, 241), 1, 1)
    end
    timer.Simple(3, function() if IsValid(notify) then notify:Remove() end end)

    concommand.Remove("matcha_menu")
    
    for i = 1, 100 do Msg("\n") end

    ML = nil
end

hook.Add("HUDPaint", "ML_ESP", function()
    if GetConVarNumber("ml_esp") == 0 or GetConVarNumber("ml_enabled") == 0 then return end
    
    local pulseCol = PulseColor()
    
    for _, ply in pairs(player.GetAll()) do
        if IsValidPlayer(ply) then
            local min, max = ply:GetCollisionBounds()
            local pos = ply:GetPos()
            local top = (pos + Vector(0, 0, max.z)):ToScreen()
            local bottom = (pos + Vector(0, 0, min.z)):ToScreen()

            draw.SimpleTextOutlined(ply:Nick(), "ML_Text", top.x, top.y - 20, pulseCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 200))

            if GetConVarNumber("ml_esp_healthbar") == 1 then
                local h = bottom.y - top.y
                local w = h * 0.65

                local distance = LocalPlayer():GetPos():Distance(ply:GetPos())
                local scaleFactor = math.Clamp(1 - (distance / 2000), 0.3, 1)
                local barW = 5 * scaleFactor

                local barX = top.x + (w * 0.6) 
                local barY = top.y
                local barH = h
                
                local hp = math.Clamp(ply:Health(), 0, 100)
                local maxHp = ply:GetMaxHealth()
                local hpPercent = hp / maxHp
                local fillH = barH * hpPercent

                surface.SetDrawColor(0, 0, 0, 200)
                surface.DrawRect(barX, barY, barW, barH)

                local col = Color(255 - (hpPercent * 255), hpPercent * 255, 0)
                surface.SetDrawColor(col.r, col.g, col.b, 255)

                surface.DrawRect(barX, barY + (barH - fillH), barW, fillH)

                if hp < 100 then
                    draw.SimpleTextOutlined(tostring(hp), "ML_Text", barX + 6, barY + (barH - fillH) - 4, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, Color(0,0,0))
                end
            end
        end
    end
end)

hook.Add("PostDrawTranslucentRenderables", "ML_3DBox", function()
    if GetConVarNumber("ml_esp") == 0 or GetConVarNumber("ml_esp_box") == 0 or GetConVarNumber("ml_enabled") == 0 then return end
    
    cam.Start3D()
    local col = PulseColor()
    
    for _, ply in pairs(player.GetAll()) do
        if IsValidPlayer(ply) then
            local min, max = ply:GetCollisionBounds()
            render.DrawWireframeBox(ply:GetPos(), Angle(0,0,0), min, max, col, true)
        end
    end
    
    cam.End3D()
end)

hook.Add("DrawDeathNotice", "ML_DisableDefaultKillfeed", function()
    if GetConVarNumber("ml_enabled") == 0 then return end
    return false
end)

hook.Add("entity_killed", "ML_Killfeed_Capture", function(data)
if GetConVarNumber("ml_enabled") == 0 then return end
    
    local victim = Entity(data.entindex_killed)
    local inflictor = Entity(data.entindex_inflictor)
    local attacker = Entity(data.entindex_attacker)
    
    if not IsValid(victim) or not victim:IsPlayer() then return end

    local attacker_name = "World"

    if IsValid(attacker) and attacker:IsPlayer() then
        attacker_name = attacker:Nick()
    elseif IsValid(inflictor) then
        local owner = inflictor:GetNWEntity("PropOwner", nil)
        if not IsValid(owner) then owner = inflictor:GetOwner() end
        
        if IsValid(owner) and owner:IsPlayer() then
            attacker_name = owner:Nick()
        elseif inflictor:GetClass() == "prop_physics" then
            attacker_name = "Physics Prop"
        end
    end

    if attacker_name == victim:Nick() then attacker_name = "Suicide" end

    local kill_text = attacker_name .. "      ►      " .. victim:Nick()

    table.insert(killfeed_entries, {
        text = kill_text,
        time = CurTime(),
        x = ScrW() + 400,
        alpha = 0
    })
end)

hook.Add("HUDPaint", "ML_Killfeed_Render", function()
    if GetConVarNumber("ml_enabled") == 0 then return end

    local start_y = 60
    local right_margin = 20
    local dt = FrameTime()
    local accent_color = PulseColor()
    
    for i, entry in ipairs(killfeed_entries) do
        local time_delta = CurTime() - entry.time
        if time_delta > killfeed_lifetime then
            table.remove(killfeed_entries, i)
            continue
        end

        surface.SetFont("ML_Subtitle")
        local text_w, text_h = surface.GetTextSize(entry.text)
        local box_width = text_w + 30
        local box_height = 25

        local target_x = ScrW() - box_width - right_margin

        entry.x = Lerp(dt * 10, entry.x, target_x)
        
        local current_y = start_y + ((i - 1) * killfeed_spacing)
        local alpha = 255
        if time_delta > (killfeed_lifetime - 0.5) then
            alpha = 255 * ((killfeed_lifetime - time_delta) / 0.5)
        end

        draw.RoundedBox(4, entry.x, current_y, box_width, box_height, Color(20, 20, 20, alpha))
        
        surface.SetDrawColor(accent_color.r, accent_color.g, accent_color.b, alpha)
        surface.DrawOutlinedRect(entry.x, current_y, box_width, box_height, 1)
        
        surface.SetDrawColor(0, 0, 0, alpha)
        surface.DrawOutlinedRect(entry.x - 1, current_y - 1, box_width + 2, box_height + 2, 1)
        surface.DrawOutlinedRect(entry.x - 2, current_y - 2, box_width + 4, box_height + 4, 1)

        draw.SimpleTextOutlined(entry.text, "ML_Subtitle", entry.x + (box_width / 2), current_y + (box_height / 2), Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, alpha))
    end
end)

hook.Add("HUDPaint", "ML_HealthAmmo", function()
    if GetConVarNumber("ml_health_ammo") == 0 or GetConVarNumber("ml_enabled") == 0 then return end
    if not IsValid(LocalPlayer()) then return end
    
    local ply = LocalPlayer()
    local health = math.max(0, ply:Health())
    local maxHealth = ply:GetMaxHealth()
    local healthPercent = math.Clamp(health / maxHealth, 0, 1)
    
    if health <= 10 and ply:Alive() then
        lethal_active = true
    elseif health > 10 or not ply:Alive() then
        lethal_active = false
    end
    
   if lethal_active then
        draw.SimpleTextOutlined("LETHAL", "ML_Subtitle", ScrW() / 2, ScrH() / 2 + 20, Color(255, 50, 50, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 200))
    end

    local x, y = 20, ScrH() - 120
    local barWidth = 225
    local barHeight = 18
    
    draw.RoundedBox(4, x, y, barWidth, barHeight, Color(35, 35, 35))

    local healthColor = Color(255 - (healthPercent * 255), healthPercent * 255, 0)
    
    draw.RoundedBox(4, x, y, barWidth * healthPercent, barHeight, healthColor)
    
    draw.SimpleTextOutlined(health .. "/" .. maxHealth .. " HP", "ML_Text", x + 5, y - 18, PulseColor(), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, Color(0, 0, 0, 200))

    if IsValid(ply:GetActiveWeapon()) then
        local wep = ply:GetActiveWeapon()
        local clip = wep:Clip1()
        local ammo = ply:GetAmmoCount(wep:GetPrimaryAmmoType())
        
        local ammoY = y + barHeight + 20
        
        draw.RoundedBox(4, x, ammoY, barWidth, barHeight, Color(35, 35, 35))
        
        if clip > 0 and wep.GetMaxClip1 then
            local maxClip = wep:GetMaxClip1()
            local clipPercent = math.Clamp(clip / maxClip, 0, 1)
            draw.RoundedBox(4, x, ammoY, barWidth * clipPercent, barHeight, PulseColor())
        end
        
        draw.SimpleTextOutlined(clip .. " | " .. ammo .. " ammo", "ML_Text", x + 5, ammoY - 18, Color(200, 230, 245, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, Color(0, 0, 0, 200))
    end
end)

hook.Add("PreDrawEffects", "ML_CHAMS", function()
    if GetConVarNumber("ml_chams") == 0 or GetConVarNumber("ml_enabled") == 0 or GetConVarNumber("ml_esp") == 0 then return end
    
    local matIndex = GetConVarNumber("ml_chams_mat")
    local selectedMatData = chams_materials[matIndex] or chams_materials[1]
    local useMaterial = selectedMatData.mat

    for _, ply in pairs(player.GetAll()) do
        if ply == LocalPlayer() then continue end
        
        if IsValidPlayer(ply) then
            cam.IgnoreZ(true)

            local material = Material(useMaterial)
            render.MaterialOverride(material)
            render.SuppressEngineLighting(true)
            
            local col = PulseColor()
            render.SetColorModulation(col.r / 255, col.g / 255, col.b / 255)

            if selectedMatData.name == "Wireframe" then
                 render.SetBlend(1)
            else
                 render.SetBlend(0.8)
            end
            
            ply:DrawModel()
            
            render.MaterialOverride(nil)
            render.SuppressEngineLighting(false)
            cam.IgnoreZ(false)

                 ply:SetColor(Color(255,255,255,255))
        end
    end
end)

hook.Add("PreDrawHalos", "ML_Halos", function()
    if GetConVarNumber("ml_chams") == 0 or GetConVarNumber("ml_enabled") == 0 then return end
    local targets = {}
    for _, ply in pairs(player.GetAll()) do
        if IsValidPlayer(ply) and not IsOutOfView(ply) then
            table.insert(targets, ply)
        end
    end
    if #targets > 0 then
        halo.Add(targets, Color(255, 196, 241, 200), 3, 3, 2, false, true)
    end
end)


hook.Add("PreDrawEffects", "ML_XRAY", function()
    if GetConVarNumber("ml_xray") == 0 or GetConVarNumber("ml_enabled") == 0 then return end
    for _, prop in pairs(ents.FindByClass("prop_physics")) do
        local glow = math.sin(RealTime() * 3) * 0.4 + 0.6
        prop:SetColor(Color(0, 0, 0, 0))

        cam.IgnoreZ(true)
        prop:SetRenderMode(RENDERMODE_TRANSALPHA)
        render.SuppressEngineLighting(true)
        render.MaterialOverride(Material("models/effects/comball_sphere"))
        render.SetColorModulation(1 * glow, 0.76 * glow, 0.94 * glow)
        render.SetBlend(0.5)
        prop:DrawModel()
        render.SuppressEngineLighting(false)

        cam.IgnoreZ(false)
        cam.IgnoreZ(true)
        prop:SetRenderMode(RENDERMODE_TRANSALPHA)
        render.SuppressEngineLighting(true)
        render.MaterialOverride(Material("!ML_GLOW"))
        render.SetColorModulation(1 * glow, 0.76 * glow, 0.94 * glow)
        render.SetBlend(0.7)
        prop:DrawModel()
        render.SuppressEngineLighting(false)
        cam.IgnoreZ(false)
        
        local pulse = 0.5 + math.sin(RealTime() * 2) * 0.5
        cam.IgnoreZ(true)
        render.DrawWireframeBox(prop:GetPos(), prop:GetAngles(), prop:OBBMaxs() * (1 + pulse * 0.08), prop:OBBMins() * (1 + pulse * 0.08), Color(255, 196, 241, 180))
        cam.IgnoreZ(false)
    end
end)

hook.Add("RenderScreenspaceEffects", "ML_Trajectory", function()
    if GetConVarNumber("ml_trajectory") == 0 or GetConVarNumber("ml_enabled") == 0 then return end
    for _, ply in pairs(player.GetAll()) do
        if IsValidPlayer(ply) and not IsOutOfView(ply) and ply:GetVelocity():LengthSqr() > 1440000 then
            local start = ply:EyePos()
            local endpos = start + ply:GetVelocity():GetNormalized() * 2000
            cam.Start3D()
            cam.IgnoreZ(true)
            render.SetMaterial(Material("sprites/tp_beam001"))
            render.DrawBeam(start, endpos, 50, 1, 1, PulseColor())
            cam.IgnoreZ(false)
            cam.End3D()
        end
    end
end)

hook.Add("HUDShouldDraw", "ML_HideCrosshair", function(name)
    if GetConVarNumber("ml_custom_crosshair") == 1 and name == "CHudCrosshair" then
        return false
    end
end)

hook.Add("HUDPaint", "ML_CustomCrosshair", function()
    if GetConVarNumber("ml_custom_crosshair") == 0 or GetConVarNumber("ml_enabled") == 0 then return end
    
    local x, y = ScrW() / 2, ScrH() / 2
    local col = PulseColor()

    surface.SetDrawColor(col.r, col.g, col.b, 255)
    draw.NoTexture()

    surface.SetDrawColor(0, 0, 0, 200)
    surface.DrawCircle(x, y, 5, 0, 0, 0, 255)

    surface.SetDrawColor(col.r, col.g, col.b, 255)
    for i = 1, 3 do
        surface.DrawCircle(x, y, 4 - i, 255, 255, 255, 255)
    end
end)

hook.Add("HUDPaint", "ML_DrawFOVCircle", function()
    if GetConVarNumber("ml_enabled") == 0 or GetConVarNumber("ml_draw_fov") == 0 then return end
    
    local fov_degrees = GetConVarNumber("ml_aimbot_fov")
    if fov_degrees <= 0 then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local center_x = ScrW() / 2
    local center_y = ScrH() / 2

    local view_fov = ply:GetFOV()
    local radius = math.tan(math.rad(fov_degrees) / 2) / math.tan(math.rad(view_fov) / 2) * (ScrW() / 2)

    local col = PulseColor()
    
    local thickness = 2
    
    for i = 0, thickness - 1 do
        surface.SetDrawColor(col.r, col.g, col.b, 255)
        surface.DrawCircle(center_x, center_y, radius + i)
        
        surface.SetDrawColor(0, 0, 0, 100)
        surface.DrawCircle(center_x, center_y, radius + i + 1)
        surface.DrawCircle(center_x, center_y, radius - 1)
    end
end)


hook.Add("RenderScreenspaceEffects", "ML_Tracers", function()
    if GetConVarNumber("ml_tracers") == 0 or GetConVarNumber("ml_enabled") == 0 then return end
    for _, ply in pairs(player.GetAll()) do
        if IsValidPlayer(ply) and LocalPlayer():GetObserverMode() == 0 then
            cam.Start3D()
            cam.IgnoreZ(true)
            local startPos = LocalPlayer():GetPos() + LocalPlayer():EyeAngles():Forward() * 50
            local endPos = ply:GetPos()
            local direction = (endPos - startPos):GetNormal()
            local perpendicular = direction:Cross(Vector(0, 0, 1)):GetNormal()
            local width = 3
            local outlineWidth = 4
            local color = Color(255, 196, 241)
            local outlineColor = Color(148, 114, 140)
            
            render.SetColorMaterial()
            
            local v1_outline = startPos + perpendicular * outlineWidth
            local v2_outline = startPos - perpendicular * outlineWidth
            local v3_outline = endPos - perpendicular * outlineWidth
            local v4_outline = endPos + perpendicular * outlineWidth
            
            mesh.Begin(MATERIAL_QUADS, 1)
            mesh.Position(v1_outline)
            mesh.Color(outlineColor.r, outlineColor.g, outlineColor.b, 255)
            mesh.AdvanceVertex()
            mesh.Position(v2_outline)
            mesh.Color(outlineColor.r, outlineColor.g, outlineColor.b, 255)
            mesh.AdvanceVertex()
            mesh.Position(v3_outline)
            mesh.Color(outlineColor.r, outlineColor.g, outlineColor.b, 255)
            mesh.AdvanceVertex()
            mesh.Position(v4_outline)
            mesh.Color(outlineColor.r, outlineColor.g, outlineColor.b, 255)
            mesh.AdvanceVertex()
            mesh.End()
            
            local v1 = startPos + perpendicular * width
            local v2 = startPos - perpendicular * width
            local v3 = endPos - perpendicular * width
            local v4 = endPos + perpendicular * width
            
            mesh.Begin(MATERIAL_QUADS, 1)
            mesh.Position(v1)
            mesh.Color(color.r, color.g, color.b, 255)
            mesh.AdvanceVertex()
            mesh.Position(v2)
            mesh.Color(color.r, color.g, color.b, 255)
            mesh.AdvanceVertex()
            mesh.Position(v3)
            mesh.Color(color.r, color.g, color.b, 255)
            mesh.AdvanceVertex()
            mesh.Position(v4)
            mesh.Color(color.r, color.g, color.b, 255)
            mesh.AdvanceVertex()
            mesh.End()
            
            cam.IgnoreZ(false)
            cam.End3D()
        end
    end
end)


local physline_data = {active = false, start = Vector(0, 0, 0), end_pos = Vector(0, 0, 0), last_update = 0}

hook.Add("DrawPhysgunBeam", "ML_Physline_Hook", function(ply, wep, enabled, target)
    if ply != LocalPlayer() or not IsValid(wep) then return end
    if enabled and IsValid(target) and target:GetClass() == "prop_physics" then
        local att = wep:GetAttachment(1)
        physline_data.start = att and att.Pos or LocalPlayer():GetShootPos()
        physline_data.end_pos = target:LocalToWorld(target:OBBCenter())
        physline_data.active = true
        physline_data.last_update = CurTime()
    else
        physline_data.active = false
    end
    return false
end)

hook.Add("PostDrawTranslucentRenderables", "ML_DrawPhysline", function()
    if GetConVarNumber("ml_physline") == 0 or GetConVarNumber("ml_enabled") == 0 then return end
    if not physline_data.active or (CurTime() - physline_data.last_update) > 0.1 then return end
    cam.Start3D()
    cam.IgnoreZ(true)
    render.SetMaterial(Material("sprites/tp_beam001"))
    render.DrawBeam(physline_data.start, physline_data.end_pos, 14, 1, 1, Color(255, 196, 241, 255))
    render.SetMaterial(Material("cable/redlaser"))
    render.DrawBeam(physline_data.start, physline_data.end_pos, 6, 1, 1, Color(255, 196, 241, 200))
    cam.IgnoreZ(false)
    cam.End3D()
end)

local stats = {max_vel = 0, current_vel = 0, distance = 0, last_pos = nil, last_time = 0}

hook.Add("Think", "ML_Stats", function()
    if ML == nil then return end
    if not (IsValid(LocalPlayer()) and LocalPlayer():Alive()) then return end
    local vel = LocalPlayer():GetVelocity():Length()
    if vel > stats.max_vel then stats.max_vel = vel end
    stats.current_vel = vel
    if vel > 500 then
        if not stats.last_pos then
            stats.last_pos = LocalPlayer():GetPos()
            stats.last_time = CurTime()
        else
            stats.distance = stats.distance + stats.last_pos:Distance(LocalPlayer():GetPos())
            stats.last_pos = LocalPlayer():GetPos()
            stats.last_time = CurTime()
        end
    end
end)

hook.Add("HUDPaint", "ML_VelocityHUD", function()
    if GetConVarNumber("ml_velocity_hud") == 0 or GetConVarNumber("ml_enabled") == 0 then return end
    draw.SimpleTextOutlined(math.Round(stats.current_vel) .. " UPS", "ML_Title", ScrW() / 2, ScrH() / 2 + 80, PulseColor(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 3, Color(0, 0, 0, 200))
    draw.SimpleTextOutlined("MAX: " .. math.Round(stats.max_vel), "ML_Subtitle", ScrW() / 2, ScrH() / 2 + 120, Color(240, 245, 250, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 200))
end)

hook.Add("HUDPaint", "ML_Watermark", function()
    if GetConVarNumber("ml_watermark") == 0 or GetConVarNumber("ml_enabled") == 0 then return end
    
    if CurTime() - watermark_last_update >= 0.5 then
        watermark_fps = math.Round(1 / FrameTime())
        watermark_last_update = CurTime()
    end
    
    local x, y = 20, 20
    local accent_color = PulseColor()
    local text_color = Color(255,255,255, 255)
    local outline_color = Color(0, 0, 0, 200)

    local box_width = 490
    local box_height = 25
    draw.RoundedBox(4, x - 5, y - 5, box_width, box_height, Color(20, 20, 20, 255))
    surface.SetDrawColor(accent_color.r, accent_color.g, accent_color.b, 255)
    surface.DrawOutlinedRect(x - 5, y - 5, box_width, box_height, 1)
    surface.SetDrawColor(0, 0, 0, 255)
    surface.DrawOutlinedRect(x - 6, y - 6, box_width + 2, box_height + 2, 1)
    surface.SetDrawColor(0, 0, 0, 255)
    surface.DrawOutlinedRect(x - 7, y - 7, box_width + 4, box_height + 4, 1)

    local ping = LocalPlayer():Ping()

    draw.SimpleTextOutlined(" matcha latte", "ML_Subtitle", x, y, accent_color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, outline_color)

    draw.SimpleTextOutlined(" | ", "ML_Subtitle", x + 90, y, text_color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, outline_color)

    draw.SimpleTextOutlined("fps: ", "ML_Subtitle", x + 110, y, text_color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, outline_color)
    draw.SimpleTextOutlined(tostring(watermark_fps), "ML_Subtitle", x + 140, y, accent_color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, outline_color)

    draw.SimpleTextOutlined(" | ", "ML_Subtitle", x + 175, y, text_color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, outline_color)

    draw.SimpleTextOutlined("ping: ", "ML_Subtitle", x + 200, y, text_color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, outline_color)
    draw.SimpleTextOutlined(tostring(ping), "ML_Subtitle", x + 240, y, accent_color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, outline_color)

    draw.SimpleTextOutlined(" | ", "ML_Subtitle", x + 260, y, text_color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, outline_color)

    local current_time = os.date("%H:%M:%S")
    draw.SimpleTextOutlined(current_time, "ML_Subtitle", x + 285, y, text_color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, outline_color)

    draw.SimpleTextOutlined(" | ", "ML_Subtitle", x + 360, y, text_color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, outline_color)

    local current_date = os.date("%d/%m/%Y")
    draw.SimpleTextOutlined(current_date, "ML_Subtitle", x + 385, y, text_color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, outline_color)
end)

hook.Add("HUDShouldDraw", "ML_HideDefaultHUD", function(name)
    if GetConVarNumber("ml_health_ammo") == 0 then return end
    
    if name == "CHudHealth" or name == "CHudAmmo" or name == "CHudSecondaryAmmo" then
        return false
    end
end)

gameevent.Listen("entity_killed")
hook.Add("entity_killed", "ML_PropKills", function(data)
    local victim = Entity(data.entindex_killed)
    local inflictor = Entity(data.entindex_inflictor)
    
    if IsValid(inflictor) and inflictor:GetClass() == "prop_physics" then
        if IsValid(victim) and victim:IsPlayer() and victim != LocalPlayer() then
            ML.propkills = ML.propkills + 1

            if not ML.KillMessage or ML.KillMessage == "" then return end

            local timerName = "matcha_say_kill_" .. CurTime()
            
            timer.Create(timerName, 0.1, 1, function()
                RunConsoleCommand("say", ML.KillMessage)
            end)
        end
    end
end)

local jump_state = false
hook.Add("Think", "ML_Bhop", function()
    if GetConVarNumber("ml_bhop") == 0 or GetConVarNumber("ml_enabled") == 0 then return end
    if gui.IsGameUIVisible() or gui.IsConsoleVisible() or LocalPlayer():IsTyping() then return end
    if input.IsKeyDown(KEY_SPACE) then
        if LocalPlayer():IsOnGround() then
            RunConsoleCommand("+jump")
            jump_state = true
        else
            RunConsoleCommand("-jump")
            jump_state = false
        end
    elseif jump_state then
        RunConsoleCommand("-jump")
        jump_state = false
    end
end)

hook.Add("ShouldDrawLocalPlayer", "ML_ShouldDrawThirdPerson", function(ply)
    if ML and GetConVarNumber("ml_enabled") == 1 and GetConVarNumber("ml_3rdperson") == 1 then
        return true
    end
end)


hook.Add("CalcView", "ML_MainView", function(ply, pos, ang, fov)
    if not ML or GetConVarNumber("ml_enabled") == 0 then return end
    
    local view = {}
    view.origin = pos
    view.angles = ang
    view.fov = fov

    if GetConVarNumber("ml_fov_enable") == 1 then
        view.fov = GetConVarNumber("ml_fov_value")
    end

    if GetConVarNumber("ml_3rdperson") == 1 and ply:Alive() then
        local dist = 100
        local tr = util.TraceLine({
            start = pos,
            endpos = pos - (ang:Forward() * dist) + (ang:Up() * 10),
            filter = ply
        })
        view.origin = tr.HitPos + tr.HitNormal * 5
        view.drawviewer = true
    end

    return view
end)


local function GetPropSpeed()
    return 2500 
end

local function PredictPos(ent)
    if not IsValid(ent) then return Vector(0,0,0) end
    
    local myPos = LocalPlayer():EyePos()
    local targetPos = ent:LocalToWorld(ent:OBBCenter())
    local dist = myPos:Distance(targetPos)
    local travelTime = dist / GetPropSpeed()
    
    local pred = targetPos + (ent:GetVelocity() * travelTime)
    
    if not ent:IsOnGround() then
        pred.z = pred.z - (0.5 * 600 * travelTime^2)
    end
    
    return pred
end

local function GetTarget()
    if not LocalPlayer():Alive() then return nil end
    
    local bestEnt = nil
    local bestFov = GetConVarNumber("ml_aimbot_fov")
    local propKillMode = GetConVarNumber("ml_aimbot") == 1

    if propKillMode then bestFov = 360 end

    local myPos = LocalPlayer():EyePos()
    local myForward = LocalPlayer():GetAimVector()
    
    for _, ply in pairs(player.GetAll()) do
        if IsValidPlayer(ply) then
            local targetPos = ply:LocalToWorld(ply:OBBCenter())
            local targetDir = (targetPos - myPos):GetNormalized()

            local dot = myForward:Dot(targetDir)
            local angleDiff = math.deg(math.acos(math.Clamp(dot, -1, 1)))
            
            if angleDiff < bestFov then
                bestFov = angleDiff
                bestEnt = ply
            end
        end
    end
    
    return bestEnt
end

local function NormalizeAngles(angles)
    angles.p = math.NormalizeAngle(angles.p)
    angles.y = math.NormalizeAngle(angles.y)
    angles.r = 0
    return angles
end


local current_view_angles = Angle(0, 0, 0)

hook.Add("CreateMove", "ML_PropkillAim", function(cmd)
    if ML == nil or GetConVarNumber("ml_enabled") == 0 or GetConVarNumber("ml_silent_aim") == 0 then 
        ML.aimbot_target = nil
        return 
    end

    if not input.IsKeyDown(KEY_X) then
        ML.aimbot_target = nil
        return 
    end

    if not IsValid(ML.aimbot_target) or not IsValidPlayer(ML.aimbot_target) then
        ML.aimbot_target = GetTarget()
    end

    if IsValid(ML.aimbot_target) then
        local propKillMode = GetConVarNumber("ml_aimbot") == 1
        local targetPos

        if propKillMode then
            targetPos = PredictPos(ML.aimbot_target)
        else
            targetPos = ML.aimbot_target:LocalToWorld(ML.aimbot_target:OBBCenter())
        end

        local myPos = LocalPlayer():EyePos()
        local targetAngle = (targetPos - myPos):Angle()
        targetAngle.p = math.NormalizeAngle(targetAngle.p)
        targetAngle.y = math.NormalizeAngle(targetAngle.y)

        local smooth = GetConVarNumber("ml_aimbot_smooth")

        if smooth > 0 and not propKillMode then
            local currentAngles = cmd:GetViewAngles()
            local lerpedAngle = LerpAngle(1 / (smooth + 1), currentAngles, targetAngle)
            cmd:SetViewAngles(lerpedAngle)
        else
            cmd:SetViewAngles(targetAngle)
        end
    end
end)

gameevent.Listen("entity_killed")
hook.Add("entity_killed", "ML_PropKills", function(data)
    local victim = Entity(data.entindex_killed)
    local inflictor = Entity(data.entindex_inflictor)
    if IsValid(inflictor) and inflictor:GetClass() == "prop_physics" then
        if IsValid(victim) and victim != LocalPlayer() then
            ML.propkills = ML.propkills + 1
        end
    end
end)

hook.Add("entity_killed", "ML_PropHitsound", function(data)
    if GetConVar("ml_prop_hitsounds"):GetInt() == 0 then return end
    
    local victim = Entity(data.entindex_killed)
    local inflictor = Entity(data.entindex_inflictor)
    
    if IsValid(inflictor) and inflictor:GetClass() == "prop_physics" then
        if IsValid(victim) and victim:IsPlayer() then
            PlayEnhanced2DSound()
        end
    end
end)

hook.Add("HUDPaint", "ML_SnowflakesBackground", function()
    if not IsValid(ml_frame) then return end
    UpdateSnowflakes()
    DrawSnowflakes()
end)

local function LerpColor(frac, from, to)
    return Color(
        from.r + (to.r - from.r) * frac,
        from.g + (to.g - from.g) * frac,
        from.b + (to.b - from.b) * frac,
        from.a + (to.a - from.a) * frac
    )
end

local menuX, menuY = nil, nil
local active_tab = "VISUALS"

local custom_icon = Material("matcha/icon.png") 


local function OpenMenu()
    if IsValid(ml_frame) then
        if ml_frame.isClosing then return end
        ml_frame.isClosing = true 
        
        SaveConfig()

        menuX, menuY = ml_frame:GetPos()
        ml_frame:SetMouseInputEnabled(false)
        ml_frame:SetKeyboardInputEnabled(false)
        ml_frame:AlphaTo(0, 0.1, 0, function()
            if IsValid(ml_frame) then
                ml_frame:Close()
                ml_frame = nil
            end
        end)
        return
    end

    local frame = vgui.Create("DFrame")
    ml_frame = frame
    frame:SetTitle("")
    frame:SetSize(480, 600)
    if menuX and menuY then
        frame:SetPos(menuX, menuY)
    else
        frame:Center()
    end

    frame:MakePopup()
    frame:ShowCloseButton(false)
    frame:SetAlpha(0)
    frame:AlphaTo(255, 0.1)

    local col_bg = Color(14, 14, 14, 255)
    local col_accent = Color(255, 196, 241, 255)
    local col_text_off = Color(100, 100, 100, 255)

    frame.Paint = function(self, w, h)
        Derma_DrawBackgroundBlur(self, self.m_fCreateTime)
        draw.RoundedBox(8, 0, 0, w, h, Color(16, 16, 16))
        draw.RoundedBox(8, 1, 1, w - 2, h - 2, Color(14, 14, 14))
        
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(custom_icon)
        surface.DrawTexturedRect(10, 6, 16, 16) 

        draw.SimpleText(" matcha latte", "ML_Title2", 28, 5, Color(255, 196, 241), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        surface.SetDrawColor(25, 25, 25)
        surface.DrawRect(20, 48, w - 40, 1) 
    end

    local content_area = vgui.Create("DPanel", frame)
    content_area:Dock(FILL)
    content_area:DockMargin(0, 40, 5, 5)
    content_area.Paint = function() end

    local panels = {}

    local function Empty(parent, height)
        local spacer = parent:Add("DPanel")
        spacer:Dock(TOP)
        spacer:SetTall(height)
        spacer.Paint = function() end
    end

    local function CreateCheckbox(parent, text, convar)
        local cb = parent:Add("DCheckBoxLabel")
        cb:SetText(text)
        cb:SetConVar(convar)
        cb:SetFont("ML_Text")
        cb:Dock(TOP)
        cb:DockMargin(10, 0, 0, 5)

        cb.Button.Paint = function(panel, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(35, 35, 35))
            if cb:GetChecked() then
                draw.RoundedBox(4, 2, 2, w - 4, h - 4, Color(255, 196, 241))
            end
        end

        cb.Think = function(self)
            self:SetTextColor(self:GetChecked() and col_accent or col_text_off)
        end
    end

    local function StyleDropdown(parent, label_text)
        if label_text then
            local lbl = parent:Add("DLabel")
            lbl:SetText(label_text)
            lbl:SetFont("ML_Text")
            lbl:SetTextColor(Color(100, 100, 100))
            lbl:Dock(TOP)
            lbl:SetContentAlignment(4)
            lbl:DockMargin(0, 5, 0, 2)
        end
    
        local combo = parent:Add("DComboBox")
        combo:Dock(TOP)
        combo:DockMargin(5, 0, 5, 10) 
        combo:SetFont("ML_Text")
        combo:SetTextColor(Color(255, 196, 241))
        
        combo.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(35, 35, 35))
            local text = self:GetSelected() or "Select..."
            draw.SimpleText(text, "ML_Text", 8, h/2, Color(255, 196, 241), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("▼", "ML_Text", w - 10, h/2, Color(255, 196, 241), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return true 
        end
        return combo
    end

    local pnl_vis_container = vgui.Create("DPanel", content_area)
    pnl_vis_container:Dock(FILL)
    pnl_vis_container:SetVisible(false)
    pnl_vis_container.Paint = function() end
    panels["VISUALS"] = pnl_vis_container

    local previewPnl = pnl_vis_container:Add("DModelPanel")
    previewPnl:Dock(RIGHT)
    previewPnl:SetWide(180)
    previewPnl:DockMargin(20, 10, 20, 150)

    previewPnl:SetModel("models/player/kleiner.mdl")
    previewPnl:SetFOV(40)
    previewPnl:SetCamPos(Vector(80, 0, 40))
    previewPnl:SetLookAt(Vector(40, 0, 38))

    local oldPaint = previewPnl.Paint
    previewPnl.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 20))
        draw.SimpleText("PREVIEW", "ML_Title2", w/2, 10, Color(50, 50, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        oldPaint(self, w, h)
    end

    previewPnl.DrawModel = function(self)
        local ent = self.Entity
        if not IsValid(ent) then return end

        local chams_on = GetConVarNumber("ml_chams") == 1
        
        if chams_on then
            local matIndex = GetConVarNumber("ml_chams_mat")
            local selectedMatData = chams_materials[matIndex] or chams_materials[1]
            local useMaterial = selectedMatData.mat

            render.MaterialOverride(Material(useMaterial))
            render.SuppressEngineLighting(true)
            
            local col = Color(255, 196, 241)
            render.SetColorModulation(col.r / 255, col.g / 255, col.b / 255)

            if selectedMatData.name == "Wireframe" then
                 render.SetBlend(1)
                 ent:SetColor(Color(0,0,0,0))
                 ent:SetRenderMode(RENDERMODE_TRANSALPHA)
            else
                 render.SetBlend(0.8)
            end
            
            ent:DrawModel()
            
            render.MaterialOverride(nil)
            render.SuppressEngineLighting(false)
            ent:SetColor(Color(255,255,255,255))
        else
            ent:DrawModel()
        end
    end

    previewPnl.PaintOver = function(self, w, h)
        local ent = self.Entity
        if not IsValid(ent) then return end

        local col = Color(255, 196, 241)

        local max_box_width = w * 0.6 
        local box_w = max_box_width
        local box_h = box_w * 2.2

        local box_x = (w - box_w) / 2
        local box_y = (h - box_h) / 2

        if GetConVarNumber("ml_esp_box") == 1 then
           surface.SetDrawColor(col)
           surface.DrawOutlinedRect(box_x, box_y, box_w, box_h)
        end

        if GetConVarNumber("ml_esp") == 1 then
            draw.SimpleText("Player", "ML_Text", w/2, box_y - 15, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        if GetConVarNumber("ml_esp_healthbar") == 1 then
            local barX = box_x + box_w + 4
            local barY = box_y
            local barH = box_h

            if barX + 4 < w then 
                surface.SetDrawColor(0, 0, 0, 255)
                surface.DrawOutlinedRect(barX, barY, 4, barH)
                
                surface.SetDrawColor(0, 255, 0, 255)
                surface.DrawRect(barX + 1, barY, 2, barH) 
            end
        end
    end

    local pnl_vis = vgui.Create("DScrollPanel", pnl_vis_container)
    pnl_vis:Dock(FILL)
    pnl_vis:DockMargin(5, 0, 10, 0)

    Empty(pnl_vis, 10)
    local lbl = pnl_vis:Add("DLabel")
    lbl:SetText("ESP, Misc")
    lbl:SetFont("ML_Subtitle")
    lbl:SetTextColor(Color(255, 196, 241))
    lbl:Dock(TOP)
    lbl:SetContentAlignment(5)
    
    Empty(pnl_vis, 10)
    CreateCheckbox(pnl_vis, "Enable ESP", "ml_esp")
    CreateCheckbox(pnl_vis, "3D Box", "ml_esp_box")
    CreateCheckbox(pnl_vis, "Health Bar", "ml_esp_healthbar")
    CreateCheckbox(pnl_vis, "Chams", "ml_chams")
    local drop_chams = StyleDropdown(pnl_vis, "  Chams Material")
    drop_chams:SetConVar("ml_chams_mat")
    for k, v in ipairs(chams_materials) do drop_chams:AddChoice(v.name, k) end
    drop_chams.OnSelect = function(self, index, value, data) RunConsoleCommand("ml_chams_mat", tostring(data)) end

    Empty(pnl_vis, 10)
    CreateCheckbox(pnl_vis, "Prop X-Ray", "ml_xray")
    CreateCheckbox(pnl_vis, "Tracers", "ml_tracers")
    CreateCheckbox(pnl_vis, "Draw Aimbot FOV", "ml_draw_fov")

    Empty(pnl_vis, 10)

    local fov_row = pnl_vis:Add("DPanel")
    fov_row:Dock(TOP)
    fov_row:SetTall(30)
    fov_row:DockMargin(10, 0, 10, 0)
    fov_row.Paint = function() end

    local cb_fov = fov_row:Add("DCheckBoxLabel")
    cb_fov:SetText("Enable FOV")
    cb_fov:SetConVar("ml_fov_enable")
    cb_fov:SetFont("ML_Text")
    cb_fov:Dock(LEFT)
    cb_fov:SetWide(100)
    cb_fov.Button.Paint = function(panel, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(35, 35, 35))
        if cb_fov:GetChecked() then
            draw.RoundedBox(4, 2, 2, w - 4, h - 4, Color(255, 196, 241))
        end
    end
    cb_fov.Think = function(self)
        self:SetTextColor(self:GetChecked() and Color(255, 196, 241) or Color(100, 100, 100))
    end

    local slider_fov = fov_row:Add("DNumSlider")
    slider_fov:Dock(FILL)
    slider_fov:SetMin(50)
    slider_fov:SetMax(140)
    slider_fov:SetDecimals(0)
    slider_fov:SetConVar("ml_fov_value")
    slider_fov:SetText("") 

    if IsValid(slider_fov.Label) then slider_fov.Label:SetVisible(false) end

    slider_fov.Slider.Paint = function(s, w, h) 
        surface.SetDrawColor(55, 55, 55) 
        surface.DrawRect(0, h/2 - 1, w, 2) 
    end
    slider_fov.Slider.Knob.Paint = function(s, w, h) 
        draw.RoundedBox(30, 2, 2, w - 4, h - 4, Color(255, 196, 241)) 
    end

    if IsValid(slider_fov.TextArea) then
        slider_fov.TextArea:SetTextColor(Color(255, 255, 255))
        slider_fov.TextArea:SetFont("ML_Text")
        slider_fov.TextArea:SetWide(25)
        slider_fov.TextArea:SetDrawBackground(false)
        slider_fov.TextArea:SetDrawBorder(false)
        slider_fov.TextArea.Think = function(self)
            self:SetTextColor(Color(255, 255, 255))
        end
    end

    slider_fov.Think = function(self)
        local val = GetConVar("ml_fov_value"):GetFloat()
        if self:GetValue() != val and not self.Slider:IsEditing() then
            self:SetValue(val)
        end
    end

local pnl_game = vgui.Create("DScrollPanel", content_area)
    pnl_game:Dock(FILL)
    pnl_game:SetVisible(false)
pnl_game:GetCanvas():DockPadding(5, 0, 5, 0)
    panels["GAMEPLAY"] = pnl_game

    Empty(pnl_game, 10)
local title_row = pnl_game:Add("DPanel")
title_row:Dock(TOP)
title_row:SetTall(20)
title_row:DockMargin(0, 0, 0, 0)
title_row.Paint = function() end

local lbl_combat = title_row:Add("DLabel")
lbl_combat:SetText("                       Combat")
lbl_combat:SetFont("ML_Subtitle")
lbl_combat:SetTextColor(Color(255, 196, 241))
lbl_combat:Dock(LEFT)
lbl_combat:SetWide(150)
lbl_combat:SetContentAlignment(4)


local lbl_movement = title_row:Add("DLabel")
lbl_movement:SetText("            Movement")
lbl_movement:SetFont("ML_Subtitle")
lbl_movement:SetTextColor(Color(255, 196, 241))
lbl_movement:Dock(LEFT)
lbl_movement:SetWide(200) 
lbl_movement:SetContentAlignment(4)

lbl_movement:DockMargin(110, 0, 0, 0)

    Empty(pnl_game, 10)
    CreateCheckbox(pnl_game, "Aimbot", "ml_silent_aim")
    CreateCheckbox(pnl_game, "Propkill Mode", "ml_aimbot")

local function CreateWhiteSlider(parent, label, convar, min, max, decimals)
    local row = parent:Add("DPanel")
    row:Dock(TOP)
    row:SetTall(30)
    row:DockMargin(15, -7, 10, 0)
    row.Paint = function() end

    local lbl = row:Add("DLabel")
    lbl:SetText(label)
    lbl:SetFont("ML_Text")
    lbl:Dock(LEFT)
    lbl:SetWide(80) 
    lbl:SetTextColor(Color(255, 255, 255))

    local slider = row:Add("DNumSlider")
    slider:Dock(FILL)
    slider:SetMin(min)
    slider:SetMax(max)
    slider:SetDecimals(decimals or 0)
    slider:SetConVar(convar)
    slider:SetText("") 

    if IsValid(slider.Slider) then
        slider.Slider:Dock(LEFT)
        slider.Slider:SetWide(100)
    end

    if IsValid(slider.Label) then slider.Label:SetVisible(false) end
    if IsValid(slider.TextArea) then
        slider.TextArea:Dock(RIGHT)
        slider.TextArea:SetWide(250)
        slider.TextArea:SetTextColor(Color(255, 255, 255))
        slider.TextArea:SetFont("ML_Text")
        slider.TextArea:SetDrawBackground(false)
        slider.TextArea:SetDrawBorder(false)
        slider.TextArea:DockMargin(10, 0, 0, 0) 
    end
    
    slider.Slider.Paint = function(s, w, h) 
        surface.SetDrawColor(55, 55, 55) 
        surface.DrawRect(0, h/2 - 1, w, 2) 
    end
    
    slider.Slider.Knob.Paint = function(s, w, h) 
        draw.RoundedBox(30, 2, 2, w - 4, h - 4, Color(255, 196, 241)) 
    end

    slider.Think = function(self)
        if self.TextArea then
            self.TextArea:SetTextColor(Color(255, 255, 255))
            self.TextArea:SetFont("ML_Text")
        end
        
        local val = GetConVar(convar):GetFloat()
        if self:GetValue() != val and not self.Slider:IsEditing() then
            self:SetValue(val)
        end
    end

    return slider
end

CreateWhiteSlider(pnl_game, "Aimbot FOV", "ml_aimbot_fov", 0, 180, 0)
CreateWhiteSlider(pnl_game, "Smoothness", "ml_aimbot_smooth", 0, 2, 2)
Empty(pnl_game, 10)
    CreateCheckbox(pnl_game, "Bhop", "ml_bhop")
    local children = pnl_game:GetCanvas():GetChildren()
local last_cb = children[#children]

if IsValid(last_cb) then
    last_cb:Dock(TOP)
    last_cb:DockMargin(250, -96, 0, 0) 
end

    local pnl_misc = vgui.Create("DScrollPanel", content_area)
    pnl_misc:Dock(FILL)
    pnl_misc:SetVisible(false)
    pnl_misc:DockPadding(15, 0, 5, 0)
    panels["MISC"] = pnl_misc

    Empty(pnl_misc, 10)
    local lbl3 = pnl_misc:Add("DLabel")
    lbl3:SetText("MISC")
    lbl3:SetFont("ML_Subtitle")
    lbl3:SetTextColor(Color(255, 196, 241))
    lbl3:Dock(TOP)
    lbl3:SetContentAlignment(5)

    Empty(pnl_misc, 10)
    CreateCheckbox(pnl_misc, "Hitsounds", "ml_prop_hitsounds")
    local drop_hits = StyleDropdown(pnl_misc, "  Hitsound")
    drop_hits:SetConVar("ml_hitsound_select")
    for k, v in ipairs(hitsounds_list) do drop_hits:AddChoice(v.name, k) end
    drop_hits.OnSelect = function(self, index, value, data) RunConsoleCommand("ml_hitsound_select", tostring(data)) end

    Empty(pnl_misc, 5) 
    CreateCheckbox(pnl_misc, "Crosshair", "ml_custom_crosshair")
    CreateCheckbox(pnl_misc, "Third Person", "ml_3rdperson")

    Empty(pnl_misc, 20) 
    local btn_unhook = pnl_misc:Add("DButton")
    btn_unhook:SetText("UNHOOK")
    btn_unhook:SetFont("ML_Subtitle")
    btn_unhook:SetTall(35)
    btn_unhook:Dock(TOP)
    btn_unhook:DockMargin(0, 20, 0, 0)
    btn_unhook:SetTextColor(Color(255, 255, 255))
    btn_unhook.Paint = function(s, w, h)
        local c = s:IsHovered() and Color(70, 30, 30) or Color(45, 25, 25)
        draw.RoundedBox(6, 0, 0, w, h, c)
        surface.SetDrawColor(255, 255, 255, 10)
        surface.DrawOutlinedRect(0, 0, w, h)
    end
    btn_unhook.DoClick = function() UnhookMatcha() end

local nav_bar = vgui.Create("DPanel", frame)
    nav_bar:SetSize(frame:GetWide(), 30)
    nav_bar:SetPos(0, 25) 
    nav_bar.Paint = function() end

    local nav_container = vgui.Create("DPanel", nav_bar)
    nav_container.Paint = function() end

    local function SwitchTab(name)
        active_tab = name
        for k, pnl in pairs(panels) do
            if k == name then pnl:SetVisible(true) else pnl:SetVisible(false) end
        end
    end

local tabs = {"VISUALS", "GAMEPLAY", "MISC"}
    local last_x = 0
    local spacing = 0

    for i, name in ipairs(tabs) do
        local btn = vgui.Create("DButton", nav_container)
        btn:SetText(name)
        btn:SetFont("ML_Subtitle")
        btn:SizeToContents()
        btn:SetWide(btn:GetWide() + 10)
        btn:SetPos(last_x, 0)
        btn:SetTall(20)
        
        last_x = last_x + btn:GetWide() + spacing
        
        btn.ColorVal = active_tab == name and col_accent or col_text_off
        btn.Paint = function(self, w, h)
            local target_col = (active_tab == name) and col_accent or col_text_off
            self.ColorVal = LerpColor(FrameTime() * 10, self.ColorVal, target_col)
            self:SetTextColor(self.ColorVal)
        end
        
        btn.DoClick = function() SwitchTab(name) end
    end
nav_container:SetWide(last_x - spacing)
    nav_container:SetPos((nav_bar:GetWide() - nav_container:GetWide()) / 2.1, 0)
    SwitchTab(active_tab)
end
concommand.Add("matcha_menu", OpenMenu)

local menu_pressed = false

hook.Add("Think", "ML_MenuKeyBind", function()
    if input.IsKeyDown(KEY_INSERT) then
        if not menu_pressed then
            OpenMenu()
            menu_pressed = true
        end
    else
        menu_pressed = false
    end
end)
