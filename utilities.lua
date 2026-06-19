
local Menu = getgenv().Menu or _G.Menu

local CB_Players = game:GetService("Players")
local CB_LocalPlayer = CB_Players.LocalPlayer
local CB_Camera = workspace.CurrentCamera
local CB_UIS = game:GetService("UserInputService")
local CB_RS = game:GetService("ReplicatedStorage")
local CB_RunService = game:GetService("RunService")
local CB_Weapons = CB_RS:FindFirstChild("Weapons")

local function CB_GetMenuFlags()
    local m = Menu or getgenv().Menu or _G.Menu
    return m and m.Flags
end

local CB_Flags = setmetatable({}, {
    __index = function(_, k)
        local flags = CB_GetMenuFlags()
        return flags and flags[k]
    end,
    __newindex = function(_, k, v)
        local flags = CB_GetMenuFlags()
        if flags then
            flags[k] = v
        end
    end
})
local CB_TeamFF = false
local CB_SpreadCache = {}
local CB_LastSpreadState = false

local function CB_ApplyValue(state, name, cache, val)
    local rsWeapons = game:GetService("ReplicatedStorage"):FindFirstChild("Weapons")
    if not rsWeapons then return end
    if state then
        for _, desc in rsWeapons:GetDescendants() do
            if desc.Name == name then
                cache[desc] = { value = desc.Value }
                pcall(function() desc.Value = val end)
                for _, child in desc:GetChildren() do
                    cache[child] = { value = child.Value }
                    pcall(function() child.Value = val end)
                end
            end
        end
    else
        for _, desc in rsWeapons:GetDescendants() do
            if desc.Name == name and cache[desc] then
                pcall(function() desc.Value = cache[desc].value end)
                for _, child in desc:GetChildren() do
                    if cache[child] then
                        pcall(function() child.Value = cache[child].value end)
                    end
                end
            end
        end
    end
end

local function CB_GetWeaponCategoryByName(toolName)
    local n = string.lower(toolName or "")
    if n:find("glock") or n:find("usp") or n:find("p250") or n:find("deagle") or n:find("desert")
        or n:find("five") or n:find("tec") or n:find("dual") or n:find("cz")
        or n:find("r8") or n:find("p2000") or n:find("beretta") or n:find("pistol") then
        return "pistol"
    elseif n == "awp" or n == "scout" or n:find("ssg") or n:find("g3sg1") or n:find("scar20") then
        return "awp"
    elseif n:find("mac") or n:find("mp9") or n:find("mp7") or n:find("mp5")
        or n:find("mp") or n:find("p90") or n:find("bizon") or n:find("ump") or n:find("smg") then
        return "smg"
    end
    return "rifles"
end

local function CB_GetWeaponCategory(toolName, wep)
    toolName = toolName or (wep and wep.Name) or ""
    if not wep then
        return CB_GetWeaponCategoryByName(toolName)
    end
    if wep:FindFirstChild("Melee") then
        return "melee"
    end
    local n = string.lower(toolName)
    if n == "awp" or n == "scout" or n == "ssg08" or n == "g3sg1" or n == "scar20" then
        return "awp"
    end
    if wep:FindFirstChild("Secondary") then
        return "pistol"
    end
    if wep:FindFirstChild("RifleThing") or wep:FindFirstChild("Primary") then
        if n:find("mac") or n:find("mp9") or n:find("mp7") or n:find("mp5")
            or n:find("mp") or n:find("p90") or n:find("bizon") or n:find("ump") then
            return "smg"
        end
        return "rifles"
    end
    return CB_GetWeaponCategoryByName(toolName)
end

local CB_State = {
    alive = false,
    melee = false,
    name = "",
    prefix = "rifles",
    sniper = false,
    silentAim = false,
    FOV = 0,
    silentFOV = 0,
    smoothness = 1,
    deadzone = 0,
    baim = false,
    trigger = false,
    triggerDelay = 0,
}
getgenv().CB_State = CB_State

getgenv().CB_ChamsAnimations = {
    ["None"] = "",
    ["Webbed"] = "rbxassetid://2179243880",
    ["Pixelated"] = "rbxassetid://140652787",
    ["Swirl"] = "rbxassetid://8133639623",
    ["Shield"] = "rbxassetid://361073795",
    ["Bubbles"] = "rbxassetid://1461576423",
    ["Matrix"] = "rbxassetid://10713189068",
    ["Honeycomb"] = "rbxassetid://179898251",
    ["Clouds"] = "rbxassetid://5176277457",
    ["Galaxy"] = "rbxassetid://1120738433",
    ["Stars"] = "rbxassetid://598201818",
    ["Wires"] = "rbxassetid://14127933",
    ["Camo"] = "rbxassetid://3280937154",
    ["Hexagon"] = "rbxassetid://6175083785",
    ["Particles"] = "rbxassetid://1133822388",
    ["Triangular"] = "rbxassetid://4504368932",
    ["Wall"] = "rbxassetid://4271279",
    ["Scanning"] = "rbxassetid://5843010904"
}

getgenv().CB_ChamsAnimationOptions = {
    "None", "Webbed", "Pixelated", "Swirl", "Shield", "Bubbles", "Matrix",
    "Honeycomb", "Clouds", "Galaxy", "Stars", "Wires", "Camo", "Hexagon",
    "Particles", "Triangular", "Wall", "Scanning"
}

getgenv().CB_ChamsMaterials = {
    "Highlight",
    "ForceField",
    "Neon",
    "Glass",
    "SmoothPlastic"
}

local function CB_IsAlive()
    local char = CB_LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    return hum ~= nil and hum.Health > 0
end
local CB_TeamValueCache = setmetatable({}, { __mode = "k" })

local function CB_GetTeamValue(plr)
    local cached = CB_TeamValueCache[plr]
    if cached and cached.Parent then
        return cached.Value
    end
    local teamVal
    pcall(function()
        local status = plr:FindFirstChild("Status")
        if status then
            teamVal = status:FindFirstChild("Team")
        end
    end)
    CB_TeamValueCache[plr] = teamVal
    return teamVal and teamVal.Value or ""
end

local function CB_TeamCheck(plr)
    if plr == CB_LocalPlayer then return false end
    local myTeam = CB_GetTeamValue(CB_LocalPlayer)
    local theirTeam = CB_GetTeamValue(plr)
    if myTeam ~= "" and theirTeam ~= "" then
        return myTeam ~= theirTeam
    end
    local sameTeam = false
    if plr.Team and CB_LocalPlayer.Team then
        if plr.Team == CB_LocalPlayer.Team or plr.Team.Name == CB_LocalPlayer.Team.Name then
            sameTeam = true
        end
    end
    if plr.TeamColor == CB_LocalPlayer.TeamColor then
        sameTeam = true
    end
    return not sameTeam
end

local function CB_GetNearest(fov, visOnly)
    if not CB_State.alive then return nil, math.huge end
    local bestDist = fov * 3
    local bestPlr = nil
    local cx = CB_Camera.ViewportSize.X / 2
    local cy = CB_Camera.ViewportSize.Y / 2
    for _, plr in CB_Players:GetPlayers() do
        if CB_TeamCheck(plr) and plr.Character then
            local head = plr.Character:FindFirstChild("Head")
            local hum = plr.Character:FindFirstChild("Humanoid")
            if head and hum and hum.Health > 0 then
                local sp, onScreen = CB_Camera:WorldToScreenPoint(head.Position)
                if onScreen then
                    local visible = true
                    if visOnly then
                        local ray = Ray.new(CB_Camera.CFrame.p,
                            (head.Position - CB_Camera.CFrame.p).Unit * 500)
                        local ignoreList = {CB_Camera, CB_LocalPlayer.Character}
                        if workspace:FindFirstChild("Ray_Ignore") then
                            table.insert(ignoreList, workspace.Ray_Ignore)
                        end
                        if workspace:FindFirstChild("Map") then
                            local clips = workspace.Map:FindFirstChild("Clips")
                            if clips then table.insert(ignoreList, clips) end
                        end
                        local hit = workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)
                        visible = hit ~= nil and hit:IsDescendantOf(plr.Character)
                    end
                    if visible then
                        local dist = Vector2.new(sp.X - cx, sp.Y - cy).Magnitude
                        if dist < bestDist then
                            bestDist = dist
                            bestPlr = plr
                        end
                    end
                end
            end
        end
    end
    return bestPlr, bestDist
end
getgenv().CB_GetNearest = CB_GetNearest

getgenv().CB_SilentDebug = getgenv().CB_SilentDebug or false
getgenv().target = getgenv().target or nil
getgenv().silentAimEnabled = getgenv().silentAimEnabled or false

local function CB_GetSilentTargetPart(char, hitbox)
    if hitbox == "Torso" then
        return char:FindFirstChild("HumanoidRootPart")
            or char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("Torso")
    elseif hitbox == "Nearest" then
        local parts = {"HeadHB", "Head", "UpperTorso", "Torso", "HumanoidRootPart", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}
        local bestDist = math.huge
        local cx = CB_Camera.ViewportSize.X / 2
        local cy = CB_Camera.ViewportSize.Y / 2
        local bestPart = nil
        for _, pName in parts do
            local pt = char:FindFirstChild(pName)
            if pt then
                local sp, onSc = CB_Camera:WorldToScreenPoint(pt.Position)
                if onSc then
                    local d = math.sqrt((sp.X - cx)^2 + (sp.Y - cy)^2)
                    if d < bestDist then
                        bestDist = d
                        bestPart = pt
                    end
                end
            end
        end
        return bestPart or char:FindFirstChild("HeadHB") or char:FindFirstChild("Head")
    end
    return char:FindFirstChild("HeadHB") or char:FindFirstChild("Head")
end

local function CB_GetSilentRayOrigin(fromCamera)
    if fromCamera ~= false then
        return CB_Camera.CFrame.Position
    end
    local char = CB_LocalPlayer.Character
    if char and char.PrimaryPart then
        local head = char:FindFirstChild("Head")
        return Vector3.new(char.PrimaryPart.Position.X,
            head and head.Position.Y or char.PrimaryPart.Position.Y,
            char.PrimaryPart.Position.Z
        )
    end
    return CB_Camera.CFrame.Position
end

local function CB_BuildSilentRay(targetPart, fromCamera, length)
    local targetPos = targetPart.CFrame and targetPart.CFrame.Position or targetPart.Position
    local rayOrigin = CB_GetSilentRayOrigin(fromCamera)
    local dist = (rayOrigin - targetPos).Magnitude
    local predicted = targetPos + Vector3.new(0, dist / 500, 0)
    local rayLen = length or 500
    return Ray.new(rayOrigin, (predicted - rayOrigin).Unit * rayLen), rayOrigin, predicted
end

local function CB_EncodeHitPos(pos)
    return Vector3.new(((pos.X - 156325) * 13 + 17854) * 16,
        (pos.Y + 64000) * 7 - 142657,
        (pos.Z * 9 - 47000) * 6
    )
end

local function CB_ApplySilentHitParl(args)
    local tgt = getgenv().target
    if not tgt or not tgt.Parent then return args end
    local hitPos = tgt.CFrame and tgt.CFrame.Position or tgt.Position
    args[1] = tgt
    args[2] = CB_EncodeHitPos(hitPos)
    if typeof(args[10]) == "Vector3" and typeof(args[12]) == "Vector3" then
        local dir = hitPos - args[10]
        if dir.Magnitude > 0.001 then
            args[12] = dir.Unit
        end
    end
    return args
end

local function CB_UpdateWeaponState()
    local s = CB_State
    s.alive = CB_IsAlive()
    if not s.alive then return end
    local wepFolder = CB_Weapons or CB_RS:FindFirstChild("Weapons")
    local char = CB_LocalPlayer.Character
    if not char then return end
    local toolVal = char:FindFirstChild("EquippedTool")
    local toolName = toolVal and toolVal.Value or ""
    local wep = wepFolder and wepFolder:FindFirstChild(toolName) or nil
    s.melee = wep and wep:FindFirstChild("Melee") ~= nil or false
    s.name = toolName
    s.sniper = (toolName == "AWP" or toolName == "Scout" or toolName == "SSG08" or toolName == "G3SG1")
    local prefix = CB_GetWeaponCategory(toolName, wep)
    s.prefix = prefix
    if prefix ~= s._lastPrefix and getgenv().CB_OnWeaponCategoryChanged then
        pcall(getgenv().CB_OnWeaponCategoryChanged, prefix)
    end
    s._lastPrefix = prefix

    local function pick(key) return CB_Flags[key] end
    local p = prefix .. "_"
    s.FOV = pick(p .. "fov") or pick("riflesFOV") or 100
    s.silentFOV = pick(p .. "silent_fov") or pick("riflesSilentFOV") or 100
    s.deadzone = 0
    s.baim = (pick(p .. "br_hitbox") or pick("br_hitbox")) == "Torso"
    s.silentAim = pick(p .. "silent_aim") or pick("riflesSilentAim") or false
    s.smoothness = 1
    s.trigger = pick(p .. "trigger") or pick("riflesTrigger") or false
    s.triggerDelay = pick(p .. "trigger_delay") or pick("riflesTriggerDelay") or 0
end

local CB_EasingFuncs = {
    Sine = function(t) return 1 - math.cos(t * math.pi / 2) end,
    Quad = function(t) return t * t end,
    Cubic = function(t) return t * t * t end,
    Quart = function(t) return t * t * t * t end,
    Quint = function(t) return t * t * t * t * t end,
    Exponential = function(t) return t == 0 and 0 or math.pow(2, 10 * (t - 1)) end,
    Linear = function(t) return t end,
}

local function CB_ApplyEasing(t, style, direction)
    local fn = CB_EasingFuncs[style] or CB_EasingFuncs.Linear
    if direction == "Out" then
        return 1 - fn(1 - t)
    elseif direction == "InOut" then
        if t < 0.5 then
            return fn(t * 2) / 2
        else
            return 1 - fn((1 - t) * 2) / 2
        end
    end
    return fn(t)
end

local CB_ESPObjects = {}

local function CB_GetFlag(key, default)
    local v = CB_Flags[key]
    if v == nil then return default end
    if type(v) == "table" then
        if v.Value ~= nil then return v.Value end
        if v.Get then return v:Get() end
        if v.Color then return v.Color end
        return default
    end
    return v
end

local function CB_GetFlagNumber(key, default)
    local v = tonumber(CB_GetFlag(key, default))
    if v == nil then return default end
    return v
end

local function CB_GetFlagColor(key, default)
    local v = CB_Flags[key]
    if v == nil then return default end
    if type(v) == "table" and v.Color then return v.Color end
    if typeof(v) == "Color3" then return v end
    return default
end

local function CB_GetFlagColorData(key, defaultColor, defaultTrans)
    local v = CB_Flags[key]
    if v == nil then return defaultColor, defaultTrans end
    if type(v) == "table" then
        return v.Color or defaultColor, v.Transparency ~= nil and v.Transparency or defaultTrans
    end
    if typeof(v) == "Color3" then return v, defaultTrans end
    return defaultColor, defaultTrans
end

local function CB_GetFlagColorDual(visKey, hidKey, defaultVis, defaultHid, isVis)
    if isVis then
        return CB_GetFlagColor(visKey, nil) or CB_GetFlagColor(visKey:gsub("_vis", ""), defaultVis)
    else
        return CB_GetFlagColor(hidKey, nil) or CB_GetFlagColor(hidKey:gsub("_hid", ""), defaultHid)
    end
end

local CB_SkeletonBones = {
    {"Head_Spine", "Head", "TorsoTop"},
    {"Shoulder_L", "TorsoTop", "LeftShoulder"},
    {"Shoulder_R", "TorsoTop", "RightShoulder"},
    {"Arm_L", "LeftShoulder", "LeftHand"},
    {"Arm_R", "RightShoulder", "RightHand"},
    {"Spine", "TorsoTop", "TorsoBottom"},
    {"Hip_L", "TorsoBottom", "LeftHip"},
    {"Hip_R", "TorsoBottom", "RightHip"},
    {"Leg_L", "LeftHip", "LeftFoot"},
    {"Leg_R", "RightHip", "RightFoot"},
}

local function CB_CreateESP(plr)
    local obj = {
        BoxOutline = Drawing.new("Square"),
        Box = Drawing.new("Square"),
        Fill = Drawing.new("Square"),
        NameText = Drawing.new("Text"),
        HealthOutline = Drawing.new("Square"),
        HealthFill = Drawing.new("Square"),
        DistText = Drawing.new("Text"),
        WeaponText = Drawing.new("Text"),
        FlagText = Drawing.new("Text"),
        Tracer = Drawing.new("Line"),
        TracerOutline = Drawing.new("Line"),
        BoxCorners = {},
        BoxCornersOutline = {},
        Skeleton = {},
        Bounds3D = {},
        OOVArrow = {},
        Highlight = nil,
    }
    obj.Box.Filled = false
    obj.BoxOutline.Filled = false
    obj.BoxOutline.Color = Color3.new(0, 0, 0)
    obj.Fill.Filled = true
    obj.FillLayers = {}
    for i = 1, 16 do
        local layer = Drawing.new("Square")
        layer.Filled = true
        layer.Visible = false
        obj.FillLayers[i] = layer
    end
    for _, t in {obj.NameText, obj.DistText, obj.WeaponText, obj.FlagText} do
        t.Center = true
        t.Outline = true
        t.Size = 13
    end
    obj.HealthOutline.Filled = true
    obj.HealthOutline.Color = Color3.new(0, 0, 0)
    obj.HealthFill.Filled = true
    obj.TracerOutline.Color = Color3.new(0, 0, 0)
    local cornerNames = {"TL1", "TL2", "TR1", "TR2", "BL1", "BL2", "BR1", "BR2"}
    for _, cn in cornerNames do
        obj.BoxCorners[cn] = Drawing.new("Line")
        obj.BoxCornersOutline[cn] = Drawing.new("Line")
    end
    for _, boneData in CB_SkeletonBones do
        obj.Skeleton[boneData[1]] = Drawing.new("Line")
    end
    for i = 1, 12 do
        obj.Bounds3D[i] = Drawing.new("Line")
    end
    for i = 1, 3 do
        obj.OOVArrow[i] = Drawing.new("Line")
    end
    for k, v in obj do
        if k == "Highlight" then
        elseif type(v) == "table" then
            for _, line in v do line.Visible = false end
        else
            v.Visible = false
        end
    end

    CB_ESPObjects[plr] = obj
    return obj
end

local function CB_RemoveESP(plr)
    local obj = CB_ESPObjects[plr]
    if not obj then return end
    for k, v in obj do
        if k == "Highlight" then
            pcall(function() if v then v:Destroy() end end)
        elseif type(v) == "table" then
            for _, line in v do
                pcall(function() line:Remove() end)
            end
        else
            pcall(function() v:Remove() end)
        end
    end
    CB_ESPObjects[plr] = nil
end

local function CB_HideESP(obj)
    for k, v in obj do
        if k == "Highlight" then
            pcall(function() if v then v.Enabled = false end end)
        elseif type(v) == "table" then
            for _, line in v do line.Visible = false end
        else
            v.Visible = false
        end
    end
end

local function CB_GetPartSize(part)
    local size = part.Size
    local mesh = part:FindFirstChildOfClass("SpecialMesh")
    if mesh then
        size = Vector3.new(size.X * mesh.Scale.X, size.Y * mesh.Scale.Y, size.Z * mesh.Scale.Z)
    end
    return size
end

local function CB_GetPartCorners(part)
    local cf = part.CFrame
    local s = CB_GetPartSize(part) * 0.5
    return {
        cf * Vector3.new(-s.X, -s.Y, -s.Z),
        cf * Vector3.new(s.X, -s.Y, -s.Z),
        cf * Vector3.new(-s.X, s.Y, -s.Z),
        cf * Vector3.new(s.X, s.Y, -s.Z),
        cf * Vector3.new(-s.X, -s.Y, s.Z),
        cf * Vector3.new(s.X, -s.Y, s.Z),
        cf * Vector3.new(-s.X, s.Y, s.Z),
        cf * Vector3.new(s.X, s.Y, s.Z),
    }
end

local function CB_IsBodyPart(part)
    if not part:IsA("BasePart") then return false end
    local n = part.Name
    if n == "HumanoidRootPart" or n == "FakeHead" or n == "Hitbox" then return false end
    return n == "Head"
        or n:match("Torso") or n:match("Leg") or n:match("Arm") or n:match("Hand") or n:match("Foot")
        or n:match("Upper") or n:match("Lower")
end

local function CB_ClampBoxSize(boxW, boxH, maxW, maxH)
    if boxW ~= boxW or boxH ~= boxH or boxW <= 0 or boxH <= 0 then return nil end
    boxH = math.clamp(boxH, 12, maxH or 800)
    boxW = math.clamp(boxW, 10, maxW or 600)
    return boxW, boxH
end

local function CB_ProjectOnViewportRelative(vpf, worldPos)
    local cam = vpf and vpf.CurrentCamera
    if not cam then return nil, false end
    local absSize = vpf.AbsoluteSize
    if absSize.X <= 0 or absSize.Y <= 0 then return nil, false end

    local objSpace = cam.CFrame:PointToObjectSpace(worldPos)
    if objSpace.Z >= 0 then return nil, false end

    local h = math.tan(math.rad(cam.FieldOfView) / 2)
    local aspect = absSize.X / absSize.Y
    if aspect ~= aspect or aspect == 0 then aspect = 1 end

    local ndcX = (objSpace.X / -objSpace.Z) / (h * aspect)
    local ndcY = (objSpace.Y / -objSpace.Z) / h

    return Vector2.new(absSize.X / 2 * (1 + ndcX), absSize.Y / 2 * (1 - ndcY)), true
end

local function CB_ComputePreviewBox(vpf, model)
    if not vpf or not model then return nil end
    local vpSize = vpf.AbsoluteSize
    if vpSize.X <= 0 or vpSize.Y <= 0 then return nil end

    local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model.PrimaryPart
    if not hrp then return nil end

    local topWorld, botWorld, centerWorld

    local bbOk, bbCF, bbSize = pcall(model.GetBoundingBox, model)
    if bbOk and bbCF and bbSize and bbSize.Y > 0.5 and bbSize.Y < 25 then
        topWorld = bbCF * CFrame.new(0, bbSize.Y * 0.5, 0).Position
        botWorld = bbCF * CFrame.new(0, -bbSize.Y * 0.5, 0).Position
        centerWorld = bbCF.Position
    else
        local hrpCF = hrp.CFrame
        topWorld = (hrpCF * CFrame.new(0, 3.2, 0)).Position
        botWorld = (hrpCF * CFrame.new(0, -3.6, 0)).Position
        centerWorld = hrp.Position

        local topY, botY = topWorld.Y, botWorld.Y
        for _, part in model:GetDescendants() do
            if CB_IsBodyPart(part) and part.Transparency < 1 then
                local half = CB_GetPartSize(part).Y * 0.5
                local py = part.Position.Y
                if py + half > topY then topY = py + half end
                if py - half < botY then botY = py - half end
            end
        end
        topWorld = Vector3.new(hrp.Position.X, topY, hrp.Position.Z)
        botWorld = Vector3.new(hrp.Position.X, botY, hrp.Position.Z)
    end

    local top2d, topOk = CB_ProjectOnViewportRelative(vpf, topWorld)
    local bot2d, botOk = CB_ProjectOnViewportRelative(vpf, botWorld)
    local mid2d, midOk = CB_ProjectOnViewportRelative(vpf, centerWorld)
    if not topOk or not botOk or not midOk then return nil end

    local boxH = math.abs(bot2d.Y - top2d.Y)
    local boxW = boxH * 0.65
    boxW, boxH = CB_ClampBoxSize(boxW, boxH, vpSize.X * 0.95, vpSize.Y * 0.95)
    if not boxW then return nil end

    local boxY = top2d.Y + 3
    boxH = boxH + 4

    return mid2d.X - boxW / 2, boxY, boxW, boxH
