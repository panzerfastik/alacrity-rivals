-- Roblox: Rivals | Executor: Solara | Insert = toggle
-- ESP fix: clamp to screen, proper geometry
-- Watermark: nick / ping / fps | Color picker | Silent aim hook

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local TweenSvc   = game:GetService("TweenService")
local Stats      = game:GetService("Stats")
local Camera     = workspace.CurrentCamera
local LP         = Players.LocalPlayer

-- ══════════════════════════════════════
-- GUI PARENT
-- ══════════════════════════════════════
local function GetGUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "Alacrity"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    if gethui then sg.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(sg)
        sg.Parent = game:GetService("CoreGui")
    else sg.Parent = LP.PlayerGui end
    return sg
end

-- ══════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════
local CFG = {
    -- Aimbot
    AimbotOn    = false,
    AimbotFOV   = 150,
    AimbotSpeed = 8,
    AimbotPart  = "Head",
    AimbotKey   = "RMB",
    Prediction  = true,
    WallCheck   = false,
    TeamCheck   = false,

    -- Silent
    SilentOn  = false,
    SilentFOV = 300,

    -- ESP types
    BoxESP      = true,
    CornerBox   = false,
    FilledBox   = false,
    Box3D       = false,
    Skeleton    = false,
    Tracer      = false,   -- линия от низа экрана к ногам
    HeadDot     = false,   -- точка над головой
    HealthBar   = true,
    HealthText  = false,   -- HP цифрой
    Names       = true,
    Distance    = true,
    WeaponESP   = false,   -- название инструмента
    FOVCircle   = true,
    MaxDist     = 600,
    BoxThick    = 1.5,

    -- ESP Color mode
    -- "Team" = красный/синий по команде
    -- "Distance" = зелёный→красный по дистанции
    -- "Health" = зелёный→красный по хп
    -- "Custom" = цвет ниже
    ColorMode   = "Custom",
    CustomColor = Color3.fromRGB(170,80,255),

    -- Chams
    Chams       = false,
    ChamsWall   = true,
    ChamsFill   = 0.4,
    ChamsOut    = 0.0,
    -- ChamsColor mode: "Flat","Neon","Team","Rainbow"
    ChamsMode   = "Flat",
    ChamsFillColor = Color3.fromRGB(140,50,255),
    ChamsOutColor  = Color3.fromRGB(200,120,255),

    -- Watermark
    WatermarkOn = true,
}

-- ══════════════════════════════════════
-- COLOR RESOLVERS
-- ══════════════════════════════════════
local function GetESPColor(player, part)
    local m = CFG.ColorMode
    if m == "Custom" then
        return CFG.CustomColor

    elseif m == "Team" then
        if player.Team == LP.Team then
            return Color3.fromRGB(80,180,255)
        else
            return Color3.fromRGB(255,60,60)
        end

    elseif m == "Distance" then
        local char = player.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local d = math.clamp((Camera.CFrame.Position-hrp.Position).Magnitude/CFG.MaxDist,0,1)
            return Color3.fromRGB(math.floor(255*d), math.floor(255*(1-d)), 0)
        end

    elseif m == "Health" then
        local char = player.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            local r = math.clamp(hum.Health/hum.MaxHealth,0,1)
            return Color3.fromRGB(math.floor(255*(1-r)), math.floor(255*r), 0)
        end

    elseif m == "Rainbow" then
        local t = tick()*0.5
        local h = (t % 1)
        return Color3.fromHSV(h, 1, 1)
    end

    return CFG.CustomColor
end

local RainbowTick = 0

-- ══════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════
local VP = Camera.ViewportSize

local function W2S(pos)
    local ok,s = pcall(function() return Camera:WorldToViewportPoint(pos) end)
    if not ok then return Vector2.zero, false, 0 end
    return Vector2.new(s.X, s.Y), s.Z > 0, s.Z
end

-- clamp box to viewport so it never goes off-screen
local function ClampBox(x, y, w, h)
    local vp = Camera.ViewportSize
    x = math.clamp(x, 0, vp.X - w)
    y = math.clamp(y, 0, vp.Y - h)
    return x, y
end

local function KeyHeld()
    local k = CFG.AimbotKey
    if k=="RMB"    then return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    elseif k=="LMB"    then return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    elseif k=="LALT"   then return UIS:IsKeyDown(Enum.KeyCode.LeftAlt)
    elseif k=="LSHIFT" then return UIS:IsKeyDown(Enum.KeyCode.LeftShift)
    elseif k=="E"      then return UIS:IsKeyDown(Enum.KeyCode.E) end
    return false
end

local function IsVis(part)
    if not CFG.WallCheck then return true end
    local origin = Camera.CFrame.Position
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {LP.Character, part.Parent}
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local res = workspace:Raycast(origin, part.Position-origin, rp)
    return res == nil
end

-- ══════════════════════════════════════
-- TARGET
-- ══════════════════════════════════════
local function GetTarget(fovLim)
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local best, bestD = nil, fovLim
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP then continue end
        if CFG.TeamCheck and p.Team==LP.Team then continue end
        local char = p.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health<=0 then continue end
        local part = char:FindFirstChild(CFG.AimbotPart)
                  or char:FindFirstChild("Head")
                  or char:FindFirstChild("UpperTorso")
        if not part then continue end
        local pos = part.Position
        if CFG.Prediction then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then pos = pos + hrp.AssemblyLinearVelocity*(2/60) end
        end
        if (Camera.CFrame.Position-pos).Magnitude > CFG.MaxDist then continue end
        if not IsVis(part) then continue end
        local sc,on = W2S(pos)
        if not on then continue end
        local d = (sc-center).Magnitude
        if d < bestD then bestD=d best=part end
    end
    return best
