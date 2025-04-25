-- Football Fusion QB Aimbot Script (Inverse Projectile Rewrite)
-- This script will always compute the correct remote "Target" so the ball lands at the predicted landing position.
-- Selection logic (press H to select nearest) and highlight is preserved.

-- === GLOBAL SERVICES ===
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Drawing API (if not already defined, require or assign appropriately)
local Drawing = Drawing or nil -- Replace with actual Drawing API if needed

-- Persistent state
local lastThrowDebug = nil
local currentArcYDebugConn = nil
local playerTrack = {}

-- Helper functions
local function formatVec3(v)
    return string.format("(%.2f, %.2f, %.2f)", (v and v.X) or 0, (v and v.Y) or 0, (v and v.Z) or 0)
end

local function safeComp(v, comp)
    return (v and v[comp]) or 0
end

-- === CONFIGURATION ===
local MAX_POWER = 120
local MIN_POWER = 50
local MAX_SPEED = 120
local MIN_SPEED = 40
local GRAVITY = workspace.Gravity or 196.2
local FIELD_Y = 3 -- Adjust if your field is at a different Y

-- === DRAWING ESP LOGIC (Selected Player Only) ===
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer
local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")

local function createText()
    local text = Drawing.new("Text")
    text.Size = 18
    text.Outline = true
    text.Center = true
    text.Visible = false
    return text
end

local playerText = {}

local function rainbowColor(frequency)
    local r = math.floor(math.sin(frequency + 0) * 127 + 128)
    local g = math.floor(math.sin(frequency + 2) * 127 + 128)
    local b = math.floor(math.sin(frequency + 4) * 127 + 128)
    return Color3.fromRGB(r, g, b)
end

local function updateTexts()
    local time = tick()
    for player, text in pairs(playerText) do
        text.Visible = false
    end
    local selected = _G.SelectedAimbotPlayer
    if selected and selected ~= localPlayer and selected.Character and selected.Character:FindFirstChild("HumanoidRootPart") then
        local rootPart = selected.Character.HumanoidRootPart
        local head = selected.Character:FindFirstChild("Head")
        if head then
            local screenPos, onScreen = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 2, 0))
            if onScreen then
                local distance = (localPlayer.Character.HumanoidRootPart.Position - rootPart.Position).magnitude
                local text = playerText[selected]
                if not text then
                    text = createText()
                    playerText[selected] = text
                end
                text.Position = Vector2.new(screenPos.X, screenPos.Y)
                text.Text = selected.Name .. " | " .. math.floor(distance) .. " studs"
                text.Color = rainbowColor(time + selected.UserId)
                text.Visible = true
            end
        end
    end
end

runService.RenderStepped:Connect(updateTexts)

players.PlayerRemoving:Connect(function(player)
    if playerText[player] then
        playerText[player]:Remove()
        playerText[player] = nil
    end
    if _G.SelectedAimbotPlayer == player then
        _G.SelectedAimbotPlayer = nil
    end
end)

-- === BALL AND TARGET RESET LOGIC ===
local function resetAimbotCalculations()
    lastThrowDebug = nil
    if currentArcYDebugConn then currentArcYDebugConn:Disconnect() currentArcYDebugConn = nil end
    -- Reset any other persistent state here (e.g., playerTrack, etc.)
    if playerTrack then
        for k in pairs(playerTrack) do playerTrack[k] = nil end
    end
end

-- Monitor ball disappearance/reappearance
local function monitorBall()
    local lastBall = nil
    game:GetService("RunService").Heartbeat:Connect(function()
        local ball = workspace.lllAnkleslll and workspace.lllAnkleslll:FindFirstChild("Football")
        if ball ~= lastBall then
            resetAimbotCalculations()
            lastBall = ball
        end
    end)
end
monitorBall()

-- Reset calculations when a new target is selected
local oldSelectPlayerFunc = nil
if selectNearestPlayer then
    oldSelectPlayerFunc = selectNearestPlayer
    selectNearestPlayer = function(...)
        resetAimbotCalculations()
        return oldSelectPlayerFunc(...)
    end
end

-- If selection is via key (H), also reset calculations there
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.H then
        resetAimbotCalculations()
    end
end)

-- === TEAMMATE CYCLING LOGIC FOR PLACE 4940687511 ===
local placeId = game.PlaceId
local teammateCycleIndex = 1
local teammateCycleList = nil