end

local function CB_ComputeCharacterScreenBox(char, projectFn, widthRatio)
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local head = char:FindFirstChild("Head")

    local topWorld = head and (head.Position + Vector3.new(0, 0.5, 0)) or (root.CFrame * CFrame.new(0, 2.45, 0)).Position
    local footY = (root.CFrame * CFrame.new(0, -3.1, 0)).Position.Y

    local function checkFoot(partName)
        local p = char:FindFirstChild(partName)
        if p and p:IsA("BasePart") then
            local bottom = p.Position.Y - CB_GetPartSize(p).Y / 2
            if bottom < footY then footY = bottom end
        end
    end
    checkFoot("LeftFoot")
    checkFoot("RightFoot")
    checkFoot("Left Leg")
    checkFoot("Right Leg")
    checkFoot("LeftLowerLeg")
    checkFoot("RightLowerLeg")

    local footWorld = Vector3.new(root.Position.X, footY, root.Position.Z)
    local headSp, headOk = projectFn(topWorld)
    local footSp, footOk = projectFn(footWorld)
    local rootSp, rootOk = projectFn(root.Position)
    if not headOk or not footOk or not rootOk then return nil end

    local boxH = math.abs(footSp.Y - headSp.Y)
    local boxW = boxH * (widthRatio or 0.55)
    boxW, boxH = CB_ClampBoxSize(boxW, boxH, CB_Camera.ViewportSize.X, CB_Camera.ViewportSize.Y)
    if not boxW then return nil end

    return rootSp.X - boxW / 2, headSp.Y, boxW, boxH
end

local function CB_WorldToScreen(pos)
    local sp, onScreen = CB_Camera:WorldToViewportPoint(pos)
    return Vector2.new(sp.X, sp.Y), onScreen, sp.Z
end
local CB_VisParams = RaycastParams.new()
CB_VisParams.FilterType = Enum.RaycastFilterType.Exclude
local CB_VisFilter = {}
local CB_VisFilterTick = 0

