local module = {}

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Vereinfachter Import ohne RuntimeLib
local function simpleImport(base, ...)
    local current = base
    for _, path in ipairs({...}) do
        current = current:WaitForChild(path)
    end
    if current:IsA("ModuleScript") then
        return require(current)
    else
        return current
    end
end

-- Versuche die echten Module zu importieren
local l_ClientEvents_0, objectutils

local success, result = pcall(function()
    local networking = simpleImport(game:GetService("ReplicatedStorage"), "Code", "modules", "networking")
    l_ClientEvents_0 = networking.ClientEvents
    
    objectutils = simpleImport(game:GetService("ReplicatedStorage"), "Code", "rbxts_include", "node_modules", "@rbxts", "object-utils")
    
    return true
end)

if not success then
    -- Fallback Implementation
    l_ClientEvents_0 = {
        ["8d932dc5-649b-4f4b-919c-ab26142bc939"] = {
            connect = function(self, callback)
                local event = Instance.new("BindableEvent")
                event.Event:Connect(callback)
                return {
                    Disconnect = function()
                        event:Destroy()
                    end
                }
            end
        }
    }
    
    objectutils = {
        entries = function(tab)
            local result = {}
            for key, value in pairs(tab) do
                table.insert(result, {key, value})
            end
            return result
        end
    }
end

-- Einstellungen
local Keys = {
    Top = {
        Enum.KeyCode.E, 
        Enum.KeyCode.Space, 
        Enum.KeyCode.ButtonA
    }, 
    Bottom = {
        Enum.KeyCode.Q, 
        Enum.KeyCode.ButtonY
    }
}

local SpeedModifiers = {
    {
        inputTypes = {Enum.KeyCode.LeftControl}, 
        speedMultiplier = 0.25
    }, 
    {
        inputTypes = {Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3}, 
        speedMultiplier = 3.25
    }
}

local Settings = {
    maxFlyHeight = 340, 
    maxAlignForce = 1000000, 
    baseSpeed = 80, 
    flyToggleInputTypes = {Enum.KeyCode.Space, Enum.KeyCode.ButtonA}
}

-- FlyController Klasse
local FlyController = {}
FlyController.__index = FlyController

function FlyController.new()
    local self = setmetatable({}, FlyController)
    return self:constructor()
end

function FlyController:constructor()
    self.camera = Workspace.CurrentCamera
    self.fly = false
    self.spacePressTime = 0
    self.flyInstances = nil
end

function FlyController:isInputPressed(inputTypes)
    for _, inputType in ipairs(inputTypes) do
        if UserInputService:IsKeyDown(inputType) or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, inputType) then
            return true
        end
    end
    return false
end

function FlyController:onStart()
    -- Input Handling für Flugaktivierung
    UserInputService.InputBegan:Connect(function(input)
        if not self:isInputPressed(Settings.flyToggleInputTypes) then
            return
        end
        
        local currentTime = tick()
        
        -- Doppelklick-Prüfung für Flugumschaltung
        if currentTime - self.spacePressTime < 0.3 and self.flyInstances then
            self:toggleFlying(not self.fly)
        end
        
        self.spacePressTime = currentTime
    end)

    -- Connect für Client-Events
    l_ClientEvents_0["8d932dc5-649b-4f4b-919c-ab26142bc939"]:connect(function(flyEnabled)
        return self:setFlyEnabled(flyEnabled)
    end)
end

