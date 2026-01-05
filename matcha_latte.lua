local ML = {
    version = 1.3, 
    propkills = 0, 
    max_vel = 0, 
    current_vel = 0, 
    aimbot_active = false, 
    aimbot_target = nil,
    KillMessage = "1",
}
--test
local snowflakes = {}

local lethal_active = false

local soundURL = "https://files.catbox.moe/575j56.mp3"
local localFileName = "hitsound_skeet.dat"

local watermark_fps = 0
local watermark_last_update = CurTime()


RunConsoleCommand("cl_updaterate", "1000")
RunConsoleCommand("cl_cmdrate", "0")
RunConsoleCommand("cl_interp", "0")
RunConsoleCommand("rate", "51200")

CreateMaterial("ML_GLOW", "UnlitGeneric", {["$basetexture"] = "models/debug/debugwhite", ["$nocull"] = 1, ["$model"] = 1})

CreateClientConVar("ml_enabled", 1, true, false)
CreateClientConVar("ml_esp", 1, true, false)
CreateClientConVar("ml_chams", 1, true, false)
CreateClientConVar("ml_xray", 1, true, false)
CreateClientConVar("ml_tracers", 1, true, false)
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
CreateClientConVar("ml_aimbot_smooth", 0, true, false, "Enable smoothing") 
CreateClientConVar("ml_aimbot_fov", 180, true, false, "Aimbot FOV")
CreateClientConVar("ml_health_ammo", 1, true, false)
CreateClientConVar("ml_prop_hitsounds", 1, true, false)
CreateClientConVar("ml_silent_aim", 0, true, false)

surface.CreateFont("ML_Title", {font = "Verdana", size = 32, weight = 900, antialias = true})
surface.CreateFont("ML_Subtitle", {font = "Verdana", size = 14, weight = 700, antialias = true})
surface.CreateFont("ML_Text", {font = "Verdana", size = 12, weight = 500, antialias = true})

local function PulseColor()
    local pulse = math.sin(RealTime() * 2.5) * 0.1 + 0.9
    return Color(255 * pulse, 196 * pulse, 241 * pulse, 255)
end