end

-- ══════════════════════════════════════
-- SILENT AIM HOOK
-- ══════════════════════════════════════
local OrigRaycast = workspace.Raycast
local SilentHooked = false

local function HookSilent()
    if SilentHooked then return end
    SilentHooked = true
    workspace.Raycast = function(self, origin, direction, params)
        if CFG.SilentOn then
            local t = GetTarget(CFG.SilentFOV)
            if t then
                local nd = (t.Position - origin)
                direction = nd.Unit * math.max(direction.Magnitude, nd.Magnitude+5)
            end
        end
        return OrigRaycast(self, origin, direction, params)
    end
    pcall(function()
        local old
        old = hookmetamethod(game, "__namecall", function(self, ...)
            if getnamecallmethod()=="Raycast" and CFG.SilentOn then
                local args = {...}
                if args[1] and args[2] then
                    local t = GetTarget(CFG.SilentFOV)
                    if t then
                        local nd = (t.Position - args[1])
                        args[2] = nd.Unit * math.max(args[2].Magnitude, nd.Magnitude+5)
                    end
                end
                return old(self, table.unpack(args))
            end
            return old(self, ...)
        end)
    end)
end

local function UnhookSilent()
    pcall(function() workspace.Raycast = OrigRaycast end)
    SilentHooked = false
end

-- ══════════════════════════════════════
-- CHAMS
-- ══════════════════════════════════════
local ChamsCache = {}
local RainbowChamsHue = 0

local function ApplyChams(p, char)
    if ChamsCache[p] then ChamsCache[p]:Destroy() end
    if not CFG.Chams then return end
    local h = Instance.new("Highlight")
    h.Adornee             = char
    h.FillTransparency    = CFG.ChamsFill
    h.OutlineTransparency = CFG.ChamsOut
    h.DepthMode = CFG.ChamsWall
        and Enum.HighlightDepthMode.AlwaysOnTop
        or  Enum.HighlightDepthMode.Occluded
    -- colors by mode
    local mode = CFG.ChamsMode
    if mode == "Flat" then
        h.FillColor    = CFG.ChamsFillColor
        h.OutlineColor = CFG.ChamsOutColor
    elseif mode == "Neon" then
        h.FillColor    = CFG.ChamsFillColor
        h.OutlineColor = Color3.fromRGB(255,255,255)
        h.FillTransparency = 0.1
    elseif mode == "Team" then
        if p.Team == LP.Team then
            h.FillColor    = Color3.fromRGB(80,160,255)
            h.OutlineColor = Color3.fromRGB(120,200,255)
        else
            h.FillColor    = Color3.fromRGB(255,60,60)
            h.OutlineColor = Color3.fromRGB(255,140,140)
        end
    elseif mode == "Wireframe" then
        h.FillTransparency = 1
        h.OutlineColor     = CFG.ChamsOutColor
        h.OutlineTransparency = 0
    elseif mode == "Rainbow" then
        h.FillColor    = Color3.fromHSV(RainbowChamsHue, 1, 1)
        h.OutlineColor = Color3.fromHSV((RainbowChamsHue+0.5)%1, 1, 1)
    elseif mode == "Xray" then
        h.FillColor           = Color3.fromRGB(255,255,255)
        h.OutlineColor        = CFG.ChamsOutColor
        h.FillTransparency    = 0.6
        h.OutlineTransparency = 0
        h.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    end
    h.Parent = workspace
    ChamsCache[p] = h
end

local function RemoveChams(p)
    if ChamsCache[p] then ChamsCache[p]:Destroy() ChamsCache[p]=nil end
end

local function RefreshChams()
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP then continue end
        if p.Character and CFG.Chams then ApplyChams(p,p.Character)
        else RemoveChams(p) end
    end
end

-- Rainbow chams live update
RunService.Heartbeat:Connect(function(dt)
    RainbowChamsHue = (RainbowChamsHue + dt*0.3) % 1
    if CFG.Chams and CFG.ChamsMode=="Rainbow" then
        for p,h in pairs(ChamsCache) do
            if h and h.Parent then
                h.FillColor    = Color3.fromHSV(RainbowChamsHue, 1, 1)
                h.OutlineColor = Color3.fromHSV((RainbowChamsHue+0.5)%1, 1, 1)
            end
        end
    end
end)

for _,p in ipairs(Players:GetPlayers()) do
    if p~=LP then
        p.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            if CFG.Chams then ApplyChams(p,c) end
        end)
    end
end
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(c)
        task.wait(0.5)
        if CFG.Chams then ApplyChams(p,c) end
    end)
end)
Players.PlayerRemoving:Connect(function(p)
    RemoveChams(p)
    if ESPCache and ESPCache[p] then
        for _,v in pairs(ESPCache[p]) do
            if type(v)=="table" then for _,l in pairs(v) do pcall(function() l:Remove() end) end
            else pcall(function() v:Remove() end) end
        end
        ESPCache[p]=nil
    end
end)

-- ══════════════════════════════════════
-- ESP DRAWINGS
-- ══════════════════════════════════════
local BONES15 = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
}
local BONES6 = {
    {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},
    {"Torso","Left Leg"},{"Torso","Right Leg"},
}

ESPCache = {}

local function DR(t,p)
    local d=Drawing.new(t)
    for k,v in pairs(p) do pcall(function() d[k]=v end) end
    return d
end