local function CB_RefreshVisFilter()
    local now = os.clock()
    if now - CB_VisFilterTick < 0.5 and #CB_VisFilter > 0 then return end
    CB_VisFilterTick = now
    table.clear(CB_VisFilter)
    CB_VisFilter[#CB_VisFilter + 1] = CB_Camera
    if CB_LocalPlayer.Character then
        CB_VisFilter[#CB_VisFilter + 1] = CB_LocalPlayer.Character
    end
    local rayIgnore = workspace:FindFirstChild("Ray_Ignore")
    if rayIgnore then CB_VisFilter[#CB_VisFilter + 1] = rayIgnore end
    local map = workspace:FindFirstChild("Map")
    if map then
        local clips = map:FindFirstChild("Clips")
        if clips then CB_VisFilter[#CB_VisFilter + 1] = clips end
    end
    CB_VisParams.FilterDescendantsInstances = CB_VisFilter
end

local function CB_VisCheck(origin, target, ignorePlr)
    local ok, result = pcall(function()
        CB_RefreshVisFilter()
        local dir = target - origin
        local hit = workspace:Raycast(origin, dir, CB_VisParams)
        if not hit then return true end
        return hit.Instance:IsDescendantOf(ignorePlr.Character)
    end)
    return ok and result or false
end

local function CB_RestoreMaterials(char)
    if not char then return end
    for _, child in char:GetDescendants() do
        if child:IsA("BasePart") then
            local origMat = child:GetAttribute("OrigMat")
            local origColor = child:GetAttribute("OrigColor")
            if origMat then child.Material = origMat end
            if origColor then child.Color = origColor end
            child:SetAttribute("OrigMat", nil)
            child:SetAttribute("OrigColor", nil)
            local chamsMesh = child:FindFirstChild("ChamsMesh")
            if chamsMesh then chamsMesh:Destroy() end
        end
    end
end

local function CB_GetESPPrefix(plr)
    if plr == CB_LocalPlayer then
        return "esp_local_", true
    end
    local isEnemy = CB_TeamCheck(plr)
    if isEnemy then
        return "esp_enemies_", false
    else
        return "esp_friendlies_", false
    end
end

local function CB_GetESPFlagP(prefix, flagName, default)
    return CB_GetFlag(prefix .. flagName, default)
end

local function CB_GetESPFlagColorP(prefix, flagName, default)
    return CB_GetFlagColor(prefix .. flagName, default)
end

local function CB_GetESPFlagColorDualP(prefix, flagNameVis, flagNameHid, defaultVis, defaultHid, isVis)
    return CB_GetFlagColorDual(prefix .. flagNameVis, prefix .. flagNameHid, defaultVis, defaultHid, isVis)
end
local function CB_GetESPFlag(plr, flagName, default)
    local prefix = CB_GetESPPrefix(plr)
    return CB_GetFlag(prefix .. flagName, default)
end

local function CB_GetESPFlagColor(plr, flagName, default)
    local prefix = CB_GetESPPrefix(plr)
    return CB_GetFlagColor(prefix .. flagName, default)
end

local function CB_GetESPFlagColorDual(plr, flagNameVis, flagNameHid, defaultVis, defaultHid, isVis)
    local prefix = CB_GetESPPrefix(plr)
    return CB_GetFlagColorDual(prefix .. flagNameVis, prefix .. flagNameHid, defaultVis, defaultHid, isVis)
end

local function CB_GetFontIndex(fontName)
    if fontName == "Tahoma" then
        return 0
    elseif fontName == "System" or fontName == "SmallestPixel" then
        return 1
    elseif fontName == "Minecraftia" or fontName == "Plex" then
        return 2
    elseif fontName == "Consolas" then
        return 3
    end
    return 1
end

local function CB_UpdateESP()
    if not (CB_GetFlag("esp_enemies_enable", false)
        or CB_GetFlag("esp_friendlies_enable", false)) then
        for _, obj in CB_ESPObjects do
            CB_HideESP(obj)
        end
        return
    end

    local maxDist = CB_GetFlag("esp_maxdist", 1000)
    local vpSize = CB_Camera.ViewportSize
    local camPos = CB_Camera.CFrame.Position

    for _, plr in CB_Players:GetPlayers() do
        local obj = CB_ESPObjects[plr]
        if not obj then obj = CB_CreateESP(plr) end
        local prefix, isLocal = CB_GetESPPrefix(plr)
        local espEnabled = CB_GetFlag(prefix .. "enable", false)
        if not espEnabled then
            CB_HideESP(obj)
            continue
        end

        local char = plr.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        local hum = char and char:FindFirstChildWhichIsA("Humanoid")

        if not root or not head or not hum or hum.Health <= 0 then
            CB_HideESP(obj)
            continue
        end

        local dist3D = (camPos - root.Position).Magnitude
        if dist3D > maxDist then CB_HideESP(obj); continue end
        local checks = CB_GetFlag(prefix .. "checks", CB_GetFlag("esp_checks", "None"))
        local isVis = false
        if not getgenv().CB_VisCache then getgenv().CB_VisCache = {} end
        local visCache = getgenv().CB_VisCache
        local now = os.clock()
        local vData = visCache[plr]
        if not vData or (now - vData.time > 0.05) then
            vData = {time = now, isVis = CB_VisCheck(camPos, head.Position, plr)}
            visCache[plr] = vData
        end
        isVis = vData.isVis

        if (checks == "Visible" or checks == "Visible, Team") and not isVis then
            CB_HideESP(obj)
            continue
        end
        local is2D = CB_GetFlag(prefix .. "2d", true)
        local boxEnabled = CB_GetFlag(prefix .. "box_enabled", true)
        local boxMode = CB_GetFlag(prefix .. "box_mode", "Box")
        local thickness = CB_GetFlag(prefix .. "thickness", 1)
        local outThick = CB_GetFlag(prefix .. "outline_thick", 1)

        local showFill = CB_GetFlag(prefix .. "fill", false)
        local showName = CB_GetFlag(prefix .. "names", false)
        local showHealth = CB_GetFlag(prefix .. "health", false)
        local showDist = CB_GetFlag(prefix .. "distance", false)
        local showWeapon = CB_GetFlag(prefix .. "weapon", false)
        local showFlags = CB_GetFlag(prefix .. "flags", false)
        local showTracer = CB_GetFlag(prefix .. "tracers", false)
        local showSkel = CB_GetFlag(prefix .. "skeleton", false)
        local skelThick = CB_GetFlag(prefix .. "skel_thick", 1)
        local tracerOrig = CB_GetFlag(prefix .. "tracer_origin", "Bottom")

        local show3D = CB_GetFlag(prefix .. "3d", false)
        local showBounds3D = CB_GetFlag(prefix .. "3d_bounds", false)
        local showChams = CB_GetFlag(prefix .. "chams_enabled", false)
        local chamsMat = CB_GetFlag(prefix .. "chams_mat", "Highlight")
        local chamsTex = CB_GetFlag(prefix .. "chams_tex", "None")
        local showOOV = CB_GetFlag(prefix .. "oov", false)

        local chamsColorVis = CB_GetFlagColor(prefix .. "chams_color_vis", Color3.fromRGB(255, 255, 255))
        local chamsColorHid = CB_GetFlagColor(prefix .. "chams_color_hid", Color3.fromRGB(255, 100, 100))
        local chamsFillTrans = (CB_GetFlag(prefix .. "chams_fill_trans", 50)) / 100
        local chamsOutTrans = (CB_GetFlag(prefix .. "chams_out_trans", 0)) / 100
        local chamsColorOut = CB_GetFlagColor(prefix .. "chams_color_out", Color3.fromRGB(0, 0, 0))

        local boxColor = CB_GetFlagColorDual(prefix .. "box_color_vis", prefix .. "box_color_hid", Color3.new(1,1,1), Color3.new(1,0,0), isVis)
        local fillColor = CB_GetFlagColorDual(prefix .. "fill_color_vis", prefix .. "fill_color_hid", Color3.fromRGB(255,255,255), Color3.fromRGB(255,100,100), isVis)
        local nameColor = CB_GetFlagColorDual(prefix .. "name_color_vis", prefix .. "name_color_hid", Color3.new(1,1,1), Color3.new(1,0,0), isVis)
        local distColor = CB_GetFlagColorDual(prefix .. "dist_color_vis", prefix .. "dist_color_hid", Color3.new(1,1,1), Color3.new(1,0,0), isVis)
        local weaponColor = CB_GetFlagColorDual(prefix .. "weapon_color_vis", prefix .. "weapon_color_hid", Color3.new(1,1,1), Color3.new(1,0,0), isVis)
        local tracerColor = CB_GetFlagColorDual(prefix .. "tracer_color_vis", prefix .. "tracer_color_hid", Color3.new(1,1,1), Color3.new(1,0,0), isVis)
        local skelColor = CB_GetFlagColorDual(prefix .. "skel_color_vis", prefix .. "skel_color_hid", Color3.new(1,1,1), Color3.new(1,0,0), isVis)
        local healthColor = CB_GetFlagColorDual(prefix .. "health_color_vis", prefix .. "health_color_hid", Color3.new(0,1,0), Color3.new(0,0.6,0), isVis)
        local outlineColor = Color3.fromRGB(0, 0, 0)

        local rootPos, onScreen, depth = CB_WorldToScreen(root.Position)

        if not onScreen then
            for k, v in obj do
                if k == "Highlight" then
                    pcall(function() if v then v.Enabled = false end end)
                elseif k ~= "OOVArrow" then
                    if type(v) == "table" then
                        for _, line in v do line.Visible = false end
                    else
                        v.Visible = false
                    end
                end
            end

            if showOOV then
                local camCF = CB_Camera.CFrame
                local lookVector = (root.Position - camCF.Position).Unit
                local x = lookVector:Dot(camCF.RightVector)
                local y = lookVector:Dot(camCF.UpVector)
                local dir = Vector2.new(x, -y)
                if dir.Magnitude < 0.001 then
                    dir = Vector2.new(0, 1)
                else
                    dir = dir.Unit
                end

                local screenCenter = CB_Camera.ViewportSize / 2
                local radius = CB_GetFlag(prefix .. "oov_dist", 200)
                local arrowSize = CB_GetFlag(prefix .. "oov_size", 20)
                local oovColor = CB_GetFlagColorDual(prefix .. "oov_color_vis", prefix .. "oov_color_hid", Color3.new(1, 1, 1), Color3.new(1, 0, 0), isVis)

                local arrowPos = screenCenter + dir * radius
                local leftDir = Vector2.new(-dir.Y, dir.X)
                local pointTip = arrowPos + dir * (arrowSize * 0.5)
                local pointLeft = arrowPos - dir * (arrowSize * 0.5) + leftDir * (arrowSize * 0.3)
                local pointRight = arrowPos - dir * (arrowSize * 0.5) - leftDir * (arrowSize * 0.3)

                local lines = obj.OOVArrow
                lines[1].Visible = true
                lines[1].From = pointLeft
                lines[1].To = pointTip
                lines[1].Color = oovColor
                lines[1].Thickness = 1.5

                lines[2].Visible = true
                lines[2].From = pointTip
                lines[2].To = pointRight
                lines[2].Color = oovColor
                lines[2].Thickness = 1.5

                lines[3].Visible = true
                lines[3].From = pointRight
                lines[3].To = pointLeft
                lines[3].Color = oovColor
                lines[3].Thickness = 1.5
            else
                for _, line in obj.OOVArrow do line.Visible = false end
            end
            continue
        end

        for _, line in obj.OOVArrow do line.Visible = false end

        local boxX, boxY, boxW, boxH = CB_ComputeCharacterScreenBox(char, function(pos)
            local sp, _, z = CB_WorldToScreen(pos)
            return Vector2.new(sp.X, sp.Y), z > 0
        end, 0.55)

        if not boxX then
            CB_HideESP(obj)
            continue
        end

        if is2D and boxEnabled and boxMode ~= "None" then
            if boxMode == "Box" then
                for _, line in obj.BoxCorners do line.Visible = false end
                for _, line in obj.BoxCornersOutline do line.Visible = false end

                obj.BoxOutline.Visible = outThick > 0
                obj.BoxOutline.Size = Vector2.new(boxW + 2, boxH + 2)
                obj.BoxOutline.Position = Vector2.new(boxX - 1, boxY - 1)
                obj.BoxOutline.Thickness = thickness + outThick * 2
                obj.BoxOutline.Color = outlineColor

                obj.Box.Visible = true
                obj.Box.Size = Vector2.new(boxW, boxH)
                obj.Box.Position = Vector2.new(boxX, boxY)
                obj.Box.Thickness = thickness
                obj.Box.Color = boxColor
            elseif boxMode == "Corner" then
                obj.Box.Visible = false
                obj.BoxOutline.Visible = false

                local xSize = CB_GetFlag(prefix .. "xsize", 10)
                local ySize = CB_GetFlag(prefix .. "ysize", 10)

                xSize = math.min(xSize, boxW / 2)
                ySize = math.min(ySize, boxH / 2)

                local Corners = {
                    TL1 = {From = Vector2.new(boxX, boxY), To = Vector2.new(boxX + xSize, boxY)},
                    TL2 = {From = Vector2.new(boxX, boxY), To = Vector2.new(boxX, boxY + ySize)},

                    TR1 = {From = Vector2.new(boxX + boxW, boxY), To = Vector2.new(boxX + boxW - xSize, boxY)},
                    TR2 = {From = Vector2.new(boxX + boxW, boxY), To = Vector2.new(boxX + boxW, boxY + ySize)},

                    BL1 = {From = Vector2.new(boxX, boxY + boxH), To = Vector2.new(boxX + xSize, boxY + boxH)},
                    BL2 = {From = Vector2.new(boxX, boxY + boxH), To = Vector2.new(boxX, boxY + boxH - ySize)},

                    BR1 = {From = Vector2.new(boxX + boxW, boxY + boxH), To = Vector2.new(boxX + boxW - xSize, boxY + boxH)},
                    BR2 = {From = Vector2.new(boxX + boxW, boxY + boxH), To = Vector2.new(boxX + boxW, boxY + boxH - ySize)},
                }

                for cn, pts in Corners do
                    local line = obj.BoxCorners[cn]
                    local outline = obj.BoxCornersOutline[cn]
                    if line and outline then
                        outline.Visible = outThick > 0
                        outline.From = pts.From
                        outline.To = pts.To
                        outline.Thickness = thickness + outThick * 2
                        outline.Color = outlineColor

                        line.Visible = true
                        line.From = pts.From
                        line.To = pts.To
                        line.Thickness = thickness
                        line.Color = boxColor
                    end
                end
            end
        else
            obj.Box.Visible = false
            obj.BoxOutline.Visible = false
            for _, line in obj.BoxCorners do line.Visible = false end
            for _, line in obj.BoxCornersOutline do line.Visible = false end
        end

        if showFill and is2D and obj.FillLayers then
            obj.Fill.Visible = false
            local fillColor1, fillTrans1 = CB_GetFlagColorData(prefix .. "fill_color_vis", Color3.fromRGB(255, 156, 156), 0.5)
            local fillColor2, fillTrans2 = CB_GetFlagColorData(prefix .. "fill_color_hid", Color3.fromRGB(255, 100, 100), 1)
            local innerW = math.max(boxW - 2, 1)
            local innerH = math.max(boxH - 2, 1)
            local layers = #obj.FillLayers
            local stripH = innerH / layers
            for i = 1, layers do
                local t = (i - 0.5) / layers
                local layer = obj.FillLayers[i]
                layer.Visible = true
                layer.Size = Vector2.new(innerW, math.max(stripH, 1))
                layer.Position = Vector2.new(boxX + 1, boxY + 1 + (i - 1) * stripH)
                layer.Color = fillColor1:Lerp(fillColor2, t)
                layer.Transparency = fillTrans1 + (fillTrans2 - fillTrans1) * t
            end
        else
            obj.Fill.Visible = false
            if obj.FillLayers then
                for _, layer in obj.FillLayers do layer.Visible = false end
            end
        end

        local topOffset = 16
        local bottomOffset = 2
        local leftOffset = 6
        local rightOffset = 6

        local function CB_PositionText(textObj, side, size, textString)
            local textW = textObj.TextBounds and textObj.TextBounds.X or (#textString * 6)

            if side == "Top" then
                textObj.Center = true
                textObj.Position = Vector2.new(rootPos.X, boxY - topOffset)
                topOffset = topOffset + size + 2
            elseif side == "Bottom" then
                textObj.Center = true
                textObj.Position = Vector2.new(rootPos.X, boxY + boxH + bottomOffset)
                bottomOffset = bottomOffset + size + 2
            elseif side == "Left" then
                textObj.Center = false
                textObj.Position = Vector2.new(boxX - leftOffset - textW, boxY + leftOffset - 6)
                leftOffset = leftOffset + size + 2
            elseif side == "Right" then
                textObj.Center = false
                textObj.Position = Vector2.new(boxX + boxW + rightOffset, boxY + rightOffset - 6)
                rightOffset = rightOffset + size + 2
            end
        end

        if showName then
            local text = plr.DisplayName or plr.Name
            local fontName = CB_GetFlag(prefix .. "names_font", "SmallestPixel")
            local size = CB_GetFlag(prefix .. "names_size", 9)
            local thicknessVal = CB_GetFlag(prefix .. "names_outline_thick", 1)
            local pos = CB_GetFlag(prefix .. "names_pos", "Top")

            obj.NameText.Visible = true
            obj.NameText.Text = text
            obj.NameText.Color = nameColor
            obj.NameText.Size = size
            obj.NameText.Font = CB_GetFontIndex(fontName)
            obj.NameText.Outline = thicknessVal > 0
            obj.NameText.OutlineColor = outlineColor

            CB_PositionText(obj.NameText, pos, size, text)
        else
            obj.NameText.Visible = false
        end

        if showHealth then
            local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local barH = boxH
            local barX = boxX - 6

            obj.HealthOutline.Visible = true
            obj.HealthOutline.Size = Vector2.new(3, barH + 2)
            obj.HealthOutline.Position = Vector2.new(barX - 1, boxY - 1)

            obj.HealthFill.Visible = true
            obj.HealthFill.Size = Vector2.new(1, math.floor(barH * hp))
            obj.HealthFill.Position = Vector2.new(barX, boxY + barH - math.floor(barH * hp))
            obj.HealthFill.Color = healthColor
        else
            obj.HealthOutline.Visible = false
            obj.HealthFill.Visible = false
        end

        if showDist then
            local text = math.floor(dist3D) .. "m"
            local fontName = CB_GetFlag(prefix .. "dist_font", "SmallestPixel")
            local size = CB_GetFlag(prefix .. "dist_size", 10)
            local thicknessVal = CB_GetFlag(prefix .. "dist_outline_thick", 1)
            local pos = CB_GetFlag(prefix .. "dist_pos", "Bottom")

            obj.DistText.Visible = true
            obj.DistText.Text = text
            obj.DistText.Color = distColor
            obj.DistText.Size = size
            obj.DistText.Font = CB_GetFontIndex(fontName)
            obj.DistText.Outline = thicknessVal > 0
            obj.DistText.OutlineColor = outlineColor

            CB_PositionText(obj.DistText, pos, size, text)
        else
            obj.DistText.Visible = false
        end

        if showWeapon then
            local toolVal = char:FindFirstChild("EquippedTool")
            local wepName = toolVal and tostring(toolVal.Value) or ""

            if wepName ~= "" then
                local fontName = CB_GetFlag(prefix .. "weapon_font", "SmallestPixel")
                local size = CB_GetFlag(prefix .. "weapon_size", 10)
                local thicknessVal = CB_GetFlag(prefix .. "weapon_outline_thick", 1)
                local pos = CB_GetFlag(prefix .. "weapon_pos", "Bottom")

                obj.WeaponText.Visible = true
                obj.WeaponText.Text = wepName
                obj.WeaponText.Color = weaponColor
                obj.WeaponText.Size = size
                obj.WeaponText.Font = CB_GetFontIndex(fontName)
                obj.WeaponText.Outline = thicknessVal > 0
                obj.WeaponText.OutlineColor = outlineColor

                CB_PositionText(obj.WeaponText, pos, size, wepName)
            else
                obj.WeaponText.Visible = false
            end
        else
            obj.WeaponText.Visible = false
        end

        if showFlags then
            local flagLines = {}
            if hum.Health < 30 then table.insert(flagLines, "LOW HP") end
            if char:FindFirstChild("C4") then table.insert(flagLines, "C4") end

            local flagTextString = table.concat(flagLines, " | ")
            if flagTextString ~= "" then
                local fontName = CB_GetFlag(prefix .. "flags_font", "SmallestPixel")
                local size = CB_GetFlag(prefix .. "flags_size", 8)
                local thicknessVal = CB_GetFlag(prefix .. "flags_outline_thick", 1)
                local pos = CB_GetFlag(prefix .. "flags_pos", "Right")

                obj.FlagText.Visible = true
                obj.FlagText.Text = flagTextString
                obj.FlagText.Color = Color3.fromRGB(255, 255, 255)
                obj.FlagText.Size = size
                obj.FlagText.Font = CB_GetFontIndex(fontName)
                obj.FlagText.Outline = thicknessVal > 0
                obj.FlagText.OutlineColor = outlineColor

                CB_PositionText(obj.FlagText, pos, size, flagTextString)
            else
                obj.FlagText.Visible = false
            end
        else
            obj.FlagText.Visible = false
        end

        if showTracer then
            local fromY = vpSize.Y
            local fromX = vpSize.X / 2
            if tracerOrig == "Top" then fromY = 0
            elseif tracerOrig == "Center" then fromY = vpSize.Y / 2
            elseif tracerOrig == "Cursor" then
                local mPos = CB_UIS:GetMouseLocation()
                fromX = mPos.X; fromY = mPos.Y
            end

            local toY = boxY + boxH
            local tTarget = CB_GetFlag(prefix .. "tracer_target", "Bottom")
            if tTarget == "Top" then
                toY = boxY
            elseif tTarget == "Center" then
                toY = boxY + (boxH / 2)
            end

            obj.TracerOutline.Visible = outThick > 0
            obj.TracerOutline.From = Vector2.new(fromX, fromY)
            obj.TracerOutline.To = Vector2.new(rootPos.X, toY)
            obj.TracerOutline.Thickness = thickness + 2

            obj.Tracer.Visible = true
            obj.Tracer.From = Vector2.new(fromX, fromY)
            obj.Tracer.To = Vector2.new(rootPos.X, toY)
            obj.Tracer.Thickness = thickness
            obj.Tracer.Color = tracerColor
        else
            obj.Tracer.Visible = false
            obj.TracerOutline.Visible = false
        end

        if showSkel then
            local isR15 = char:FindFirstChild("UpperTorso") ~= nil
            local torso = isR15 and char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
            local lowerTorso = isR15 and char:FindFirstChild("LowerTorso") or torso
            local headJoint = char:FindFirstChild("Head")
            local lArm = isR15 and char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("Left Arm")
            local rArm = isR15 and char:FindFirstChild("RightUpperArm") or char:FindFirstChild("Right Arm")
            local lLeg = isR15 and char:FindFirstChild("LeftUpperLeg") or char:FindFirstChild("Left Leg")
            local rLeg = isR15 and char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg")

            local lHand = isR15 and char:FindFirstChild("LeftHand") or lArm
            local rHand = isR15 and char:FindFirstChild("RightHand") or rArm
            local lFoot = isR15 and char:FindFirstChild("LeftFoot") or lLeg
            local rFoot = isR15 and char:FindFirstChild("RightFoot") or rLeg

            if torso and lowerTorso and headJoint and lArm and rArm and lLeg and rLeg then
                local Joints = {
                    Head = headJoint.Position,
                    TorsoTop = torso.Position + Vector3.new(0, torso.Size.Y / 2, 0),
                    TorsoBottom = lowerTorso.Position - Vector3.new(0, lowerTorso.Size.Y / 2, 0),
                    LeftShoulder= lArm.Position + Vector3.new(0, lArm.Size.Y / 2, 0),
                    LeftHand = lHand.Position - Vector3.new(0, lHand.Size.Y / 2, 0),
                    RightShoulder= rArm.Position + Vector3.new(0, rArm.Size.Y / 2, 0),
                    RightHand = rHand.Position - Vector3.new(0, rHand.Size.Y / 2, 0),
                    LeftHip = lLeg.Position + Vector3.new(0, lLeg.Size.Y / 2, 0),
                    LeftFoot = lFoot.Position - Vector3.new(0, lFoot.Size.Y / 2, 0),
                    RightHip = rLeg.Position + Vector3.new(0, rLeg.Size.Y / 2, 0),
                    RightFoot = rFoot.Position - Vector3.new(0, rFoot.Size.Y / 2, 0),
                }
                for _, boneData in CB_SkeletonBones do
                    local boneName, startJoint, endJoint = boneData[1], boneData[2], boneData[3]
                    local line = obj.Skeleton[boneName]
                    if line then
                        local posA = Joints[startJoint]
                        local posB = Joints[endJoint]
                        if posA and posB then
                            local sA, onA = CB_WorldToScreen(posA)
                            local sB, onB = CB_WorldToScreen(posB)
                            if onA and onB then
                                line.Visible = true
                                line.From = sA
                                line.To = sB
                                line.Thickness = skelThick
                                line.Color = skelColor
                            else
                                line.Visible = false
                            end
                        else
                            line.Visible = false
                        end
                    end
                end
            else
                for _, line in obj.Skeleton do line.Visible = false end
            end
        else
            for _, line in obj.Skeleton do line.Visible = false end
        end
        if show3D and showBounds3D then
            local sizeX, sizeY, sizeZ = 2, 3.25, 1.2
            local cf = root.CFrame

            local corners = {
                cf * Vector3.new(-sizeX, sizeY, -sizeZ),
                cf * Vector3.new(sizeX, sizeY, -sizeZ),
                cf * Vector3.new(sizeX, sizeY, sizeZ),
                cf * Vector3.new(-sizeX, sizeY, sizeZ),
                cf * Vector3.new(-sizeX, -sizeY, -sizeZ),
                cf * Vector3.new(sizeX, -sizeY, -sizeZ),
                cf * Vector3.new(sizeX, -sizeY, sizeZ),
                cf * Vector3.new(-sizeX, -sizeY, sizeZ),
            }

            local proj = {}
            local allOnScreen = true
            for i = 1, 8 do
                local p2d, onScr, zDepth = CB_WorldToScreen(corners[i])
                proj[i] = p2d
                if zDepth <= 0 then
                    allOnScreen = false
                    break
                end
            end

            if allOnScreen then
                local edges = {
                    {1, 2}, {2, 3}, {3, 4}, {4, 1},
                    {5, 6}, {6, 7}, {7, 8}, {8, 5},
                    {1, 5}, {2, 6}, {3, 7}, {4, 8}
                }

                for idx, edge in edges do
                    local line = obj.Bounds3D[idx]
                    if line then
                        line.Visible = true
                        line.From = proj[edge[1]]
                        line.To = proj[edge[2]]
                        line.Thickness = thickness
                        line.Color = boxColor
                    end
                end
            else
                for _, line in obj.Bounds3D do line.Visible = false end
            end
        else
            for _, line in obj.Bounds3D do line.Visible = false end
        end
        if show3D and showChams then
            local currentChamsColor = chamsColorVis
            if obj.Highlight then
                obj.Highlight.Enabled = false
            end

            if not obj.ChamsActive or obj.LastChamsColor ~= currentChamsColor then
                obj.ChamsActive = true
                obj.LastChamsColor = currentChamsColor
                for _, child in char:GetDescendants() do
                    if child:IsA("BasePart") and child.Transparency < 1 then
                        if not child:GetAttribute("OrigMat") then
                            child:SetAttribute("OrigMat", child.Material.Value)
                            child:SetAttribute("OrigColor", child.Color)
                        end

                        child.Material = Enum.Material.ForceField
                        child.Color = currentChamsColor

                        local chamsMesh = child:FindFirstChild("ChamsMesh")
                        if chamsMesh then chamsMesh:Destroy() end
                    end
                end
            end
        else
            if obj.ChamsActive then
                obj.ChamsActive = false
                CB_RestoreMaterials(char)
            end
            if obj.Highlight then
                obj.Highlight.Enabled = false
            end
        end
    end
    for plr, _ in CB_ESPObjects do
        if not plr.Parent then CB_RemoveESP(plr) end
    end
end
CB_Players.PlayerRemoving:Connect(function(plr)
    CB_RemoveESP(plr)
    CB_TeamValueCache[plr] = nil
end)

local CB_PreviewESPStore = {}

local function CB_GetPreviewOverlay(vpf)
    local overlay = vpf:FindFirstChild("CB_ESPOverlay")
    if not overlay then
        overlay = Instance.new("Frame")
        overlay.Name = "CB_ESPOverlay"
        overlay.BackgroundTransparency = 1
        overlay.Size = UDim2.fromScale(1, 1)
        overlay.Position = UDim2.fromOffset(0, 0)
        overlay.BorderSizePixel = 0
        overlay.ClipsDescendants = true
        overlay.Active = false
        overlay.ZIndex = (vpf.ZIndex or 1) + 7
        overlay.Parent = vpf
    end
    return overlay
end

local function CB_MakePreviewLabel(parent, z)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.BorderSizePixel = 0
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.Visible = false
    lbl.ZIndex = z
    lbl.Parent = parent
    Instance.new("UIStroke", lbl)
    return lbl
end

local function CB_GetPreviewUI(id, vpf)
    local existing = CB_PreviewESPStore[id]
    if existing then
        if existing.fill and existing.fill.Parent ~= existing.box then
            pcall(function() existing.overlay:Destroy() end)
            CB_PreviewESPStore[id] = nil
        else
            return existing
        end
    end

    local overlay = CB_GetPreviewOverlay(vpf)
    local baseZ = overlay.ZIndex

    local box = Instance.new("Frame")
    box.Name = "Box"
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.ClipsDescendants = true
    box.Visible = false
    box.ZIndex = baseZ + 2
    box.Parent = overlay
    local boxStroke = Instance.new("UIStroke")
    boxStroke.Color = Color3.new(1, 1, 1)
    boxStroke.Thickness = 1
    boxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    boxStroke.Parent = box

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.BorderSizePixel = 0
    fill.Visible = false
    fill.ZIndex = baseZ + 1
    fill.Position = UDim2.fromOffset(1, 1)
    fill.Size = UDim2.new(1, -2, 1, -2)
    fill.Parent = box
    local fillGrad = Instance.new("UIGradient")
    fillGrad.Rotation = -90
    fillGrad.Parent = fill

    local healthBg = Instance.new("Frame")
    healthBg.Name = "HealthBg"
    healthBg.BackgroundColor3 = Color3.new(0, 0, 0)
    healthBg.BorderSizePixel = 0
    healthBg.Visible = false
    healthBg.ZIndex = baseZ + 3
    healthBg.Parent = overlay
    local healthFill = Instance.new("Frame")
    healthFill.Name = "HealthFill"
    healthFill.BorderSizePixel = 0
    healthFill.Visible = false
    healthFill.ZIndex = baseZ + 4
    healthFill.Parent = healthBg

    local ui = {
        overlay = overlay,
        fill = fill,
        fillGrad = fillGrad,
        box = box,
        boxStroke = boxStroke,
        healthBg = healthBg,
        healthFill = healthFill,
        name = CB_MakePreviewLabel(overlay, baseZ + 5),
        dist = CB_MakePreviewLabel(overlay, baseZ + 5),
        weapon = CB_MakePreviewLabel(overlay, baseZ + 5),
        flag = CB_MakePreviewLabel(overlay, baseZ + 5),
        OrigProps = {},
    }
    ui.name.Text = "Enemy"
    ui.dist.Text = "[8m]"
    ui.weapon.Text = "AK-47"
    ui.flag.Text = "C4"
    ui.flag.TextXAlignment = Enum.TextXAlignment.Left
    ui.flag.Size = UDim2.fromOffset(40, 14)

    CB_PreviewESPStore[id] = ui
    return ui
end

local function CB_HidePreviewESP(obj)
    if not obj then return end
    if obj.box then obj.box.Visible = false end
    if obj.fill then obj.fill.Visible = false end
    if obj.healthBg then obj.healthBg.Visible = false end
    if obj.healthFill then obj.healthFill.Visible = false end
    for _, key in {"name", "dist", "weapon", "flag"} do
        if obj[key] then obj[key].Visible = false end
    end
    if obj.OrigProps then
        for child, props in obj.OrigProps do
            if child.Parent then
                child.Color = props.Color
                child.Material = props.Material
            end
        end
        table.clear(obj.OrigProps)
    end
end

function CB_UpdatePreviewESP()
    local targets = getgenv().CB_PreviewTargets
    if not targets then return end
    local activeIds = {}

    for _, target in targets do
        local ok, err = pcall(function()
            local id = target.id
            local vpf = target.vpf
            local model = target.model
            local prefix = target.prefix or "esp_enemies_"
            local window = target.window
            local tab = target.tab
            local isOpen = window and window.IsVisible and (not tab or tab.IsVisible) and vpf and vpf.Parent and vpf.Visible

            if not isOpen or not model or not model.Parent then
                CB_HidePreviewESP(CB_PreviewESPStore[id])
                return
            end

            if not CB_GetFlag(prefix .. "enable", false) then
                CB_HidePreviewESP(CB_PreviewESPStore[id])
                return
            end

            activeIds[id] = true
            local ui = CB_GetPreviewUI(id, vpf)

            local boxX, boxY, boxW, boxH = CB_ComputePreviewBox(vpf, model)
            if not boxX then
                CB_HidePreviewESP(ui)
                return
            end

            local previewBox = CB_GetFlag(prefix .. "box_enabled", true)
            local showFill = CB_GetFlag(prefix .. "fill", false)
            local showName = CB_GetFlag(prefix .. "names", false)
            local showHealth = CB_GetFlag(prefix .. "health", false)
            local showDist = CB_GetFlag(prefix .. "distance", false)
            local showWeapon = CB_GetFlag(prefix .. "weapon", false)
            local showFlags = CB_GetFlag(prefix .. "flags", false)
            local showChams = CB_GetFlag(prefix .. "chams_enabled", false)
            local chamsMat = CB_GetFlag(prefix .. "chams_mat", "Highlight")
            local chamsTex = CB_GetFlag(prefix .. "chams_tex", "None")

            local boxColor = CB_GetFlagColor(prefix .. "box_color_vis", Color3.new(1, 1, 1))
            local thickness = math.max(CB_GetFlagNumber(prefix .. "thickness", 1), 1)
            local fillColorVis, fillTransVis = CB_GetFlagColorData(prefix .. "fill_color_vis", Color3.fromRGB(255, 156, 156), 0.5)
            local fillColorHid, fillTransHid = CB_GetFlagColorData(prefix .. "fill_color_hid", Color3.fromRGB(255, 100, 100), 1)

            local anyVisible = previewBox or showFill or showName or showHealth or showDist or showWeapon or showFlags
            ui.overlay.Visible = anyVisible

            if previewBox or showFill then
                ui.box.Visible = true
                ui.box.Position = UDim2.fromOffset(boxX, boxY)
                ui.box.Size = UDim2.fromOffset(boxW, boxH)

                if previewBox then
                    ui.boxStroke.Enabled = true
                    ui.boxStroke.Color = boxColor
                    ui.boxStroke.Thickness = thickness
                else
                    ui.boxStroke.Enabled = false
                end

                if showFill then
                    ui.fill.Visible = true
                    ui.fill.BackgroundColor3 = Color3.new(1, 1, 1)
                    ui.fillGrad.Color = ColorSequence.new(fillColorVis, fillColorHid)
                    ui.fillGrad.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, fillTransVis),
                        NumberSequenceKeypoint.new(1, fillTransHid),
                    })
                else
                    ui.fill.Visible = false
                end
            else
                ui.box.Visible = false
                ui.fill.Visible = false
            end

            if showName then
                ui.name.Visible = true
                ui.name.Text = target.label or "Preview"
                ui.name.TextColor3 = CB_GetFlagColor(prefix .. "name_color_vis", Color3.new(1, 1, 1))
                ui.name.TextSize = CB_GetFlagNumber(prefix .. "names_size", 13)
                ui.name.Size = UDim2.fromOffset(boxW, 14)
                ui.name.Position = UDim2.fromOffset(boxX, boxY - 16)
            else
                ui.name.Visible = false
            end

            if showHealth then
                ui.healthBg.Visible = true
                ui.healthFill.Visible = true
                ui.healthBg.Position = UDim2.fromOffset(boxX - 6, boxY)
                ui.healthBg.Size = UDim2.fromOffset(2, boxH)
                ui.healthFill.BackgroundColor3 = CB_GetFlagColor(prefix .. "health_color_vis", Color3.new(0, 1, 0))
                ui.healthFill.Size = UDim2.new(1, 0, 0.8, 0)
                ui.healthFill.Position = UDim2.new(0, 0, 0.2, 0)
            else
                ui.healthBg.Visible = false
            end

            local bottomY = boxY + boxH + 2
            if showDist then
                ui.dist.Visible = true
                ui.dist.Text = "[8m]"
                ui.dist.TextColor3 = CB_GetFlagColor(prefix .. "dist_color_vis", Color3.new(1, 1, 1))
                ui.dist.TextSize = CB_GetFlagNumber(prefix .. "dist_size", 10)
                ui.dist.Size = UDim2.fromOffset(boxW, 14)
                ui.dist.Position = UDim2.fromOffset(boxX, bottomY)
                bottomY = bottomY + 13
            else
                ui.dist.Visible = false
            end

            if showWeapon then
                ui.weapon.Visible = true
                ui.weapon.Text = "AK-47"
                ui.weapon.TextColor3 = CB_GetFlagColor(prefix .. "weapon_color_vis", Color3.new(1, 1, 1))
                ui.weapon.TextSize = CB_GetFlagNumber(prefix .. "weapon_size", 10)
                ui.weapon.Size = UDim2.fromOffset(boxW, 14)
                ui.weapon.Position = UDim2.fromOffset(boxX, bottomY)
            else
                ui.weapon.Visible = false
            end

            if showFlags then
                ui.flag.Visible = true
                ui.flag.Text = "C4"
                ui.flag.TextColor3 = CB_GetFlagColor(prefix .. "flags_color_vis", Color3.new(1, 1, 1))
                ui.flag.TextSize = CB_GetFlagNumber(prefix .. "flags_size", 9)
                ui.flag.Position = UDim2.fromOffset(boxX + boxW + 4, boxY)
            else
                ui.flag.Visible = false
            end

            if showChams then
                local chamsColor = CB_GetFlagColor(prefix .. "chams_color_vis", Color3.fromRGB(255, 255, 255))
                for _, child in model:GetDescendants() do
                    if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
                        if not ui.OrigProps[child] then
                            ui.OrigProps[child] = { Color = child.Color, Material = child.Material }
                        end

                        child.Material = Enum.Material.ForceField
                        child.Color = chamsColor

                        local chamsMesh = child:FindFirstChild("ChamsMesh")
                        if chamsMesh then chamsMesh:Destroy() end
                    end
                end
            else
                for child, props in ui.OrigProps do
                    if child.Parent then
                        child.Color = props.Color
                        child.Material = props.Material
                        local chamsMesh = child:FindFirstChild("ChamsMesh")
                        if chamsMesh then chamsMesh:Destroy() end
                    end
                end
                table.clear(ui.OrigProps)
            end
        end)
        if not ok and not getgenv()._CB_PREVIEW_ERR then
            getgenv()._CB_PREVIEW_ERR = true
            warn("[Pulsehack] Preview ESP: " .. tostring(err))
        end
    end

    for id, obj in CB_PreviewESPStore do
        if not activeIds[id] then
            CB_HidePreviewESP(obj)
        end
    end
end

getgenv().CB_UpdatePreviewESP = CB_UpdatePreviewESP

getgenv().CB_RefreshPreviewDummies = function()
    local targets = getgenv().CB_PreviewTargets
    if not targets then return end
    local create = getgenv().CB_CreateDummy
    if not create then return false end
    local allSuccess = true
    for _, target in targets do
        local vpf = target.vpf
        if vpf and vpf.Parent then
            if target.id ~= "skins" then
                if not target.model then
                    target.model = Instance.new("Model", vpf)
                else
                    target.model:ClearAllChildren()
                end
                local successDummy = create(target.model)
                if not successDummy then
                    allSuccess = false
                end
            end
        end
    end
    return allSuccess
end

local CB_AA_FOVCircle = Drawing.new("Circle")
CB_AA_FOVCircle.Thickness = 1
CB_AA_FOVCircle.NumSides = 64
CB_AA_FOVCircle.Filled = false
CB_AA_FOVCircle.Transparency = 1
CB_AA_FOVCircle.Visible = false

local CB_Silent_FOVCircle = Drawing.new("Circle")
CB_Silent_FOVCircle.Thickness = 1
CB_Silent_FOVCircle.NumSides = 64
CB_Silent_FOVCircle.Filled = false
CB_Silent_FOVCircle.Transparency = 1
CB_Silent_FOVCircle.Visible = false

local function CB_UpdateFOVCircles()
    local isAlive = CB_IsAlive()
    local p = (CB_State.prefix or "rifles") .. "_"
    local isMelee = CB_State.melee or false

    local center = CB_Camera.ViewportSize / 2
    local aaFovShow = CB_GetFlag(p .. "aa_fov_on", false)
    local aaFovVal = CB_GetFlagNumber(p .. "fov", 100)
    local aaColor = CB_GetFlagColor(p .. "aa_fov_color", Color3.fromRGB(255, 0, 0))

    if aaFovShow and isAlive and not isMelee then
        CB_AA_FOVCircle.Visible = true
        CB_AA_FOVCircle.Radius = aaFovVal * 3
        CB_AA_FOVCircle.Position = center
        CB_AA_FOVCircle.Color = aaColor
    else
        CB_AA_FOVCircle.Visible = false
    end

    local silentFovShow = CB_GetFlag(p .. "br_fov_on", false)
    local silentFovVal = CB_GetFlagNumber(p .. "silent_fov", 100)
    local silentColor = CB_GetFlagColor(p .. "br_fov_color", Color3.fromRGB(0, 255, 255))

    if silentFovShow and isAlive and not isMelee then
        CB_Silent_FOVCircle.Visible = true
        CB_Silent_FOVCircle.Radius = silentFovVal * 3
        CB_Silent_FOVCircle.Position = center
        CB_Silent_FOVCircle.Color = silentColor
    else
        CB_Silent_FOVCircle.Visible = false
    end
end

local function CB_GetClientEnv()
    local clientScript = CB_LocalPlayer.PlayerGui:FindFirstChild("Client") or CB_LocalPlayer.PlayerScripts:FindFirstChild("Client", true)
    if clientScript then
        local ok, env = pcall(getsenv, clientScript)
        if ok and env then return env end
    end
    for _, child in CB_LocalPlayer.PlayerScripts:GetDescendants() do
        if child:IsA("LocalScript") and child.Name == "Client" then
            local ok, env = pcall(getsenv, child)
            if ok and env then return env end
        end
    end
    return nil
end

local function IsKeyHeld(bindFlag)
    local bind = CB_Flags[bindFlag]
    if not bind then return false end
    local key = typeof(bind) == "table" and bind.Value or bind
    if not key then return false end

    local ok, res = pcall(function()
        if key.EnumType == Enum.KeyCode then
            return CB_UIS:IsKeyDown(key)
        elseif key.EnumType == Enum.UserInputType then
            return CB_UIS:IsMouseButtonPressed(key)
        end
        return false
    end)
    return ok and res or false
end

local function CB_IsSilentFlagOn(p)
    if CB_GetFlag(p .. "silent_aim", false) then return true end
    if CB_Flags[p .. "silent_key"] then
        return IsKeyHeld(p .. "silent_key")
    end
    return false
end

CB_RunService.RenderStepped:Connect(function()
    local ok, err = pcall(CB_UpdateESP)
    if not ok and err then
        if not getgenv()._CB_ESP_ERR_SHOWN then
            getgenv()._CB_ESP_ERR_SHOWN = true
            warn("[Pulsehack] ESP Error: " .. tostring(err))
        end
    end
    pcall(CB_UpdateFOVCircles)
    pcall(CB_UpdatePreviewESP)
end)

local tbDebounce = false

CB_RunService.Heartbeat:Connect(function()
    pcall(function()
        CB_UpdateWeaponState()

        local charAlive = CB_IsAlive()
        if not charAlive then
            getgenv().target = nil
            getgenv().silentAimEnabled = false
            return
        end
        local p = (CB_State.prefix or "rifles") .. "_"
        local aaEnabled = CB_GetFlag(p .. "aa_enabled", false)
        if aaEnabled and not CB_State.melee then
            local mouseHeld = CB_UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            if mouseHeld then
            local smoothEnabled = CB_GetFlag(p .. "aa_smooth", false) or CB_GetFlag("aa_smoothness_enabled", false)
            local fovEnabled = CB_GetFlag(p .. "aa_fov_on", false) or CB_GetFlag("aa_fov_enabled", false)
            local fov = fovEnabled and (CB_GetFlag(p .. "fov", 100) or CB_GetFlag("riflesFOV", 100)) or math.huge
            local hitbox = CB_GetFlag(p .. "aa_hitbox", nil) or CB_GetFlag("aa_hitbox", "Head")
            local checksAA = CB_GetFlag(p .. "aa_checks", nil) or CB_GetFlag("aa_checks", "Visible, Team")
            local visOnly = checksAA == "Visible" or checksAA == "Visible, Team"

            local plr, dist = CB_GetNearest(fov, visOnly)
            if plr and plr.Character then
                local targetPart
                if hitbox == "Torso" then
                    targetPart = plr.Character:FindFirstChild("HumanoidRootPart") or plr.Character:FindFirstChild("Torso")
                elseif hitbox == "Nearest" then
                    local parts = {"Head", "Torso", "HumanoidRootPart", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}
                    local bestDist = math.huge
                    local cx, cy = CB_Camera.ViewportSize.X / 2, CB_Camera.ViewportSize.Y / 2
                    for _, pName in parts do
                        local pt = plr.Character:FindFirstChild(pName)
                        if pt then
                            local sp, onSc = CB_Camera:WorldToScreenPoint(pt.Position)
                            if onSc then
                                local d = math.sqrt((sp.X - cx)^2 + (sp.Y - cy)^2)
                                if d < bestDist then
                                    bestDist = d
                                    targetPart = pt
                                end
                            end
                        end
                    end
                    if not targetPart then targetPart = plr.Character:FindFirstChild("Head") end
                else
                    targetPart = plr.Character:FindFirstChild("Head")
                end

                if targetPart then
                    local sp, onSc = CB_Camera:WorldToScreenPoint(targetPart.Position)
                    if onSc then
                        local cx = CB_Camera.ViewportSize.X / 2
                        local cy = CB_Camera.ViewportSize.Y / 2
                        local dx = -(cx - sp.X)
                        local dy = -(cy - sp.Y)

                        if smoothEnabled then
                            local easingStyle = CB_GetFlag("aa_easing_style", "Sine")
                            local easingDir = CB_GetFlag("aa_easing_dir", "In")
                            local smoothX = math.max(CB_GetFlag("aa_smoothness_x", 30), 1)
                            local smoothY = math.max(CB_GetFlag("aa_smoothness_y", 30), 1)
                            local smX = smoothX / 100
                            local smY = smoothY / 100

                            local easedX = CB_ApplyEasing(1 - smX, easingStyle, easingDir)
                            local easedY = CB_ApplyEasing(1 - smY, easingStyle, easingDir)

                            dx = dx * math.max(easedX, 0.01)
                            dy = dy * math.max(easedY, 0.01)
                            if CB_GetFlag("aa_curve_enabled", false) then
                                local curveStyle = CB_GetFlag("aa_curve_easing_style", "Sine")
                                local curveDir = CB_GetFlag("aa_curve_easing_dir", "In")
                                local curveStr = CB_GetFlag("aa_curve_strength", 50) / 100

                                local angle = math.atan2(dy, dx)
                                local mag = math.sqrt(dx * dx + dy * dy)
                                local curved = CB_ApplyEasing(curveStr, curveStyle, curveDir)
                                angle = angle + curved * 0.3
                                dx = math.cos(angle) * mag
                                dy = math.sin(angle) * mag
                            end
                        else
                            local sm = math.max(CB_State.smoothness or 1, 1)
                            dx = dx / sm
                            dy = dy / sm
                        end

                        mousemoverel(dx, dy)
                    end
                end
            end
            end
        end
        local silentEnabled = CB_IsSilentFlagOn(p)
        getgenv().silentAimEnabled = charAlive and not CB_State.melee and silentEnabled
        getgenv().target = nil

        if getgenv().silentAimEnabled and CB_UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            local silentFOV = CB_GetFlag(p .. "silent_fov", 100) or CB_GetFlag("riflesSilentFOV", 100)
            local br_checks = CB_GetFlag(p .. "br_checks", nil) or CB_GetFlag("br_checks", "Visible, Team")
            local visOnly = br_checks == "Visible" or br_checks == "Visible, Team"
            local plr, dist = CB_GetNearest(silentFOV, visOnly)

            local deadzone = CB_GetFlag(p .. "deadzone", 0) or 0
            local inFov = dist <= silentFOV * 3
            local outDeadzone = deadzone <= 0 or dist > deadzone * 2.3

            if plr and plr.Character and inFov and outDeadzone then
                local hitbox = CB_GetFlag(p .. "br_hitbox", nil) or CB_GetFlag("br_hitbox", "Head")
                getgenv().target = CB_GetSilentTargetPart(plr.Character, hitbox)
            end
        end
        local triggerEnabled = CB_GetFlag(p .. "trigger", false) or CB_GetFlag("riflesTrigger", false)
        local triggerKeyHeld = true
        local tbBind = CB_Flags["tb_key"]
        if tbBind then
            triggerKeyHeld = IsKeyHeld("tb_key")
        end

        if triggerEnabled and CB_State.alive and not CB_State.melee and triggerKeyHeld and not tbDebounce then
            local mousePos = CB_UIS:GetMouseLocation()
            local mouseRay = CB_Camera:ViewportPointToRay(mousePos.X, mousePos.Y)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            local filter = {CB_Camera, CB_LocalPlayer.Character}
            if workspace:FindFirstChild("Ray_Ignore") then
                table.insert(filter, workspace.Ray_Ignore)
            end
            if workspace:FindFirstChild("Map") then
                local clips = workspace.Map:FindFirstChild("Clips")
                if clips then table.insert(filter, clips) end
            end
            params.FilterDescendantsInstances = filter

            local hit = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000, params)
            if hit and hit.Instance then
                local hitPart = hit.Instance
                local hitModel = hitPart.Parent
                if hitModel and hitModel:FindFirstChild("Humanoid") then
                    local plr = CB_Players:GetPlayerFromCharacter(hitModel)
                    if plr and CB_TeamCheck(plr) then
                        local tbHitbox = CB_GetFlag("tb_hitbox", "Head")
                        local isTargetValid = false
                        if tbHitbox == "Head" then
                            isTargetValid = (hitPart.Name == "Head" or hitPart.Name == "HeadHB")
                        elseif tbHitbox == "Torso" then
                            isTargetValid = (hitPart.Name == "HumanoidRootPart" or hitPart.Name == "UpperTorso" or hitPart.Name == "LowerTorso" or hitPart.Name == "Torso")
                        else
                            isTargetValid = true
                        end

                        if isTargetValid then
                            tbDebounce = true
                            local delayVal = (CB_GetFlag(p .. "trigger_delay", nil) or CB_GetFlag("riflesTriggerDelay", 0)) / 1000
                            task.spawn(function()
                                if delayVal > 0 then
                                    task.wait(delayVal)
                                end
                                mouse1press()
                                task.wait(0.01)
                                mouse1release()
                                task.wait(0.1)
                                tbDebounce = false
                            end)
                        end
                    end
                end
            end
        end

        local currentSpreadState = CB_GetFlag("removeSpread", false)
        if currentSpreadState ~= CB_LastSpreadState then
            CB_LastSpreadState = currentSpreadState
            CB_ApplyValue(currentSpreadState, "Spread", CB_SpreadCache, 0.1)
        end

        local char = CB_LocalPlayer.Character
        if char then
            local toolVal = char:FindFirstChild("EquippedTool")
            local wep = toolVal and CB_Weapons and CB_Weapons:FindFirstChild(toolVal.Value)
            if wep then
                local wepName = wep.Name
                if not getgenv().CB_OrigWeaponStats then getgenv().CB_OrigWeaponStats = {} end
                if not getgenv().CB_OrigWeaponStats[wepName] then
                    getgenv().CB_OrigWeaponStats[wepName] = {}
                    local fr = wep:FindFirstChild("FireRate")
                    if fr then getgenv().CB_OrigWeaponStats[wepName].FireRate = fr.Value end
                    local sp = wep:FindFirstChild("Spread")
                    if sp then
                        local rec = sp:FindFirstChild("Recoil")
                        if rec then getgenv().CB_OrigWeaponStats[wepName].Recoil = rec.Value end
                        if sp:IsA("ValueBase") or (type(sp)=="userdata" and sp.ClassName:match("Value$")) then getgenv().CB_OrigWeaponStats[wepName].Spread = sp.Value end
                        local stand = sp:FindFirstChild("Stand")
                        if stand then getgenv().CB_OrigWeaponStats[wepName].Stand = stand.Value end
                        local crouch = sp:FindFirstChild("Crouch")
                        if crouch then getgenv().CB_OrigWeaponStats[wepName].Crouch = crouch.Value end
                        local fire = sp:FindFirstChild("Fire")
                        if fire then getgenv().CB_OrigWeaponStats[wepName].Fire = fire.Value end
                        local land = sp:FindFirstChild("Land")
                        if land then getgenv().CB_OrigWeaponStats[wepName].Land = land.Value end
                    end
                end

                local orig = getgenv().CB_OrigWeaponStats[wepName]

                local fr = wep:FindFirstChild("FireRate")
                if fr then
                    if CB_GetFlag("rapid_fire", false) then
                        fr.Value = 0
                    elseif orig.FireRate and fr.Value == 0 then
                        fr.Value = orig.FireRate
                    end
                end

                    local env = CB_GetClientEnv()
                    if env then
                        if CB_GetFlag("removeRecoil", false) then
                            env.RecoilX = 0.1
                            env.RecoilY = 0.1
                        end
                    end
                end
            end

        local speedVal = CB_GetFlag("misc_speed", 16)
        if speedVal and speedVal > 16 then
            local char = CB_LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = speedVal end
            end
        end
        local jumpVal = CB_GetFlag("misc_jumppower", 50)
        if jumpVal and jumpVal > 50 then
            local char = CB_LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.JumpPower = jumpVal end
            end
        end
        if CB_GetFlag("misc_autostrafe", false) then
            local char = CB_LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum:GetState() == Enum.HumanoidStateType.Freefall then
                    local delta = CB_UIS:GetMouseDelta()
                    if delta.X > 1 then
                        hum:Move(Vector3.new(1, 0, 0), true)
                    elseif delta.X < -1 then
                        hum:Move(Vector3.new(-1, 0, 0), true)
                    end
                end
            end
        end
    end)
end)

local CB_OldNamecall
CB_OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local name = tostring(self.Name or "")

    if getgenv().CB_SilentDebug and CB_UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        if string.find(method, "FindPartOnRay") or method == "Raycast" then
            warn("[SilentDbg] " .. method .. " @ " .. tostring(self))
        elseif method == "FireServer" and (name == "HitParl" or name == "Whizz" or name == "Trail" or name == "ReplicateShot") then
            warn("[SilentDbg] " .. name .. " fired")
        end
    end

    if getgenv().silentAimEnabled and getgenv().target then
        local pfx = CB_State.prefix and (CB_State.prefix .. "_") or "rifles_"
        local hitchance = CB_GetFlag(pfx .. "br_hitchance", 50)
        local missShot = hitchance < 100 and math.random(1, 100) > hitchance
        local fromCamera = CB_GetFlag(pfx .. "br_from_camera", true)

        if string.find(method, "FindPartOnRay") and not missShot then
            local newRay = CB_BuildSilentRay(getgenv().target, fromCamera, 500)
            if getgenv().CB_SilentDebug then
                warn("[Silent] redirect FindPartOnRay -> " .. getgenv().target.Name)
            end
            return CB_OldNamecall(self, newRay, select(2, ...))
        end

        if method == "Raycast" and self == workspace and not missShot then
            local origin, direction = ...
            if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                local _, rayOrigin, predicted = CB_BuildSilentRay(getgenv().target, fromCamera, direction.Magnitude)
                local mag = direction.Magnitude
                if mag < 0.001 then mag = 500 end
                if getgenv().CB_SilentDebug then
                    warn("[Silent] redirect Raycast -> " .. getgenv().target.Name)
                end
                return CB_OldNamecall(self, rayOrigin, (predicted - rayOrigin).Unit * mag, select(3, ...))
            end
        end
    end

    if not checkcaller() then
        if method == "FireServer" then
            local args = {...}
            if name == "RemoteEvent" and type(args[1]) == "table" then
                if args[1][1] == "kick" then
                    return
                end
            end
            if name == "FallDamage" and CB_GetFlag("misc_nofall", false) then
                return
            end
            if name == "ewrtsjkwrslk" then
                return
            end
            if name == "Rem3" then
                return
            end
            if name == "Boogers" and CB_Flags["removeSpread"] then
                return
            end
            if name == "HitParl" then
                local args_hp = table.pack(...)
                local hitParlModified = false
                if getgenv().silentAimEnabled and getgenv().target then
                    local pfx = CB_State.prefix and (CB_State.prefix .. "_") or "rifles_"
                    local hitchance = CB_GetFlag(pfx .. "br_hitchance", 50)
                    if hitchance >= 100 or math.random(1, 100) <= hitchance then
                        args_hp = CB_ApplySilentHitParl(args_hp)
                        hitParlModified = true
                        if getgenv().CB_SilentDebug then
                            warn("[Silent] redirect HitParl -> " .. tostring(getgenv().target.Name))
                        end
                    end
                end
                if CB_GetFlag("br_overdmg_enabled", false) then
                    args_hp[7] = CB_GetFlag("br_overdmg", 100) / 100
                    hitParlModified = true
                end
                if hitParlModified then
                    return CB_OldNamecall(self, unpack(args_hp, 1, args_hp.n))
                end
            end
        end

    end

    return CB_OldNamecall(self, ...)
end)
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            if not CB_Flags["inf_ammo"] then return end
            local wepFolder = CB_Weapons or CB_RS:FindFirstChild("Weapons")
            if not wepFolder then return end
            for _, wep in wepFolder:GetChildren() do
                local ammo = wep:FindFirstChild("Ammo")
                local stored = wep:FindFirstChild("StoredAmmo")
                if ammo and ammo.Value ~= 9999999 then ammo.Value = 9999999 end
                if stored and stored.Value ~= 9999999 then stored.Value = 9999999 end
            end
            local char = CB_LocalPlayer.Character
            if char then
                local toolVal = char:FindFirstChild("EquippedTool")
                local wep2 = toolVal and wepFolder:FindFirstChild(toolVal.Value)
                if wep2 then
                    local ammo2 = wep2:FindFirstChild("Ammo")
                    local stored2 = wep2:FindFirstChild("StoredAmmo")
                    if ammo2 then ammo2.Value = 9999999 end
                    if stored2 then stored2.Value = 9999999 end
                end
            end
        end)
    end