local function getTeammates()
    local myTeam = LocalPlayer.Team
    local teammates = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Team == myTeam then
            table.insert(teammates, player)
        end
    end
    return teammates
end

local function getNextTeammate()
    if not teammateCycleList or #teammateCycleList == 0 then
        teammateCycleList = getTeammates()
        teammateCycleIndex = 1
    end
    if #teammateCycleList == 0 then
        return nil
    end
    local teammate = teammateCycleList[teammateCycleIndex]
    teammateCycleIndex = teammateCycleIndex + 1
    if teammateCycleIndex > #teammateCycleList then
        teammateCycleList = getTeammates()
        teammateCycleIndex = 1
    end
    return teammate
end

-- Replace nearest player selection logic if in place 4940687511
local function selectTargetPlayer()
    if placeId == 4940687511 then
        return getNextTeammate()
    else
        -- original nearest player logic here
        local function getNearestPlayer()
            local qbChar = LocalPlayer.Character
            if not (qbChar and qbChar:FindFirstChild("HumanoidRootPart")) then return nil end
            local qbPos = qbChar.HumanoidRootPart.Position
            local nearest, minDist = nil, math.huge
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local dist = (player.Character.HumanoidRootPart.Position - qbPos).Magnitude
                    if dist < minDist then
                        minDist = dist
                        nearest = player
                    end
                end
            end
            return nearest
        end
        return getNearestPlayer()
    end
end

-- === NEAREST PLAYER SELECTION LOGIC (H KEY) ===
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.H then
        local nearest = selectTargetPlayer()
        _G.SelectedAimbotPlayer = nearest
        if nearest then
            print("[Aimbot QB Script] Selected nearest player: " .. nearest.Name)
        else
            print("[Aimbot QB Script] No valid player found to select.")
        end
    end
end)

-- === ADVANCED PREDICTION TRACKING ===
local function updatePlayerTrack(player, curPos, curVel)
    local track = playerTrack[player] or {lastPos=curPos, lastVel=curVel, acc=Vector3.new(), history={}}
    -- Compute acceleration
    local acc = (curVel - track.lastVel)
    -- Smooth velocity over last N frames
    table.insert(track.history, 1, curVel)
    if #track.history > 5 then table.remove(track.history) end
    local avgVel = Vector3.new(0,0,0)
    for _,v in ipairs(track.history) do avgVel = avgVel + v end
    avgVel = avgVel / #track.history
    -- Store
    track.lastPos = curPos
    track.lastVel = curVel
    track.acc = acc
    track.avgVel = avgVel
    playerTrack[player] = track
    return track
end

-- === PROJECTILE PHYSICS HELPERS ===
local function getBallSpeed(power)
    return MIN_SPEED + ((power / 100) * (MAX_SPEED - MIN_SPEED))
end

local function getPowerForDistance(distance)
    -- Use a quadratic scale for more power at longer distances
    local normalized = math.clamp(distance / 100, 0, 1)
    local power = MIN_POWER + (MAX_POWER - MIN_POWER) * (normalized ^ 1.25)
    return math.clamp(math.floor(power + 0.5), MIN_POWER, MAX_POWER)
end

-- Predicts where the player will be after t seconds
local function predictTorsoPos(player, t)
    local char = player.Character
    if not char then return nil end
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    if not torso then return nil end
    local pos = torso.Position
    local vel = torso.Velocity
    return pos + vel * t
end

-- Simulates the projectile from origin to target, returns landing position for given power and "remote target" (throwTarget)
local function simulateLanding(origin, throwTarget, power)
    local speed = getBallSpeed(power)
    local dir = (throwTarget - origin).Unit
    local flatDist = Vector3.new(throwTarget.X - origin.X, 0, throwTarget.Z - origin.Z).Magnitude
    local dy = throwTarget.Y - origin.Y
    local bestT, landingPos, bestYdiff = nil, nil, math.huge
    local bestAngle = nil
    for angle = math.rad(5), math.rad(85), math.rad(0.25) do
        local vxz = speed * math.cos(angle)
        local vy = speed * math.sin(angle)
        local t = flatDist / vxz
        local y_at_t = origin.Y + vy * t - 0.5 * GRAVITY * t^2
        local ydiff = math.abs(y_at_t - throwTarget.Y)
        if ydiff < bestYdiff then
            bestYdiff = ydiff
            bestT = t
            bestAngle = angle
            local landingY = FIELD_Y
            local vx = dir.X * vxz
            local vz = dir.Z * vxz
            local x = origin.X + vx * t
            local z = origin.Z + vz * t
            landingPos = Vector3.new(x, landingY, z)
        end
    end
    return landingPos, bestT