local function NewESP()
    return {
        -- Box types
        Box    = DR("Square",{Visible=false,Filled=false,Thickness=1.5}),
        Fill   = DR("Square",{Visible=false,Filled=true}),
        Cors   = (function() local t={} for i=1,8 do t[i]=DR("Line",{Visible=false,Thickness=1.5}) end return t end)(),
        B3D    = (function() local t={} for i=1,12 do t[i]=DR("Line",{Visible=false,Thickness=1}) end return t end)(),
        -- Skeleton
        Bon    = (function() local t={} for i=1,14 do t[i]=DR("Line",{Visible=false,Thickness=1}) end return t end)(),
        -- Tracer
        Tracer = DR("Line",{Visible=false,Thickness=1}),
        -- Head dot
        Dot    = DR("Circle",{Visible=false,Filled=true,Thickness=1,NumSides=16}),
        -- Health
        HpBG   = DR("Square",{Visible=false,Filled=true,Color=Color3.fromRGB(20,20,20)}),
        HpBar  = DR("Square",{Visible=false,Filled=true}),
        -- Texts
        Name   = DR("Text",{Visible=false,Size=13,Center=true,Outline=true,Font=2}),
        Dist   = DR("Text",{Visible=false,Size=11,Center=true,Outline=true,Font=2,Color=Color3.fromRGB(200,200,200)}),
        HpText = DR("Text",{Visible=false,Size=10,Center=true,Outline=true,Font=2,Color=Color3.fromRGB(200,255,200)}),
        Weapon = DR("Text",{Visible=false,Size=10,Center=true,Outline=true,Font=2,Color=Color3.fromRGB(255,220,100)}),
    }
end

local function HideESP(e)
    for k,v in pairs(e) do
        if type(v)=="table" then
            for _,l in pairs(v) do pcall(function() l.Visible=false end) end
        else
            pcall(function() v.Visible=false end)
        end
    end
end

local function DrawCors(ls,x,y,w,h,col,th)
    local cl=w*0.22 local ct=h*0.22
    local pts={
        {x,y,x+cl,y},{x,y,x,y+ct},
        {x+w,y,x+w-cl,y},{x+w,y,x+w,y+ct},
        {x,y+h,x+cl,y+h},{x,y+h,x,y+h-ct},
        {x+w,y+h,x+w-cl,y+h},{x+w,y+h,x+w,y+h-ct},
    }
    for i,p in ipairs(pts) do
        ls[i].From=Vector2.new(p[1],p[2]) ls[i].To=Vector2.new(p[3],p[4])
        ls[i].Color=col ls[i].Thickness=th ls[i].Visible=true
    end
end

