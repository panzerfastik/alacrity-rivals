-- Roblox: Rivals | Executor: Solara | Insert = toggle
-- Ghost ESP fix: CharacterRemoving hook, death check, cache invalidation

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
        syn.protect_gui(sg) sg.Parent = game:GetService("CoreGui")
    else sg.Parent = LP.PlayerGui end
    return sg
end

-- ══════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════
local CFG = {
    AimbotOn    = false,
    AimbotFOV   = 150,
    AimbotSpeed = 8,
    AimbotPart  = "Head",
    AimbotKey   = "RMB",
    Prediction  = true,
    WallCheck   = false,
    TeamCheck   = false,
    SilentOn    = false,
    SilentFOV   = 300,
    BoxESP      = true,
    CornerBox   = false,
    FilledBox   = false,
    Box3D       = false,
    Skeleton    = false,
    Tracer      = false,
    HeadDot     = false,
    HealthBar   = true,
    HealthText  = false,
    Names       = true,
    Distance    = true,
    WeaponESP   = false,
    FOVCircle   = true,
    MaxDist     = 600,
    BoxThick    = 1.5,
    ColorMode   = "Custom",
    CustomColor = Color3.fromRGB(170,80,255),
    Chams           = false,
    ChamsWall       = true,
    ChamsFill       = 0.4,
    ChamsOut        = 0.0,
    ChamsMode       = "Flat",
    ChamsFillColor  = Color3.fromRGB(140,50,255),
    ChamsOutColor   = Color3.fromRGB(200,120,255),
    WatermarkOn     = true,
}

-- ══════════════════════════════════════
-- COLOR
-- ══════════════════════════════════════
local function GetESPColor(player)
    local m = CFG.ColorMode
    if m == "Custom" then
        return CFG.CustomColor
    elseif m == "Team" then
        return player.Team == LP.Team
            and Color3.fromRGB(80,180,255)
            or  Color3.fromRGB(255,60,60)
    elseif m == "Distance" then
        local char = player.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local d = math.clamp((Camera.CFrame.Position-hrp.Position).Magnitude/CFG.MaxDist,0,1)
            return Color3.fromRGB(math.floor(255*d),math.floor(255*(1-d)),0)
        end
    elseif m == "Health" then
        local char = player.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.MaxHealth > 0 then
            local r = math.clamp(hum.Health/hum.MaxHealth,0,1)
            return Color3.fromRGB(math.floor(255*(1-r)),math.floor(255*r),0)
        end
    elseif m == "Rainbow" then
        return Color3.fromHSV((tick()*0.3)%1,1,1)
    end
    return CFG.CustomColor
end

-- ══════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════
local function W2S(pos)
    local ok,s = pcall(function() return Camera:WorldToViewportPoint(pos) end)
    if not ok then return Vector2.zero,false,0 end
    return Vector2.new(s.X,s.Y), s.Z>0, s.Z
end

local function ClampV2(v, margin)
    margin = margin or 0
    local vp = Camera.ViewportSize
    return Vector2.new(
        math.clamp(v.X, margin, vp.X-margin),
        math.clamp(v.Y, margin, vp.Y-margin)
    )
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
        local sc,on = W2S(pos)
        if not on then continue end
        local d = (sc-center).Magnitude
        if d < bestD then bestD=d best=part end
    end
    return best
end

-- ══════════════════════════════════════
-- SILENT AIM
-- ══════════════════════════════════════
local OrigRaycast  = workspace.Raycast
local SilentHooked = false

local function HookSilent()
    if SilentHooked then return end
    SilentHooked = true
    workspace.Raycast = function(self, origin, direction, params)
        if CFG.SilentOn then
            local t = GetTarget(CFG.SilentFOV)
            if t then
                local nd = t.Position - origin
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
                        local nd = t.Position - args[1]
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
local ChamsCache    = {}
local RainbowHue    = 0

local function ApplyChams(p, char)
    if ChamsCache[p] then
        pcall(function() ChamsCache[p]:Destroy() end)
        ChamsCache[p] = nil
    end
    if not CFG.Chams or not char or not char.Parent then return end
    local h = Instance.new("Highlight")
    h.Adornee             = char
    h.FillTransparency    = CFG.ChamsFill
    h.OutlineTransparency = CFG.ChamsOut
    h.DepthMode = CFG.ChamsWall
        and Enum.HighlightDepthMode.AlwaysOnTop
        or  Enum.HighlightDepthMode.Occluded
    local mode = CFG.ChamsMode
    if mode=="Neon" then
        h.FillColor=CFG.ChamsFillColor h.OutlineColor=Color3.new(1,1,1) h.FillTransparency=0.1
    elseif mode=="Team" then
        local isTeam = p.Team==LP.Team
        h.FillColor    = isTeam and Color3.fromRGB(80,160,255) or Color3.fromRGB(255,60,60)
        h.OutlineColor = isTeam and Color3.fromRGB(120,200,255) or Color3.fromRGB(255,140,140)
    elseif mode=="Wireframe" then
        h.FillTransparency=1 h.OutlineColor=CFG.ChamsOutColor h.OutlineTransparency=0
    elseif mode=="Rainbow" then
        h.FillColor=Color3.fromHSV(RainbowHue,1,1)
        h.OutlineColor=Color3.fromHSV((RainbowHue+0.5)%1,1,1)
    elseif mode=="Xray" then
        h.FillColor=Color3.new(1,1,1) h.OutlineColor=CFG.ChamsOutColor
        h.FillTransparency=0.6 h.OutlineTransparency=0
        h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    else -- Flat
        h.FillColor=CFG.ChamsFillColor h.OutlineColor=CFG.ChamsOutColor
    end
    h.Parent = workspace
    ChamsCache[p] = h