function FlyController:setFlyEnabled(enabled)
    local character = Players.LocalPlayer.Character
    if not character then return end
    
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    if enabled then
        if self.flyInstances then return end
        
        -- Flug-Instanzen erstellen
        local attachment = Instance.new("Attachment")
        attachment.Parent = humanoidRootPart
        
        local alignPosition = Instance.new("AlignPosition")
        alignPosition.Attachment0 = attachment
        alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
        alignPosition.MaxForce = Settings.maxAlignForce
        alignPosition.Responsiveness = 5
        alignPosition.Position = humanoidRootPart.Position
        alignPosition.Parent = humanoidRootPart
        
        local alignOrientation = Instance.new("AlignOrientation")
        alignOrientation.Attachment0 = attachment
        alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
        alignOrientation.MaxTorque = Settings.maxAlignForce
        alignOrientation.Parent = humanoidRootPart
        
        self.flyInstances = {
            attachment = attachment,
            alignPosition = alignPosition,
            alignOrientation = alignOrientation
        }
        
        self:toggleFlying(true)
    else
        if not self.flyInstances then return end
        
        self:toggleFlying(false)
        self.flyInstances.attachment:Destroy()
        self.flyInstances.alignPosition:Destroy()
        self.flyInstances.alignOrientation:Destroy()
        self.flyInstances = nil
    end
end

function FlyController:isFlying()
    return self.fly
end

function FlyController:toggleFlying(flyState)
    if not self.flyInstances then return end
    if self.fly == flyState then return end
    
    self.fly = flyState
    local character = Players.LocalPlayer.Character
    if character then
        local humanoid = character:WaitForChild("Humanoid")
        humanoid.PlatformStand = flyState
        self.flyInstances.alignOrientation.Enabled = flyState
        self.flyInstances.alignPosition.Enabled = flyState
    end
end

function FlyController:getSpeed()
    for _, modifier in ipairs(SpeedModifiers) do
        if self:isInputPressed(modifier.inputTypes) then
            return Settings.baseSpeed * modifier.speedMultiplier
        end
    end
    return Settings.baseSpeed
end

function FlyController:applyMovement()
    local character = Players.LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or not humanoid.RootPart then return end
    
    humanoid.PlatformStand = true
    
    -- Bewegungseingaben verarbeiten (wie im Original)
    local v40 = objectutils.entries(Keys)
    local v41 = Vector3.new(0, 0, 0)
    
    for v47 = 1, #v40 do
        local l_v41_0 = v41
        local v49 = v40[v47]
        local direction = v49[1]
        local keys = v49[2]
        
        if self:isInputPressed(keys) then
            if direction == "Top" then
                v41 = l_v41_0 + Vector3.new(0, 1, 0)
            elseif direction == "Bottom" then
                v41 = l_v41_0 + Vector3.new(0, -1, 0)
            end
        end
    end
    
    -- Kombiniere mit Humanoid-Bewegung
    local v52 = self.camera.CFrame:VectorToObjectSpace(humanoid.MoveDirection)
    local v53 = v41 + if v52.Magnitude > 0 then Vector3.new(v52.X, 0, v52.Z).Unit else Vector3.new(0, 0, 0)
    local v54 = self:getSpeed()
    local v55 = CFrame.new(humanoid.RootPart.Position)
    local l_Rotation_0 = self.camera.CFrame.Rotation
    local v57 = if v53.Magnitude > 0 then v53.Unit * v54 else Vector3.new(0, 0, 0)
    local v58 = v55 * l_Rotation_0 * v57
    local v59 = Vector3.new(v58.X, math.min(v58.Y, Settings.maxFlyHeight), v58.Z)
    
    self.flyInstances.alignPosition.Position = v59
end

function FlyController:applyOrientation()
    local l_CFrame_0 = self.camera.CFrame
    self.flyInstances.alignOrientation.CFrame = l_CFrame_0
end

function FlyController:onTick()
    if not self.fly then return end
    self:applyMovement()
    self:applyOrientation()
end

-- Modul-Funktionen
function module.start()
    local flyController = FlyController.new()
    flyController:onStart()
    
    -- Tick-Connection
    local connection = RunService.Heartbeat:Connect(function()
        flyController:onTick()
    end)
    
    return {
        controller = flyController,
        disconnect = function()
            connection:Disconnect()
            if flyController.flyInstances then
                flyController:setFlyEnabled(false)
            end
        end
    }
end

function module.createController()
    return FlyController.new()
end

-- Exportiere die Klasse für direkte Verwendung
module.FlyController = FlyController
module.Keys = Keys
module.Settings = Settings

return module