end)

if Menu and Menu.Flags then
    CB_TeamFF = Menu.Flags["legitteam"] or false
end

warn("[Pulsehack] utilities.lua loaded OK")





do
    
    local ebDebounce = false
    local ebWasFalling = false
    local ebEdgePos = nil
    local ebLastSound = 0
    local ebChainCount = 0
    local ebLoggedSeek = false
    local ebLastEdgeLog = 0
    local ebCooldown = 0
    local ebLastEdgeY = nil
    local edgebugDebounce = false
    local lastBhopVelocity = Vector3.new()
    local bhopActive = false
    local bhopMaintainDebounce = false
    local surfing = false
    local lastWallNormal = nil
    local fmIsOnLadder = false
    local fmWasOnLadder = false
    local fmLastCooldown = 0
    local fmCanBoost = false
    local headbounceWasRiding = false

    
    local wallScanDirs = {
        CFrame.new(1, 0, 0), CFrame.new(-1, 0, 0),
        CFrame.new(0, 0, 1), CFrame.new(0, 0, -1),
        CFrame.new(0.7, 0, 0.7), CFrame.new(-0.7, 0, 0.7),
        CFrame.new(0.7, 0, -0.7), CFrame.new(-0.7, 0, -0.7),
        CFrame.new(1, -0.6, 0), CFrame.new(-1, -0.6, 0),
        CFrame.new(0, -0.6, 1), CFrame.new(0, -0.6, -1),
        CFrame.new(0.7, -0.6, 0.7), CFrame.new(-0.7, -0.6, 0.7),
        CFrame.new(0.7, -0.6, -0.7), CFrame.new(-0.7, -0.6, -0.7)
    }

    local function findWallHit()
        local hrp = CB_LocalPlayer.Character and CB_LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil, nil, nil end
        local cam = workspace.CurrentCamera
        local ignoreList = {
            cam,
            CB_LocalPlayer.Character,
            workspace:FindFirstChild("Ray_Ignore"),
        }
        local mapSP = workspace:FindFirstChild("Map")
        if mapSP then
            local sp = mapSP:FindFirstChild("SpawnPoints")
            if sp then table.insert(ignoreList, sp) end
        end
        local closestDist = math.huge
        local closestPart, closestNormal, closestPos = nil, nil, nil
        for _, dir in next, wallScanDirs do
            local worldDir = (hrp.CFrame * dir).p - hrp.CFrame.p
            local ray = Ray.new(hrp.CFrame.p, worldDir.unit * 2.0)
            local hitPart, hitPos, hitNormal = workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)
            if hitPart then
                local dist = (hitPos - hrp.CFrame.p).Magnitude
                if dist < closestDist then
                    local allow = true
                    if lastWallNormal then
                        local angle = math.acos(math.clamp(hitNormal:Dot(lastWallNormal), -1, 1))
                        if math.deg(angle) > 35 then allow = false end
                    end
                    if allow then
                        closestDist = dist
                        closestPart = hitPart
                        closestNormal = hitNormal
                        closestPos = hitPos
                    end
                end
            end
        end
        if closestPart then
            lastWallNormal = closestNormal
        else
            lastWallNormal = nil
        end
        return closestPart, closestNormal, closestPos
    end

    
    local ebScanDirs = {
        Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
        Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
        Vector3.new(0.707, 0, 0.707), Vector3.new(-0.707, 0, 0.707),
        Vector3.new(0.707, 0, -0.707), Vector3.new(-0.707, 0, -0.707),
        Vector3.new(0.924, 0, 0.383), Vector3.new(-0.924, 0, 0.383),
        Vector3.new(0.924, 0, -0.383), Vector3.new(-0.924, 0, -0.383),
        Vector3.new(0.383, 0, 0.924), Vector3.new(-0.383, 0, 0.924),
        Vector3.new(0.383, 0, -0.924), Vector3.new(-0.383, 0, -0.924),
    }

    
    local function detectLadder()
        local char = CB_LocalPlayer.Character
        if not char then return false end
        local hum = char:FindFirstChild("Humanoid")
        if not hum then return false end
        return hum:GetState() == Enum.HumanoidStateType.Climbing
    end

    
    local function getClosestEnemy()
        local localChar = CB_LocalPlayer.Character
        if not localChar then return nil, math.huge end
        local localHrp = localChar:FindFirstChild("HumanoidRootPart")
        if not localHrp then return nil, math.huge end
        local closest = nil
        local minDist = math.huge
        local currentTeam = CB_LocalPlayer.Team
        for _, plr in pairs(game:GetService("Players"):GetPlayers()) do
            if plr ~= CB_LocalPlayer and plr.Character then
                local isEnemy = true
                if currentTeam then
                    pcall(function()
                        if plr.Team and plr.Team.Name == currentTeam.Name then
                            isEnemy = false
                        end
                    end)
                end
                if isEnemy then
                    local hrp2 = plr.Character:FindFirstChild("HumanoidRootPart")
                    local hum2 = plr.Character:FindFirstChild("Humanoid")
                    if hrp2 and hum2 and hum2.Health > 0 then
                        local dist = (localHrp.Position - hrp2.Position).Magnitude
                        if dist < minDist then
                            minDist = dist
                            closest = plr
                        end
                    end
                end
            end
        end
        return closest, minDist
    end

    
    
    
    CB_RunService.RenderStepped:Connect(function(dt)
        if not CB_State.alive then return end
        local char = CB_LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if not hrp or not hum then return end

        local function isHeld(keyFlag)
            local key = CB_GetFlag(keyFlag)
            if type(key) == "boolean" then return key end
            if typeof(key) == "EnumItem" then
                if key.EnumType == Enum.KeyCode then
                    return CB_UIS:IsKeyDown(key)
                elseif key.EnumType == Enum.UserInputType then
                    for _, state in next, CB_UIS:GetMouseButtonsPressed() do
                        if state.UserInputType == key then return true end
                    end
                end
            end
            return false
        end

        local velocity = hrp.Velocity
        local state = hum:GetState()
        local isGrounded = hum.FloorMaterial ~= Enum.Material.Air
        local isInAir = not isGrounded
        local cam = workspace.CurrentCamera

        
        
        
        if CB_GetFlag("misc_no_crouch_cd") then
            pcall(function()
                local gun = char:FindFirstChild("Gun")
                if gun then
                    local controller = gun:FindFirstChild("GunController") or gun:FindFirstChild("Controller")
                    if controller then
                        local src = require(controller)
                        if src and src.crouchcooldown ~= nil then
                            src.crouchcooldown = 0
                        end
                    end
                end
            end)
        end

        
        
        
        if CB_GetFlag("misc_bhop") and CB_UIS:IsKeyDown(Enum.KeyCode.Space) and not CB_UIS:GetFocusedTextBox() then
            bhopActive = true
            local method = CB_GetFlag("misc_bhop_method") or "Auto Hop"
            local baseSpeed = CB_GetFlagNumber("misc_bhop_speed") or 18
            if not getgenv().bhopSpeed then getgenv().bhopSpeed = baseSpeed end
            if getgenv().bhopSpeed < baseSpeed then getgenv().bhopSpeed = baseSpeed end
            local isAutoHop = (method == "Auto Hop")
            local strafing = false

            
            if CB_GetFlag("misc_autostrafe") then
                if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
                    local mouseDelta = CB_UIS:GetMouseDelta()
                    if math.abs(mouseDelta.X) > 0.5 then
                        strafing = true
                        if isAutoHop then
                            local rawGain = math.abs(mouseDelta.X) * 0.005
                            local clampedGain = math.min(rawGain, 0.15)
                            getgenv().bhopSpeed = math.min(getgenv().bhopSpeed + clampedGain, baseSpeed + 25)
                            local camLook = cam.CFrame.LookVector
                            local rightVec = Vector3.new(-camLook.Z, 0, camLook.X)
                            local strafeDir = mouseDelta.X > 0 and rightVec or -rightVec
                            local currentVelXZ = Vector3.new(velocity.X, 0, velocity.Z)
                            local newVelXZ = currentVelXZ + (strafeDir * 1.5)
                            if newVelXZ.Magnitude > 0 then
                                newVelXZ = newVelXZ.Unit * getgenv().bhopSpeed
                            end
                            hrp.Velocity = Vector3.new(newVelXZ.X, velocity.Y, newVelXZ.Z)
                        else
                            local camLook = cam.CFrame.LookVector
                            local rightVec = Vector3.new(-camLook.Z, 0, camLook.X)
                            local strafeDir = mouseDelta.X > 0 and rightVec or -rightVec
                            hrp.Velocity = Vector3.new(
                                velocity.X + strafeDir.X * 0.7,
                                velocity.Y,
                                velocity.Z + strafeDir.Z * 0.7
                            )
                        end
                    end
                end
            end

            
            if isAutoHop and not strafing and getgenv().bhopSpeed > baseSpeed then
                getgenv().bhopSpeed = math.max(getgenv().bhopSpeed - 0.5, baseSpeed)
            elseif not isAutoHop then
                getgenv().bhopSpeed = baseSpeed
            end

            local speed = isAutoHop and getgenv().bhopSpeed or baseSpeed
            local lookVec = hrp.CFrame.LookVector
            local moveVec = Vector3.new()

            if method == "CFrame" or method == "Velocity" then
                moveVec = CB_UIS:IsKeyDown(Enum.KeyCode.W) and moveVec + lookVec or moveVec
                moveVec = CB_UIS:IsKeyDown(Enum.KeyCode.S) and moveVec - lookVec or moveVec
                moveVec = CB_UIS:IsKeyDown(Enum.KeyCode.D) and moveVec + Vector3.new(-lookVec.Z, 0, lookVec.X) or moveVec
                moveVec = CB_UIS:IsKeyDown(Enum.KeyCode.A) and moveVec + Vector3.new(lookVec.Z, 0, -lookVec.X) or moveVec

                if method == "CFrame" and moveVec ~= Vector3.new() then
                    local cfSpeed = speed / 300
                    moveVec = moveVec.Unit
                    hrp.CFrame = hrp.CFrame + Vector3.new(moveVec.X * cfSpeed, 0, moveVec.Z * cfSpeed)
                    if isGrounded and (tick() - (getgenv()._ph_lastJump or 0) > 0.1) then getgenv()._ph_lastJump = tick(); hum.Jump = true end
                else
                    if not strafing then
                        local hasSideKey = CB_UIS:IsKeyDown(Enum.KeyCode.S) or CB_UIS:IsKeyDown(Enum.KeyCode.D) or CB_UIS:IsKeyDown(Enum.KeyCode.A)
                        if moveVec.Unit.X == moveVec.Unit.X and (not CB_GetFlag("misc_autostrafe") or hasSideKey) then
                            moveVec = moveVec.Unit
                            hrp.Velocity = Vector3.new(moveVec.X * speed, hrp.Velocity.Y, moveVec.Z * speed)
                        elseif CB_GetFlag("misc_autostrafe") and not hasSideKey then
                            moveVec = moveVec + lookVec
                            moveVec = moveVec.Unit
                            hrp.Velocity = Vector3.new(moveVec.X * speed, hrp.Velocity.Y, moveVec.Z * speed)
                            hum:MoveTo(hrp.Position + lookVec)
                        end
                    end
                    lastBhopVelocity = hrp.Velocity
                end

            elseif method == "Directional" or method == "Directional 2" or method == "Gyro" then
                local add = 0
                local keyHeld = false
                if method == "Directional" or method == "Directional 2" then
                    if CB_UIS:IsKeyDown(Enum.KeyCode.W) or CB_UIS:IsKeyDown(Enum.KeyCode.A) or CB_UIS:IsKeyDown(Enum.KeyCode.S) or CB_UIS:IsKeyDown(Enum.KeyCode.D) then keyHeld = true end
                    if CB_UIS:IsKeyDown(Enum.KeyCode.A) then add = 90 end
                    if CB_UIS:IsKeyDown(Enum.KeyCode.S) then add = 180 end
                    if CB_UIS:IsKeyDown(Enum.KeyCode.D) then add = 270 end
                    if CB_UIS:IsKeyDown(Enum.KeyCode.A) and CB_UIS:IsKeyDown(Enum.KeyCode.W) then add = 45 end
                    if CB_UIS:IsKeyDown(Enum.KeyCode.D) and CB_UIS:IsKeyDown(Enum.KeyCode.W) then add = 315 end
                    if CB_UIS:IsKeyDown(Enum.KeyCode.D) and CB_UIS:IsKeyDown(Enum.KeyCode.S) then add = 225 end
                    if CB_UIS:IsKeyDown(Enum.KeyCode.A) and CB_UIS:IsKeyDown(Enum.KeyCode.S) then add = 145 end
                end
                if isGrounded and (tick() - (getgenv()._ph_lastJump or 0) > 0.1) then getgenv()._ph_lastJump = tick(); hum.Jump = true end
                if not strafing and (not keyHeld and method == "Directional") then
                    
                elseif not strafing then
                    local camCF = cam.CFrame
                    local _, camY, _ = camCF:ToOrientation()
                    local rot = CFrame.new(camCF.Position) * CFrame.Angles(0, camY, 0) * CFrame.Angles(0, math.rad(add), 0)
                    if method == "Gyro" then
                        if not getgenv().bhopGyro or not pcall(function() return getgenv().bhopGyro.Parent end) then
                            getgenv().bhopGyro = Instance.new("BodyVelocity")
                        end
                        local bv = getgenv().bhopGyro
                        bv.MaxForce = Vector3.new(300000, 0, 300000)
                        bv.Velocity = Vector3.new(rot.LookVector.X, 0, rot.LookVector.Z) * speed
                        bv.Parent = char:FindFirstChild("UpperTorso") or hrp
                        delay(0.1, function()
                            pcall(function() bv:Destroy() end)
                            getgenv().bhopGyro = nil
                        end)
                    else
                        hrp.Velocity = Vector3.new(rot.LookVector.X * speed, hrp.Velocity.Y, rot.LookVector.Z * speed)
                    end
                end
                lastBhopVelocity = hrp.Velocity

            end

            if isGrounded and (tick() - (getgenv()._ph_lastJump or 0) > 0.1) then getgenv()._ph_lastJump = tick(); hum.Jump = true end
        else
            if bhopActive then
                bhopActive = false
            end
        end

        
        
        
        if CB_GetFlag("misc_autostrafe") and not CB_GetFlag("misc_bhop") then
            if isInAir then
                local mouseDelta = CB_UIS:GetMouseDelta()
                if math.abs(mouseDelta.X) > 0.5 then
                    local camLook = cam.CFrame.LookVector
                    local rightVec = Vector3.new(-camLook.Z, 0, camLook.X)
                    local strafeDir = mouseDelta.X > 0 and rightVec or -rightVec
                    hrp.Velocity = Vector3.new(
                        velocity.X + strafeDir.X * 0.7,
                        velocity.Y,
                        velocity.Z + strafeDir.Z * 0.7
                    )
                end
            end
        end

        
        
        
        if CB_GetFlag("misc_edgejump") and isHeld("misc_edgejump_kb") then
            if isGrounded then
                local rp = RaycastParams.new()
                rp.FilterType = Enum.RaycastFilterType.Exclude
                rp.FilterDescendantsInstances = {char}
                local moveDir = hum.MoveDirection
                if moveDir.Magnitude > 0.1 then
                    local checkPos = hrp.Position + moveDir.Unit * 2.5
                    local downRay = workspace:Raycast(checkPos, Vector3.new(0, -5, 0), rp)
                    if not downRay then
                        hum.Jump = true
                    end
                end
            end
        end

        
        
        
        local ebMode = CB_GetFlag("misc_eb_mode") or "redirectional"
        local ebEnabled = CB_GetFlag("misc_edgebug")
        local ebAutoEnabled = CB_GetFlag("misc_auto_eb")
        local ebHolding = isHeld("misc_edgebug_kb")

        if ebEnabled and (ebHolding or ebAutoEnabled) and ebMode == "mimic" then
            if getgenv()._ph_mimicHum ~= hum then
                getgenv()._ph_mimicHum = hum
                if getgenv()._ph_mimicConn then
                    getgenv()._ph_mimicConn:Disconnect()
                    getgenv()._ph_mimicConn = nil
                end
                getgenv()._ph_mimicConn = hum.StateChanged:Connect(function(old, new)
                    if not (CB_GetFlag("misc_edgebug") and (CB_GetFlag("misc_auto_eb") or isHeld("misc_edgebug_kb"))) then return end
                    if (CB_GetFlag("misc_eb_mode") or "redirectional") ~= "mimic" then return end
                    if new == Enum.HumanoidStateType.Freefall then
                        getgenv()._ph_mimicWasFalling = true
                    end
                    if getgenv()._ph_mimicWasFalling and new == Enum.HumanoidStateType.Landed and not edgebugDebounce then
                        getgenv()._ph_mimicWasFalling = false
                        edgebugDebounce = true
                        getgenv().hookJP = 0
                        local currentHrp = CB_LocalPlayer.Character and CB_LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        local currentHum = CB_LocalPlayer.Character and CB_LocalPlayer.Character:FindFirstChild("Humanoid")
                        if not currentHrp or not currentHum then
                            edgebugDebounce = false
                            return
                        end
                        spawn(function()
                            wait()
                            if not currentHrp then return end
                            local vel = currentHrp.AssemblyLinearVelocity
                            currentHrp.AssemblyLinearVelocity = Vector3.new(vel.X * 1.8, -7, vel.Z * 1.8)
                            local vel2 = currentHrp.AssemblyLinearVelocity
                            for i = 1, 4 do
                                wait()
                                if not currentHrp then return end
                                currentHrp.AssemblyLinearVelocity = vel2 - Vector3.new(0, 2, 0)
                            end
                            wait()
                            if not currentHrp then return end
                            currentHrp.AssemblyLinearVelocity = currentHrp.AssemblyLinearVelocity * Vector3.new(1.8, 1, 1.8)
                            getgenv().hookJP = nil
                            delay(0.3, function()
                                edgebugDebounce = false
                            end)
                        end)
                    end
                end)
            end
        else
            if getgenv()._ph_mimicConn and ebMode ~= "mimic" then
                getgenv()._ph_mimicConn:Disconnect()
                getgenv()._ph_mimicConn = nil
                getgenv()._ph_mimicHum = nil
            end
        end

        
        
        
        if ebEnabled and (ebHolding or ebAutoEnabled) and ebMode == "csgo" then
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = {char, workspace:FindFirstChild("Ray_Ignore")}
            if state == Enum.HumanoidStateType.Freefall and velocity.Y < -8 then
                local moveDir = Vector3.new(velocity.X, 0, velocity.Z)
                if moveDir.Magnitude < 0.5 then
                    moveDir = hrp.CFrame.LookVector
                else
                    moveDir = moveDir.Unit
                end
                local underRay = workspace:Raycast(hrp.Position, Vector3.new(0, -6, 0), rayParams)
                local forwardOrigin = hrp.Position + moveDir * 2.0
                local forwardRay = workspace:Raycast(forwardOrigin, Vector3.new(0, -6, 0), rayParams)
                local isEdge = (underRay and not forwardRay) or
                    (underRay and forwardRay and (underRay.Position.Y - forwardRay.Position.Y) > 1.0)
                if isEdge then
                    getgenv()._ph_csgoEdge = true
                    getgenv()._ph_csgoEdgeTime = tick()
                end
            end
            if getgenv()._ph_csgoEdge and state == Enum.HumanoidStateType.Landed and not edgebugDebounce then
                if (tick() - (getgenv()._ph_csgoEdgeTime or 0)) < 0.5 then
                    edgebugDebounce = true
                    getgenv().hookJP = 0
                    local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
                    local flatDir = Vector3.new(velocity.X, 0, velocity.Z)
                    local moveDir = flatDir.Magnitude > 0.5 and flatDir.Unit or hrp.CFrame.LookVector
                    hum:ChangeState(Enum.HumanoidStateType.Freefall)
                    hrp.AssemblyLinearVelocity = Vector3.new(velocity.X * 1.15, 5, velocity.Z * 1.15)
                    hrp.CFrame = hrp.CFrame + moveDir * 0.4
                    task.delay(0.15, function()
                        getgenv().hookJP = nil
                        edgebugDebounce = false
                    end)
                end
                getgenv()._ph_csgoEdge = false
            end
            if getgenv()._ph_csgoEdge and (tick() - (getgenv()._ph_csgoEdgeTime or 0)) > 0.8 then
                getgenv()._ph_csgoEdge = false
            end
        end

        
        
        
        if ebEnabled and (ebHolding or ebAutoEnabled) and ebMode == "redirectional" then
            local vel = hrp.AssemblyLinearVelocity
            local isAuto = ebAutoEnabled and not ebHolding
            local fallThreshold = isAuto and -25 or -8
            local cooldownNeeded = (ebChainCount > 0) and 0.25 or 1.5
            if state == Enum.HumanoidStateType.Freefall and vel.Y < fallThreshold and (tick() - ebCooldown) > cooldownNeeded then
                ebWasFalling = true
                if not ebEdgePos then
                    local rp = RaycastParams.new()
                    rp.FilterDescendantsInstances = {char}
                    rp.FilterType = Enum.RaycastFilterType.Exclude
                    local startPos = hrp.Position
                    local bestEdgePoint = nil
                    local bestEdgeDir = nil
                    local bestScore = math.huge
                    local allDirs = {}
                    local flatVel = Vector3.new(vel.X, 0, vel.Z)
                    local camLook = cam.CFrame.LookVector
                    local flatCam = Vector3.new(camLook.X, 0, camLook.Z)
                    local hasCam = flatCam.Magnitude > 0.1
                    local hasVel = flatVel.Magnitude > 1
                    local velDir = hasVel and flatVel.Unit or nil
                    local camDir = hasCam and flatCam.Unit or nil
                    local moveDir
                    if velDir and camDir then
                        local blend = (velDir * 0.6 + camDir * 0.4)
                        moveDir = blend.Magnitude > 0.05 and blend.Unit or velDir
                    else
                        moveDir = velDir or camDir or Vector3.new(0, 0, 1)
                    end
                    local primaries = {}
                    if velDir then table.insert(primaries, velDir) end
                    if camDir then table.insert(primaries, camDir) end
                    table.insert(primaries, moveDir)
                    local seen = {}
                    for _, dir in next, primaries do
                        local key = string.format("%.2f_%.2f", dir.X, dir.Z)
                        if not seen[key] then
                            seen[key] = true
                            table.insert(allDirs, dir)
                            for deg = 10, 60, 10 do
                                table.insert(allDirs, (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(0, math.rad(deg), 0)).LookVector)
                                table.insert(allDirs, (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(0, math.rad(-deg), 0)).LookVector)
                            end
                        end
                    end
                    local MIN_DIST = 1.2
                    local MAX_DIST = (ebChainCount > 0) and 6.0 or 8.0
                    local STEP = 0.35
                    local feetY = startPos.Y - 3
                    for _, scanDir in next, allDirs do
                        for dist = MIN_DIST, MAX_DIST, STEP do
                            local pPos = startPos + (scanDir * dist)
                            local pRay = workspace:Raycast(pPos, Vector3.new(0, -40, 0), rp)
                            local fPos = startPos + (scanDir * (dist + STEP))
                            local fRay = workspace:Raycast(fPos, Vector3.new(0, -40, 0), rp)
                            local isCandidate = false
                            if pRay and pRay.Normal.Y > 0.4 and pRay.Position.Y <= feetY + 1.5 and pRay.Position.Y >= feetY - 60 then
                                if not fRay then
                                    isCandidate = true
                                elseif math.abs(pRay.Position.Y - fRay.Position.Y) > 0.5 then
                                    isCandidate = true
                                end
                            end
                            if isCandidate then
                                local pt = Vector3.new(pPos.X, pRay.Position.Y, pPos.Z) + Vector3.new(scanDir.X, 0, scanDir.Z) * (STEP * 0.5)
                                local skipChain = ebChainCount > 0 and ebLastEdgeY and pt.Y > ebLastEdgeY - 1.0
                                if not skipChain then
                                    local toEdge = pt - startPos
                                    local horizDir = Vector3.new(toEdge.X, 0, toEdge.Z)
                                    if horizDir.Magnitude >= MIN_DIST then
                                        local obstruct = workspace:Raycast(startPos, horizDir, rp)
                                        local blocked = false
                                        if obstruct then
                                            local distToHit = (obstruct.Position - startPos).Magnitude
                                            if distToHit < horizDir.Magnitude - 0.6 and obstruct.Position.Y > pt.Y - 1.5 then
                                                blocked = true
                                            end
                                        end
                                        local edgeWallCheck = workspace:Raycast(pt + Vector3.new(0, 0.5, 0), Vector3.new(0, 2, 0), rp)
                                        if edgeWallCheck then blocked = true end
                                        if not blocked then
                                            local dropRay = workspace:Raycast(pt + (scanDir * 1.05) + Vector3.new(0, 0.2, 0), Vector3.new(0, -120, 0), rp)
                                            local dropDepth = dropRay and (pt.Y - dropRay.Position.Y) or 120
                                            local minDrop = (ebChainCount > 0) and 1.5 or 0.35
                                            if dropDepth >= minDrop then
                                                local edgeDir = horizDir.Unit
                                                local camAlign = camDir and math.max(0, edgeDir:Dot(camDir)) or 0
                                                local velAlign = velDir and math.max(0, edgeDir:Dot(velDir)) or 0
                                                local alignment = (camDir and velDir) and (camAlign * 0.55 + velAlign * 0.45) or (camAlign + velAlign)
                                                local d = horizDir.Magnitude
                                                local score = d - (alignment * 4.0) - math.min(dropDepth, 30) * 0.05
                                                if score < bestScore then
                                                    bestScore = score
                                                    bestEdgePoint = pt
                                                    bestEdgeDir = scanDir
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if bestEdgePoint then
                        ebEdgePos = bestEdgePoint
                    end
                end
                
                if ebEdgePos then
                    local pullVec = (Vector3.new(ebEdgePos.X, 0, ebEdgePos.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z))
                    local pullDist = pullVec.Magnitude
                    local feetY = hrp.Position.Y - 3
                    local altitude = feetY - ebEdgePos.Y
                    local ENGAGE_ALT = 22
                    local engaged = altitude <= ENGAGE_ALT and altitude > -5.0
                    if pullDist > 12.0 or altitude < -5.0 then
                        ebEdgePos = nil
                    elseif engaged then
                        local flatHRP = Vector3.new(vel.X, 0, vel.Z)
                        if pullDist > 0.1 and flatHRP.Magnitude > 5.0 then
                            local altProx = math.clamp(1 - (altitude / ENGAGE_ALT), 0, 1)
                            local distProx = math.clamp(1 - (pullDist / 12.0), 0, 1)
                            local proximity = altProx * 0.6 + distProx * 0.4
                            local cfLerp = 0.03 + 0.07 * proximity
                            local velLerp = 0.025 + 0.065 * proximity
                            local targetPos = Vector3.new(ebEdgePos.X, hrp.Position.Y, ebEdgePos.Z)
                            hrp.CFrame = hrp.CFrame:Lerp(CFrame.new(targetPos) * (hrp.CFrame - hrp.CFrame.Position), cfLerp)
                            local curDir = flatHRP.Unit
                            local newDir = curDir:Lerp(pullVec.Unit, velLerp).Unit
                            hrp.AssemblyLinearVelocity = Vector3.new(newDir.X * flatHRP.Magnitude, vel.Y, newDir.Z * flatHRP.Magnitude)
                        end
                    end
                end
            elseif state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Climbing then
                ebWasFalling = false
                ebEdgePos = nil
                ebChainCount = 0
                ebLastEdgeY = nil
                ebLoggedSeek = false
            end
            
            if ebWasFalling and ebEdgePos and state == Enum.HumanoidStateType.Landed then
                local rp = RaycastParams.new()
                rp.FilterDescendantsInstances = {char}
                rp.FilterType = Enum.RaycastFilterType.Exclude
                local landDist = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(ebEdgePos.X, 0, ebEdgePos.Z)).Magnitude
                local feetY = hrp.Position.Y - 3
                local edgeDelta = math.abs(feetY - ebEdgePos.Y)
                local landRay = workspace:Raycast(hrp.Position, Vector3.new(0, -6, 0), rp)
                local onEdgeSurface = landRay and math.abs(landRay.Position.Y - ebEdgePos.Y) < 0.4
                if landDist < 3.5 and (onEdgeSurface or edgeDelta < 1.1) and velocity.Y > -80 then
                    ebLastEdgeY = ebEdgePos.Y
                    ebEdgePos = nil
                    if not ebDebounce then
                        ebDebounce = true
                        ebChainCount = ebChainCount + 1
                        getgenv().hookJP = 0
                        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
                        task.wait()
                        if not (hrp and hrp.Parent) then
                            ebDebounce = false
                            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                            return
                        end
                        local vX, vZ = velocity.X, velocity.Z
                        local flatSpeed = Vector3.new(vX, 0, vZ).Magnitude
                        local boostMult = flatSpeed > 5 and 1.0 or 1.15
                        local flatDir = Vector3.new(vX, 0, vZ)
                        local moveDir = flatDir.Magnitude > 0.5 and flatDir.Unit or hrp.CFrame.LookVector
                        hum:ChangeState(Enum.HumanoidStateType.Freefall)
                        hrp.AssemblyLinearVelocity = Vector3.new(
                            vX * boostMult + moveDir.X * 2.5,
                            0,
                            vZ * boostMult + moveDir.Z * 2.5
                        )
                        hrp.CFrame = hrp.CFrame + (moveDir * 0.5)
                        getgenv().hookJP = nil
                        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                        getgenv().lastEdgebugTime = tick()
                        ebCooldown = tick()
                        task.delay(0.15, function()
                            ebDebounce = false
                        end)
                    end
                else
                    ebEdgePos = nil
                end
            end
        end

        
        
        
        if isGrounded then
            getgenv()._ph_jbWasGrounded = true
            getgenv()._ph_jbHasBoosted = nil
        end
        if CB_GetFlag("misc_jumpbug") and isHeld("misc_jumpbug_kb") then
            if velocity.Y > 1 and getgenv()._ph_jbWasGrounded and not getgenv()._ph_jbHasBoosted then
                local boostVal = CB_GetFlagNumber("misc_jb_height") or 3.5
                local multiplier = 0.8
                hrp.Velocity = Vector3.new(velocity.X, velocity.Y + (boostVal * multiplier), velocity.Z)
                getgenv()._ph_jbHasBoosted = true
                getgenv()._ph_jbWasGrounded = false
                getgenv().lastJumpbugTime = tick()
            end
        end

        
        
        
        if getgenv()._ph_minijumpActive then
            if tick() - (getgenv()._ph_mjArmedTime or 0) > 1.5 then
                getgenv()._ph_minijumpActive = nil
            elseif velocity.Y > 2 then
                local mult = (CB_GetFlagNumber("misc_mj_mult") or 50) / 100
                hrp.Velocity = Vector3.new(velocity.X, velocity.Y * mult, velocity.Z)
                getgenv()._ph_minijumpActive = nil
            end
        end
        if CB_GetFlag("misc_minijump") and isHeld("misc_minijump_kb") then
            local lastTime = getgenv()._ph_lastMinijumpTime or 0
            if tick() - lastTime > 0.15 then
                getgenv()._ph_lastMinijumpTime = tick()
                getgenv()._ph_minijumpActive = true
                getgenv()._ph_mjArmedTime = tick()
            end
        end

        
        
        
        if CB_GetFlag("misc_longjump") and isHeld("misc_longjump_kb") then
            if isInAir then
                local ljStuds = CB_GetFlagNumber("misc_lj_studs") or 5
                local dir = hum.MoveDirection
                if dir.Magnitude > 0 then
                    hrp.Velocity = Vector3.new(dir.X * ljStuds * 4, hrp.Velocity.Y, dir.Z * ljStuds * 4)
                    getgenv().lastLongJumpTime = tick()
                end
            end
        end

        
        
        
        do
            local bv = hrp:FindFirstChild("PH_PixelSurfVelocity")
            if not bv then
                bv = Instance.new("BodyVelocity")
                bv.Name = "PH_PixelSurfVelocity"
                bv.MaxForce = Vector3.new(0, 0, 0)
                bv.Parent = hrp
            end
            local isMoveHeld = CB_UIS:IsKeyDown(Enum.KeyCode.W) or CB_UIS:IsKeyDown(Enum.KeyCode.S) or CB_UIS:IsKeyDown(Enum.KeyCode.A) or CB_UIS:IsKeyDown(Enum.KeyCode.D)
            if CB_GetFlag("misc_pixelsurf") and isHeld("misc_pixelsurf_kb") and isMoveHeld and isInAir then
                surfing = true
                local wallPart, wallNormal, wallPos = findWallHit()
                getgenv().pixelSurfTouching = wallPart ~= nil
                if wallPart and wallNormal then
                    if lastWallNormal and wallNormal:Dot(lastWallNormal) < 0.9 then
                        surfing = false
                        bv.MaxForce = Vector3.new(0, 0, 0)
                        lastWallNormal = nil
                        getgenv().pixelSurfTouching = false
                    else
                        lastWallNormal = wallNormal
                        local pspeed = CB_GetFlagNumber("misc_ps_speed") or 25
                        local moveDir = hum.MoveDirection
                        local horizNormal = Vector3.new(wallNormal.X, 0, wallNormal.Z).Unit
                        local glideDir = Vector3.new(0, 0, 0)
                        if moveDir.Magnitude > 0.1 then
                            local horizMove = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
                            local projected = horizMove - horizNormal * horizMove:Dot(horizNormal)
                            if projected.Magnitude > 0.01 then
                                glideDir = projected.Unit
                            end
                        else
                            local horizVel = Vector3.new(velocity.X, 0, velocity.Z)
                            if horizVel.Magnitude > 1 then
                                local projected = horizVel.Unit - horizNormal * horizVel.Unit:Dot(horizNormal)
                                if projected.Magnitude > 0.01 then
                                    glideDir = projected.Unit
                                end
                            end
                        end
                        bv.Velocity = Vector3.new(glideDir.X * pspeed, 0, glideDir.Z * pspeed)
                        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    end
                else
                    bv.MaxForce = Vector3.new(0, 0, 0)
                    lastWallNormal = nil
                    getgenv().pixelSurfTouching = false
                end
            else
                surfing = false
                if bv then bv.MaxForce = Vector3.new(0, 0, 0) end
                lastWallNormal = nil
                getgenv().pixelSurfTouching = false
            end
        end

        
        
        
        if CB_GetFlag("misc_airstuck") then
            local shouldAnchor = isHeld("misc_airstuck_kb")
            hrp.Anchored = shouldAnchor
            if shouldAnchor then
                hrp.Velocity = Vector3.new()
                local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
                if torso then torso.Velocity = Vector3.new() end
            end
        end

        
        
        
        if CB_GetFlag("misc_headboost") and isHeld("misc_headboost_kb") then
            local enemy, dist = getClosestEnemy()
            if enemy and dist < 12 then
                local targetHead = enemy.Character:FindFirstChild("Head") or enemy.Character:FindFirstChild("HumanoidRootPart")
                if targetHead then
                    local heightDiff = hrp.Position.Y - targetHead.Position.Y
                    local horizDist = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(targetHead.Position.X, 0, targetHead.Position.Z)).Magnitude
                    if heightDiff > 1.5 and heightDiff < 4.5 and horizDist < 3.5 then
                        headbounceWasRiding = true
                        local targetPos = targetHead.Position
                        local steer = (Vector3.new(targetPos.X, 0, targetPos.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)) * 6
                        local move = hum.MoveDirection or Vector3.new()
                        hrp.AssemblyLinearVelocity = Vector3.new(steer.X + move.X * 14, hrp.AssemblyLinearVelocity.Y, steer.Z + move.Z * 14) + targetHead.AssemblyLinearVelocity
                    else
                        headbounceWasRiding = false
                    end
                end
            else
                if headbounceWasRiding then
                    headbounceWasRiding = false
                    local dir = hum.MoveDirection
                    if dir.Magnitude < 0.1 then dir = hrp.CFrame.LookVector * Vector3.new(1,0,1) end
                    if dir.Magnitude > 0 then dir = dir.Unit end
                    hrp.AssemblyLinearVelocity = dir * 45 + Vector3.new(0, 22, 0)
                end
            end
        else
            if headbounceWasRiding then
                headbounceWasRiding = false
                local dir = hum.MoveDirection
                if dir.Magnitude < 0.1 then dir = hrp.CFrame.LookVector * Vector3.new(1,0,1) end
                if dir.Magnitude > 0 then dir = dir.Unit end
                hrp.AssemblyLinearVelocity = dir * 45 + Vector3.new(0, 22, 0)
            end
        end


        
        
        if CB_GetFlag("misc_ladderbug") and isHeld("misc_ladderbug_kb") then
            if state == Enum.HumanoidStateType.Climbing then
                local climbDir = hum.MoveDirection
                if climbDir.Magnitude > 0.1 then
                    hrp.Velocity = Vector3.new(hrp.Velocity.X, hrp.Velocity.Y + 8, hrp.Velocity.Z) + climbDir * 3
                end
            end
        end

        
        
        
        if CB_GetFlag("misc_jetpack") and isHeld("misc_jetpack_kb") then
            local speedLimit = CB_GetFlagNumber("misc_jetpack_speed") or 35
            local currentY = hrp.Velocity.Y
            if currentY < 0 then currentY = 0 end
            hrp.Velocity = Vector3.new(hrp.Velocity.X, math.min(currentY + 1.2, speedLimit), hrp.Velocity.Z)
        end

        
        
        
        if CB_GetFlag("misc_noclip") and isHeld("misc_noclip_kb") then
            for _, part in next, char:GetDescendants() do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)

    
    
    
    CB_RunService.Heartbeat:Connect(function(dt)
        if not CB_GetFlag("misc_fireman") or not isHeld_global("misc_fireman_kb") then
            fmCanBoost = false
            fmWasOnLadder = false
            return
        end
        local char = CB_LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if not hrp or not hum then return end

        fmWasOnLadder = fmIsOnLadder
        fmIsOnLadder = detectLadder()
        local vel = hrp.AssemblyLinearVelocity
        local fmBoost = CB_GetFlagNumber("misc_fm_boost") or 50

        if fmIsOnLadder then
            local dir = hum.MoveDirection
            if dir.Magnitude > 0.1 then
                dir = dir.Unit
                local horizontalVel = Vector3.new(vel.X, 0, vel.Z)
                local horizontalSpeed = horizontalVel.Magnitude
                local boostedHorizontal = dir * math.max(horizontalSpeed, 16)
                local verticalBoost = vel.Y * 2.5
                hrp.AssemblyLinearVelocity = Vector3.new(boostedHorizontal.X, verticalBoost, boostedHorizontal.Z)
            end
            fmCanBoost = true
        elseif fmWasOnLadder and not fmIsOnLadder and fmCanBoost then
            if (tick() - fmLastCooldown) > 0.2 then
                fmLastCooldown = tick()
                fmCanBoost = false
                local dir = hum.MoveDirection
                if dir.Magnitude < 0.1 then
                    dir = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
                end
                if dir.Magnitude > 0 then dir = dir.Unit end
                local speed = (vel * Vector3.new(1, 0, 1)).Magnitude
                local boostForce = fmBoost * 0.3
                local boostVel = dir * (speed + boostForce)
                local verticalBoost = vel.Y < 0 and 3 or 15
                hrp.AssemblyLinearVelocity = Vector3.new(boostVel.X, verticalBoost, boostVel.Z)
            end
        else
            if not fmIsOnLadder then fmCanBoost = false end
        end
    end)