end

local function RemoveChams(p)
    if ChamsCache[p] then
        pcall(function() ChamsCache[p]:Destroy() end)
        ChamsCache[p] = nil
    end
end

local function RefreshChams()
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP then continue end
        if p.Character and CFG.Chams then ApplyChams(p,p.Character)
        else RemoveChams(p) end
    end
end

RunService.Heartbeat:Connect(function(dt)
    RainbowHue = (RainbowHue + dt*0.3)%1
    if CFG.Chams and CFG.ChamsMode=="Rainbow" then
        for _,h in pairs(ChamsCache) do
            if h and h.Parent then
                h.FillColor    = Color3.fromHSV(RainbowHue,1,1)
                h.OutlineColor = Color3.fromHSV((RainbowHue+0.5)%1,1,1)
            end
        end
    end
end)

-- ══════════════════════════════════════
-- ESP CACHE
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

local ESPCache = {} -- [player] = { drawings, trackedChar }

local function DR(t, props)
    local d = Drawing.new(t)
    for k,v in pairs(props) do pcall(function() d[k]=v end) end
    return d
end

local function NewEntry()
    return {
        char   = nil, -- tracked character reference
        Box    = DR("Square",{Visible=false,Filled=false,Thickness=1.5}),
        Fill   = DR("Square",{Visible=false,Filled=true}),
        Cors   = (function() local t={} for i=1,8  do t[i]=DR("Line",{Visible=false,Thickness=1.5}) end return t end)(),
        B3D    = (function() local t={} for i=1,12 do t[i]=DR("Line",{Visible=false,Thickness=1}) end return t end)(),
        Bon    = (function() local t={} for i=1,14 do t[i]=DR("Line",{Visible=false,Thickness=1.2}) end return t end)(),
        Tracer = DR("Line",{Visible=false,Thickness=1}),
        Dot    = DR("Circle",{Visible=false,Filled=true,Thickness=1,NumSides=16}),
        HpBG   = DR("Square",{Visible=false,Filled=true,Color=Color3.fromRGB(20,20,20)}),
        HpBar  = DR("Square",{Visible=false,Filled=true}),
        Name   = DR("Text",{Visible=false,Size=13,Center=true,Outline=true,Font=2}),
        Dist   = DR("Text",{Visible=false,Size=11,Center=true,Outline=true,Font=2,Color=Color3.fromRGB(200,200,200)}),
        HpText = DR("Text",{Visible=false,Size=10,Center=true,Outline=true,Font=2,Color=Color3.fromRGB(200,255,200)}),
        Weapon = DR("Text",{Visible=false,Size=10,Center=true,Outline=true,Font=2,Color=Color3.fromRGB(255,220,100)}),
    }
end

local function HideEntry(e)
    if not e then return end
    pcall(function() e.Box.Visible=false end)
    pcall(function() e.Fill.Visible=false end)
    pcall(function() e.Tracer.Visible=false end)
    pcall(function() e.Dot.Visible=false end)
    pcall(function() e.HpBG.Visible=false end)
    pcall(function() e.HpBar.Visible=false end)
    pcall(function() e.Name.Visible=false end)
    pcall(function() e.Dist.Visible=false end)
    pcall(function() e.HpText.Visible=false end)
    pcall(function() e.Weapon.Visible=false end)
    for _,l in ipairs(e.Cors) do pcall(function() l.Visible=false end) end
    for _,l in ipairs(e.B3D)  do pcall(function() l.Visible=false end) end
    for _,l in ipairs(e.Bon)  do pcall(function() l.Visible=false end) end
end

local function DestroyEntry(e)
    if not e then return end
    HideEntry(e)
    pcall(function() e.Box:Remove() end)
    pcall(function() e.Fill:Remove() end)
    pcall(function() e.Tracer:Remove() end)
    pcall(function() e.Dot:Remove() end)
    pcall(function() e.HpBG:Remove() end)
    pcall(function() e.HpBar:Remove() end)
    pcall(function() e.Name:Remove() end)
    pcall(function() e.Dist:Remove() end)
    pcall(function() e.HpText:Remove() end)
    pcall(function() e.Weapon:Remove() end)
    for _,l in ipairs(e.Cors) do pcall(function() l:Remove() end) end
    for _,l in ipairs(e.B3D)  do pcall(function() l:Remove() end) end
    for _,l in ipairs(e.Bon)  do pcall(function() l:Remove() end) end
end

-- ── Ghost ESP fix: hook character changes per player ──
local CharConnections = {} -- [player] = {conn1, conn2, ...}

local function CleanupPlayer(p)
    HideEntry(ESPCache[p])
    DestroyEntry(ESPCache[p])
    ESPCache[p] = nil
    RemoveChams(p)
    if CharConnections[p] then
        for _,c in ipairs(CharConnections[p]) do
            pcall(function() c:Disconnect() end)
        end
        CharConnections[p] = nil
    end
end