local CUBE_O={
    Vector3.new(-1,0,-1),Vector3.new(1,0,-1),Vector3.new(1,0,1),Vector3.new(-1,0,1),
    Vector3.new(-1,2,-1),Vector3.new(1,2,-1),Vector3.new(1,2,1),Vector3.new(-1,2,1),
}
local CUBE_E={{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}

local function Draw3D(ls,cf,col)
    local hw=1.5
    local v={}
    for i,o in ipairs(CUBE_O) do
        local w2=cf*CFrame.new(o.X*hw,o.Y-1,o.Z*hw)
        local sc,on=W2S(w2.Position)
        v[i]={sc=sc,on=on}
    end
    for i,ed in ipairs(CUBE_E) do
        local a,b=v[ed[1]],v[ed[2]]
        if a.on or b.on then
            ls[i].From=a.sc ls[i].To=b.sc
            ls[i].Color=col ls[i].Thickness=1 ls[i].Visible=true
        else ls[i].Visible=false end
    end
end

-- FOV circle
local FOVDraw = DR("Circle",{Visible=false,Thickness=1,Filled=false,NumSides=64})

-- ══════════════════════════════════════
-- WATERMARK (Drawing-based, always on top)
-- ══════════════════════════════════════
local WM = {
    BG   = DR("Square",{Visible=true,Filled=true,Color=Color3.fromRGB(14,10,22),Transparency=0.3}),
    Line = DR("Line",{Visible=true,Color=Color3.fromRGB(150,60,255),Thickness=2}),
    Text = DR("Text",{Visible=true,Size=13,Outline=true,Font=2,Color=Color3.fromRGB(220,200,240)}),
}

local FPSBuffer = {}
local LastFPSUpdate = 0

local function UpdateWatermark(dt)
    if not CFG.WatermarkOn then
        WM.BG.Visible=false WM.Line.Visible=false WM.Text.Visible=false
        return
    end

    -- FPS: rolling average
    table.insert(FPSBuffer, 1/math.max(dt,0.001))
    if #FPSBuffer > 30 then table.remove(FPSBuffer,1) end
    local fps = 0
    for _,v in ipairs(FPSBuffer) do fps=fps+v end
    fps = math.floor(fps/#FPSBuffer)

    -- Ping
    local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())

    -- Name
    local name = LP.Name

    local str = string.format("ALACRITY  |  %s  |  %d fps  |  %d ms", name, fps, ping)

    local x,y = 8, 8
    local tw   = #str * 7.5
    local th   = 20

    WM.BG.Position    = Vector2.new(x-4, y-3)
    WM.BG.Size        = Vector2.new(tw+8, th+6)
    WM.BG.Visible     = true

    WM.Line.From      = Vector2.new(x-4, y+th+3)
    WM.Line.To        = Vector2.new(x-4+tw+8, y+th+3)
    WM.Line.Visible   = true

    WM.Text.Text      = str
    WM.Text.Position  = Vector2.new(x, y)
    WM.Text.Visible   = true
end

-- ══════════════════════════════════════
-- MAIN LOOP
-- ══════════════════════════════════════
RunService.RenderStepped:Connect(function(dt)
    local vp     = Camera.ViewportSize
    local center = Vector2.new(vp.X/2, vp.Y/2)

    -- watermark
    UpdateWatermark(dt)

    -- FOV circle
    FOVDraw.Position = center
    FOVDraw.Radius   = CFG.SilentOn and CFG.SilentFOV or CFG.AimbotFOV
    FOVDraw.Color    = CFG.SilentOn and Color3.fromRGB(255,80,80) or Color3.fromRGB(170,80,255)
    FOVDraw.Visible  = CFG.FOVCircle and (CFG.AimbotOn or CFG.SilentOn)

    -- aimbot
    if CFG.AimbotOn and KeyHeld() then
        local t = GetTarget(CFG.AimbotFOV)
        if t then
            local sc = W2S(t.Position)
            local dx = sc.X-center.X
            local dy = sc.Y-center.Y
            local dist = math.sqrt(dx*dx+dy*dy)
            if dist > 0.5 then
                local spd = math.min(CFG.AimbotSpeed, dist)
                mousemoverel(dx/dist*spd, dy/dist*spd)
            end
        end
    end

    -- ESP
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP then continue end
        if CFG.TeamCheck and p.Team==LP.Team then continue end

        local char = p.Character
        if not char then
            if ESPCache[p] then HideESP(ESPCache[p]) end
            continue
        end

        local hrp  = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not head or not hum then continue end

        local worldDist = (Camera.CFrame.Position-hrp.Position).Magnitude
        if worldDist>CFG.MaxDist or hum.Health<=0 then
            if ESPCache[p] then HideESP(ESPCache[p]) end
            continue
        end

        if not ESPCache[p] then ESPCache[p]=NewESP() end
        local e = ESPCache[p]

        -- ── Screen positions ──────────────────────
        -- top = slightly above head, bottom = feet
        local headTop,headOn = W2S(head.Position + Vector3.new(0, head.Size.Y/2+0.1, 0))
        local feetBot        = W2S(hrp.Position  - Vector3.new(0, 3.0, 0))

        if not headOn then HideESP(e) continue end

        -- make sure top is above bottom (can flip at edge cases)
        local top_y  = math.min(headTop.Y, feetBot.Y)
        local bot_y  = math.max(headTop.Y, feetBot.Y)
        local ctr_x  = headTop.X

        local bh = bot_y - top_y
        if bh < 8 then HideESP(e) continue end  -- too small, skip

        local bw = bh * 0.50
        local bx = ctr_x - bw/2
        local by = top_y

        -- clamp box to screen
        bx, by = ClampBox(bx, by, bw, bh)

        -- ESP colour for this player
        local col = GetESPColor(p, head)

        -- ── FILLED BOX ────────────────────────────
        if CFG.FilledBox then
            e.Fill.Size=Vector2.new(bw,bh) e.Fill.Position=Vector2.new(bx,by)
            e.Fill.Color=col e.Fill.Transparency=0.80 e.Fill.Visible=true
        else e.Fill.Visible=false end

        -- ── FULL BOX ──────────────────────────────
        if CFG.BoxESP then
            e.Box.Size=Vector2.new(bw,bh) e.Box.Position=Vector2.new(bx,by)
            e.Box.Color=col e.Box.Thickness=CFG.BoxThick e.Box.Visible=true
        else e.Box.Visible=false end

        -- ── CORNER BOX ────────────────────────────
        if CFG.CornerBox then
            DrawCors(e.Cors,bx,by,bw,bh,col,CFG.BoxThick)
        else for _,l in ipairs(e.Cors) do l.Visible=false end end

        -- ── 3D BOX ────────────────────────────────
        if CFG.Box3D then
            Draw3D(e.B3D,hrp.CFrame,col)
        else for _,l in ipairs(e.B3D) do l.Visible=false end end

        -- ── SKELETON ──────────────────────────────
        if CFG.Skeleton then
            local bones = char:FindFirstChild("UpperTorso") and BONES15 or BONES6
            for i,pair in ipairs(bones) do
                local a=char:FindFirstChild(pair[1])
                local b=char:FindFirstChild(pair[2])
                if a and b and e.Bon[i] then
                    local sa,aOn=W2S(a.Position)
                    local sb2   =W2S(b.Position)
                    e.Bon[i].From=sa e.Bon[i].To=sb2
                    e.Bon[i].Color=col e.Bon[i].Thickness=1.2
                    e.Bon[i].Visible=aOn
                elseif e.Bon[i] then e.Bon[i].Visible=false end
            end
            for i=#(char:FindFirstChild("UpperTorso") and BONES15 or BONES6)+1,14 do
                if e.Bon[i] then e.Bon[i].Visible=false end
            end
        else for _,l in ipairs(e.Bon) do l.Visible=false end end

        -- ── TRACER ────────────────────────────────
        if CFG.Tracer then
            local botSc = W2S(hrp.Position - Vector3.new(0,3,0))
            e.Tracer.From   = Vector2.new(vp.X/2, vp.Y)  -- bottom center screen
            e.Tracer.To     = botSc
            e.Tracer.Color  = col
            e.Tracer.Thickness = 1
            e.Tracer.Visible= true
        else e.Tracer.Visible=false end

        -- ── HEAD DOT ──────────────────────────────
        if CFG.HeadDot then
            local dotSize = math.clamp(bw*0.18, 3, 10)
            e.Dot.Position = headTop
            e.Dot.Radius   = dotSize
            e.Dot.Color    = col
            e.Dot.Visible  = true
        else e.Dot.Visible=false end

        -- ── HEALTH BAR (left side, fixed) ─────────
        if CFG.HealthBar then
            local r     = math.clamp(hum.Health/hum.MaxHealth,0,1)
            local barX  = bx - 7
            local barW  = 4
            local barH  = bh
            -- background
            e.HpBG.Size     = Vector2.new(barW, barH)
            e.HpBG.Position = Vector2.new(barX, by)
            e.HpBG.Visible  = true
            -- fill (bottom-anchored: grows up)
            local fillH = barH * r
            e.HpBar.Size     = Vector2.new(barW, fillH)
            e.HpBar.Position = Vector2.new(barX, by + barH - fillH)
            e.HpBar.Color    = Color3.fromRGB(
                math.floor(255*(1-r)),
                math.floor(255*r),
                0
            )
            e.HpBar.Visible = true
        else e.HpBG.Visible=false e.HpBar.Visible=false end

        -- ── HP TEXT ───────────────────────────────
        if CFG.HealthText then
            local hp = math.floor(hum.Health)
            e.HpText.Text     = hp.." hp"
            e.HpText.Position = Vector2.new(bx-7+2, by+bh+1)
            e.HpText.Visible  = true
        else e.HpText.Visible=false end

        -- ── NAME (above box, not overlapping) ─────
        if CFG.Names then
            e.Name.Text     = p.Name
            e.Name.Color    = col
            e.Name.Size     = math.clamp(bh*0.11+8, 10, 14)
            e.Name.Position = Vector2.new(ctr_x, by - 15)
            e.Name.Visible  = true
        else e.Name.Visible=false end

        -- ── DISTANCE (below box) ──────────────────
        if CFG.Distance then
            e.Dist.Text     = math.floor(worldDist).."m"
            e.Dist.Position = Vector2.new(ctr_x, by + bh + 3)
            e.Dist.Visible  = true
        else e.Dist.Visible=false end

        -- ── WEAPON LABEL ──────────────────────────
        if CFG.WeaponESP then
            local tool = char:FindFirstChildOfClass("Tool")
            e.Weapon.Text     = tool and tool.Name or ""
            e.Weapon.Position = Vector2.new(ctr_x, by + bh + (CFG.Distance and 14 or 3))
            e.Weapon.Visible  = tool ~= nil
        else e.Weapon.Visible=false end
    end
end)

-- ══════════════════════════════════════
-- GUI
-- ══════════════════════════════════════
local ScreenGui = GetGUI()

local C={
    BG=Color3.fromRGB(14,10,22),Sidebar=Color3.fromRGB(10,7,18),
    Panel=Color3.fromRGB(19,13,30),Header=Color3.fromRGB(9,6,16),
    Accent=Color3.fromRGB(150,60,255),AccentD=Color3.fromRGB(110,30,210),
    Glow=Color3.fromRGB(180,100,255),Text=Color3.fromRGB(220,200,240),
    TextDim=Color3.fromRGB(130,110,160),Line=Color3.fromRGB(50,30,75),
    TabSel=Color3.fromRGB(30,18,50),SliderBG=Color3.fromRGB(35,22,58),
    CheckOff=Color3.fromRGB(55,38,80),
    Red=Color3.fromRGB(255,80,80),
    Green=Color3.fromRGB(80,255,120),
    Blue=Color3.fromRGB(80,160,255),
    Yellow=Color3.fromRGB(255,220,60),
    Cyan=Color3.fromRGB(60,220,255),
    Orange=Color3.fromRGB(255,140,40),
    Pink=Color3.fromRGB(255,100,200),
    White=Color3.fromRGB(240,240,240),
}

local function N(cls,props,par)
    local i=Instance.new(cls)
    for k,v in pairs(props) do pcall(function() i[k]=v end) end
    if par then i.Parent=par end
    return i
end
local function Corner(r,p) N("UICorner",{CornerRadius=UDim.new(0,r)},p) end
local function Pad(t,r,b,l,p) N("UIPadding",{PaddingTop=UDim.new(0,t),PaddingRight=UDim.new(0,r),PaddingBottom=UDim.new(0,b),PaddingLeft=UDim.new(0,l)},p) end
local function List(pad,p) N("UIListLayout",{Padding=UDim.new(0,pad),SortOrder=Enum.SortOrder.LayoutOrder},p) end

-- Window
local Win=N("Frame",{
    Size=UDim2.new(0,570,0,490),
    Position=UDim2.new(0.5,-285,0.5,-245),
    BackgroundColor3=C.BG,BorderSizePixel=0,Visible=false
},ScreenGui)
Corner(8,Win)
N("UIStroke",{Color=C.Accent,Thickness=1.5,Transparency=0.3},Win)

-- Header
local Hdr=N("Frame",{Size=UDim2.new(1,0,0,36),BackgroundColor3=C.Header,BorderSizePixel=0,ZIndex=5},Win)
Corner(8,Hdr)
N("Frame",{Size=UDim2.new(1,0,0,8),Position=UDim2.new(0,0,1,-8),BackgroundColor3=C.Header,BorderSizePixel=0,ZIndex=5},Hdr)
N("Frame",{Size=UDim2.new(1,0,0,2),Position=UDim2.new(0,0,1,-2),BackgroundColor3=C.Accent,BorderSizePixel=0,ZIndex=6},Hdr)
N("TextLabel",{Text="ALACRITY",Font=Enum.Font.GothamBold,TextSize=14,TextColor3=C.Glow,BackgroundTransparency=1,Size=UDim2.new(0,90,1,0),Position=UDim2.new(0,12,0,0),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=6},Hdr)
N("TextLabel",{Text="rivals",Font=Enum.Font.Gotham,TextSize=10,TextColor3=C.TextDim,BackgroundTransparency=1,Size=UDim2.new(0,60,1,0),Position=UDim2.new(0,100,0,0),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=6},Hdr)

-- drag
local drag,dS,dP=false,nil,nil
Hdr.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true dS=i.Position dP=Win.Position end end)
Hdr.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
UIS.InputChanged:Connect(function(i)
    if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-dS
        Win.Position=UDim2.new(dP.X.Scale,dP.X.Offset+d.X,dP.Y.Scale,dP.Y.Offset+d.Y)
    end
end)

