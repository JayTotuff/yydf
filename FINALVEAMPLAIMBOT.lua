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
local FOV_RADIUS = 100
local Power100_PREDICTION_FACTOR = 1
local Power90_PREDICTION_FACTOR = 1.2
local Power80_PREDICTION_FACTOR = 1.3
local Power65_PREDICTION_FACTOR = 1.5
-- Removed TEAM_ONLY_PLACE_ID as it's no longer needed

-- State
local AimbotEnabled = false

-- Define arcTable with trajectory data
local arcTable = {
    [100] = { 
        {241, 110}, {246, 120}, {251, 130}, {256, 140}, {260, 145}, {265, 150}, 
        {270, 158}, {275, 165}, {280, 170}, {285, 187}, {290, 193}, {295, 200}, {300, 210}, {305, 220}, {310, 230}

    },
    [90] = {
        {215, 120}, {220, 125},
        {225, 135}, {230, 145}, {235, 155}, {240, 165}
         
    },
    [80] = {
        {30, 10}, {40, 15}, {50, 15}, {60, 15}, {65, 15}, 
        {70, 20}, {75, 22}, {80, 22}, {85, 25}, {90, 26}, {95, 28}, {140, 60}, {145, 65}, {150, 72}, {155, 75}, {160, 80}, {165, 88}, {170, 100}, {175, 105}, {180, 110}, {185, 122}, {190, 133}, {195, 147}, {200, 165}, {205, 175}, {210, 200}, {214, 220}
         
    },
    [65] = {
        {100, 50}, {105, 55}, {110, 65}, {115, 70},
        {120, 80}, {125, 85}, {130, 95}, {135, 120}

    },
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
    part.Material = Enum.Material.ForceField
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
    
    print("[AimbotDebug] Landing indicator created successfully!")
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
print("[AimbotDebug] Initial landing indicator created at:", landingIndicator.Position)

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
        print("[AimbotDebug] Invalid football object for landing prediction")
        return nil
    end
    
    if not football or not football.Position or not football.Velocity then
        return nil
    end
    
    local pos = football.Position 
    local vel = football.Velocity 
    local grav = workspace.Gravity 
    
    -- Debug info
    print("[AimbotDebug] Football position:", pos, "velocity:", vel, "gravity:", grav)
    
    -- Check if velocity is too small to calculate landing
    if vel.Magnitude < 1 then
        print("[AimbotDebug] Football velocity too low for prediction")
        return pos
    end
    
    local y = vel.Y 
    
    -- Handle case where ball might not land (going straight up)
    local discriminant = y^2 - 2 * grav * (pos.Y - 1)
    if discriminant < 0 then
        print("[AimbotDebug] Discriminant negative, ball won't land")
        return nil
    end
    
    local t = (-y - math.sqrt(discriminant)) / -grav 
    
    -- If time is negative, ball is going up and won't land
    if t < 0 then
        print("[AimbotDebug] Negative time to landing, ball going up")
        return nil
    end
    
    local landingPos = pos + vel * t + 0.5 * Vector3.new(0, -grav, 0) * t^2 
    print("[AimbotDebug] Predicted landing position:", landingPos)
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
    
    -- Always check team ID (removed place ID condition)
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

-- Lagrange interpolation function
local function LagrangeInterpolate(x, points)
    local result = 0
    
    for i = 1, #points do
        local term = points[i][2]
        for j = 1, #points do
            if i ~= j then
                term = term * (x - points[j][1]) / (points[i][1] - points[j][1])
            end
        end
        result = result + term
    end
    
    return result
end

local function GetArcY(distance, power)
    local powerTable = arcTable[power]
    if not powerTable then return 0 end
    
    -- Find closest points for interpolation
    local points = {}
    for _, entry in ipairs(powerTable) do
        local tableDist = entry[1]
        local tableArc = entry[2]
        table.insert(points, {math.abs(tableDist - distance), tableDist, tableArc})
    end
    
    table.sort(points, function(a, b) return a[1] < b[1] end)
    
    -- If exact match found, return it
    if points[1][1] == 0 then return points[1][3] end
    
    -- Get points for Lagrange interpolation (use 3-4 points for better accuracy)
    local selectedPoints = {}
    local hasLower, hasHigher = false, false
    
    -- First check if we have points on both sides
    for i = 1, math.min(6, #points) do
        if points[i][2] < distance then hasLower = true end
        if points[i][2] > distance then hasHigher = true end
    end
    
    -- If we have points on both sides, prioritize getting a balanced selection
    if hasLower and hasHigher then
        -- Find closest lower points
        local lowerPoints = {}
        for i = 1, #points do
            if points[i][2] < distance then
                table.insert(lowerPoints, {points[i][1], i})
            end
        end
        table.sort(lowerPoints, function(a, b) return a[1] < b[1] end)
        
        -- Find closest higher points
        local higherPoints = {}
        for i = 1, #points do
            if points[i][2] > distance then
                table.insert(higherPoints, {points[i][1], i})
            end
        end
        table.sort(higherPoints, function(a, b) return a[1] < b[1] end)
        
        -- Add 1-2 lower points and 1-2 higher points
        for i = 1, math.min(2, #lowerPoints) do
            table.insert(selectedPoints, {points[lowerPoints[i][2]][2], points[lowerPoints[i][2]][3]})
        end
        
        for i = 1, math.min(2, #higherPoints) do
            table.insert(selectedPoints, {points[higherPoints[i][2]][2], points[higherPoints[i][2]][3]})
        end
    else
        -- Just use the closest points
        for i = 1, math.min(4, #points) do
            table.insert(selectedPoints, {points[i][2], points[i][3]})
        end
    end
    
    -- Sort selected points by distance value for interpolation
    table.sort(selectedPoints, function(a, b) return a[1] < b[1] end)
    
    -- Apply Lagrange interpolation
    local result = LagrangeInterpolate(distance, selectedPoints)
    
    -- Safety check for unreasonable values
    local maxArcValue = -math.huge
    local minArcValue = math.huge
    for _, point in ipairs(selectedPoints) do
        maxArcValue = math.max(maxArcValue, point[2])
        minArcValue = math.min(minArcValue, point[2])
    end
    
    -- If result is outside a reasonable range, clamp it
    if result > maxArcValue * 1.5 or result < minArcValue * 0.5 then
        print("[AimbotDebug] Interpolation produced extreme value: " .. result .. 
              " for distance " .. distance)
        
        -- Use nearest neighbor as fallback
        local closestPoint = points[1]
        result = closestPoint[3]
    end
    
    -- Apply AI-based correction factors based on distance patterns
    -- This helps fine-tune the interpolation for in-between distances
    local distanceRatio = (distance - selectedPoints[1][1]) / 
                          (selectedPoints[#selectedPoints][1] - selectedPoints[1][1])
    
    -- Apply dynamic correction based on curve characteristics
    local correctionFactor = 1.0
    
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
    
    -- Final safety check - if still extreme, use nearest neighbor
    if result > 1500 or result < 50 then
        print("[AimbotDebug] Final result still extreme after correction: " .. result .. 
              " for distance " .. distance .. ". Using nearest neighbor.")
        
        -- Find the closest point and use its arc value
        local closestPoint = points[1]
        result = closestPoint[3]
    end
    
    return result
end

local function GetPredictionFactor(distance, velocity)
    -- Get velocity magnitude (horizontal only for better prediction)
    local velocityMagnitude = Vector2.new(velocity.X, velocity.Z).Magnitude
    
    -- Dynamic prediction factor scaling based on distance
    local baseFactor
    if distance <= 50 then
        baseFactor = Power80_PREDICTION_FACTOR * 0.4  -- Very short distances
    elseif distance <= 70 then
        baseFactor = Power80_PREDICTION_FACTOR * 0.5  -- Short distances
    elseif distance <= 95 then
        baseFactor = Power80_PREDICTION_FACTOR * 0.8  -- Medium-short distances
    elseif distance <= 110 then
        baseFactor = Power65_PREDICTION_FACTOR * 0.9  -- Medium distances (65 power)
    elseif distance <= 135 then
        baseFactor = Power65_PREDICTION_FACTOR * 1.1  -- Medium-long distances (65 power)
    elseif distance <= 170 then
        baseFactor = Power80_PREDICTION_FACTOR * 1.2  -- Long distances (80 power)
    elseif distance <= 214 then
        baseFactor = Power80_PREDICTION_FACTOR * 1.35  -- Very long distances (80 power)
    elseif distance <= 225 then
        baseFactor = Power90_PREDICTION_FACTOR * 1.47  -- Extended distances (90 power)
    elseif distance <= 240 then
        baseFactor = Power90_PREDICTION_FACTOR * 1.57  -- Deep throws (90 power)
    elseif distance <= 270 then
        baseFactor = Power100_PREDICTION_FACTOR * 1.68  -- Extreme distances (100 power)
    elseif distance <= 310 then
        baseFactor = Power100_PREDICTION_FACTOR * 1.8  -- Ultra distances (100 power)
    else
        -- For extremely long distances, scale even higher
        baseFactor = Power100_PREDICTION_FACTOR * (2.5 + ((distance - 310) / 50) * 0.3)
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
    -- Set power based on distance ranges with more precise boundaries
    local power
    
    if distance >= 30 and distance < 100 then
        power = 80
    elseif distance >= 100 and distance < 140 then
        power = 65
    elseif distance >= 140 and distance < 215 then
        power = 80
    elseif distance >= 215 and distance < 241 then
        power = 90
    elseif distance >= 241 and distance <= 310 then
        power = 100
    else
        -- Default fallback for distances outside specified ranges
        if distance < 30 then
            power = 80
        else
            power = 100
        end
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

    -- Get the target's current position
    local targetPos = target.Character.HumanoidRootPart.Position
    local currentDistance = (ball.Position - targetPos).Magnitude
    
    -- Predict where the target will be (future position)
    local predictedPosition = PredictPosition(target, currentDistance)
    if not predictedPosition then 
        landingIndicator.Transparency = 1  -- Hide indicator if no prediction
        for _, beam in ipairs(arcBeams) do
            beam.Transparency = NumberSequence.new(1) -- Hide all beams
        end
        return 
    end

    -- Calculate the distance from ball to the predicted position
    local predictedDistance = (ball.Position - predictedPosition).Magnitude
    
    -- Determine the appropriate power based on the predicted distance
    local power = SetAutoPower(predictedDistance)
    
    -- Get the arc height from the arcTable using the predicted distance and power
    local arcY = GetArcY(predictedDistance, power)
    
    print("[AimbotDebug] Distance to future position: " .. predictedDistance .. ", Power: " .. power .. ", Arc Height: " .. arcY)

    -- Update ball attachment position
    ballAttachment.WorldPosition = ball.Position
    beamPart.Position = ball.Position
    
    -- Show landing indicator at the predicted position
    landingIndicator.Position = Vector3.new(predictedPosition.X, 0, predictedPosition.Z)
    targetAttachment.WorldPosition = Vector3.new(predictedPosition.X, 0, predictedPosition.Z)
    landingIndicator.Transparency = 0.2  -- Make visible
    
    -- Update arc beam to simulate throw trajectory from ball to predicted position
    UpdateArcBeam(ball.Position, Vector3.new(predictedPosition.X, 0, predictedPosition.Z), arcY, power)
    
    -- Fire remote when T is pressed
    if UserInputService:IsKeyDown(FIRE_KEY) then
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
                error("No model in workspace.MiniGames with Replicated (Model) and SpotTags (Folder) found!")
            end
        else
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
                    ["Target"] = Vector3.new(predictedPosition.X, arcY, predictedPosition.Z),
                    ["AutoThrow"] = false,
                    ["Power"] = power
                    }
                }))
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
            print("[AimbotDebug] Aimbot enabled but no valid target found")
        end
    end
end)

-- Print confirmation that the script loaded successfully
print("[AimbotDebug] 3D Landing Indicator Aimbot loaded successfully!")