local function SetupPlayer(p)
    if p == LP then return end
    if CharConnections[p] then
        for _,c in ipairs(CharConnections[p]) do
            pcall(function() c:Disconnect() end)
        end
    end
    CharConnections[p] = {}

    -- CharacterRemoving: hide ESP immediately
    local c1 = p.CharacterRemoving:Connect(function()
        HideEntry(ESPCache[p])
        -- invalidate so next frame creates fresh entry
        if ESPCache[p] then
            ESPCache[p].char = nil
        end
        RemoveChams(p)
    end)
    table.insert(CharConnections[p], c1)

    -- CharacterAdded: reset entry, reapply chams
    local c2 = p.CharacterAdded:Connect(function(char)
        -- destroy stale drawings
        if ESPCache[p] then
            DestroyEntry(ESPCache[p])
            ESPCache[p] = nil
        end
        RemoveChams(p)
        task.wait(0.5)
        if CFG.Chams then ApplyChams(p, char) end
    end)
    table.insert(CharConnections[p], c2)

    -- Humanoid Died: hide immediately
    local function HookHumanoid(char)
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            local c3 = hum.Died:Connect(function()
                HideEntry(ESPCache[p])
            end)
            table.insert(CharConnections[p], c3)
        else
            -- wait for humanoid to appear
            local c3 = char.ChildAdded:Connect(function(child)
                if child:IsA("Humanoid") then
                    local c4 = child.Died:Connect(function()
                        HideEntry(ESPCache[p])
                    end)
                    table.insert(CharConnections[p], c4)
                end
            end)
            table.insert(CharConnections[p], c3)
        end
    end

    if p.Character then HookHumanoid(p.Character) end
    local c5 = p.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        HookHumanoid(char)
    end)
    table.insert(CharConnections[p], c5)

    -- existing char: apply chams
    if p.Character and CFG.Chams then
        task.wait(0.5)
        ApplyChams(p, p.Character)
    end
end

-- init existing players
for _,p in ipairs(Players:GetPlayers()) do SetupPlayer(p) end
Players.PlayerAdded:Connect(function(p) SetupPlayer(p) end)
Players.PlayerRemoving:Connect(function(p) CleanupPlayer(p) end)

-- ══════════════════════════════════════
-- DRAWING HELPERS
-- ══════════════════════════════════════
local function DrawCors(ls,x,y,w,h,col,th)
    local cl=w*0.22 local ct=h*0.22
    local pts={
        {x,y,x+cl,y},{x,y,x,y+ct},
        {x+w,y,x+w-cl,y},{x+w,y,x+w,y+ct},
        {x,y+h,x+cl,y+h},{x,y+h,x,y+h-ct},
        {x+w,y+h,x+w-cl,y+h},{x+w,y+h,x+w,y+h-ct},
    }
    for i,pp in ipairs(pts) do
        ls[i].From=Vector2.new(pp[1],pp[2]) ls[i].To=Vector2.new(pp[3],pp[4])
        ls[i].Color=col ls[i].Thickness=th ls[i].Visible=true
    end
end