end

-- Analytically solve for the remote target so the ball lands at landingPos, using a fixed arc angle
local function solveThrowTarget(origin, landingPos, power)
    local g = GRAVITY
    local fixedAngleDeg = 45 -- You can change this to any fixed angle you want
    local theta = math.rad(fixedAngleDeg)
    local dx = landingPos.X - origin.X
    local dz = landingPos.Z - origin.Z
    local dy = landingPos.Y - origin.Y
    local dxz = math.sqrt(dx * dx + dz * dz)
    local dirXZ = Vector3.new(dx, 0, dz).Unit
    -- Solve for required speed (v) given fixed angle
    local cosTheta = math.cos(theta)
    local sinTheta = math.sin(theta)
    local denom = dxz * math.tan(theta) - dy
    if denom <= 0 then
        print("[Aimbot QB Script] No valid arc for this throw (denom <= 0)")
        return landingPos
    end
    local v2 = (g * dxz * dxz) / (2 * cosTheta * cosTheta * denom)
    if v2 < 0 then
        print("[Aimbot QB Script] No valid arc for this throw (v^2 < 0)")
        return landingPos
    end
    local v = math.sqrt(v2)
    local t = dxz / (v * cosTheta)
    -- The server expects the remote target to be where the ball would be after t seconds at the launch angle
    local vxz = v * cosTheta
    local vy = v * sinTheta
    local remoteTargetXZ = Vector3.new(origin.X, 0, origin.Z) + dirXZ * vxz * t
    local remoteTargetY = origin.Y + vy * t - 0.5 * g * t * t
    local remoteTarget = Vector3.new(remoteTargetXZ.X, remoteTargetY, remoteTargetXZ.Z)
    return remoteTarget, v
end

-- Decide power based on distance and receiver velocity
local function choosePower(dist, receiverVel)
    if dist >= 300 then return 120 end
    if receiverVel > 12 or dist > 100 then return 100 end
    return 80
end

-- Improved prediction: Iteratively estimate landing position using both QB and receiver velocities & acceleration
local function predictLandingPos(qbPos, qbVel, receiverPos, receiverVel, power, lead, acc)
    if not lead then
        return Vector3.new(receiverPos.X, FIELD_Y, receiverPos.Z), 0
    end
    local maxIter, epsilon = 7, 0.03
    local t = ((receiverPos - qbPos).Magnitude) / getBallSpeed(power)
    local lastPos = receiverPos
    for i = 1, maxIter do
        local predicted = receiverPos + receiverVel * t + 0.5 * acc * t * t
        local qbFuture = qbPos + qbVel * t
        local dist = (predicted - qbFuture).Magnitude
        local newT = dist / getBallSpeed(power)
        if math.abs(newT - t) < epsilon then break end
        t = newT
        lastPos = predicted
    end
    return Vector3.new(lastPos.X, FIELD_Y, lastPos.Z), t
end

-- Enhanced debug: Print only after ball lands (first ground contact), using actual landing position and intended target
local function debugArcYTableOnLand(power, dist, arcY, target, landPos)
    local FIELD_Y = FIELD_Y or 3
    local dxz = (Vector3.new(landPos.X, 0, landPos.Z) - Vector3.new(target.X, 0, target.Z)).Magnitude
    local dy = landPos.Y - FIELD_Y
    local status, advice = '', ''
    local catchRadius = 3.5
    local upperTorsoMinY, upperTorsoMaxY = FIELD_Y + 3, FIELD_Y + 6.5
    local lowerTorsoMinY, lowerTorsoMaxY = FIELD_Y + 1, FIELD_Y + 2.9
    -- Use QB origin for more accurate short/overshoot logic
    local qbOrigin = Vector3.new(0, FIELD_Y, 0)
    local distToTarget = (Vector3.new(target.X, 0, target.Z) - qbOrigin).Magnitude
    local distToLand = (Vector3.new(landPos.X, 0, landPos.Z) - qbOrigin).Magnitude
    if dxz <= catchRadius then
        if landPos.Y >= upperTorsoMinY and landPos.Y <= upperTorsoMaxY then
            status = 'Caught'
            advice = 'Perfect!'
        elseif landPos.Y >= lowerTorsoMinY and landPos.Y < upperTorsoMinY then
            status = 'Lower torso hit'
            advice = 'Increase arcY for upper torso catch.'
        elseif landPos.Y < lowerTorsoMinY then
            status = 'Too low'
            advice = 'Increase arcY for upper torso catch.'
        elseif landPos.Y > upperTorsoMaxY and landPos.Y < FIELD_Y + 10 then
            status = 'Above head'
            advice = 'Slightly decrease arcY for upper torso catch.'
        elseif landPos.Y >= FIELD_Y + 10 then
            status = 'Way too high'
            advice = 'Decrease arcY for upper torso catch.'
        else
            status = 'Unusual height'
            advice = 'Check arcY value.'
        end
    elseif distToLand < distToTarget then
        status = 'Short'
        advice = 'Increase arcY for upper torso catch.'
    else
        status = 'Overshoot'
        advice = 'Decrease arcY for upper torso catch.'
    end
    print(string.format("[ArcYTest] Power: %3d | Dist: %3d | ArcY: %5.2f | Land: (%.2f, %.2f, %.2f) | ΔXZ: %.2f | ΔY: %.2f | Target: (%.2f, %.2f, %.2f) | Status: %-16s | Advice: %s", power or 0, dist or 0, arcY or 0, landPos.X or 0, landPos.Y or 0, landPos.Z or 0, dxz or 0, dy or 0, target.X or 0, target.Y or 0, target.Z or 0, status, advice))