local function PlayEnhanced2DSound()
    if not file.Exists(localFileName, "DATA") then 
        surface.PlaySound("physics/wood_box_impact_bullet4.wav")
        return 
    end

    for i = 1, 3 do
        sound.PlayFile("data/" .. localFileName, "nopitch mono", function(station)
            if IsValid(station) then
                station:SetVolume(1.0)
                station:Play()
            end
        end)
    end
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
        {"CalcView", "ML_CalcView"},
        {"ShouldDrawLocalPlayer", "ML_ShouldDrawThirdPerson"},
        {"entity_killed", "ML_PropKills"},
        {"Think", "ML_MenuKeyBind"},
        {"HUDPaint", "ML_SnowflakesBackground"},
        {"HUDPaint", "ML_HealthAmmo"},
        {"HUDShouldDraw", "ML_HideDefaultHUD"},
        {"entity_killed", "ML_PropHitsound"},
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
    for _, ply in pairs(player.GetAll()) do
        if IsValidPlayer(ply) then
            local pos = ply:EyePos():ToScreen()
            draw.SimpleTextOutlined(ply:Nick(), "ML_Text", pos.x, pos.y - 20, PulseColor(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 200))
        end
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

    local healthColor
    if healthPercent > 0.5 then
        local greenAmount = (healthPercent - 0.5) * 2
        healthColor = Color(100 - (greenAmount * 50), 220, 100)
    else
        local redAmount = healthPercent * 2
        healthColor = Color(255, 120 * redAmount, 120 * redAmount)
    end
    
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
    if GetConVarNumber("ml_chams") == 0 or GetConVarNumber("ml_enabled") == 0 then return end
    
    for _, ply in pairs(player.GetAll()) do
        if ply == LocalPlayer() then continue end
        
        if IsValidPlayer(ply) then
            ply:SetColor(Color(0, 0, 0, 0))
            cam.IgnoreZ(true)
            ply:SetRenderMode(RENDERMODE_TRANSALPHA)
            render.SuppressEngineLighting(true)
            render.MaterialOverride(Material("!ML_GLOW"))
            
            local col = PulseColor()
            render.SetColorModulation(col.r / 255, col.g / 255, col.b / 255)
            render.SetBlend(0.8)
            
            ply:DrawModel()
            
            render.MaterialOverride(nil)
            render.SuppressEngineLighting(false)
            cam.IgnoreZ(false)
        else
            ply:SetColor(Color(255, 255, 255, 255))
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
            timer.Simple(0.1, function()
                LocalPlayer():ConCommand("say " .. ML.KillMessage)
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

hook.Add("CalcView", "ML_CalcView", function(ply, pos, angles, fov)
    if not ML or GetConVarNumber("ml_enabled") == 0 then return end
    
    if GetConVarNumber("ml_3rdperson") == 1 and ply:Alive() then
        local view = {}
        local dist = 100
        local tr = util.TraceLine({
            start = pos,
            endpos = pos - (angles:Forward() * dist) + (angles:Up() * 10),
            filter = ply
        })
        
        view.origin = tr.HitPos + tr.HitNormal * 5
        view.angles = angles
        view.drawviewer = true
        if GetConVarNumber("ml_fov_enable") == 1 then
            view.fov = GetConVarNumber("ml_fov_value")
        end
        
        return view
    end
end)

hook.Add("CalcView", "ML_CalcView", function(ply, pos, ang)
    local view = {}
    if GetConVarNumber("ml_fov_enable") == 1 then view.fov = GetConVarNumber("ml_fov_value") end
    if GetConVarNumber("ml_3rdperson") == 1 then view.origin = pos - ang:Forward() * 100 end
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
    local bestFov = GetConVarNumber("ml_aimbot_fov") or 180
    local myAng = LocalPlayer():GetViewPunchAngles() + LocalPlayer():EyeAngles()
    local myPos = LocalPlayer():EyePos()
    
    for _, ply in pairs(player.GetAll()) do
        if IsValidPlayer(ply) then
            local pos = ply:LocalToWorld(ply:OBBCenter())
            local ang = (pos - myPos):Angle()
            local diff = math.abs(math.NormalizeAngle(ang.y - myAng.y)) + math.abs(math.NormalizeAngle(ang.p - myAng.p))
            
            if diff < bestFov then
                bestFov = diff
                bestEnt = ply
            end
        end
    end
    
    return bestEnt
end

hook.Add("CreateMove", "ML_PropkillAim", function(cmd)
    if not ML or GetConVarNumber("ml_enabled") == 0 or GetConVarNumber("ml_aimbot") == 0 then 
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
        local targetPos
        local isSilent = GetConVarNumber("ml_silent_aim") == 1
        
        -- Use direct center for Silent, Prediction for Snap
        if isSilent then
            targetPos = ML.aimbot_target:LocalToWorld(ML.aimbot_target:OBBCenter())
        else
            targetPos = PredictPos(ML.aimbot_target)
        end

        local myPos = LocalPlayer():EyePos()
        local aimAngle = (targetPos - myPos):Angle()

        aimAngle.p = math.NormalizeAngle(aimAngle.p)
        aimAngle.y = math.NormalizeAngle(aimAngle.y)
        
        if isSilent then
            -- TRUE SILENT: We ONLY set the command angles.
            -- We do NOT call SetEyeAngles.
            cmd:SetViewAngles(aimAngle)
            
            -- Some servers/setups force the view to follow cmd. 
            -- This is a common trick to "fix" that:
            return false 
        else
            -- SNAP AIM:
            local currentAng = cmd:GetViewAngles()
            if GetConVarNumber("ml_aimbot_smooth") == 1 then
                local smoothAmt = 0.2
                local diffP = math.NormalizeAngle(aimAngle.p - currentAng.p)
                local diffY = math.NormalizeAngle(aimAngle.y - currentAng.y)
                aimAngle.p = math.NormalizeAngle(currentAng.p + (diffP * smoothAmt))
                aimAngle.y = math.NormalizeAngle(currentAng.y + (diffY * smoothAmt))
            end
            
            cmd:SetViewAngles(aimAngle)
            LocalPlayer():SetEyeAngles(aimAngle) 
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

local menuX, menuY = nil, nil
local function OpenMenu()
if IsValid(ml_frame) then
        if ml_frame.isClosing then return end
        ml_frame.isClosing = true 

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
    frame:SetSize(400, 650)

    if menuX and menuY then
        frame:SetPos(menuX, menuY)
    else
        frame:Center()
    end

    frame:MakePopup()
    frame:ShowCloseButton(false)
    frame:SetAlpha(0)
    frame:AlphaTo(255, 0.1)

    local color_bg = Color(14, 14, 14, 255)
    local color_outline = Color(16, 16, 16, 255)
    local color_section = Color(16,16,16, 255)
    local color_accent = Color(255, 196, 241, 255)
    local color_header_bg = Color(28, 28, 28, 255)
    local color_text_off = Color(160, 160, 160, 255)
    frame.Paint = function(self, w, h)
        Derma_DrawBackgroundBlur(self, self.m_fCreateTime)

        draw.RoundedBox(8, 0, 0, w, h, color_outline)
        draw.RoundedBox(8, 1, 1, w - 2, h - 2, color_bg) 

        draw.RoundedBoxEx(8, 1, 1, w - 2, 25, color_header_bg, true, true, false, false)
        draw.SimpleText("matcha latte", "ML_Subtitle", 10, 4, color_accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
    
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(5, 30, 5, 5)

    local function AddSection(name, items_callback)
        local container = vgui.Create("DPanel", scroll)
        container:Dock(TOP)
        container:DockMargin(5, 0, 5, 10)
        
        local content = vgui.Create("DListLayout", container)
        content:Dock(TOP)
        content:DockMargin(10, 30, 10, 10)

        container.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, color_section)
            draw.SimpleText(name, "ML_Subtitle", 10, 7, color_accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        local function CustomCheck(parent, text, convar)
            local cb = parent:Add("DCheckBoxLabel")
            cb:SetText(text)
            cb:SetConVar(convar)
            cb:SetFont("ML_Text")
            cb:DockMargin(0, 0, 0, 7)
            
            cb.Button.Paint = function(panel, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(35, 35, 35))
                if cb:GetChecked() then
                    draw.RoundedBox(4, 2, 2, w - 4, h - 4, color_accent)
                end
            end

            cb.Think = function(self)
                self:SetTextColor(self:GetChecked() and color_accent or color_text_off)
            end
            return cb
        end
        

        items_callback(content, CustomCheck)
        content:InvalidateLayout(true)
        container:SetTall(content:GetTall() + 40)
    end

    AddSection("VISUALS", function(p, check)
        check(p, "Player ESP", "ml_esp")
        check(p, "Player Glow (CHAMS)", "ml_chams")
        check(p, "Prop X-Ray", "ml_xray")
        check(p, "Tracers", "ml_tracers")
        check(p, "Third Person", "ml_3rdperson")
        check(p, "Enable FOV Changer", "ml_fov_enable")
        check(p, "HUD", "ml_healthammo")
        
        local fov_slider = p:Add("DNumSlider")
        fov_slider:SetMin(50)
        fov_slider:SetMax(140)
        fov_slider:SetDecimals(0)
        fov_slider:SetConVar("ml_fov_value")
        fov_slider:SetText("Field of View Amount")
        fov_slider:DockMargin(5, 0, 0, 5)
        fov_slider.Label:SetFont("ML_Text")
        fov_slider.Label:SetTextColor(color_text_off)

        fov_slider.Slider.Paint = function(panel, w, h)
            surface.SetDrawColor(35, 35, 35)
            surface.DrawRect(0, h / 2 - 1, w, 2)
        end

        fov_slider.Slider.Knob.Paint = function(panel, w, h)
            draw.NoTexture()
            surface.SetDrawColor(color_accent)
            for i = 0, 10 do
                local radius = (w / 2) - 3
                for j = 0, 360, 20 do
                    local rad = math.rad(j)
                    surface.DrawLine(w / 2, h / 2, w / 2 + math.cos(rad) * radius, h / 2 + math.sin(rad) * radius)
                end
            end
        end
    end)

    AddSection("GAMEPLAY", function(p, check)
        check(p, "Bhop", "ml_bhop")
        check(p, "Propkill Aimbot", "ml_aimbot")
        check(p, "Silent Aim", "ml_silent_aim")
    end)

    AddSection("MISC", function(p, check)
        check(p, "Hitsounds", "ml_prop_hitsounds")

        local unhook = p:Add("DButton")
        unhook:SetText("UNHOOK")
        unhook:SetTall(35)
        unhook:DockMargin(0, 5, 0, 5)
        unhook:SetFont("ML_Subtitle")
        unhook:SetTextColor(Color(255, 255, 255))

        local col_idle = Color(45, 25, 25)
        local col_hover = Color(70, 30, 30)

        unhook.Paint = function(self, w, h)
            local targetCol = self:IsHovered() and col_hover or col_idle
            draw.RoundedBox(6, 0, 0, w, h, targetCol)

            surface.SetDrawColor(255, 255, 255, 5)
            surface.DrawOutlinedRect(0, 0, w, h)
        end
        
        unhook.DoClick = function()
            UnhookMatcha()
        end
    end)
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