local CUBE_O={
    Vector3.new(-1,0,-1),Vector3.new(1,0,-1),Vector3.new(1,0,1),Vector3.new(-1,0,1),
    Vector3.new(-1,2,-1),Vector3.new(1,2,-1),Vector3.new(1,2,1),Vector3.new(-1,2,1),
}
local CUBE_E={{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}

local function Draw3D(ls,cf,col)
    local v={}
    for i,o in ipairs(CUBE_O) do
        local wc=cf*CFrame.new(o.X*1.5,o.Y-1,o.Z*1.5)
        local sc,on=W2S(wc.Position)
        v[i]={sc=sc,on=on}
    end
    for i,ed in ipairs(CUBE_E) do
        local a,b=v[ed[1]],v[ed[2]]
        if a.on or b.on then
            ls[i].From=a.sc ls[i].To=b.sc ls[i].Color=col ls[i].Thickness=1 ls[i].Visible=true
        else ls[i].Visible=false end
    end
end

-- FOV
local FOVDraw = DR("Circle",{Visible=false,Thickness=1,Filled=false,NumSides=64})

-- ══════════════════════════════════════
-- WATERMARK
-- ══════════════════════════════════════
local WM = {
    BG   = DR("Square",{Visible=false,Filled=true,Color=Color3.fromRGB(14,10,22),Transparency=0.25}),
    Line = DR("Line",{Visible=false,Color=Color3.fromRGB(150,60,255),Thickness=2}),
    Text = DR("Text",{Visible=false,Size=13,Outline=true,Font=2,Color=Color3.fromRGB(220,200,240)}),
}
local FPSBuf = {}

local function UpdateWM(dt)
    table.insert(FPSBuf, 1/math.max(dt,0.001))
    if #FPSBuf>30 then table.remove(FPSBuf,1) end
    local fps=0
    for _,v in ipairs(FPSBuf) do fps=fps+v end
    fps = math.floor(fps/#FPSBuf)
    local ping = math.floor(pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end) and Stats.Network.ServerStatsItem["Data Ping"]:GetValue() or 0)
    local str  = string.format("ALACRITY  |  %s  |  %d fps  |  %d ms", LP.Name, fps, ping)
    local tw   = #str * 7.4
    WM.BG.Position=Vector2.new(4,4) WM.BG.Size=Vector2.new(tw+12,24) WM.BG.Visible=CFG.WatermarkOn
    WM.Line.From=Vector2.new(4,28) WM.Line.To=Vector2.new(tw+16,28) WM.Line.Visible=CFG.WatermarkOn
    WM.Text.Text=str WM.Text.Position=Vector2.new(10,8) WM.Text.Visible=CFG.WatermarkOn
end

-- ══════════════════════════════════════
-- MAIN LOOP
-- ══════════════════════════════════════
RunService.RenderStepped:Connect(function(dt)
    local vp     = Camera.ViewportSize
    local center = Vector2.new(vp.X/2, vp.Y/2)

    UpdateWM(dt)

    FOVDraw.Position = center
    FOVDraw.Radius   = CFG.SilentOn and CFG.SilentFOV or CFG.AimbotFOV
    FOVDraw.Color    = CFG.SilentOn and Color3.fromRGB(255,80,80) or Color3.fromRGB(170,80,255)
    FOVDraw.Visible  = CFG.FOVCircle and (CFG.AimbotOn or CFG.SilentOn)

    -- aimbot
    if CFG.AimbotOn and KeyHeld() then
        local t = GetTarget(CFG.AimbotFOV)
        if t then
            local sc = W2S(t.Position)
            local dx,dy = sc.X-center.X, sc.Y-center.Y
            local dist  = math.sqrt(dx*dx+dy*dy)
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

        -- ── Ghost fix: no character = hide and skip ──
        if not char or not char.Parent then
            HideEntry(ESPCache[p])
            continue
        end

        local hrp  = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        local hum  = char:FindFirstChildOfClass("Humanoid")

        -- ── Ghost fix: parts missing or dead ──
        if not hrp or not head or not hum then
            HideEntry(ESPCache[p])
            continue
        end
        if hum.Health <= 0 or hum.Health ~= hum.Health then  -- NaN check too
            HideEntry(ESPCache[p])
            continue
        end

        local worldDist = (Camera.CFrame.Position-hrp.Position).Magnitude
        if worldDist > CFG.MaxDist then
            HideEntry(ESPCache[p])
            continue
        end

        -- ── Ghost fix: if tracked char changed, destroy old entry ──
        if ESPCache[p] and ESPCache[p].char ~= char then
            DestroyEntry(ESPCache[p])
            ESPCache[p] = nil
        end

        if not ESPCache[p] then
            ESPCache[p] = NewEntry()
            ESPCache[p].char = char
        end

        local e = ESPCache[p]

        -- screen positions
        local headSz = head.Size.Y/2 + 0.15
        local topSc, topOn = W2S(head.Position + Vector3.new(0, headSz, 0))
        local botSc        = W2S(hrp.Position  - Vector3.new(0, 3.0,  0))

        if not topOn then HideEntry(e) continue end

        -- safe geometry
        local top_y = math.min(topSc.Y, botSc.Y)
        local bot_y = math.max(topSc.Y, botSc.Y)
        local ctr_x = topSc.X
        local bh    = bot_y - top_y
        if bh < 6 then HideEntry(e) continue end

        local bw = bh * 0.50
        local bx = ctr_x - bw/2
        local by = top_y

        -- clamp to viewport
        local vx = math.clamp(bx, 0, vp.X - bw)
        local vy = math.clamp(by, 0, vp.Y - bh)

        local col = GetESPColor(p)

        -- FILLED
        if CFG.FilledBox then
            e.Fill.Size=Vector2.new(bw,bh) e.Fill.Position=Vector2.new(vx,vy)
            e.Fill.Color=col e.Fill.Transparency=0.80 e.Fill.Visible=true
        else e.Fill.Visible=false end

        -- BOX
        if CFG.BoxESP then
            e.Box.Size=Vector2.new(bw,bh) e.Box.Position=Vector2.new(vx,vy)
            e.Box.Color=col e.Box.Thickness=CFG.BoxThick e.Box.Visible=true
        else e.Box.Visible=false end

        -- CORNERS
        if CFG.CornerBox then DrawCors(e.Cors,vx,vy,bw,bh,col,CFG.BoxThick)
        else for _,l in ipairs(e.Cors) do l.Visible=false end end

        -- 3D
        if CFG.Box3D then Draw3D(e.B3D,hrp.CFrame,col)
        else for _,l in ipairs(e.B3D) do l.Visible=false end end

        -- SKELETON
        if CFG.Skeleton then
            local bones = char:FindFirstChild("UpperTorso") and BONES15 or BONES6
            for i,pair in ipairs(bones) do
                local a=char:FindFirstChild(pair[1])
                local b=char:FindFirstChild(pair[2])
                if a and b and e.Bon[i] then
                    local sa,aOn=W2S(a.Position)
                    local sb2   =W2S(b.Position)
                    e.Bon[i].From=sa e.Bon[i].To=sb2
                    e.Bon[i].Color=col e.Bon[i].Visible=aOn
                elseif e.Bon[i] then e.Bon[i].Visible=false end
            end
            for i=#(char:FindFirstChild("UpperTorso") and BONES15 or BONES6)+1,14 do
                if e.Bon[i] then e.Bon[i].Visible=false end
            end
        else for _,l in ipairs(e.Bon) do l.Visible=false end end

        -- TRACER
        if CFG.Tracer then
            local botScr = W2S(hrp.Position - Vector3.new(0,3,0))
            e.Tracer.From=Vector2.new(vp.X/2,vp.Y)
            e.Tracer.To=botScr e.Tracer.Color=col e.Tracer.Thickness=1 e.Tracer.Visible=true
        else e.Tracer.Visible=false end

        -- HEAD DOT
        if CFG.HeadDot then
            local dotR = math.clamp(bw*0.18,3,10)
            e.Dot.Position=topSc e.Dot.Radius=dotR e.Dot.Color=col e.Dot.Visible=true
        else e.Dot.Visible=false end

        -- HP BAR (bottom-anchored)
        if CFG.HealthBar then
            local r      = math.clamp(hum.Health/hum.MaxHealth,0,1)
            local barX   = vx - 7
            local fillH  = bh * r
            e.HpBG.Size=Vector2.new(4,bh)   e.HpBG.Position=Vector2.new(barX,vy)  e.HpBG.Visible=true
            e.HpBar.Size=Vector2.new(4,fillH) e.HpBar.Position=Vector2.new(barX,vy+bh-fillH)
            e.HpBar.Color=Color3.fromRGB(math.floor(255*(1-r)),math.floor(255*r),0) e.HpBar.Visible=true
        else e.HpBG.Visible=false e.HpBar.Visible=false end

        -- HP TEXT
        if CFG.HealthText then
            e.HpText.Text=math.floor(hum.Health).."hp"
            e.HpText.Position=Vector2.new(ctr_x, vy+bh+3) e.HpText.Visible=true
        else e.HpText.Visible=false end

        -- NAME
        if CFG.Names then
            e.Name.Text=p.Name e.Name.Color=col
            e.Name.Size=math.clamp(bh*0.11+8,10,14)
            e.Name.Position=Vector2.new(ctr_x, vy-16) e.Name.Visible=true
        else e.Name.Visible=false end

        -- DISTANCE
        if CFG.Distance then
            local yOff = vy+bh + (CFG.HealthText and 14 or 3)
            e.Dist.Text=math.floor(worldDist).."m"
            e.Dist.Position=Vector2.new(ctr_x, yOff) e.Dist.Visible=true
        else e.Dist.Visible=false end

        -- WEAPON
        if CFG.WeaponESP then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                local yOff = vy+bh + (CFG.Distance and 25 or 3)
                e.Weapon.Text=tool.Name
                e.Weapon.Position=Vector2.new(ctr_x, yOff) e.Weapon.Visible=true
            else e.Weapon.Visible=false end
        else e.Weapon.Visible=false end
    end
end)

-- ══════════════════════════════════════
-- GUI — OLD MENU (Neverlose layout)
-- ══════════════════════════════════════
local ScreenGui = GetGUI()

local C={
    BG=Color3.fromRGB(20,20,25),Panel=Color3.fromRGB(28,28,33),
    Sidebar=Color3.fromRGB(18,18,22),Accent=Color3.fromRGB(52,152,219),
    AccentD=Color3.fromRGB(30,110,170),Text=Color3.fromRGB(200,200,200),
    TextDim=Color3.fromRGB(110,110,120),Line=Color3.fromRGB(40,40,50),
    TabSel=Color3.fromRGB(35,35,42),CheckOn=Color3.fromRGB(52,152,219),
    CheckOff=Color3.fromRGB(55,55,65),SliderBG=Color3.fromRGB(38,38,48),
    SliderFG=Color3.fromRGB(52,152,219),Header=Color3.fromRGB(16,16,20),
    -- purple accents
    PAcc=Color3.fromRGB(150,60,255),PGlow=Color3.fromRGB(180,100,255),
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
    Size=UDim2.new(0,660,0,460),
    Position=UDim2.new(0.5,-330,0.5,-230),
    BackgroundColor3=C.BG,BorderSizePixel=0,Visible=false
},ScreenGui)
Corner(6,Win)

