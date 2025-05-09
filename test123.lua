-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Settings
local TOGGLE_KEY = Enum.KeyCode.Q
local FIRE_KEY = Enum.KeyCode.T  -- Changed to T
local FOV_RADIUS = 250
local Power100_PREDICTION_FACTOR = 1
local Power80_PREDICTION_FACTOR = 1.3
local TEAM_ONLY_PLACE_ID = 14801724413  -- The place ID where team targeting is disabled

-- State
local AimbotEnabled = false

-- Define arcTable with trajectory data
local arcTable = {
    [100] = { 
        {40, 6}, {50, 9}, {60, 13}, {70, 17}, {80, 21}, {90, 23}, 
        {100, 24}, {110, 28}, {120, 32}, {130, 36}, {140, 40}, 
        {150, 44}, {160, 50}, {170, 55}, {178, 65}, {190, 75}, 
        {200, 85}, {220, 95}, {233, 105}, {264, 140}, {274, 170}, 
        {317, 200}, {332, 220}, {360, 270} 
    }, 
    [80] = { 
        {4, 2}, {13, 4}, {31, 6}, {33, 7}, {40, 8}, {50, 13}, 
        {60, 15}, {68, 18}, {75, 20}, {80, 12}, {89, 13}, {100, 15}, 
        {150, 38}, {170, 55}, {185, 70}, {200, 120}, {233, 140}, 
        {264, 180}, {274, 210}, {317, 220}, {332, 250} 
    }
}

-- Landing Indicator and Beam Setup
local landingIndicator
local ballAttachment
local targetAttachment
local aimBeam
local arcPoints = {}
local arcAttachments = {}
local arcBeams = {}
local NUM_ARC_POINTS = 10 -- Number of points to create the arc

-- Clean up any existing indicators first
for _, obj in pairs(workspace:GetChildren()) do
    if obj.Name == "LandingIndicator" or obj.Name == "AimbotBeam" or obj.Name == "ArcBeam" then
        obj:Destroy()
    end
end

local function CreateLandingIndicator() 
    local part = Instance.new("Part") 
    part.Size = Vector3.new(5, 5, 5)  -- Even larger for better visibility
    part.Anchored = true 
    part.CanCollide = false 
    part.Material = Enum.Material.Neon 
    part.BrickColor = BrickColor.new("Really red")  -- Changed to red for better visibility
    part.Name = "LandingIndicator" 
    part.Transparency = 0.2  -- More visible
    part.Shape = Enum.PartType.Ball  -- Sphere shape
    
    -- Add a point light
    local light = Instance.new("PointLight")
    light.Range = 15
    light.Brightness = 2
    light.Color = Color3.fromRGB(255, 0, 0)
    light.Parent = part
    
    -- Create attachment for beam
    targetAttachment = Instance.new("Attachment")
    targetAttachment.Position = Vector3.new(0, 0, 0)
    targetAttachment.Parent = part
    
    part.Parent = workspace
    
   
    return part 
end 

-- Create arc beam system
local function CreateArcBeamSystem()
    local beamPart = Instance.new("Part")
    beamPart.Name = "ArcBeam"
    beamPart.Transparency = 1
    beamPart.CanCollide = false
    beamPart.Anchored = true
    beamPart.Size = Vector3.new(1, 1, 1)
    beamPart.Parent = workspace
    
    ballAttachment = Instance.new("Attachment")
    ballAttachment.Parent = beamPart
    
    -- Create arc points and attachments
    for i = 1, NUM_ARC_POINTS do
        local attachment = Instance.new("Attachment")
        attachment.Parent = beamPart
        table.insert(arcAttachments, attachment)
        
        -- Create beams between points
        if i > 1 then
            local beam = Instance.new("Beam")
            beam.Attachment0 = arcAttachments[i-1]
            beam.Attachment1 = attachment
            beam.Width0 = 0.5
            beam.Width1 = 0.5
            beam.FaceCamera = true
            beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
            beam.Transparency = NumberSequence.new(0.2)
            beam.Parent = beamPart
            table.insert(arcBeams, beam)
        end
    end
    
    -- Create final beam to target
    local finalBeam = Instance.new("Beam")
    finalBeam.Attachment0 = arcAttachments[NUM_ARC_POINTS]
    finalBeam.Attachment1 = targetAttachment
    finalBeam.Width0 = 0.5
    finalBeam.Width1 = 0.5
    finalBeam.FaceCamera = true
    finalBeam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
    finalBeam.Transparency = NumberSequence.new(0.2)
    finalBeam.Parent = beamPart
    table.insert(arcBeams, finalBeam)
    
    return beamPart