-- Layout
local Sb=N("Frame",{Size=UDim2.new(0,138,1,-36),Position=UDim2.new(0,0,0,36),BackgroundColor3=C.Sidebar,BorderSizePixel=0},Win)
local SS=N("ScrollingFrame",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=0,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y},Sb)
List(2,SS) Pad(8,6,8,6,SS)
N("Frame",{Size=UDim2.new(0,1,1,-36),Position=UDim2.new(0,138,0,36),BackgroundColor3=C.Line,BorderSizePixel=0},Win)
local CA=N("Frame",{Size=UDim2.new(1,-139,1,-36),Position=UDim2.new(0,139,0,36),BackgroundColor3=C.Panel,BorderSizePixel=0},Win)

-- ── UI Components ──

local function SecLabel(par,text,order)
    local f=N("Frame",{Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,LayoutOrder=order},par)
    N("TextLabel",{Text=text:upper(),Font=Enum.Font.GothamBold,TextSize=9,TextColor3=C.Accent,BackgroundTransparency=1,Size=UDim2.new(1,0,0,14),Position=UDim2.new(0,0,0,8),TextXAlignment=Enum.TextXAlignment.Left},f)
    N("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=C.Line,BorderSizePixel=0},f)
end

local function Checkbox(par,label,tbl,key,order,cb)
    local row=N("Frame",{Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,LayoutOrder=order},par)
    local bg=N("Frame",{Size=UDim2.new(0,14,0,14),Position=UDim2.new(1,-14,0.5,-7),BackgroundColor3=tbl[key] and C.Accent or C.CheckOff,BorderSizePixel=0},row)
    Corner(3,bg)
    local st=N("UIStroke",{Color=tbl[key] and C.Glow or C.Line,Thickness=1},bg)
    local chk=N("TextLabel",{Text="✓",Font=Enum.Font.GothamBold,TextSize=10,TextColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),TextXAlignment=Enum.TextXAlignment.Center,Visible=tbl[key]},bg)
    N("TextLabel",{Text=label,Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.Text,BackgroundTransparency=1,Size=UDim2.new(1,-20,1,0),TextXAlignment=Enum.TextXAlignment.Left},row)
    N("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=""},row).MouseButton1Click:Connect(function()
        tbl[key]=not tbl[key]
        TweenSvc:Create(bg,TweenInfo.new(0.1),{BackgroundColor3=tbl[key] and C.Accent or C.CheckOff}):Play()
        st.Color=tbl[key] and C.Glow or C.Line chk.Visible=tbl[key]
        if cb then cb(tbl[key]) end
    end)