-- shadow image
N("ImageLabel",{
    Size=UDim2.new(1,30,1,30),Position=UDim2.new(0,-15,0,-15),
    BackgroundTransparency=1,Image="rbxassetid://6015897843",
    ImageColor3=Color3.new(0,0,0),ImageTransparency=0.6,
    ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(49,49,450,450),ZIndex=0
},Win)

-- Header
local Hdr=N("Frame",{Size=UDim2.new(1,0,0,38),BackgroundColor3=C.Header,BorderSizePixel=0,ZIndex=2},Win)
Corner(6,Hdr)
N("Frame",{Size=UDim2.new(1,0,0,8),Position=UDim2.new(0,0,1,-8),BackgroundColor3=C.Header,BorderSizePixel=0,ZIndex=2},Hdr)
-- purple accent line
N("Frame",{Size=UDim2.new(1,0,0,2),Position=UDim2.new(0,0,1,-2),BackgroundColor3=C.PAcc,BorderSizePixel=0,ZIndex=3},Hdr)

N("TextLabel",{Text="ALACRITY",Font=Enum.Font.GothamBold,TextSize=13,TextColor3=C.PGlow,BackgroundTransparency=1,Size=UDim2.new(0,100,1,0),Position=UDim2.new(0,14,0,0),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=3},Hdr)
N("TextLabel",{Text="💾  Save     Global  ▾",Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.TextDim,BackgroundTransparency=1,Size=UDim2.new(0,160,1,0),Position=UDim2.new(0,112,0,0),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=3},Hdr)
N("TextLabel",{Text="⚙  🔍",Font=Enum.Font.Gotham,TextSize=13,TextColor3=C.TextDim,BackgroundTransparency=1,Size=UDim2.new(0,60,1,0),Position=UDim2.new(1,-70,0,0),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=3},Hdr)