end

-- Create the landing indicator and beam
landingIndicator = CreateLandingIndicator()
local beamPart = CreateArcBeamSystem()

-- Initial position (will be updated during aiming)
landingIndicator.Position = workspace.CurrentCamera.CFrame.Position + Vector3.new(0, 5, -10)
beamPart.Position = workspace.CurrentCamera.CFrame.Position


-- Function to update arc beam positions
local function UpdateArcBeam(startPos, endPos, arcHeight, power)
    if not startPos or not endPos or not arcHeight then return end
    
    -- Calculate horizontal distance
    local horizontalDist = Vector2.new(endPos.X - startPos.X, endPos.Z - startPos.Z).Magnitude
    
    -- Calculate initial velocity needed to reach the target
    local gravity = workspace.Gravity
    local initialVelocityY = math.sqrt(2 * gravity * arcHeight)
    
    -- Time to reach the peak of the arc
    local timeToApex = initialVelocityY / gravity
    
    -- Total time of flight (time to apex * 2)
    local totalFlightTime = timeToApex * 2
    
    -- Calculate horizontal velocity needed
    local horizontalVelocity = horizontalDist / totalFlightTime
    
    -- Calculate arc points using projectile motion equations
    for i = 1, NUM_ARC_POINTS do
        local t = (i / NUM_ARC_POINTS) * totalFlightTime
        
        -- Calculate position at time t
        local horizontalProgress = t / totalFlightTime
        local x = startPos.X + (endPos.X - startPos.X) * horizontalProgress
        local z = startPos.Z + (endPos.Z - startPos.Z) * horizontalProgress
        
        -- Calculate y using projectile motion equation: y = y0 + v0*t - 0.5*g*t^2
        local y = startPos.Y + (initialVelocityY * t) - (0.5 * gravity * t * t)
        
        -- Update attachment positions
        if arcAttachments[i] then
            arcAttachments[i].WorldPosition = Vector3.new(x, y, z)
        end
    end
end

local function PredictLandingPosition(football) 
    if not football or not football:IsA("BasePart") then
        
        return nil
    end
    
    if not football or not football.Position or not football.Velocity then
        return nil
    end
    
    local pos = football.Position 
    local vel = football.Velocity 
    local grav = workspace.Gravity 
    
    -- Debug info
    
    
    -- Check if velocity is too small to calculate landing
    if vel.Magnitude < 1 then
        
        return pos
    end
    
    local y = vel.Y 
    
    -- Handle case where ball might not land (going straight up)
    local discriminant = y^2 - 2 * grav * (pos.Y - 1)
    if discriminant < 0 then
        
        return nil
    end
    
    local t = (-y - math.sqrt(discriminant)) / -grav 
    
    -- If time is negative, ball is going up and won't land
    if t < 0 then
        
        return nil
    end
    
    local landingPos = pos + vel * t + 0.5 * Vector3.new(0, -grav, 0) * t^2 
   
    return landingPos 
end 

-- Utility Functions
local function IsValidTarget(player)
    if player == LocalPlayer then return false end
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then return false end
    
    -- Check team ID if not in the specific place
    if game.PlaceId ~= TEAM_ONLY_PLACE_ID then
        -- Get local player's team ID
        local localTeamID = nil
        if LocalPlayer:FindFirstChild("Replicated") and LocalPlayer.Replicated:FindFirstChild("TeamID") then
            localTeamID = LocalPlayer.Replicated.TeamID.Value
        end
        
        -- Get target player's team ID
        local targetTeamID = nil
        if player:FindFirstChild("Replicated") and player.Replicated:FindFirstChild("TeamID") then
            targetTeamID = player.Replicated.TeamID.Value
        end
        
        -- Only target players on the same team
        if localTeamID and targetTeamID and localTeamID ~= targetTeamID then
            return false
        end
    end
    
    local screenPoint, onScreen = Camera:WorldToViewportPoint(hrp.Position)
    if not onScreen then return false end
    return true
end

local function GetClosestPlayer()
local closestPlayer = nil
local closestDist = FOV_RADIUS