end


function isHeld_global(keyFlag)
    local key = CB_GetFlag(keyFlag)
    if type(key) == "boolean" then return key end
    if typeof(key) == "EnumItem" then
        if key.EnumType == Enum.KeyCode then
            return CB_UIS:IsKeyDown(key)
        elseif key.EnumType == Enum.UserInputType then
            for _, state in next, CB_UIS:GetMouseButtonsPressed() do
                if state.UserInputType == key then return true end
            end
        end
    end
    return false
end



local function CB_ResolveDummyJoints(clone, hrp)
    local hrpCF = hrp.CFrame
    local resolvedCFrames = {}
    resolvedCFrames[hrp] = CFrame.new(0, 1, 0)

    local function resolveJoints()
        local added = false
        for _, d in clone:GetDescendants() do
            if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
                local p0, p1 = d.Part0, d.Part1
                if p0 and p1 then
                    local c0, c1
                    pcall(function() c0 = d.C0; c1 = d.C1 end)
                    if c0 and c1 then
                        local transform = CFrame.new()
                        if d:IsA("Motor6D") then
                            transform = d.Transform
                            local n = d.Name
                            if n == "Root" or n == "Waist" or n == "Neck" or n:match("Hip") or n:match("Knee")
                                or n:match("Ankle") or n:match("Shoulder") or n:match("Elbow") or n:match("Wrist") then
                                transform = CFrame.new()
                            end
                        end
                        if not resolvedCFrames[p1] and resolvedCFrames[p0] then
                            resolvedCFrames[p1] = resolvedCFrames[p0] * c0 * transform * c1:Inverse()
                            added = true
                        elseif not resolvedCFrames[p0] and resolvedCFrames[p1] then
                            resolvedCFrames[p0] = resolvedCFrames[p1] * c1 * transform:Inverse() * c0:Inverse()
                            added = true
                        end
                    else
                        local rel = p0.CFrame:Inverse() * p1.CFrame
                        if not resolvedCFrames[p1] and resolvedCFrames[p0] then
                            resolvedCFrames[p1] = resolvedCFrames[p0] * rel
                            added = true
                        elseif not resolvedCFrames[p0] and resolvedCFrames[p1] then
                            resolvedCFrames[p0] = resolvedCFrames[p1] * rel:Inverse()
                            added = true
                        end
                    end
                end
            end
        end
        return added
    end

    for _ = 1, 30 do
        if not resolveJoints() then break end
    end

    local origCF = {}
    for _, d in clone:GetDescendants() do
        if d:IsA("BasePart") then
            origCF[d] = d.CFrame
        end
    end

    for _, d in clone:GetDescendants() do
        if d:IsA("BasePart") then
            if resolvedCFrames[d] then
                d.CFrame = resolvedCFrames[d]
            else
                local bestDist = math.huge
                local bestBP = hrp
                for bp, rCF in resolvedCFrames do
                    if bp ~= d and origCF[bp] then
                        local dist = (origCF[bp].Position - origCF[d].Position).Magnitude
                        if dist < bestDist then
                            bestDist = dist
                            bestBP = bp
                        end
                    end
                end
                if origCF[bestBP] and origCF[d] then
                    d.CFrame = resolvedCFrames[bestBP] * (origCF[bestBP]:Inverse() * origCF[d])
                else
                    d.CFrame = resolvedCFrames[hrp] * (hrpCF:Inverse() * d.CFrame)
                end
            end
        end
    end