-- drag
local drag,dS,dP=false,nil,nil
Hdr.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true dS=i.Position dP=Win.Position end
end)
Hdr.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
end)
UIS.InputChanged:Connect(function(i)
    if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-dS
        Win.Position=UDim2.new(dP.X.Scale,dP.X.Offset+d.X,dP.Y.Scale,dP.Y.Offset+d.Y)
    end
end)

-- Sidebar
local Sidebar=N("Frame",{Size=UDim2.new(0,148,1,-38),Position=UDim2.new(0,0,0,38),BackgroundColor3=C.Sidebar,BorderSizePixel=0},Win)
local SideScroll=N("ScrollingFrame",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=0,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y},Sidebar)
List(2,SideScroll) Pad(8,6,8,6,SideScroll)

-- divider
N("Frame",{Size=UDim2.new(0,1,1,-38),Position=UDim2.new(0,148,0,38),BackgroundColor3=C.Line,BorderSizePixel=0},Win)

-- Content
local ContentArea=N("Frame",{Size=UDim2.new(1,-149,1,-38),Position=UDim2.new(0,149,0,38),BackgroundColor3=C.Panel,BorderSizePixel=0},Win)

-- ── Page system ──
local Pages,TabBtns,ActiveTab={},{},""

local function MakePage(name)
    local p=N("ScrollingFrame",{
        Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,
        ScrollBarThickness=4,ScrollBarImageColor3=C.PAcc,
        CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,
        Visible=false,ClipsDescendants=true
    },ContentArea)
    List(0,p) Pad(10,12,12,14,p)
    Pages[name]=p return p
end