for _, player in pairs(Players:GetPlayers()) do
if IsValidTarget(player) then
local char = player.Character
local hrp = char.HumanoidRootPart
local screenPos, _ = Camera:WorldToViewportPoint(hrp.Position)
local distance = (Vector2.new(Mouse.X, Mouse.Y) - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
if distance < closestDist then
closestDist = distance
closestPlayer = player
end
end
end

return closestPlayer
end

-- Quadratic interpolation function
local function QuadraticInterpolate(x, x1, y1, x2, y2, x3, y3)
    local L1 = (x - x2) * (x - x3) / ((x1 - x2) * (x1 - x3))
    local L2 = (x - x1) * (x - x3) / ((x2 - x1) * (x2 - x3))
    local L3 = (x - x1) * (x - x2) / ((x3 - x1) * (x3 - x2))
    return y1 * L1 + y2 * L2 + y3 * L3
end

local function GetArcY(distance, power)
    local powerTable = arcTable[power]
    if not powerTable then return 0 end
    
    -- Find three closest points for interpolation
    local points = {}
    for _, entry in ipairs(powerTable) do
        local tableDist = entry[1]
        local tableArc = entry[2]
        table.insert(points, {math.abs(tableDist - distance), tableDist, tableArc})
    end
    
    table.sort(points, function(a, b) return a[1] < b[1] end)
    
    -- If exact match found, return it
    if points[1][1] == 0 then return points[1][3] end
    
    -- Get three closest points for quadratic interpolation
    -- Make sure we have points on both sides of the target distance when possible
    local selectedPoints = {}
    local hasLower, hasHigher = false, false
    
    -- First check if we have points on both sides
    for i = 1, math.min(6, #points) do
        if points[i][2] < distance then hasLower = true end
        if points[i][2] > distance then hasHigher = true end
    end
    
    -- If we have points on both sides, prioritize getting a balanced selection
    if hasLower and hasHigher then
        -- Find closest lower point
        local closestLower = nil
        for i = 1, #points do
            if points[i][2] < distance and (closestLower == nil or points[i][1] < points[closestLower][1]) then
                closestLower = i
            end
        end
        
        -- Find closest higher point
        local closestHigher = nil
        for i = 1, #points do
            if points[i][2] > distance and (closestHigher == nil or points[i][1] < points[closestHigher][1]) then
                closestHigher = i
            end
        end
        
        -- Add these two points
        table.insert(selectedPoints, points[closestLower])
        table.insert(selectedPoints, points[closestHigher])
        
        -- Add one more point (either second closest lower or higher)
        local thirdPoint = nil
        for i = 1, #points do
            if i ~= closestLower and i ~= closestHigher and (thirdPoint == nil or points[i][1] < points[thirdPoint][1]) then
                thirdPoint = i
            end
        end
        table.insert(selectedPoints, points[thirdPoint])
    else
        -- Just use the three closest points
        for i = 1, 3 do
            selectedPoints[i] = points[i]
        end
    end
    
    -- Sort selected points by distance value for interpolation
    table.sort(selectedPoints, function(a, b) return a[2] < b[2] end)
    
    -- Get coordinates for quadratic interpolation
    local x1, y1 = selectedPoints[1][2], selectedPoints[1][3]
    local x2, y2 = selectedPoints[2][2], selectedPoints[2][3]
    local x3, y3 = selectedPoints[3][2], selectedPoints[3][3]
    
    -- Apply weighted interpolation for better accuracy
    local result = QuadraticInterpolate(distance, x1, y1, x2, y2, x3, y3)
    
    -- Apply AI-based correction factors based on distance patterns
    -- This helps fine-tune the interpolation for in-between distances
    local distanceRatio = (distance - x1) / (x3 - x1)
    local curvature = (y2 - (y1 + (y3 - y1) * ((x2 - x1) / (x3 - x1)))) / ((x2 - x1) * (x2 - x3))
    
    -- Apply dynamic correction based on curve characteristics
    local correctionFactor = 1.0
    
    -- If high curvature detected, apply stronger correction
    if math.abs(curvature) > 0.01 then
        correctionFactor = 1.0 + (math.abs(curvature) * 10) * (distanceRatio * (1 - distanceRatio))
    end
    
    -- Apply distance-specific corrections
    if distance > 300 then
        correctionFactor = correctionFactor * (1 + ((distance - 300) / 100) * 0.15)
    elseif distance > 200 then
        correctionFactor = correctionFactor * (1 + ((distance - 200) / 100) * 0.1)
    elseif distance > 150 then
        correctionFactor = correctionFactor * (1 + ((distance - 150) / 100) * 0.05)
    end
    
    -- Apply the correction to the interpolated result
    result = result * correctionFactor
    
    return result
end

local function GetPredictionFactor(distance, velocity)
    -- Get velocity magnitude (horizontal only for better prediction)
    local velocityMagnitude = Vector2.new(velocity.X, velocity.Z).Magnitude
    
    -- Dynamic prediction factor scaling based on distance
    -- The higher the distance, the higher the multiplier
    local baseFactor
    if distance <= 50 then
        baseFactor = Power80_PREDICTION_FACTOR * 0.4  -- Short distances
    elseif distance <= 70 then
        baseFactor = Power80_PREDICTION_FACTOR * 0.6   -- Medium-short distances
    elseif distance <= 90 then
        baseFactor = Power80_PREDICTION_FACTOR * 0.75  -- Medium distances
    elseif distance <= 110 then
        baseFactor = Power100_PREDICTION_FACTOR * 0.9  -- Medium-long distances
    elseif distance <= 130 then
        baseFactor = Power100_PREDICTION_FACTOR * 1.1  -- Long distances
    elseif distance <= 150 then
        baseFactor = Power100_PREDICTION_FACTOR * 1.5  -- Very long distances
    elseif distance <= 170 then
        baseFactor = Power100_PREDICTION_FACTOR * 1.2  -- Extended distances
    elseif distance <= 190 then
        baseFactor = Power100_PREDICTION_FACTOR * 1.3  -- Deep throws
    elseif distance <= 210 then
        baseFactor = Power100_PREDICTION_FACTOR * 1.5
    else
        -- For extremely long distances, scale even higher
        baseFactor = Power100_PREDICTION_FACTOR * (2.0 + ((distance - 300) / 50) * 0.2)
    end
    
    -- Apply velocity-based scaling with improved curve
    local velocityFactor = math.min(0.8 + (velocityMagnitude / 20)^0.8, 1.5)
    
    -- Progressive scaling based on distance - additional fine-tuning
    local distanceFactor = 1.0 + (distance / 250) * 0.15
    
    -- Direction-aware prediction (if moving away, need more prediction)
    local directionFactor = 1.0
    if velocity.Magnitude > 5 then
        local ball = workspace[LocalPlayer.Name]:FindFirstChild("Football")
        if ball then
            local ballToTarget = (Vector3.new(velocity.X, 0, velocity.Z).Unit)
            local velocityDir = velocity.Unit
            local dotProduct = ballToTarget:Dot(velocityDir)
            
            -- If target is moving away (dot product > 0), increase prediction
            if dotProduct > 0 then
                directionFactor = 1.0 + dotProduct * 0.25  -- Increased from 0.2 to 0.25
            end
        end
    end
    
    -- Combine all factors with weighted importance
    local finalFactor = baseFactor * velocityFactor * distanceFactor * directionFactor
    
    -- No need for additional distance-based adjustments since we've already
    -- implemented a comprehensive distance-based scaling system above
    
    return finalFactor
end

local function PredictPosition(target, distance)
    local hrp = target.Character.HumanoidRootPart
    local velocity = hrp.Velocity
    local predictionFactor = GetPredictionFactor(distance, velocity)
    return hrp.Position + (velocity * predictionFactor)
end

local function SetAutoPower(distance)
    -- Use 80 power for distances less than 100, otherwise use 100 power
    local power
    if distance < 100 then
        power = 80
    else
        power = 100
    end
    
    -- Update the power text box in the GUI
    local gui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("ScreenGui")
    if not gui then return power end

    local powerBox = gui:FindFirstChild("Power") or gui:FindFirstChild("PowerBox") or gui:FindFirstChildWhichIsA("TextBox", true)
    if powerBox and powerBox:IsA("TextBox") then
        powerBox.Text = tostring(power)
    end
    
    
    
    return power
end

local function AimAt(target)
    -- Add error handling
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
        landingIndicator.Transparency = 1  -- Hide indicator if no target
        for _, beam in ipairs(arcBeams) do
            beam.Transparency = NumberSequence.new(1) -- Hide all beams
        end
        return
    end

    local ball = workspace[LocalPlayer.Name]:FindFirstChild("Football")
    if not ball or not ball:IsA("BasePart") then 
        landingIndicator.Transparency = 1  -- Hide indicator if no ball
        for _, beam in ipairs(arcBeams) do
            beam.Transparency = NumberSequence.new(1) -- Hide all beams
        end
        return 
    end

    local targetPos = target.Character.HumanoidRootPart.Position
    local distance = (ball.Position - targetPos).Magnitude
    local predictedPosition = PredictPosition(target, distance)
    if not predictedPosition then 
        landingIndicator.Transparency = 1  -- Hide indicator if no prediction
        for _, beam in ipairs(arcBeams) do
            beam.Transparency = NumberSequence.new(1) -- Hide all beams
        end
        return 
    end

    -- Calculate the predicted distance after applying prediction
    local predictedDistance = (ball.Position - Vector3.new(predictedPosition.X, predictedPosition.Y, predictedPosition.Z)).Magnitude
    local power = SetAutoPower(predictedDistance)
    local arcY = GetArcY(predictedDistance, power)

    -- Update ball attachment position
    ballAttachment.WorldPosition = ball.Position
    beamPart.Position = ball.Position
    
    -- Show landing indicator for the predicted position
    landingIndicator.Position = Vector3.new(predictedPosition.X, 0, predictedPosition.Z)
    targetAttachment.WorldPosition = Vector3.new(predictedPosition.X, 0, predictedPosition.Z)
    landingIndicator.Transparency = 0.2  -- Make visible
    
    -- Update arc beam to simulate throw trajectory with physics-based calculation
    UpdateArcBeam(ball.Position, Vector3.new(predictedPosition.X, 0, predictedPosition.Z), arcY, power)
    
    -- Make beams visible
    for _, beam in ipairs(arcBeams) do
        beam.Transparency = NumberSequence.new(0.2)
    end

    -- Fire remote when T key is pressed
    if UserInputService:IsKeyDown(FIRE_KEY) then
        local chosenModel = nil
        local wsMiniGames = workspace:FindFirstChild("MiniGames")
        if wsMiniGames and #wsMiniGames:GetChildren() > 0 then
            for _, obj in ipairs(wsMiniGames:GetChildren()) do
                if obj:IsA("Model") then
                    local replicated = obj:FindFirstChild("Replicated")
                    if replicated and replicated:IsA("Model") then
                        local spotTags = replicated:FindFirstChild("SpotTags")
                        if spotTags and spotTags:IsA("Folder") then
                            chosenModel = obj
                            
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
                        ["Target"] = Vector3.new(predictedPosition.X, arcY, predictedPosition.Z),
                        ["AutoThrow"] = false,
                        ["Power"] = power
                    }
                }))
            else
                -- Fallback to workspace.Games
                local wsGames = workspace:FindFirstChild("Games")
                if not wsGames or #wsGames:GetChildren() == 0 then
                    
                end
                
                for _, obj in ipairs(wsGames:GetChildren()) do
                    if obj:IsA("Model") then
                        local replicated = obj:FindFirstChild("Replicated")
                        if replicated and replicated:IsA("Model") then
                            local ActiveSpots = replicated:FindFirstChild("ActiveSpots")
                            if ActiveSpots and ActiveSpots:IsA("Folder") then
                                chosenModel = obj
                                
                                break
                            end
                        end
                    end
                end
                
                
                if not chosenModel then
                   
                end
                
                game:GetService("ReplicatedStorage"):WaitForChild("Games"):WaitForChild(chosenModel.Name):WaitForChild("ReEvent"):FireServer(unpack({
                    [1] = "Mechanics",
                    [2] = "ThrowBall",
                    [3] = {
                        ["Target"] = Vector3.new(predictedPosition.X, arcY, predictedPosition.Z),
                        ["AutoThrow"] = false,
                        ["Power"] = power
                    }
                }))
            end
        end
    end
end

-- Toggle Handler
UserInputService.InputBegan:Connect(function(input, processed)
if processed then return end
if input.KeyCode == TOGGLE_KEY then
AimbotEnabled = not AimbotEnabled
end
end)

-- Main Loop
RunService.RenderStepped:Connect(function() 
    if not AimbotEnabled then 
        landingIndicator.Transparency = 1  -- Hide when disabled
        return 
    end 

    local target = GetClosestPlayer() 
    if target then 
        AimAt(target) 
    else 
        landingIndicator.Transparency = 1  -- Hide when no target
    end 
    
    -- Debug message to confirm the script is running
    if AimbotEnabled and not target then
        -- Only print occasionally to avoid spam
        if math.random(1, 100) == 1 then
            
        end
    end
end)