end

local function Slider(par,label,tbl,key,mn,mx,order,cb)
    local frame=N("Frame",{Size=UDim2.new(1,0,0,44),BackgroundTransparency=1,LayoutOrder=order},par)
    N("TextLabel",{Text=label,Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.Text,BackgroundTransparency=1,Size=UDim2.new(1,-34,0,16),TextXAlignment=Enum.TextXAlignment.Left},frame)
    local vl=N("TextLabel",{Text=tostring(tbl[key]),Font=Enum.Font.GothamBold,TextSize=11,TextColor3=C.Accent,BackgroundTransparency=1,Size=UDim2.new(0,30,0,16),Position=UDim2.new(1,-30,0,0),TextXAlignment=Enum.TextXAlignment.Right},frame)
    local track=N("Frame",{Size=UDim2.new(1,0,0,5),Position=UDim2.new(0,0,0,22),BackgroundColor3=C.SliderBG,BorderSizePixel=0},frame)
    Corner(3,track)
    local r0=math.clamp((tbl[key]-mn)/(mx-mn),0,1)
    local fill=N("Frame",{Size=UDim2.new(r0,0,1,0),BackgroundColor3=C.Accent,BorderSizePixel=0},track)
    Corner(3,fill)
    N("UIGradient",{Color=ColorSequence.new{ColorSequenceKeypoint.new(0,C.AccentD),ColorSequenceKeypoint.new(1,C.Glow)}},fill)
    local knob=N("Frame",{Size=UDim2.new(0,11,0,11),Position=UDim2.new(r0,-5,0.5,-5.5),BackgroundColor3=Color3.fromRGB(230,210,255),BorderSizePixel=0},track)
    Corner(6,knob)
    local sliding=false
    local function Set(ix)
        local rel=math.clamp((ix-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        local val=math.floor(mn+(mx-mn)*rel)
        tbl[key]=val fill.Size=UDim2.new(rel,0,1,0)
        knob.Position=UDim2.new(rel,-5,0.5,-5.5) vl.Text=tostring(val)
        if cb then cb(val) end
    end
    track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then sliding=true Set(i.Position.X) end end)
    UIS.InputChanged:Connect(function(i) if sliding and i.UserInputType==Enum.UserInputType.MouseMovement then Set(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then sliding=false end end)
end

local function Dropdown(par,label,tbl,key,opts,order,cb)
    local frame=N("Frame",{Size=UDim2.new(1,0,0,46),BackgroundTransparency=1,LayoutOrder=order,ClipsDescendants=false},par)
    N("TextLabel",{Text=label,Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.Text,BackgroundTransparency=1,Size=UDim2.new(1,0,0,18),TextXAlignment=Enum.TextXAlignment.Left},frame)
    local box=N("TextButton",{Size=UDim2.new(1,0,0,22),Position=UDim2.new(0,0,0,20),BackgroundColor3=C.SliderBG,BorderSizePixel=0,Text=" "..tostring(tbl[key]).."  ▾",Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.Text,AutoButtonColor=false,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=3},frame)
    Corner(4,box) Pad(0,0,0,6,box)
    N("UIStroke",{Color=C.Line,Thickness=1},box)
    local drop=N("Frame",{Size=UDim2.new(1,0,0,#opts*22+6),Position=UDim2.new(0,0,0,46),BackgroundColor3=Color3.fromRGB(12,8,20),BorderSizePixel=0,Visible=false,ZIndex=20,ClipsDescendants=false},frame)
    Corner(4,drop) N("UIStroke",{Color=C.Accent,Thickness=1,Transparency=0.5},drop)
    List(1,drop) Pad(3,4,3,4,drop)
    for _,opt in ipairs(opts) do
        local ob=N("TextButton",{Size=UDim2.new(1,0,0,20),BackgroundColor3=C.Panel,BorderSizePixel=0,Text=" "..opt,Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.Text,AutoButtonColor=false,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=21},drop)
        Corner(3,ob) Pad(0,0,0,4,ob)
        ob.MouseEnter:Connect(function() ob.BackgroundColor3=C.TabSel end)
        ob.MouseLeave:Connect(function() ob.BackgroundColor3=C.Panel end)
        ob.MouseButton1Click:Connect(function()
            tbl[key]=opt box.Text=" "..opt.."  ▾" drop.Visible=false
            if cb then cb(opt) end
        end)
    end
    box.MouseButton1Click:Connect(function()
        drop.Visible=not drop.Visible frame.ZIndex=drop.Visible and 50 or 1
    end)
end

-- Color Swatch Picker
local function ColorPicker(par,label,tbl,key,order,cb)
    local frame=N("Frame",{Size=UDim2.new(1,0,0,46),BackgroundTransparency=1,LayoutOrder=order},par)
    N("TextLabel",{Text=label,Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.Text,BackgroundTransparency=1,Size=UDim2.new(1,0,0,18),TextXAlignment=Enum.TextXAlignment.Left},frame)

    local swatches = {
        {Color3.fromRGB(170,80,255),"Purple"},
        {Color3.fromRGB(255,60,60),"Red"},
        {Color3.fromRGB(80,255,120),"Green"},
        {Color3.fromRGB(80,160,255),"Blue"},
        {Color3.fromRGB(255,220,60),"Yellow"},
        {Color3.fromRGB(60,220,255),"Cyan"},
        {Color3.fromRGB(255,100,200),"Pink"},
        {Color3.fromRGB(255,140,40),"Orange"},
        {Color3.fromRGB(240,240,240),"White"},
    }

    local row=N("Frame",{Size=UDim2.new(1,0,0,22),Position=UDim2.new(0,0,0,20),BackgroundTransparency=1},frame)
    N("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},row)

    local selected = nil

    for i,sw in ipairs(swatches) do
        local col,_ = sw[1],sw[2]
        local btn=N("TextButton",{
            Size=UDim2.new(0,20,0,20),
            BackgroundColor3=col,
            BorderSizePixel=0,Text="",
            AutoButtonColor=false,LayoutOrder=i
        },row)
        Corner(4,btn)
        -- highlight if current
        if tbl[key] == col then
            N("UIStroke",{Color=Color3.fromRGB(255,255,255),Thickness=1.5},btn)
        end
        btn.MouseButton1Click:Connect(function()
            tbl[key]=col
            -- clear all strokes
            for _,ch in ipairs(row:GetChildren()) do
                if ch:IsA("TextButton") then
                    local st=ch:FindFirstChildOfClass("UIStroke")
                    if st then st:Destroy() end
                end
            end
            N("UIStroke",{Color=Color3.fromRGB(255,255,255),Thickness=1.5},btn)
            if cb then cb(col) end
        end)
    end
    return frame
end

-- ── PAGES ──
local Pages,TabBtns,ActiveTab={},{},""

local function MakePage(name)
    local p=N("ScrollingFrame",{
        Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,
        ScrollBarThickness=3,ScrollBarImageColor3=C.Accent,
        CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,
        Visible=false,ClipsDescendants=true
    },CA)
    List(0,p) Pad(8,10,12,10,p)
    Pages[name]=p return p
end

local function TwoCol(par,order)
    local row=N("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=order},par)
    N("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Top},row)
    local function Col()
        local c=N("Frame",{Size=UDim2.new(0.5,-4,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1},row)
        List(3,c) return c
    end
    return Col(),Col()
end

-- ══════════════════════════════════════
-- AIMBOT PAGE
-- ══════════════════════════════════════
local AP=MakePage("Aimbot")
local ac1,ac2=TwoCol(AP,1)

SecLabel(ac1,"Aimbot",1)
Checkbox(ac1,"Enable",     CFG,"AimbotOn",  2)
Slider  (ac1,"FOV",        CFG,"AimbotFOV", 10,300,3)
Slider  (ac1,"Speed",      CFG,"AimbotSpeed",1,20,4)
Dropdown(ac1,"Target",     CFG,"AimbotPart",{"Head","UpperTorso","HumanoidRootPart"},5)
Dropdown(ac1,"Key",        CFG,"AimbotKey", {"RMB","LMB","LALT","LSHIFT","E"},6)
SecLabel(ac1,"Options",7)
Checkbox(ac1,"Prediction", CFG,"Prediction",8)
Checkbox(ac1,"Wall Check", CFG,"WallCheck", 9)
Checkbox(ac1,"Team Check", CFG,"TeamCheck", 10)

SecLabel(ac2,"Silent Aim",1)
Checkbox(ac2,"Enable",CFG,"SilentOn",2,function(v)
    if v then HookSilent() else UnhookSilent() end
end)
Slider(ac2,"FOV",CFG,"SilentFOV",50,500,3)
N("TextLabel",{
    Text="Перехватывает workspace.\nRaycast и редиректит\nпули к ближайшей цели\nв пределах FOV.",
    Font=Enum.Font.Gotham,TextSize=10,TextColor3=C.TextDim,
    BackgroundTransparency=1,Size=UDim2.new(1,0,0,52),
    TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,LayoutOrder=4
},ac2)

-- ══════════════════════════════════════
-- ESP PAGE
-- ══════════════════════════════════════
local EP=MakePage("ESP")
local ec1,ec2=TwoCol(EP,1)

SecLabel(ec1,"Box Types",1)
Checkbox(ec1,"Box ESP",     CFG,"BoxESP",    2)
Checkbox(ec1,"Corner Box",  CFG,"CornerBox", 3)
Checkbox(ec1,"Filled Box",  CFG,"FilledBox", 4)
Checkbox(ec1,"3D Box",      CFG,"Box3D",     5)
Slider  (ec1,"Thickness",   CFG,"BoxThick",1,5,6)

SecLabel(ec1,"Overlay",7)
Checkbox(ec1,"Skeleton",    CFG,"Skeleton",  8)
Checkbox(ec1,"Tracer",      CFG,"Tracer",    9)
Checkbox(ec1,"Head Dot",    CFG,"HeadDot",   10)
Checkbox(ec1,"Health Bar",  CFG,"HealthBar", 11)
Checkbox(ec1,"HP Text",     CFG,"HealthText",12)
Checkbox(ec1,"Names",       CFG,"Names",     13)
Checkbox(ec1,"Distance",    CFG,"Distance",  14)
Checkbox(ec1,"Weapon",      CFG,"WeaponESP", 15)
Checkbox(ec1,"FOV Circle",  CFG,"FOVCircle", 16)
Slider  (ec1,"Max Dist",    CFG,"MaxDist",50,1000,17)
Checkbox(ec1,"Watermark",   CFG,"WatermarkOn",18)

SecLabel(ec2,"ESP Color",1)
Dropdown(ec2,"Mode",CFG,"ColorMode",{"Custom","Team","Distance","Health","Rainbow"},2,function()
    -- nothing extra needed, GetESPColor reads CFG.ColorMode live
end)
ColorPicker(ec2,"Custom Color",CFG,"CustomColor",3)

SecLabel(ec2,"Chams",4)
Checkbox(ec2,"Enable",       CFG,"Chams",    5,function() RefreshChams() end)
Checkbox(ec2,"Through Walls",CFG,"ChamsWall",6,function() RefreshChams() end)
Dropdown(ec2,"Style",CFG,"ChamsMode",{"Flat","Neon","Wireframe","Team","Rainbow","Xray"},7,function()
    RefreshChams()
end)
Slider  (ec2,"Fill Trans",CFG,"ChamsFill",0,10,8,function(v) CFG.ChamsFill=v/10 RefreshChams() end)
Slider  (ec2,"Outline Trans",CFG,"ChamsOut",0,10,9,function(v) CFG.ChamsOut=v/10 RefreshChams() end)
ColorPicker(ec2,"Chams Fill",CFG,"ChamsFillColor",10,function() RefreshChams() end)
ColorPicker(ec2,"Chams Outline",CFG,"ChamsOutColor",11,function() RefreshChams() end)

-- ══════════════════════════════════════
-- TABS
-- ══════════════════════════════════════
local tabDefs={
    {name="Aimbot",icon="🎯"},
    {name="ESP",   icon="👁"},
}

for i,def in ipairs(tabDefs) do
    local btn=N("TextButton",{
        Size=UDim2.new(1,0,0,30),BackgroundColor3=C.TabSel,
        BackgroundTransparency=1,BorderSizePixel=0,
        Text="",AutoButtonColor=false,LayoutOrder=i
    },SS)
    Corner(5,btn)
    local acc=N("Frame",{Size=UDim2.new(0,3,0.6,0),Position=UDim2.new(0,0,0.2,0),BackgroundColor3=C.Accent,BorderSizePixel=0,Visible=false},btn)
    Corner(2,acc)
    N("TextLabel",{Text=def.icon.."  "..def.name,Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.Text,BackgroundTransparency=1,Size=UDim2.new(1,-10,1,0),Position=UDim2.new(0,10,0,0),TextXAlignment=Enum.TextXAlignment.Left},btn)
    TabBtns[def.name]={btn=btn,acc=acc}
    local function Sel()
        for _,t in pairs(TabBtns) do t.btn.BackgroundTransparency=1 t.acc.Visible=false end
        for _,pg in pairs(Pages) do pg.Visible=false end
        btn.BackgroundTransparency=0 btn.BackgroundColor3=C.TabSel acc.Visible=true
        if Pages[def.name] then Pages[def.name].Visible=true end
        ActiveTab=def.name
    end
    btn.MouseButton1Click:Connect(Sel)
    btn.MouseEnter:Connect(function() if ActiveTab~=def.name then TweenSvc:Create(btn,TweenInfo.new(0.1),{BackgroundTransparency=0.5,BackgroundColor3=C.TabSel}):Play() end end)
    btn.MouseLeave:Connect(function() if ActiveTab~=def.name then TweenSvc:Create(btn,TweenInfo.new(0.1),{BackgroundTransparency=1}):Play() end end)
    if i==1 then Sel() end
end

UIS.InputBegan:Connect(function(input)
    if input.KeyCode==Enum.KeyCode.Insert then Win.Visible=not Win.Visible end
end)

print("[ALACRITY] ready — Insert")