local function TwoCol(par,order)
    local row=N("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=order},par)
    N("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Top},row)
    local function Col()
        local c=N("Frame",{Size=UDim2.new(0.5,-5,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1},row)
        List(4,c) return c
    end
    return Col(),Col()
end

local function SecLabel(par,text,order)
    local f=N("Frame",{Size=UDim2.new(1,-16,0,22),BackgroundTransparency=1,LayoutOrder=order},par)
    N("TextLabel",{Text=text,Font=Enum.Font.GothamBold,TextSize=10,TextColor3=C.TextDim,BackgroundTransparency=1,Size=UDim2.new(1,0,0,14),Position=UDim2.new(0,0,0,8),TextXAlignment=Enum.TextXAlignment.Left},f)
    N("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=C.Line,BorderSizePixel=0},f)
end

local function Checkbox(par,label,tbl,key,order,cb)
    local row=N("Frame",{Size=UDim2.new(1,-16,0,22),BackgroundTransparency=1,LayoutOrder=order},par)
    local bg=N("Frame",{Size=UDim2.new(0,14,0,14),Position=UDim2.new(1,-14,0.5,-7),BackgroundColor3=tbl[key] and C.PAcc or C.CheckOff,BorderSizePixel=0},row)
    Corner(3,bg)
    local chk=N("TextLabel",{Text="✓",Font=Enum.Font.GothamBold,TextSize=10,TextColor3=Color3.new(1,1,1),BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),TextXAlignment=Enum.TextXAlignment.Center,Visible=tbl[key]},bg)
    N("TextLabel",{Text=label,Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.Text,BackgroundTransparency=1,Size=UDim2.new(1,-20,1,0),TextXAlignment=Enum.TextXAlignment.Left},row)
    N("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=""},row).MouseButton1Click:Connect(function()
        tbl[key]=not tbl[key]
        TweenSvc:Create(bg,TweenInfo.new(0.1),{BackgroundColor3=tbl[key] and C.PAcc or C.CheckOff}):Play()
        chk.Visible=tbl[key]
        if cb then cb(tbl[key]) end
    end)
end

local function Slider(par,label,tbl,key,mn,mx,order,cb)
    local frame=N("Frame",{Size=UDim2.new(1,-16,0,40),BackgroundTransparency=1,LayoutOrder=order},par)
    N("TextLabel",{Text=label,Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.Text,BackgroundTransparency=1,Size=UDim2.new(1,-34,0,16),TextXAlignment=Enum.TextXAlignment.Left},frame)
    local vl=N("TextLabel",{Text=tostring(tbl[key]),Font=Enum.Font.GothamBold,TextSize=11,TextColor3=C.PAcc,BackgroundTransparency=1,Size=UDim2.new(0,30,0,16),Position=UDim2.new(1,-30,0,0),TextXAlignment=Enum.TextXAlignment.Right},frame)
    local track=N("Frame",{Size=UDim2.new(1,0,0,5),Position=UDim2.new(0,0,0,20),BackgroundColor3=C.SliderBG,BorderSizePixel=0},frame)
    Corner(3,track)
    local r0=math.clamp((tbl[key]-mn)/(mx-mn),0,1)
    local fill=N("Frame",{Size=UDim2.new(r0,0,1,0),BackgroundColor3=C.PAcc,BorderSizePixel=0},track)
    Corner(3,fill)
    N("UIGradient",{Color=ColorSequence.new{ColorSequenceKeypoint.new(0,C.AccentD),ColorSequenceKeypoint.new(1,C.PGlow)}},fill)
    local knob=N("Frame",{Size=UDim2.new(0,12,0,12),Position=UDim2.new(r0,-6,0.5,-6),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},track)
    Corner(6,knob)
    local sliding=false
    local function Set(ix)
        local rel=math.clamp((ix-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        local val=math.floor(mn+(mx-mn)*rel)
        tbl[key]=val fill.Size=UDim2.new(rel,0,1,0) knob.Position=UDim2.new(rel,-6,0.5,-6)
        vl.Text=tostring(val) if cb then cb(val) end
    end
    track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then sliding=true Set(i.Position.X) end end)
    UIS.InputChanged:Connect(function(i) if sliding and i.UserInputType==Enum.UserInputType.MouseMovement then Set(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then sliding=false end end)
end

local function Dropdown(par,label,tbl,key,opts,order,cb)
    local frame=N("Frame",{Size=UDim2.new(1,-16,0,46),BackgroundTransparency=1,LayoutOrder=order,ClipsDescendants=false},par)
    N("TextLabel",{Text=label,Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.Text,BackgroundTransparency=1,Size=UDim2.new(1,0,0,18),TextXAlignment=Enum.TextXAlignment.Left},frame)
    local box=N("TextButton",{Size=UDim2.new(1,0,0,22),Position=UDim2.new(0,0,0,20),BackgroundColor3=C.SliderBG,BorderSizePixel=0,Text=" "..tostring(tbl[key]).."  ▾",Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.Text,AutoButtonColor=false,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=3},frame)
    Corner(4,box) Pad(0,0,0,8,box)
    N("UIStroke",{Color=C.Line,Thickness=1},box)
    local drop=N("Frame",{Size=UDim2.new(1,0,0,#opts*22+6),Position=UDim2.new(0,0,0,46),BackgroundColor3=C.Sidebar,BorderSizePixel=0,Visible=false,ZIndex=20,ClipsDescendants=false},frame)
    Corner(4,drop) N("UIStroke",{Color=C.PAcc,Thickness=1,Transparency=0.5},drop)
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

local function ColorSwatches(par,label,tbl,key,order,cb)
    local frame=N("Frame",{Size=UDim2.new(1,-16,0,44),BackgroundTransparency=1,LayoutOrder=order},par)
    N("TextLabel",{Text=label,Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.Text,BackgroundTransparency=1,Size=UDim2.new(1,0,0,16),TextXAlignment=Enum.TextXAlignment.Left},frame)
    local row=N("Frame",{Size=UDim2.new(1,0,0,22),Position=UDim2.new(0,0,0,18),BackgroundTransparency=1},frame)
    N("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},row)
    local swatches={
        Color3.fromRGB(170,80,255),Color3.fromRGB(255,60,60),Color3.fromRGB(80,255,120),
        Color3.fromRGB(80,160,255),Color3.fromRGB(255,220,60),Color3.fromRGB(60,220,255),
        Color3.fromRGB(255,100,200),Color3.fromRGB(255,140,40),Color3.fromRGB(240,240,240),
    }
    local btnRefs={}
    for i,col in ipairs(swatches) do
        local btn=N("TextButton",{Size=UDim2.new(0,20,0,20),BackgroundColor3=col,BorderSizePixel=0,Text="",AutoButtonColor=false,LayoutOrder=i},row)
        Corner(4,btn)
        btnRefs[i]=btn
        if tbl[key]==col then N("UIStroke",{Color=Color3.new(1,1,1),Thickness=1.5},btn) end
        btn.MouseButton1Click:Connect(function()
            tbl[key]=col
            for _,b in ipairs(btnRefs) do
                local st=b:FindFirstChildOfClass("UIStroke")
                if st then st:Destroy() end
            end
            N("UIStroke",{Color=Color3.new(1,1,1),Thickness=1.5},btn)
            if cb then cb(col) end
        end)
    end
end

-- ══════════════════════════════════════
-- AIMBOT PAGE
-- ══════════════════════════════════════
local AP=MakePage("Aimbot")
local am,ae=TwoCol(AP,1)

SecLabel(am,"Main",1)
Checkbox(am,"Enable Aimbot",  CFG,"AimbotOn",  2)
Slider  (am,"FOV",            CFG,"AimbotFOV", 10,300,3)
Slider  (am,"Speed",          CFG,"AimbotSpeed",1,20,4)
Dropdown(am,"Target Part",    CFG,"AimbotPart",{"Head","UpperTorso","HumanoidRootPart"},5)
Dropdown(am,"Aim Key",        CFG,"AimbotKey", {"RMB","LMB","LALT","LSHIFT","E"},6)
SecLabel(am,"Options",7)
Checkbox(am,"Prediction",     CFG,"Prediction",8)
Checkbox(am,"Wall Check",     CFG,"WallCheck", 9)
Checkbox(am,"Team Check",     CFG,"TeamCheck", 10)
Checkbox(am,"FOV Circle",     CFG,"FOVCircle", 11)

SecLabel(ae,"Silent Aim",1)
Checkbox(ae,"Enable Silent",  CFG,"SilentOn",  2,function(v)
    if v then HookSilent() else UnhookSilent() end
end)
Slider  (ae,"Silent FOV",     CFG,"SilentFOV", 50,500,3)
N("TextLabel",{
    Text="Перехватывает\nworkspace.Raycast\nи редиректит пули\nк ближайшей цели.",
    Font=Enum.Font.Gotham,TextSize=10,TextColor3=C.TextDim,
    BackgroundTransparency=1,Size=UDim2.new(1,-16,0,52),
    TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,LayoutOrder=4
},ae)

-- ══════════════════════════════════════
-- ESP PAGE
-- ══════════════════════════════════════
local EP=MakePage("ESP")
local em,ee=TwoCol(EP,1)

SecLabel(em,"Box",1)
Checkbox(em,"Box ESP",        CFG,"BoxESP",    2)
Checkbox(em,"Corner Box",     CFG,"CornerBox", 3)
Checkbox(em,"Filled Box",     CFG,"FilledBox", 4)
Checkbox(em,"3D Box",         CFG,"Box3D",     5)
Slider  (em,"Thickness",      CFG,"BoxThick",1,5,6)

SecLabel(em,"Overlay",7)
Checkbox(em,"Skeleton",       CFG,"Skeleton",  8)
Checkbox(em,"Tracer",         CFG,"Tracer",    9)
Checkbox(em,"Head Dot",       CFG,"HeadDot",   10)
Checkbox(em,"Health Bar",     CFG,"HealthBar", 11)
Checkbox(em,"HP Text",        CFG,"HealthText",12)
Checkbox(em,"Names",          CFG,"Names",     13)
Checkbox(em,"Distance",       CFG,"Distance",  14)
Checkbox(em,"Weapon Label",   CFG,"WeaponESP", 15)
Checkbox(em,"Watermark",      CFG,"WatermarkOn",16)
Slider  (em,"Max Distance",   CFG,"MaxDist",50,1000,17)

SecLabel(ee,"ESP Color",1)
Dropdown(ee,"Color Mode",CFG,"ColorMode",{"Custom","Team","Distance","Health","Rainbow"},2)
ColorSwatches(ee,"Custom Color",CFG,"CustomColor",3)

SecLabel(ee,"Chams",4)
Checkbox(ee,"Enable Chams",   CFG,"Chams",    5,function() RefreshChams() end)
Checkbox(ee,"Through Walls",  CFG,"ChamsWall",6,function() RefreshChams() end)
Dropdown(ee,"Chams Style",    CFG,"ChamsMode",{"Flat","Neon","Wireframe","Team","Rainbow","Xray"},7,function() RefreshChams() end)
Slider  (ee,"Fill Alpha",     CFG,"ChamsFill",0,10,8,function(v) CFG.ChamsFill=v/10 RefreshChams() end)
Slider  (ee,"Outline Alpha",  CFG,"ChamsOut",0,10,9,function(v) CFG.ChamsOut=v/10 RefreshChams() end)
ColorSwatches(ee,"Chams Fill", CFG,"ChamsFillColor",10,function() RefreshChams() end)
ColorSwatches(ee,"Chams Outline",CFG,"ChamsOutColor",11,function() RefreshChams() end)

-- ══════════════════════════════════════
-- TABS (sidebar, Neverlose style)
-- ══════════════════════════════════════
local tabDefs={
    {name="Aimbot",icon="🎯",group="Aimbot"},
    {name="ESP",   icon="👁", group="Visuals"},
}

local lastGroup=""
for i,def in ipairs(tabDefs) do
    if def.group~=lastGroup then
        lastGroup=def.group
        N("TextLabel",{
            Text=def.group:upper(),Font=Enum.Font.GothamBold,TextSize=9,
            TextColor3=C.TextDim,BackgroundTransparency=1,
            Size=UDim2.new(1,0,0,18),TextXAlignment=Enum.TextXAlignment.Left,
            LayoutOrder=i*10-1
        },SideScroll)
    end

    local btn=N("TextButton",{
        Size=UDim2.new(1,0,0,30),BackgroundColor3=C.TabSel,
        BackgroundTransparency=1,BorderSizePixel=0,
        Text="",AutoButtonColor=false,LayoutOrder=i*10
    },SideScroll)
    Corner(5,btn)

    local accent=N("Frame",{
        Size=UDim2.new(0,3,0.55,0),Position=UDim2.new(0,0,0.225,0),
        BackgroundColor3=C.PAcc,BorderSizePixel=0,Visible=false
    },btn)
    Corner(2,accent)

    N("TextLabel",{
        Text=def.icon.."  "..def.name,Font=Enum.Font.Gotham,TextSize=12,
        TextColor3=C.Text,BackgroundTransparency=1,
        Size=UDim2.new(1,-10,1,0),Position=UDim2.new(0,10,0,0),
        TextXAlignment=Enum.TextXAlignment.Left
    },btn)

    TabBtns[def.name]={btn=btn,accent=accent}

    local function Sel()
        for _,t in pairs(TabBtns) do
            t.btn.BackgroundTransparency=1 t.accent.Visible=false
        end
        for _,pg in pairs(Pages) do pg.Visible=false end
        btn.BackgroundTransparency=0 btn.BackgroundColor3=C.TabSel
        accent.Visible=true
        if Pages[def.name] then Pages[def.name].Visible=true end
        ActiveTab=def.name
    end

    btn.MouseButton1Click:Connect(Sel)
    btn.MouseEnter:Connect(function()
        if ActiveTab~=def.name then
            TweenSvc:Create(btn,TweenInfo.new(0.1),{BackgroundTransparency=0.5,BackgroundColor3=C.TabSel}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if ActiveTab~=def.name then
            TweenSvc:Create(btn,TweenInfo.new(0.1),{BackgroundTransparency=1}):Play()
        end
    end)

    if i==1 then Sel() end
end

UIS.InputBegan:Connect(function(input)
    if input.KeyCode==Enum.KeyCode.Insert then Win.Visible=not Win.Visible end
end)

print("[ALACRITY] ready — Insert")