end

local function CB_BuildStaticR15Dummy(model)
    local parts = {
        {"Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 3.1, 0)},
        {"UpperTorso", Vector3.new(2, 0.8, 1), CFrame.new(0, 1.9, 0)},
        {"LowerTorso", Vector3.new(2, 1, 1), CFrame.new(0, 1.0, 0)},
        {"LeftUpperArm", Vector3.new(1, 1.2, 1), CFrame.new(-1.6, 1.9, 0)},
        {"LeftLowerArm", Vector3.new(1, 1.2, 1), CFrame.new(-1.6, 0.6, 0)},
        {"LeftHand", Vector3.new(1, 0.5, 1), CFrame.new(-1.6, -0.2, 0)},
        {"RightUpperArm", Vector3.new(1, 1.2, 1), CFrame.new(1.6, 1.9, 0)},
        {"RightLowerArm", Vector3.new(1, 1.2, 1), CFrame.new(1.6, 0.6, 0)},
        {"RightHand", Vector3.new(1, 0.5, 1), CFrame.new(1.6, -0.2, 0)},
        {"LeftUpperLeg", Vector3.new(1, 1.2, 1), CFrame.new(-0.5, -0.1, 0)},
        {"LeftLowerLeg", Vector3.new(1, 1.2, 1), CFrame.new(-0.5, -1.4, 0)},
        {"LeftFoot", Vector3.new(1, 0.4, 1), CFrame.new(-0.5, -2.1, 0)},
        {"RightUpperLeg", Vector3.new(1, 1.2, 1), CFrame.new(0.5, -0.1, 0)},
        {"RightLowerLeg", Vector3.new(1, 1.2, 1), CFrame.new(0.5, -1.4, 0)},
        {"RightFoot", Vector3.new(1, 0.4, 1), CFrame.new(0.5, -2.1, 0)},
        {"HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 1, 0), true},
    }
    for _, info in parts do
        local p = Instance.new("Part")
        p.Name = info[1]
        p.Size = info[2]
        p.CFrame = info[3]
        p.Transparency = info[4] and 1 or 0
        p.Color = Color3.fromRGB(180, 180, 180)
        p.Material = Enum.Material.SmoothPlastic
        p.Anchored = true
        p.CanCollide = false
        p.Parent = model
    end
    local hum = Instance.new("Humanoid", model)
    hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    model.PrimaryPart = model:FindFirstChild("HumanoidRootPart")
end

getgenv().CB_CreateDummy = function(targetModel)
    local model = targetModel or Instance.new("Model")
    model.Name = "PreviewDummy"
    model:ClearAllChildren()

    local ok = false
    local src = nil
    pcall(function()
        for _, plr in CB_Players:GetPlayers() do
            if plr ~= CB_LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                src = plr.Character
                break
            end
        end
        if not src then
            local me = CB_LocalPlayer.Character
            if me and me:FindFirstChild("HumanoidRootPart") then src = me end
        end
    end)

    if src then
        pcall(function()
            src.Archivable = true
            for _, d in src:GetDescendants() do
                pcall(function() d.Archivable = true end)
            end
            local clone = src:Clone()
            if clone then
                for _, d in clone:GetDescendants() do
                    if d:IsA("BaseScript") or d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
                    if d:IsA("BillboardGui") or d:IsA("ForceField") then d:Destroy() end
                    if d:IsA("BasePart") then
                        d.Anchored = true
                        d.CanCollide = false
                    end
                end
                for _, d in clone:GetChildren() do
                    if d:IsA("Accessory") then
                    elseif d:IsA("Tool") or d:IsA("BackpackItem") or d:IsA("Folder") then
                        d:Destroy()
                    elseif d:IsA("Model") then
                        d:Destroy()
                    elseif d:IsA("BasePart") and not (d.Name:match("Torso") or d.Name:match("Leg") or d.Name:match("Arm") or d.Name:match("Hand")
                        or d.Name:match("Foot") or d.Name == "Head" or d.Name == "HumanoidRootPart"
                        or d.Name == "FakeHead" or d.Name == "Hitbox"
                    ) then
                        d:Destroy()
                    end
                end

                local hrp = clone:FindFirstChild("HumanoidRootPart")
                if hrp then
                    CB_ResolveDummyJoints(clone, hrp)
                end

                local hum = clone:FindFirstChildWhichIsA("Humanoid")
                if hum then
                    hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                end

                if #clone:GetChildren() > 3 then
                    for _, child in clone:GetChildren() do
                        child.Parent = model
                    end
                    clone:Destroy()
                    ok = true
                end
            end
        end)
    end

    if not ok then
        pcall(function()
            local desc = Instance.new("HumanoidDescription")
            local built = CB_Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
            if built then
                for _, d in built:GetDescendants() do
                    if d:IsA("BaseScript") or d:IsA("Script") then d:Destroy() end
                    if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false end
                end
                local hrp = built:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local off = hrp.CFrame
                    for _, d in built:GetDescendants() do
                        if d:IsA("BasePart") then d.CFrame = off:Inverse() * d.CFrame end
                    end
                end
                local hum = built:FindFirstChildWhichIsA("Humanoid")
                if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
                for _, d in built:GetChildren() do
                    if d:IsA("Tool") or d:IsA("BackpackItem") then d:Destroy() end
                end
                for _, child in built:GetChildren() do
                    child.Parent = model
                end
                built:Destroy()
                if #model:GetChildren() > 3 then ok = true end
            end
        end)
    end

    if not ok then
        CB_BuildStaticR15Dummy(model)
        ok = true
    end

    local hrp = model:FindFirstChild("HumanoidRootPart", true)
    if hrp then
        model.PrimaryPart = hrp
    end

    return model
end

task.spawn(function()
    while task.wait(3) do
        pcall(function()
            if not isfolder("Pulsehack/dumps") then makefolder("Pulsehack/dumps") end
            local lines = {}
            table.insert(lines, "=== ESP/COMBAT DEBUG LOG ===")
            table.insert(lines, "Time: " .. tostring(os.time()))
            table.insert(lines, "esp_enemies_enable: " .. tostring(CB_GetFlag("esp_enemies_enable", false)))
            table.insert(lines, "esp_friendlies_enable: " .. tostring(CB_GetFlag("esp_friendlies_enable", false)))
            table.insert(lines, "esp_enemies_box_enabled: " .. tostring(CB_GetFlag("esp_enemies_box_enabled", true)))
            table.insert(lines, "Target: " .. tostring(getgenv().target))
            table.insert(lines, "Silent Aim FOV Enabled: " .. tostring(CB_GetFlag(CB_State.prefix.."_br_fov_on", false) or CB_GetFlag("br_fov_enabled", false)))

            for _, plr in CB_Players:GetPlayers() do
                if plr ~= CB_LocalPlayer then
                    local pfx = CB_GetESPPrefix(plr)
                    local isVis = false
                    if plr.Character and plr.Character:FindFirstChild("Head") then
                        isVis = CB_VisCheck(workspace.CurrentCamera.CFrame.Position, plr.Character.Head.Position, plr)
                    end
                    table.insert(lines, "Plr: " .. plr.Name .. " Prefix: " .. tostring(pfx) .. " Vis: " .. tostring(isVis) .. " TeamEnemy: " .. tostring(CB_TeamCheck(plr)))
                end
            end
            writefile("Pulsehack/dumps/esp_debug.txt", table.concat(lines, "\n"))
        end)
    end
end)

task.spawn(function()
    while task.wait(5) do
        pcall(function()
            local espEnabled = CB_GetFlag("esp_enemies_enable", false)
            local boxEnabled = CB_GetFlag("esp_enemies_box_enabled", true)
            local playersFound = 0
            for _, plr in CB_Players:GetPlayers() do
                if plr ~= CB_LocalPlayer and plr.Character and plr.Character:FindFirstChild("Head") then playersFound = playersFound + 1 end
            end
        end)
    end
end)


local CB_AllSleeves = {"Default", "None"}
local CB_SleeveTemplates = {}

local function findArmSleeve(arm)
    if not arm then return nil end
    for _, d in arm:GetDescendants() do
        if string.find(string.lower(d.Name), "sleeve") and (d:IsA("BasePart") or d:IsA("MeshPart")) then
            return d
        end
    end
    return nil
end

local function modelHasSleeve(model)
    if not model then return false end
    for _, d in model:GetDescendants() do
        if string.find(string.lower(d.Name), "sleeve") and (d:IsA("BasePart") or d:IsA("MeshPart")) then
            return true
        end
    end
    return false
end

local function getSideFromSleeve(part)
    local path = string.lower(part.Name)
    local parent = part.Parent
    while parent do
        path = path .. " " .. string.lower(parent.Name)
        parent = parent.Parent
    end
    if string.find(path, "right") or string.find(path, "rarm") or string.find(path, "r_") then return "R" end
    if string.find(path, "left") or string.find(path, "larm") or string.find(path, "l_") then return "L" end
    return nil
end

local function sleeveTemplateName(name, model)
    name = tostring(name or "Sleeve"):gsub("^v_", ""):gsub("Arms$", "")
    if not CB_SleeveTemplates[name] then return name end
    local parentName = model and model.Parent and model.Parent.Name or "Model"
    local altName = parentName .. " " .. name
    if not CB_SleeveTemplates[altName] then return altName end
    local i = 2
    while CB_SleeveTemplates[altName .. " " .. tostring(i)] do i = i + 1 end
    return altName .. " " .. tostring(i)
end

local function registerSleeveTemplate(name, model)
    if not name or not model then return end
    local rArm = model and model:FindFirstChild("Right Arm", true)
    local lArm = model and model:FindFirstChild("Left Arm", true)
    local rSleeve = findArmSleeve(rArm)
    local lSleeve = findArmSleeve(lArm)
    if not rSleeve or not lSleeve then
        for _, d in model:GetDescendants() do
            if string.find(string.lower(d.Name), "sleeve") and (d:IsA("BasePart") or d:IsA("MeshPart")) then
                local side = getSideFromSleeve(d)
                if side == "R" and not rSleeve then rSleeve = d
                elseif side == "L" and not lSleeve then lSleeve = d
                elseif not rSleeve then rSleeve = d
                elseif not lSleeve then lSleeve = d end
            end
        end
    end
    if rSleeve or lSleeve then
        name = sleeveTemplateName(name, model)
        local rOffset = (rSleeve and rArm) and rArm.CFrame:ToObjectSpace(rSleeve.CFrame) or nil
        local lOffset = (lSleeve and lArm) and lArm.CFrame:ToObjectSpace(lSleeve.CFrame) or nil
        CB_SleeveTemplates[name] = {
            R = rSleeve and rSleeve:Clone() or nil,
            L = lSleeve and lSleeve:Clone() or nil,
            RO = rOffset,
            LO = lOffset,
        }
        table.insert(CB_AllSleeves, name)
        return name
    end
end

local CB_ScannedSleeveModels = {}
local function scanSleeveRoot(root)
    if not root then return end
    pcall(function()
        if root:IsA("Model") and not CB_ScannedSleeveModels[root] and modelHasSleeve(root) then
            CB_ScannedSleeveModels[root] = true
            registerSleeveTemplate(root.Name, root)
        end
        for _, model in root:GetDescendants() do
            if model:IsA("Model") and not CB_ScannedSleeveModels[model] and modelHasSleeve(model) then
                CB_ScannedSleeveModels[model] = true
                registerSleeveTemplate(model.Name, model)
            end
        end
    end)
end

getgenv().CB_InitSleeveTemplates = function()
    for _, rootName in {"Characters", "CharacterModels", "Agents", "PlayerModels", "Models", "CeeT", "Tee"} do
        scanSleeveRoot(CB_RS:FindFirstChild(rootName))
    end
    scanSleeveRoot(CB_RS)
    table.sort(CB_AllSleeves, function(a, b)
        if a == "Default" then return true end
        if b == "Default" then return false end
        if a == "None" then return true end
        if b == "None" then return false end
        return a < b
    end)
    return CB_AllSleeves
end

local CB_AllGloves = {}

getgenv().CB_InitGloveTemplates = function()
    local glovesFolder = CB_RS:FindFirstChild("Gloves")
    if not glovesFolder then return CB_AllGloves end

    local gloveModels = glovesFolder:FindFirstChild("Models")
    if not gloveModels then return CB_AllGloves end

    for _, gloveTypeFolder in glovesFolder:GetChildren() do
        if gloveTypeFolder:IsA("Folder") and gloveTypeFolder.Name ~= "Models" then
            CB_AllGloves[gloveTypeFolder.Name] = {"Default"}
            for _, skinData in gloveTypeFolder:GetChildren() do
                if skinData:IsA("Folder") or skinData:IsA("Model") then
                    table.insert(CB_AllGloves[gloveTypeFolder.Name], skinData.Name)
                end
            end
            table.sort(CB_AllGloves[gloveTypeFolder.Name])
        end
    end

    return CB_AllGloves
end

local function applySleeveChanger(model, forceTeam)
    if not model then return end
    local team = forceTeam or "T"
    if not forceTeam then
        pcall(function()
            if CB_LocalPlayer:FindFirstChild("Status") and CB_LocalPlayer.Status:FindFirstChild("Team") then
                team = CB_LocalPlayer.Status.Team.Value
            end
        end)
    end

    getgenv().CB_AppliedSleevesCT = getgenv().CB_AppliedSleevesCT or "Default"
    getgenv().CB_AppliedSleevesT = getgenv().CB_AppliedSleevesT or "Default"

    local selected = team == "CT" and getgenv().CB_AppliedSleevesCT or getgenv().CB_AppliedSleevesT
    if type(selected) == "table" then local k, _ = next(selected); selected = k or "Default" end
    if not selected or selected == "" or selected == "None" then return end

    local rArm = model:FindFirstChild("Right Arm") or model:FindFirstChild("Right Arm", true)
    local lArm = model:FindFirstChild("Left Arm") or model:FindFirstChild("Left Arm", true)
    if not rArm and not lArm then return end

    local function isAppliedOk(arm)
        if not arm then return true end
        local s = arm:FindFirstChild("Sleeve")
        if not s then return false end
        return s:GetAttribute("CB_Applied") == selected
    end
    if isAppliedOk(rArm) and isAppliedOk(lArm) then return end

    local originals = model:FindFirstChild("CB_OriginalSleeves")
    local originalR = findArmSleeve(rArm)
    local originalL = findArmSleeve(lArm)
    if not originals then
        if (not originalR and not originalL) and selected == "Default" then return end
        originals = Instance.new("Folder")
        originals.Name = "CB_OriginalSleeves"
        originals.Parent = model
        local function stash(src, name)
            local c = src:Clone()
            c.Name = name
            for _, j in c:GetDescendants() do
                if j:IsA("Weld") or j:IsA("WeldConstraint") or j:IsA("Motor6D") or j:IsA("JointInstance") then j:Destroy() end
            end
            if c:IsA("BasePart") or c:IsA("MeshPart") then
                c.Anchored = true
                c.CanCollide = false
                c.Transparency = 1
            end
            c.Parent = originals
            return c
        end
        if originalR and rArm then
            stash(originalR, "R")
            local off = Instance.new("CFrameValue", originals)
            off.Name = "RO"
            off.Value = rArm.CFrame:ToObjectSpace(originalR.CFrame)
        end
        if originalL and lArm then
            stash(originalL, "L")
            local off = Instance.new("CFrameValue", originals)
            off.Name = "LO"
            off.Value = lArm.CFrame:ToObjectSpace(originalL.CFrame)
        end
    end

    for _, d in model:GetDescendants() do
        if (d:IsA("BasePart") or d:IsA("MeshPart")) and string.find(string.lower(d.Name), "sleeve") then
            if not (d.Parent == originals) then d:Destroy() end
        end
    end

    for _, arm in {rArm, lArm} do
        if arm and (arm:IsA("BasePart") or arm:IsA("MeshPart")) then
            if arm:GetAttribute("CB_OrigTrans") ~= nil then
                arm.Transparency = arm:GetAttribute("CB_OrigTrans")
                arm:SetAttribute("CB_OrigTrans", nil)
            end
        end
    end

    local function attachSleeve(src, arm, offset)
        if not src or not arm then return end
        local sleeve = src:Clone()
        sleeve.Name = "Sleeve"
        sleeve.Anchored = false
        sleeve.CanCollide = false
        sleeve.Massless = true
        sleeve.Transparency = 0
        for _, j in sleeve:GetDescendants() do
            if j:IsA("Weld") or j:IsA("WeldConstraint") or j:IsA("Motor6D") or j:IsA("JointInstance") then j:Destroy() end
        end
        sleeve.Parent = arm
        if offset then sleeve.CFrame = arm.CFrame * offset
        else sleeve.CFrame = arm.CFrame end
        local wc = Instance.new("WeldConstraint")
        wc.Part0 = arm
        wc.Part1 = sleeve
        wc.Parent = sleeve
        sleeve:SetAttribute("CB_Applied", selected)
    end

    if selected == "Default" then
        local rOff = originals:FindFirstChild("RO")
        local lOff = originals:FindFirstChild("LO")
        attachSleeve(originals:FindFirstChild("R"), rArm, rOff and rOff.Value or nil)
        attachSleeve(originals:FindFirstChild("L"), lArm, lOff and lOff.Value or nil)
        return
    end
    if selected == "None" then return end

    local template = CB_SleeveTemplates[selected]
    if not template then return end
    attachSleeve(template.R, rArm, template.RO)
    attachSleeve(template.L, lArm, template.LO)
end



local function applyGloveChanger(model, forceTeam)
    if not model then return end
    local team = forceTeam or "T"
    if not forceTeam then
        pcall(function()
            if CB_LocalPlayer:FindFirstChild("Status") and CB_LocalPlayer.Status:FindFirstChild("Team") then
                team = CB_LocalPlayer.Status.Team.Value
            end
        end)
    end

    getgenv().CB_AppliedGlovesCT = getgenv().CB_AppliedGlovesCT or { model = "None", skin = "Default" }
    getgenv().CB_AppliedGlovesT = getgenv().CB_AppliedGlovesT or { model = "None", skin = "Default" }

    local gloveType = team == "CT" and getgenv().CB_AppliedGlovesCT.model or getgenv().CB_AppliedGlovesT.model
    local gloveSkin = team == "CT" and getgenv().CB_AppliedGlovesCT.skin or getgenv().CB_AppliedGlovesT.skin
    if type(gloveType) == "table" then local k,_=next(gloveType); gloveType = k or "None" end
    if type(gloveSkin) == "table" then local k,_=next(gloveSkin); gloveSkin = k or "Default" end
    if not gloveType then gloveType = "None" end
    if not gloveSkin then gloveSkin = "Default" end
    gloveType = tostring(gloveType)
    gloveSkin = tostring(gloveSkin)

    local glovesFolder = CB_RS:FindFirstChild("Gloves")
    local gloveModels = glovesFolder and glovesFolder:FindFirstChild("Models")

    if gloveType == "None" or not gloveModels or not gloveModels:FindFirstChild(gloveType) then
        return
    end

    local gloveTexData = nil
    local _gloveTex = ""
    if gloveSkin ~= "Default" then
        gloveTexData = glovesFolder:FindFirstChild(gloveType) and glovesFolder[gloveType]:FindFirstChild(gloveSkin)
    end

    if gloveTexData and gloveTexData:FindFirstChild("Textures") then
        _gloveTex = gloveTexData.Textures.TextureId or ""
    elseif gloveTexData then
        for _, texData in gloveTexData:GetChildren() do
            if texData:IsA("StringValue") then
                _gloveTex = texData.Value
                break
            elseif texData:IsA("MeshPart") then
                _gloveTex = texData.TextureID
                break
            end
        end
    end

    local newLG = gloveModels[gloveType]:FindFirstChild("LGlove")
    if newLG then
        newLG = newLG:Clone()
        if newLG:FindFirstChild("Mesh") then
            newLG.Mesh.TextureId = _gloveTex
        else
            pcall(function() newLG.TextureID = _gloveTex end)
        end
        newLG.Name = "CW_OriginalGloves"

        local lArm = model:FindFirstChild("Left Arm") or model:FindFirstChild("LeftArm")
        if lArm then
            local oldGlove = lArm:FindFirstChild("Glove") or lArm:FindFirstChild("LGlove") or lArm:FindFirstChild("CW_OriginalGloves")
            if oldGlove then oldGlove:Destroy() end
            newLG.Transparency = 0
            pcall(function() newLG.Welded.Part0 = lArm end)
            newLG.Parent = lArm
        else
            newLG.CFrame = CFrame.new(-0.8, 0, 0)
            newLG.Anchored = true
            newLG.CanCollide = false
            newLG.Transparency = 0
            newLG.Parent = model
        end
    end

    local newRG = gloveModels[gloveType]:FindFirstChild("RGlove")
    if newRG then
        newRG = newRG:Clone()
        if newRG:FindFirstChild("Mesh") then
            newRG.Mesh.TextureId = _gloveTex
        else
            pcall(function() newRG.TextureID = _gloveTex end)
        end
        newRG.Name = "CW_OriginalGloves"

        local rArm = model:FindFirstChild("Right Arm") or model:FindFirstChild("RightArm")
        if rArm then
            local oldGlove = rArm:FindFirstChild("Glove") or rArm:FindFirstChild("RGlove") or rArm:FindFirstChild("CW_OriginalGloves")
            if oldGlove then oldGlove:Destroy() end
            newRG.Transparency = 0
            pcall(function() newRG.Welded.Part0 = rArm end)
            newRG.Parent = rArm
        else
            newRG.CFrame = CFrame.new(0.8, 0, 0)
            newRG.Anchored = true
            newRG.CanCollide = false
            newRG.Transparency = 0
            newRG.Parent = model
        end
    end
end

getgenv().CB_ReapplyGloveChangerToCurrent = function()
    local cam = workspace.CurrentCamera
    local arms = cam and cam:FindFirstChild("Arms")
    if not arms then return end
    local targets = {}
    for _, v in arms:GetDescendants() do
        if v:IsA("Model") and (v:FindFirstChild("Right Arm") or v:FindFirstChild("Left Arm") or v:FindFirstChild("RightArm") or v:FindFirstChild("LeftArm")) then
            table.insert(targets, v)
        end
    end
    if #targets == 0 then
        applyGloveChanger(arms)
    else
        for _, t in targets do
            local skip = false
            for _, other in targets do
                if other ~= t and other:IsDescendantOf(t) then skip = true; break end
            end
            if not skip then applyGloveChanger(t) end
        end
    end
end

getgenv().CB_ApplyGloveChangerToCurrent = function()
    getgenv().CB_AppliedGlovesCT = { model = CB_GetFlag("misc_skin_glove_ct_model", "None"), skin = CB_GetFlag("misc_skin_glove_ct_skin", "Default") }
    getgenv().CB_AppliedGlovesT = { model = CB_GetFlag("misc_skin_glove_t_model", "None"), skin = CB_GetFlag("misc_skin_glove_t_skin", "Default") }

    if getgenv().CB_ReapplyGloveChangerToCurrent then getgenv().CB_ReapplyGloveChangerToCurrent() end
end


getgenv().CB_ReapplySleeveChangerToCurrent = function()
    local arms = CB_Camera and CB_Camera:FindFirstChild("Arms")
    if not arms then return end
    local targets = {}
    for _, v in arms:GetDescendants() do
        if v:IsA("Model") and (v:FindFirstChild("Right Arm") or v:FindFirstChild("Left Arm") or v:FindFirstChild("RightArm") or v:FindFirstChild("LeftArm")) then
            table.insert(targets, v)
        end
    end
    if #targets == 0 then
        applySleeveChanger(arms)
    else
        for _, t in targets do
            local skip = false
            for _, other in targets do
                if other ~= t and other:IsDescendantOf(t) then skip = true; break end
            end
            if not skip then applySleeveChanger(t) end
        end
    end
end

getgenv().CB_ApplySleeveChangerToCurrent = function()
    getgenv().CB_AppliedSleevesCT = CB_GetFlag("misc_skin_sleeve_ct", "Default")
    getgenv().CB_AppliedSleevesT = CB_GetFlag("misc_skin_sleeve_t", "Default")

    if getgenv().CB_ReapplySleeveChangerToCurrent then getgenv().CB_ReapplySleeveChangerToCurrent() end
end



local CB_AllWeapons = {}
local CB_AllSkins = {}

getgenv().CB_InitSkinTemplates = function()
    local skinsFolder = CB_RS:FindFirstChild("Skins")
    if skinsFolder then
        for _, wepFolder in skinsFolder:GetChildren() do
            if wepFolder:IsA("Folder") then
                table.insert(CB_AllWeapons, wepFolder.Name)
                CB_AllSkins[wepFolder.Name] = {"Default"}
                for _, skinFolder in wepFolder:GetChildren() do
                    if skinFolder:IsA("Folder") or skinFolder:IsA("Model") then
                        table.insert(CB_AllSkins[wepFolder.Name], skinFolder.Name)
                    end
                end
            end
        end
        table.sort(CB_AllWeapons)
    end
    return CB_AllWeapons, CB_AllSkins
end

getgenv().CB_GetTrueWeaponName = function(weaponName)
    if not weaponName then return nil end
    local skinsFolder = CB_RS:FindFirstChild("Skins")
    if not skinsFolder then return weaponName end

    local wepFolder = skinsFolder:FindFirstChild(weaponName)
    if wepFolder then return weaponName end

    local strippedTarget = weaponName:gsub("[%p%c%s]", ""):lower()
    for _, child in skinsFolder:GetChildren() do
        if child.Name:gsub("[%p%c%s]", ""):lower() == strippedTarget then
            return child.Name
        end
    end
    return weaponName
end

getgenv().CB_ApplyWeaponSkin = function(viewmodel, weaponName, skinName, isPreview, isMelee)
    if not viewmodel or not weaponName or not skinName or skinName == "Default" then
        return
    end

    local skinsFolder = CB_RS:FindFirstChild("Skins")
    if not skinsFolder then print("[SkinChanger] Aborted: No Skins folder.") return end

    local wepForSkin = getgenv().CB_GetTrueWeaponName(weaponName)
    if (wepForSkin == "CT Knife" or wepForSkin == "T Knife") and not skinsFolder:FindFirstChild(wepForSkin) then
        wepForSkin = "M9 Bayonet"
    end

    local wepFolder = skinsFolder:FindFirstChild(wepForSkin)
    if not wepFolder then return end

    local targetSkin = wepFolder:FindFirstChild(skinName)
    if not targetSkin then return end
    if targetSkin:FindFirstChild("Animated") then return end

    local function applySkinToPart(targetPart)
        if targetPart:IsA("BasePart") or targetPart:IsA("MeshPart") then
            local tex = nil
            local wm = targetSkin:FindFirstChild("WorldModel")

            for _, Data in next, targetSkin:GetDescendants() do
                if wm and Data:IsDescendantOf(wm) then continue end
                local cleanDataName = Data.Name:gsub("^#%s*", "")
                if cleanDataName == targetPart.Name or string.match(cleanDataName, "^" .. targetPart.Name .. "%d*$") or (targetPart.Name == "Main" and (cleanDataName == "Part1" or cleanDataName == "Part")) then
                    if Data:IsA("StringValue") then tex = Data.Value
                    elseif Data:IsA("MeshPart") then tex = Data.TextureID
                    elseif Data:IsA("Decal") or Data:IsA("Texture") then tex = Data.Texture
                    elseif Data:IsA("SurfaceAppearance") then tex = Data end
                    if tex and tex ~= "" and tex ~= "rbxassetid://0" then break end
                end
            end
            if not tex or tex == "" then
                for _, Data in next, targetSkin:GetDescendants() do
                    if wm and Data:IsDescendantOf(wm) then continue end
                    local cleanDataName = Data.Name:gsub("^#%s*", "")
                    if cleanDataName == "Handle" and (targetPart.Name == "Blade" or targetPart.Name == "Main") then
                        if Data:IsA("StringValue") then tex = Data.Value
                        elseif Data:IsA("MeshPart") then tex = Data.TextureID
                        elseif Data:IsA("Decal") or Data:IsA("Texture") then tex = Data.Texture
                        elseif Data:IsA("SurfaceAppearance") then tex = Data end
                        if tex and tex ~= "" and tex ~= "rbxassetid://0" then break end
                    end
                end
            end
            if not tex or tex == "" then
                if wm then
                    for _, Data in next, wm:GetDescendants() do
                        local cleanDataName = Data.Name:gsub("^#%s*", "")
                        if cleanDataName == targetPart.Name or string.match(cleanDataName, "^" .. targetPart.Name .. "%d*$") or (targetPart.Name == "Main" and (cleanDataName == "Part1" or cleanDataName == "Part")) then
                            if Data:IsA("StringValue") then tex = Data.Value
                            elseif Data:IsA("MeshPart") then tex = Data.TextureID
                            elseif Data:IsA("Decal") or Data:IsA("Texture") then tex = Data.Texture
                            elseif Data:IsA("SurfaceAppearance") then tex = Data end
                            if tex and tex ~= "" and tex ~= "rbxassetid://0" then break end
                        end
                    end
                end
            end
            if not tex or tex == "" then
                if wm then
                    for _, Data in next, wm:GetDescendants() do
                        local cleanDataName = Data.Name:gsub("^#%s*", "")
                        if cleanDataName == "Handle" and (targetPart.Name == "Blade" or targetPart.Name == "Main") then
                            if Data:IsA("StringValue") then tex = Data.Value
                            elseif Data:IsA("MeshPart") then tex = Data.TextureID
                            elseif Data:IsA("Decal") or Data:IsA("Texture") then tex = Data.Texture
                            elseif Data:IsA("SurfaceAppearance") then tex = Data end
                            if tex and tex ~= "" and tex ~= "rbxassetid://0" then break end
                        end
                    end
                end
            end
            if tex then
                local existingSA = targetPart:FindFirstChildWhichIsA("SurfaceAppearance")
                if existingSA then existingSA:Destroy() end

                if typeof(tex) == "Instance" and tex:IsA("SurfaceAppearance") then
                    local clone = tex:Clone()
                    clone.Parent = targetPart
                elseif targetPart:IsA("MeshPart") then
                    targetPart.TextureID = tex
                elseif targetPart:FindFirstChild("Mesh") then
                    targetPart.Mesh.TextureId = tex
                else
                    pcall(function() targetPart.TextureID = tex end)
                end
            end
        end
    end

    for _, targetPart in next, viewmodel:GetDescendants() do
        applySkinToPart(targetPart)
    end

    if not isPreview then
        local skinConn = viewmodel.DescendantAdded:Connect(applySkinToPart)
        viewmodel.AncestryChanged:Connect(function(_, newParent)
            if not newParent and skinConn then
                skinConn:Disconnect()
            end
        end)
    end
end

getgenv().CB_UpdateSkinPreview = function(weaponName, skinName, mode)
    local targets = getgenv().CB_PreviewTargets
    if not targets then return end

    local skinsTarget = nil
    for _, t in targets do
        if t.id == "skins" then skinsTarget = t; break end
    end

    if not skinsTarget or not skinsTarget.model then return end

    skinsTarget.model:ClearAllChildren()

    local clone
    local team = "T"
    if mode == "Glove" or mode == "Sleeve" then
        team = weaponName or "T"
        clone = Instance.new("Model")
        clone.Name = mode .. "Preview"
    else
        local wepTemplate
        local isExtModel = false
        local vmName = "v_" .. weaponName
        local viewmodels = CB_RS:FindFirstChild("Viewmodels")
        local srcVM = viewmodels and viewmodels:FindFirstChild(vmName)

        if not srcVM then
            local extModels = getgenv().CB_ExtModels
            if not extModels then
                pcall(function() extModels = game:GetObjects("rbxassetid://7285197035")[1] end)
                getgenv().CB_ExtModels = extModels
            end
            if extModels and extModels:FindFirstChild("Knives") then
                srcVM = extModels.Knives:FindFirstChild(weaponName)
                isExtModel = true
            end
        end

        if not srcVM then
            srcVM = CB_RS:FindFirstChild("Weapons") and CB_RS.Weapons:FindFirstChild(weaponName)
        end

        if srcVM then
            pcall(function()
                srcVM.Archivable = true
                for _, d in srcVM:GetDescendants() do
                    pcall(function() d.Archivable = true end)
                end
            end)

            clone = srcVM:Clone()
            if not clone then return end

            for _, d in clone:GetDescendants() do
                if d:IsA("BaseScript") or d:IsA("Script") or d:IsA("LocalScript") then
                    d:Destroy()
                end
            end

            pcall(function()
                if CB_LocalPlayer:FindFirstChild("Status") and CB_LocalPlayer.Status:FindFirstChild("Team") then
                    team = CB_LocalPlayer.Status.Team.Value
                end
            end)

            if team == "T" and CB_GetFlag("misc_skin_glove_t_model", "None") == "None" and CB_GetFlag("misc_skin_sleeve_t", "Default") == "Default" then
                if CB_GetFlag("misc_skin_glove_ct_model", "None") ~= "None" or CB_GetFlag("misc_skin_sleeve_ct", "Default") ~= "Default" then
                    team = "CT"
                end
            elseif team == "CT" and CB_GetFlag("misc_skin_glove_ct_model", "None") == "None" and CB_GetFlag("misc_skin_sleeve_ct", "Default") == "Default" then
                if CB_GetFlag("misc_skin_glove_t_model", "None") ~= "None" or CB_GetFlag("misc_skin_sleeve_t", "Default") ~= "Default" then
                    team = "T"
                end
            end

            for _, d in clone:GetDescendants() do
                if d:IsA("BasePart") then
                    local n = d.Name:lower()
                    if n == "left arm" or n == "right arm" or n == "rglove" or n == "lglove" or n == "glove" or n:find("fake") then
                        d.Transparency = 1
                    end
                    d.Anchored = true
                    d.CanCollide = false
                end
            end
        else
            return
        end
    end

    local sleeveEnabled = mode == "Sleeve" or (mode == nil and ((team == "CT" and CB_GetFlag("misc_skin_sleeve_ct", "Default") ~= "Default") or (team == "T" and CB_GetFlag("misc_skin_sleeve_t", "Default") ~= "Default")))
    local gloveModel = CB_GetFlag("misc_skin_glove_" .. team:lower() .. "_model", "None")
    if type(gloveModel) == "table" then
        local k, _ = next(gloveModel)
        gloveModel = k or "None"
    end
    if not gloveModel then gloveModel = "None" end
    gloveModel = tostring(gloveModel)

    local gloveEnabled = mode == "Glove" or (mode == nil and gloveModel ~= "None")
    local showArms = sleeveEnabled or gloveEnabled

    if showArms then
        if sleeveEnabled then
                local sName = CB_GetFlag("misc_skin_sleeve_" .. team:lower(), "Default")
                if type(sName) == "table" then
                    local k, _ = next(sName)
                    sName = k or "Default"
                end
                if not sName then sName = "Default" end
                sName = tostring(sName)

                if CB_SleeveTemplates and CB_SleeveTemplates[sName] then
                    local t = CB_SleeveTemplates[sName]
                    if t.L then
                        local l = t.L:Clone()
                        for _, j in l:GetDescendants() do if j:IsA("JointInstance") or j:IsA("WeldConstraint") then j:Destroy() end end
                        local xOffset = (mode == "Glove" or mode == "Sleeve") and 0.8 or 3
                        l.CFrame = CFrame.new(-xOffset, 0, 0) * (t.LO or CFrame.new())
                        l.Anchored = true
                        l.CanCollide = false
                        l.Transparency = 0
                        l.Parent = clone
                    end
                    if t.R then
                        local r = t.R:Clone()
                        for _, j in r:GetDescendants() do if j:IsA("JointInstance") or j:IsA("WeldConstraint") then j:Destroy() end end
                        local xOffset = (mode == "Glove" or mode == "Sleeve") and 0.8 or 3
                        r.CFrame = CFrame.new(xOffset, 0, 0) * (t.RO or CFrame.new())
                        r.Anchored = true
                        r.CanCollide = false
                        r.Transparency = 0
                        r.Parent = clone
                    end
                end
            end

            if gloveEnabled then
                local glovesFolder = CB_RS:FindFirstChild("Gloves")
                local gloveModelsFolder = glovesFolder and glovesFolder:FindFirstChild("Models")
                if gloveModelsFolder and gloveModelsFolder:FindFirstChild(gloveModel) then
                    local lg = gloveModelsFolder[gloveModel]:FindFirstChild("LGlove")
                    local rg = gloveModelsFolder[gloveModel]:FindFirstChild("RGlove")

                    local tex = ""
                    local gloveModelFolder = glovesFolder:FindFirstChild(gloveModel)
                    if gloveModelFolder then
                        local skinName = CB_GetFlag("misc_skin_glove_" .. team:lower() .. "_skin", "Default")
                        if type(skinName) == "table" then
                            local k, _ = next(skinName)
                            skinName = k or "Default"
                        end
                        if not skinName then skinName = "Default" end
                        local skinFolder = gloveModelFolder:FindFirstChild(tostring(skinName))
                        if skinFolder then
                            if skinFolder:FindFirstChild("Textures") then
                                tex = skinFolder.Textures.TextureId or ""
                            else
                                for _, td in skinFolder:GetChildren() do
                                    if td:IsA("StringValue") then tex = td.Value break
                                    elseif td:IsA("MeshPart") then tex = td.TextureID break end
                                end
                            end
                        end
                    end

                    if lg then
                        local clg = lg:Clone()
                        if clg:FindFirstChild("Mesh") then clg.Mesh.TextureId = tex else pcall(function() clg.TextureID = tex end) end
                        local xOffset = (mode == "Glove" or mode == "Sleeve") and 0.8 or 3
                        clg.CFrame = CFrame.new(-xOffset, 0, 0)
                        clg.Anchored = true
                        clg.CanCollide = false
                        clg.Transparency = 0
                        clg.Parent = clone
                    end
                    if rg then
                        local crg = rg:Clone()
                        if crg:FindFirstChild("Mesh") then crg.Mesh.TextureId = tex else pcall(function() crg.TextureID = tex end) end
                        local xOffset = (mode == "Glove" or mode == "Sleeve") and 0.8 or 3
                        crg.CFrame = CFrame.new(xOffset, 0, 0)
                        crg.Anchored = true
                        crg.CanCollide = false
                        crg.Transparency = 0
                        crg.Parent = clone
                    end
                end
            end
        end

        local minV = Vector3.new(math.huge, math.huge, math.huge)
        local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
        local hasVisible = false

        for _, d in clone:GetDescendants() do
            if d:IsA("BasePart") and d.Transparency < 1 then
                hasVisible = true
                local p = d.Position
                local s = d.Size / 2
                minV = Vector3.new(math.min(minV.X, p.X - s.X), math.min(minV.Y, p.Y - s.Y), math.min(minV.Z, p.Z - s.Z))
                maxV = Vector3.new(math.max(maxV.X, p.X + s.X), math.max(maxV.Y, p.Y + s.Y), math.max(maxV.Z, p.Z + s.Z))
            end
        end

        if not hasVisible then minV = Vector3.new(); maxV = Vector3.new(1,1,1) end

        local center = (minV + maxV) / 2
        local size = (maxV - minV).Magnitude
        local preRot = CFrame.new()

        local corePart = nil
        for _, d in clone:GetDescendants() do
            if d:IsA("BasePart") and d.Transparency < 1 then
                if d.Name:lower() == "handle" or d.Name:lower() == "main" or d.Name:lower() == "blade" then
                    corePart = d
                    break
                end
            end
        end
        if not corePart then
            for _, d in clone:GetDescendants() do
                if d:IsA("BasePart") and d.Transparency < 1 then
                    corePart = d
                    break
                end
            end
        end

        if corePart then
            local coreRotInv = (corePart.CFrame - corePart.Position):Inverse()
            local bMin = Vector3.new(math.huge, math.huge, math.huge)
            local bMax = Vector3.new(-math.huge, -math.huge, -math.huge)

            for _, d in clone:GetDescendants() do
                if d:IsA("BasePart") and d.Transparency < 1 then
                    local relCFrame = coreRotInv * (d.CFrame - corePart.Position)
                    for x = -1, 1, 2 do
                        for y = -1, 1, 2 do
                            for z = -1, 1, 2 do
                                local corner = relCFrame * (d.Size * Vector3.new(x, y, z) / 2)
                                bMin = Vector3.new(math.min(bMin.X, corner.X), math.min(bMin.Y, corner.Y), math.min(bMin.Z, corner.Z))
                                bMax = Vector3.new(math.max(bMax.X, corner.X), math.max(bMax.Y, corner.Y), math.max(bMax.Z, corner.Z))
                            end
                        end
                    end
                end
            end

            local sz = bMax - bMin
            local localCenter = (bMin + bMax) / 2
            local addedRot = CFrame.new()

            if sz.Y > sz.X and sz.Y > sz.Z then
                addedRot = CFrame.Angles(0, 0, math.rad(90))
            elseif sz.Z > sz.X and sz.Z > sz.Y then
                addedRot = CFrame.Angles(0, math.rad(90), 0)
            end

            preRot = addedRot * coreRotInv
            center = corePart.Position + (corePart.CFrame - corePart.Position) * localCenter
            size = sz.Magnitude
        end

        for _, d in clone:GetDescendants() do
            if d:IsA("BasePart") then
                local offset = d.Position - center
                d.CFrame = CFrame.new(preRot * offset) * (preRot * (d.CFrame - d.CFrame.Position))
            end
        end

        clone.Parent = skinsTarget.model

        if mode ~= "Glove" and mode ~= "Sleeve" then
            if getgenv().CB_ApplyWeaponSkin then
                getgenv().CB_ApplyWeaponSkin(skinsTarget.model, weaponName, skinName, true)
            end
        end

        local cam = skinsTarget.vpf and skinsTarget.vpf:FindFirstChildOfClass("Camera")
        if cam then
            local skinDist
            if mode == "Glove" then skinDist = math.clamp(size * 1.1, 4, 15)
            elseif mode == "Sleeve" then skinDist = math.clamp(size * 1.1, 5, 15)
            else skinDist = math.clamp(size * 1.1, 1, 15) end

            local radY = math.rad(-90)
            local radX = 0
            local offset = CFrame.Angles(radX, radY, 0) * Vector3.new(0, 0, skinDist)
            cam.CFrame = CFrame.new(offset, Vector3.new(0, 0, 0))
        end
    end

getgenv().CB_ApplyEquippedKnife = function(team, knifeModel, knifeSkin)
    local rs = game:GetService("ReplicatedStorage")
    local dataEvent = rs:FindFirstChild("Events") and rs.Events:FindFirstChild("DataEvent")

    if dataEvent then
        local equipStr = knifeModel
        if knifeSkin and knifeSkin ~= "None" and knifeSkin ~= "Default" then
            equipStr = knifeModel .. "_" .. knifeSkin
        elseif knifeModel == "CT Knife" or knifeModel == "T Knife" then
            equipStr = knifeModel .. "_Stock"
        end

        local payload = {
            [1] = "EquipItem",
            [2] = team,
            [3] = "Knife",
            [4] = {
                [1] = equipStr
            }
        }
        pcall(function() dataEvent:FireServer(payload) end)
    end

    getgenv().CB_AppliedKnives = getgenv().CB_AppliedKnives or {}
    getgenv().CB_AppliedKnives[team] = {
        Model = knifeModel,
        Skin = knifeSkin
    }

    if not getgenv().CB_OriginalCTKnife then
        local viewmodels = rs:FindFirstChild("Viewmodels")
        if viewmodels then
            local ct = viewmodels:FindFirstChild("v_CT Knife")
            if ct then getgenv().CB_OriginalCTKnife = ct:Clone() end
            local t = viewmodels:FindFirstChild("v_T Knife")
            if t then getgenv().CB_OriginalTKnife = t:Clone() end
        end
    end

    local targetKnifeName = "v_" .. team .. " Knife"
    local viewmodels = rs:FindFirstChild("Viewmodels")
    if viewmodels then
        local existing = viewmodels:FindFirstChild(targetKnifeName)
        if existing then existing:Destroy() end
        task.wait()

        local sourceVM = nil
        if knifeModel == "CT Knife" or knifeModel == "T Knife" then
            if team == "CT" and getgenv().CB_OriginalCTKnife then
                sourceVM = getgenv().CB_OriginalCTKnife
            elseif team == "T" and getgenv().CB_OriginalTKnife then
                sourceVM = getgenv().CB_OriginalTKnife
            end
        else
            sourceVM = viewmodels:FindFirstChild("v_" .. knifeModel)
            if not sourceVM then
                local models = rs:FindFirstChild("Models")
                local knives = models and models:FindFirstChild("Knives")
                if knives then
                    sourceVM = knives:FindFirstChild(knifeModel)
                end
            end
        end

        if sourceVM then
            local clone = sourceVM:Clone()
            clone.Name = targetKnifeName
            clone.Parent = viewmodels
        end
    end
end

CB_Camera.ChildAdded:Connect(function(child)
    if child:IsA("Model") and child.Name == "Arms" then
        CB_RunService.RenderStepped:Wait()

        local env = CB_GetClientEnv()
        if not env or not env.gun or env.gun == "none" then return end

        local wepName = env.gun.Name

        local knownKnives = {
            ["CT Knife"] = true, ["T Knife"] = true, ["Knife"] = true, ["Melee"] = true,
            ["Bayonet"] = true, ["M9 Bayonet"] = true, ["Butterfly Knife"] = true,
            ["Karambit"] = true, ["Gut Knife"] = true, ["Flip Knife"] = true,
            ["Falchion Knife"] = true, ["Huntsman Knife"] = true, ["Banana"] = true,
            ["Bearded Axe"] = true, ["Cleaver"] = true, ["Crowbar"] = true,
            ["Sickle"] = true
        }
        local isMelee = (env.gun:FindFirstChild("Melee") ~= nil) or knownKnives[wepName]

        local team = "CT"
        if game.Players.LocalPlayer.Team and game.Players.LocalPlayer.Team.Name == "Terrorists" then
            team = "T"
        end

        if getgenv().CB_ReapplySleeveChangerToCurrent then
            pcall(getgenv().CB_ReapplySleeveChangerToCurrent)
        end
        if getgenv().CB_ReapplyGloveChangerToCurrent then
            pcall(getgenv().CB_ReapplyGloveChangerToCurrent)
        end

        if getgenv().CB_ApplyWeaponSkin then
            if isMelee or wepName == "CT Knife" or wepName == "T Knife" or wepName == "Knife" then
                if not getgenv().CB_AppliedKnives then
                    getgenv().CB_AppliedKnives = {}
                    pcall(function()
                        local sf = game.Players.LocalPlayer:FindFirstChild("SkinFolder")
                        if sf then
                            local function parseFolder(f, t)
                                if f and f:FindFirstChild("Knife") then
                                    local val = f.Knife.Value
                                    local parts = string.split(val, "_")
                                    if #parts >= 2 then
                                        getgenv().CB_AppliedKnives[t] = {
                                            Model = parts[1],
                                            Skin = table.concat(parts, "_", 2)
                                        }
                                    end
                                end
                            end
                            parseFolder(sf:FindFirstChild("CTFolder"), "CT")
                            parseFolder(sf:FindFirstChild("TFolder"), "T")
                        end
                    end)
                end

                local applied = getgenv().CB_AppliedKnives[team]
                if applied and applied.Skin and applied.Skin ~= "Default" then
                    pcall(getgenv().CB_ApplyWeaponSkin, child, applied.Model, applied.Skin, false, true)
                end
            else
                local trueWepName = getgenv().CB_GetTrueWeaponName and getgenv().CB_GetTrueWeaponName(wepName) or wepName
                local skinFlag = "misc_skin_wep_" .. trueWepName:gsub(" ", "_"):gsub("-", "_")
                local selectedSkin = CB_GetFlag(skinFlag, "Default")

                if selectedSkin and selectedSkin ~= "Default" then
                    pcall(getgenv().CB_ApplyWeaponSkin, child, wepName, selectedSkin, false, false)
                end
            end
        end
    end
end)

task.spawn(function()
    local RunService = game:GetService("RunService")

    local PredictionFolder = Instance.new("Folder")
    PredictionFolder.Name = "CW_GrenadePredictor"
    pcall(function() PredictionFolder.Parent = workspace.Terrain end)
    local gAtts = {}
    local gBeams = {}
    for i = 1, 40 do
        local att = Instance.new("Attachment", PredictionFolder)
        gAtts[i] = att
        if i > 1 then
            local beam = Instance.new("Beam", PredictionFolder)
            beam.Attachment0 = gAtts[i-1]
            beam.Attachment1 = att
            beam.Width0 = 0.2
            beam.Width1 = 0.2
            beam.FaceCamera = true
            beam.Segments = 1
            beam.LightEmission = 1
            beam.LightInfluence = 0
            beam.Transparency = NumberSequence.new(0.2)
            beam.Enabled = false
            gBeams[i-1] = beam
        end
    end
    local gSphere = Instance.new("Part")
    gSphere.Shape = Enum.PartType.Ball
    gSphere.Size = Vector3.new(1.2, 1.2, 1.2)
    gSphere.Material = Enum.Material.Neon
    gSphere.Anchored = true
    gSphere.CanCollide = false
    gSphere.Parent = PredictionFolder
    gSphere.CastShadow = false
    gSphere.Transparency = 1
    local pulseDir = 1
    local pulseVal = 1.0

    local function isHoldingNade()
        local lp = game.Players.LocalPlayer
        if not lp or not lp.Character then return false end
        local gun = lp.Character:FindFirstChild("Gun")
        if gun and gun:FindFirstChild("Grenade") then return true end
        local eqVal = lp.Character:FindFirstChild("EquippedTool")
        if eqVal and type(eqVal.Value) == "string" then
            local weaponDef = game:GetService("ReplicatedStorage"):FindFirstChild("Weapons")
            if weaponDef then
                local w = weaponDef:FindFirstChild(eqVal.Value)
                if w and w:FindFirstChild("Grenade") then return true end
            end
            local n = eqVal.Value:lower()
            if n:find("flash") or n:find("hegren") or n:find("smoke") or n:find("molotov") or n:find("incen") or n:find("decoy") or n:find("grenade") or n:find("nade") then
                return true
            end
        end
        return false
    end

    local function getNadePosition()
        local cam = workspace.CurrentCamera
        return (cam.CFrame * CFrame.new(0.5, -0.4, -2.5)).Position
    end

    local function getNadeType()
        local lp = game.Players.LocalPlayer
        if not lp or not lp.Character then return "default" end
        local eqVal = lp.Character:FindFirstChild("EquippedTool")
        if not eqVal or type(eqVal.Value) ~= "string" then return "default" end
        local v = eqVal.Value
        if v == "Molotov" or v == "Incendiary Grenade" then return "molotov" end
        if v == "HE Grenade" then return "he" end
        if v == "Smoke Grenade" then return "smoke" end
        if v == "Flashbang" then return "flash" end
        if v == "Decoy Grenade" then return "decoy" end
        local lv = v:lower()
        if lv:find("molotov") or lv:find("incen") then return "molotov" end
        if lv:find("hegren") or lv == "he grenade" then return "he" end
        if lv:find("smoke") then return "smoke" end
        if lv:find("flash") then return "flash" end
        if lv:find("decoy") then return "decoy" end
        return "default"
    end

    local lmbDown, rmbDown = false, false
    local UIS = game:GetService("UserInputService")
    UIS.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then lmbDown = true end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then rmbDown = true end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then lmbDown = false end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then rmbDown = false end
    end)

    local CB_ArmChamFF = "4573037993"
    RunService.RenderStepped:Connect(function(dt)
        pcall(function()
            local cam = workspace.CurrentCamera
            local arms = cam:FindFirstChild("Arms")
            if not arms or arms.Name ~= "Arms" then return end

            local weaponOn = CB_GetFlag("esp_local_weapon_chams", false)
            local armOn = CB_GetFlag("esp_local_arm_chams", false)
            local gloveOn = CB_GetFlag("esp_local_glove_chams", false)
            local sleeveOn = CB_GetFlag("esp_local_sleeve_chams", false)

            for _, child in arms:GetChildren() do
                if weaponOn and (child:IsA("MeshPart") or child.Name == "Part") then
                    if child.Name == "StatClock" then child:ClearAllChildren() end
                    child.Color = CB_GetFlagColor("esp_local_weapon_color", Color3.fromRGB(255, 255, 255))
                    child.Transparency = CB_GetFlag("esp_local_weapon_trans", 0) / 100
                    local matName = CB_GetFlag("esp_local_weapon_mat", "ForceField")
                    child.Material = Enum.Material[matName] or Enum.Material.ForceField
                    pcall(function() child.TextureID = "" end)
                    pcall(function() child.Reflectance = CB_GetFlag("esp_local_weapon_ref", 0) / 100 end)
                    if child:FindFirstChild("SurfaceAppearance") then child.SurfaceAppearance:Destroy() end
                    local hasKnife = false
                    for _, c in arms:GetChildren() do
                        if string.find(c.Name, "Knife") or c.Name == "Handle2" or c.Name == "Blade" then hasKnife = true end
                    end
                    if hasKnife and arms:FindFirstChild("Handle") then arms.Handle.Transparency = 1 end
                end
                if child:IsA("Model") then
                    for _, d in child:GetDescendants() do
                        local lname = string.lower(d.Name)
                        local isSleeve = string.find(lname, "sleeve")
                        local isGlove = string.find(lname, "glove")
                        local prefix
                        if isGlove and gloveOn then prefix = "glove"
                        elseif isSleeve and sleeveOn then prefix = "sleeve"
                        elseif (not isSleeve and not isGlove) and armOn then prefix = "arm" end
                        if prefix then
                            pcall(function() d.CastShadow = false end)
                            local matName = CB_GetFlag("esp_local_" .. prefix .. "_mat", "ForceField")
                            local pMat = Enum.Material[matName] or Enum.Material.ForceField
                            local col = CB_GetFlagColor("esp_local_" .. prefix .. "_color", Color3.fromRGB(255, 255, 255))
                            if d:IsA("SpecialMesh") then
                                if matName == "ForceField" then d.TextureId = CB_ArmChamFF else d.TextureId = "" end
                                d.VertexColor = Vector3.new(col.R, col.G, col.B)
                            elseif d:IsA("BasePart") then
                                d.Material = pMat
                                d.Color = col
                                d.Transparency = CB_GetFlag("esp_local_" .. prefix .. "_trans", 0) / 100
                            end
                        end
                    end
                end
            end
        end)

        if not CB_GetFlag("esp_local_grenade_pred", false) or not isHoldingNade() or not (lmbDown or rmbDown) then
            for _, b in gBeams do b.Enabled = false end
            gSphere.Transparency = 1
            return
        end
        local rgb = CB_GetFlagColor("esp_local_grenade_color", Color3.fromRGB(255, 50, 50))
        local c3 = typeof(rgb) == "Color3" and rgb or Color3.new(1, 0.2, 0.2)
        for _, b in gBeams do
            b.Color = ColorSequence.new(c3)
            b.Enabled = true
        end
        gSphere.Color = c3
        pulseVal = pulseVal + (pulseDir * dt * 2.5)
        if pulseVal >= 1.6 then pulseDir = -1 end
        if pulseVal <= 0.7 then pulseDir = 1 end
        gSphere.Size = Vector3.new(pulseVal, pulseVal, pulseVal)

        local cam = workspace.CurrentCamera
        local lp = game.Players.LocalPlayer
        local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        local plrVel = hrp and hrp.AssemblyLinearVelocity or Vector3.new()
        local nadeType = getNadeType()
        local LOOK_SPEED = 100
        local PLR_FACTOR = 1.0
        local UP_BIAS = 12
        local maxBounces, bounceDamping = 3, 0.42
        if nadeType == "molotov" then
            maxBounces, bounceDamping = 5, 0.4
        elseif nadeType == "he" then
            maxBounces, bounceDamping = 4, 0.55
        elseif nadeType == "smoke" then
            maxBounces, bounceDamping = 3, 0.38
        elseif nadeType == "flash" then
            maxBounces, bounceDamping = 4, 0.55
        elseif nadeType == "decoy" then
            maxBounces, bounceDamping = 3, 0.42
        end
        local velocity = cam.CFrame.LookVector * LOOK_SPEED + plrVel * PLR_FACTOR + Vector3.new(0, UP_BIAS, 0)
        local startPos = getNadePosition()
        local grav = Vector3.new(0, -workspace.Gravity, 0)
        local tStep = 1/60
        local maxSteps = 240
        local currentPos = startPos
        local rp = RaycastParams.new()
        local filterList = {lp.Character, workspace:FindFirstChild("Ray_Ignore"), PredictionFolder}
        local mapObj = workspace:FindFirstChild("Map")
        if mapObj then
            local clips = mapObj:FindFirstChild("Clips")
            if clips then table.insert(filterList, clips) end
        end
        rp.FilterDescendantsInstances = filterList
        rp.FilterType = Enum.RaycastFilterType.Exclude
        local bounces = 0
        local pointCount = 1
        gAtts[1].WorldPosition = startPos
        local samplePeriod = 3
        local stepIdx = 0
        for s = 1, maxSteps do
            local nextVel = velocity + (grav * tStep)
            local moveDelta = (velocity + nextVel) * 0.5 * tStep
            local nextPos = currentPos + moveDelta
            local ray = workspace:Raycast(currentPos, nextPos - currentPos, rp)
            if ray then
                bounces = bounces + 1
                nextPos = ray.Position + ray.Normal * 0.05
                local normal = ray.Normal
                local reflected = nextVel - (2 * nextVel:Dot(normal) * normal)
                velocity = reflected * bounceDamping
                local isFloor = normal.Y > 0.6
                if (nadeType == "molotov" and isFloor) or bounces >= maxBounces or velocity.Magnitude < 5 then
                    pointCount = pointCount + 1
                    if pointCount <= 40 then
                        gAtts[pointCount].WorldPosition = nextPos
                        gBeams[pointCount-1].Transparency = NumberSequence.new(0.15 + (pointCount/40)*0.85)
                    end
                    currentPos = nextPos
                    break
                end
            else
                velocity = nextVel
            end
            currentPos = nextPos
            stepIdx = stepIdx + 1
            if stepIdx % samplePeriod == 0 or ray then
                pointCount = pointCount + 1
                if pointCount > 40 then break end
                gAtts[pointCount].WorldPosition = nextPos
                gBeams[pointCount-1].Transparency = NumberSequence.new(0.15 + (pointCount/40)*0.85)
            end
        end
        for j = pointCount, 39 do
            if gBeams[j] then gBeams[j].Enabled = false end
        end
        gSphere.CFrame = CFrame.new(currentPos)
        gSphere.Transparency = 0.3
    end)
end)