end

-- === THROW LOGIC ===
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Q then
        local selected = _G.SelectedAimbotPlayer
        if not selected then print("[Aimbot QB Script] No player selected. Press H.") return end
        local ball = workspace.lllAnkleslll and workspace.lllAnkleslll:FindFirstChild("Football")
        if not ball then print("[Aimbot QB Script] Ball not found!") return end
        local origin = ball.Position
        local lastBallPos = ball and ball.Position
        local lastBallVel = ball and ball.Velocity
        local qbVel = (ball.Velocity or Vector3.new())
        local receiver = selected.Character.HumanoidRootPart
        local receiverPos = receiver.Position
        local receiverVel = receiver.Velocity
        -- Update advanced tracking
        local track = updatePlayerTrack(selected, receiverPos, receiverVel)
        local dist = (receiverPos - origin).Magnitude
        local power = choosePower(dist, (track.avgVel and track.avgVel.Magnitude) or 0)

        -- === ARC TABLES ===
        local arcYTable_stationary = {
            [120] = { {324, 230}, {335, 250}, {355, 320}, {360, 370}, {380, 420}, {317, 260} },
            [100] = { {40, 6}, {50, 9}, {60, 13}, {70, 17}, {80, 21}, {90, 23}, {100, 24}, {110, 28}, {120, 32}, {130, 36}, {140, 40}, {150, 44}, {160, 50}, {170, 55}, {178, 65}, {190, 75}, {200, 85}, {220, 95}, {233, 105}, {264, 140}, {274, 170}, {317, 200}, {332, 220}, {360, 270} },
            [80] = { {4, 2}, {13, 4}, {31, 6}, {33, 7}, {40, 8}, {50, 13}, {60, 15}, {68, 18}, {75, 20}, {80, 12}, {89, 13}, {100, 15}, {150, 38}, {170, 55}, {185, 70}, {200, 120}, {233, 140}, {264, 180}, {274, 210}, {317, 220}, {332, 250} }
        }
        local arcYTable_moving = {
            [120] = { {324, 250}, {335, 270}, {355, 340}, {360, 390} },
            [100] = {
                {40, 15}, {45, 15}, {50, 16}, {55, 17}, {60, 18}, {65, 18}, {70, 20}, {75, 21}, {80, 22}, {85, 23}, {90, 25}, {95, 27}, {100, 28}, {105, 30}, {110, 32}, {115, 34}, {120, 36}, {125, 39}, {130, 41}, {135, 44}, {140, 46}, {145, 49}, {150, 52}, {155, 55}, {160, 58}, {165, 61}, {170, 64}, {175, 68}, {180, 71}, {185, 75}, {190, 79}, {195, 82}, {200, 86}, {205, 90}, {210, 95}, {215, 99}, {220, 103}, {225, 108}, {230, 112}, {235, 117}, {240, 122}, {245, 127}, {250, 132}, {255, 137}, {260, 142}, {265, 148}, {270, 153}, {275, 159}, {280, 165}, {285, 171}, {290, 176}, {295, 183}, {300, 189}, {305, 195}, {310, 201}, {315, 208}, {320, 214}, {325, 221}, {330, 228}, {332, 231}, {335, 235}

            },
            [80] = { {4, 3}, {13, 5}, {31, 7}, {33, 8}, {40, 10}, {50, 12}, {54, 12}, {60, 13}, {80, 16}, {89, 17}, {100, 19}, {150, 45}, {170, 65}, {185, 85}, {200, 130} }
        }

        -- Helper to select arcYTable based on movement
        local function getArcYTable(isMoving)
            return isMoving and arcYTable_moving or arcYTable_stationary
        end

        -- Helper to get arcY from table
        local function getArcYFromTable(arcYTable, power, dist)
            local tbl = arcYTable[power]
            if not tbl then return FIELD_Y end
            if dist <= tbl[1][1] then return tbl[1][2] end
            if dist >= tbl[#tbl][1] then return tbl[#tbl][2] end
            for i = 2, #tbl do
                local d0, y0 = tbl[i-1][1], tbl[i-1][2]
                local d1, y1 = tbl[i][1], tbl[i][2]
                if dist == d1 then return y1 end
                if dist < d1 then
                    local t = (dist - d0) / (d1 - d0)
                    return y0 + t * (y1 - y0)
                end
            end
            return tbl[#tbl][2]
        end

        -- === SMART AI PREDICTION LOGIC ===
        local velocityThreshold = 3.0
        local trackMag = (track.avgVel and track.avgVel.Magnitude) or 0
        local predictedPos
        local arcY
        local flightTime = 0 -- Ensure flightTime is always defined
        if trackMag > velocityThreshold then
            local leadMultiplier = 1
            if dist < 100 then
                leadMultiplier = 1.25 -- Lead even more for short moving throws
            elseif dist > 150 then
                leadMultiplier = 1.15 -- Slightly more lead for deep throws
            end
            -- Iterative prediction (lead multiplier only affects X/Z, never Y)
            local predicted = receiverPos
            for i = 1, 3 do
                local _, t = simulateLanding(origin, predicted, power)
                local leadVec = track.avgVel * t + 0.5 * (track.acc or Vector3.new()) * t * t
                predicted = Vector3.new(
                    receiverPos.X + leadVec.X * leadMultiplier,
                    receiverPos.Y, -- never modify Y
                    receiverPos.Z + leadVec.Z * leadMultiplier
                )
            end
            local moveDist = (Vector3.new(predicted.X, origin.Y, predicted.Z) - Vector3.new(origin.X, origin.Y, origin.Z)).Magnitude
            arcY = getArcYFromTable(arcYTable_moving, power, moveDist)
            if moveDist > 280 then
                arcY = arcY + 2
                elseif moveDist > 150 then
                    arcY = arcY + 1.5
            end
            -- Ensure Y is always from arcY table
            predictedPos = Vector3.new(predicted.X, arcY, predicted.Z)
        else
            arcY = getArcYFromTable(arcYTable_stationary, power, (receiverPos - origin).Magnitude)
            predictedPos = Vector3.new(receiverPos.X, arcY, receiverPos.Z)
        end
        -- Optionally estimate flightTime for debug (using straight-line distance and power)
        local _, simTime = simulateLanding(origin, predictedPos, power)
        flightTime = simTime or 0
        local throwTarget = predictedPos
        -- Helper for safe vector component access
        local function safeComp(v, comp)
            return (v and v[comp]) or 0
        end
        local function safeMag(v)
            return (v and v.Magnitude) or 0
        end

        -- === DEBUG OUTPUT ===

        -- === THROW LOGIC ===
        -- Try workspace.MiniGames first
        local chosenModel = nil
        local useGames = false
        local wsMiniGames = workspace:FindFirstChild("MiniGames")
        if wsMiniGames and #wsMiniGames:GetChildren() > 0 then
            for _, obj in ipairs(wsMiniGames:GetChildren()) do
                if obj:IsA("Model") then
                    local replicated = obj:FindFirstChild("Replicated")
                    if replicated and replicated:IsA("Model") then
                        local spotTags = replicated:FindFirstChild("SpotTags")
                        if spotTags and spotTags:IsA("Folder") then
                            chosenModel = obj
                            print("Chosen model:", obj.Name, "(has Replicated->SpotTags)")
                            break
                        end
                    end
                end
            end
            if chosenModel then
                game:GetService("ReplicatedStorage"):WaitForChild("MiniGames"):WaitForChild(chosenModel.Name):WaitForChild("ReEvent"):FireServer(unpack({
                    [1] = "Mechanics",
                    [2] = "ThrowBall",
                    [3] = {
                        ["Target"] = throwTarget,
                        ["AutoThrow"] = false,
                        ["Power"] = power
                    }
                }))
            else
                -- Fallback to workspace.Games
                local wsGames = workspace:FindFirstChild("Games")
                if not wsGames or #wsGames:GetChildren() == 0 then
                    error("Neither workspace.MiniGames nor workspace.Games have usable models!")
                end
                for _, obj in ipairs(wsGames:GetChildren()) do
                    if obj:IsA("Model") then
                        local replicated = obj:FindFirstChild("Replicated")
                        if replicated and replicated:IsA("Model") then
                            local ActiveSpots = replicated:FindFirstChild("ActiveSpots")
                            if ActiveSpots and ActiveSpots:IsA("Folder") then
                                chosenModel = obj
                                print("Chosen model:", obj.Name, "(has Replicated->ActiveSpots)")
                                break
                            end
                        end
                    end
                end
                if not chosenModel then
                    error("No model in workspace.Games with Replicated (Model) and ActiveSpots (Folder) found!")
                end
                game:GetService("ReplicatedStorage"):WaitForChild("Games"):WaitForChild(chosenModel.Name):WaitForChild("ReEvent"):FireServer(unpack({
                    [1] = "Mechanics",
                    [2] = "ThrowBall",
                    [3] = {
                        ["Target"] = throwTarget,
                        ["AutoThrow"] = false,
                        ["Power"] = power
                    }
                }))
            end
        end
    end
end)

-- Improved ArcYTest advice logic
local function debugArcYTableOnLand(power, dist, arcY, target, landPos)
    local FIELD_Y = FIELD_Y or 3
    local dxz = (Vector3.new(landPos.X, 0, landPos.Z) - Vector3.new(target.X, 0, target.Z)).Magnitude
    local dy = landPos.Y - FIELD_Y
    local status, advice = '', ''
    local catchRadius = 3.5
    local upperTorsoMinY, upperTorsoMaxY = FIELD_Y + 3, FIELD_Y + 6.5
    local lowerTorsoMinY, lowerTorsoMaxY = FIELD_Y + 1, FIELD_Y + 2.9
    -- Use QB origin for more accurate short/overshoot logic
    local qbOrigin = Vector3.new(0, FIELD_Y, 0)
    local distToTarget = (Vector3.new(target.X, 0, target.Z) - qbOrigin).Magnitude
    local distToLand = (Vector3.new(landPos.X, 0, landPos.Z) - qbOrigin).Magnitude
    if dxz <= catchRadius then
        if landPos.Y >= upperTorsoMinY and landPos.Y <= upperTorsoMaxY then
            status = 'Caught'
            advice = 'Perfect!'
        elseif landPos.Y >= lowerTorsoMinY and landPos.Y < upperTorsoMinY then
            status = 'Lower torso hit'
            advice = 'Increase arcY for upper torso catch.'
        elseif landPos.Y < lowerTorsoMinY then
            status = 'Too low'
            advice = 'Increase arcY for upper torso catch.'
        elseif landPos.Y > upperTorsoMaxY and landPos.Y < FIELD_Y + 10 then
            status = 'Above head'
            advice = 'Slightly decrease arcY for upper torso catch.'
        elseif landPos.Y >= FIELD_Y + 10 then
            status = 'Way too high'
            advice = 'Decrease arcY for upper torso catch.'
        else
            status = 'Unusual height'
            advice = 'Check arcY value.'
        end
    elseif distToLand < distToTarget then
        status = 'Short'
        advice = 'Increase arcY for upper torso catch.'
    else
        status = 'Overshoot'
        advice = 'Decrease arcY for upper torso catch.'
    end
    print(string.format("[ArcYTest] Power: %3d | Dist: %3d | ArcY: %5.2f | Land: (%.2f, %.2f, %.2f) | ΔXZ: %.2f | ΔY: %.2f | Target: (%.2f, %.2f, %.2f) | Status: %-16s | Advice: %s", power or 0, dist or 0, arcY or 0, landPos.X or 0, landPos.Y or 0, landPos.Z or 0, dxz or 0, dy or 0, target.X or 0, target.Y or 0, target.Z or 0, status, advice))
end

print("[Aimbot QB Script Loaded] Press H to select and highlight the nearest player, Q to throw to them.")
