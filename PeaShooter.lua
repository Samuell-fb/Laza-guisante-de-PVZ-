--[[ 
	PvZ Pea Shooter + Manual Button + Fire/Ice Modes
	Single-script version for Studio Lite.
	- Manual mode: shows a movable action button that fires forward.
	- Auto mode: fires forward continuously.
	- Fire mode: fire projectile + burn effect on hit.
	- Ice mode: ice projectile + freeze effect on hit.
	- Minimize/restore fixed.
	- Dragging fixed for both menu and floating button.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GUI_NAME = "PvZ_PeaShooter_GUI_V2"

-- Cleanup old UI
do
	local old = playerGui:FindFirstChild(GUI_NAME)
	if old then
		old:Destroy()
	end
end

--=====================================================
-- STATE
--=====================================================
local State = {
	SystemEnabled = false,
	AutoShoot = false,
	ManualMode = false,
	FireMode = false,
	IceMode = false,
	Damage = 25,
	Power = 50, -- used for freeze duration / intensity
}

local character, humanoid, head
local autoToken = 0
local freezeRegistry = {}
local burnRegistry = {}

--=====================================================
-- CHARACTER REFS
--=====================================================
local function refreshCharacter()
	character = player.Character
	if not character then
		humanoid = nil
		head = nil
		return
	end

	humanoid = character:FindFirstChildOfClass("Humanoid")
	head = character:FindFirstChild("Head")
end

local function onCharacterAdded(char)
	character = char
	humanoid = char:WaitForChild("Humanoid", 10)
	head = char:WaitForChild("Head", 10)
end

player.CharacterAdded:Connect(onCharacterAdded)
player.CharacterRemoving:Connect(function()
	character = nil
	humanoid = nil
	head = nil
end)

if player.Character then
	onCharacterAdded(player.Character)
end

--=====================================================
-- HELPERS
--=====================================================
local function clampNumber(value, minValue, maxValue, defaultValue)
	value = tonumber(value)
	if not value then
		return defaultValue
	end
	value = math.floor(value)
	if value < minValue then
		return minValue
	end
	if value > maxValue then
		return maxValue
	end
	return value
end

local function getFreezeDuration()
	-- 5s for weaker power, 10s for stronger power
	if State.Power >= 50 then
		return 10
	end
	return 5
end

local function getShootOriginAndDirection()
	refreshCharacter()
	if not character or not head then
		return nil, nil
	end

	local origin = head.Position + (head.CFrame.LookVector * 1.6) + Vector3.new(0, 0.15, 0)
	local direction = head.CFrame.LookVector
	if direction.Magnitude < 0.001 then
		direction = Vector3.new(0, 0, -1)
	end

	return origin, direction.Unit
end

local function safeDestroy(instance)
	if instance and instance.Parent then
		instance:Destroy()
	end
end

--=====================================================
-- EFFECTS: FIRE / ICE
--=====================================================
local function applyBurnEffect(part, duration)
	if not part or not part.Parent or not part:IsA("BasePart") then
		return
	end

	local token = os.clock()
	burnRegistry[part] = token

	local oldColor = part.Color
	local oldMaterial = part.Material
	local oldTransparency = part.Transparency
	local oldAnchored = part.Anchored

	part.Color = Color3.fromRGB(255, 120, 35)
	part.Material = Enum.Material.Neon
	part.Transparency = math.clamp(oldTransparency - 0.05, 0, 1)

	local fire = Instance.new("Fire")
	fire.Heat = 12
	fire.Size = 7
	fire.Parent = part

	local smoke = Instance.new("Smoke")
	smoke.Opacity = 0.35
	smoke.RiseVelocity = 8
	smoke.Size = 5
	smoke.Parent = part

	Debris:AddItem(fire, duration)
	Debris:AddItem(smoke, duration)

	task.delay(duration, function()
		if not part or not part.Parent then
			return
		end
		if burnRegistry[part] ~= token then
			return
		end

		-- Restore if still present, otherwise do nothing.
		if part.Parent then
			-- Burn mode destroys the hit object as requested.
			-- If you want only visual burning, comment out the next line.
			safeDestroy(part)
		end
	end)
end

local function freezeHumanoid(targetHumanoid, duration)
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return
	end

	local model = targetHumanoid.Parent
	if not model or not model:IsA("Model") then
		return
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local token = os.clock()
	freezeRegistry[targetHumanoid] = token

	local oldWalkSpeed = targetHumanoid.WalkSpeed
	local oldJumpPower = targetHumanoid.JumpPower
	local oldAutoRotate = targetHumanoid.AutoRotate
	local oldPlatformStand = targetHumanoid.PlatformStand
	local oldAnchored = root.Anchored

	targetHumanoid.WalkSpeed = 0
	targetHumanoid.JumpPower = 0
	targetHumanoid.AutoRotate = false
	targetHumanoid.PlatformStand = true
	root.Anchored = true

	local icePart = Instance.new("Part")
	icePart.Name = "IceShell"
	icePart.Size = Vector3.new(4, 5, 4)
	icePart.Transparency = 0.45
	icePart.Material = Enum.Material.Ice
	icePart.Color = Color3.fromRGB(160, 220, 255)
	icePart.CanCollide = false
	icePart.Anchored = true
	icePart.CFrame = root.CFrame
	icePart.Parent = Workspace

	Debris:AddItem(icePart, duration)

	task.delay(duration, function()
		if not targetHumanoid or not targetHumanoid.Parent then
			return
		end
		if freezeRegistry[targetHumanoid] ~= token then
			return
		end

		local currentModel = targetHumanoid.Parent
		local currentRoot = currentModel and currentModel:FindFirstChild("HumanoidRootPart")
		if currentRoot then
			currentRoot.Anchored = oldAnchored
		end

		if targetHumanoid.Health > 0 then
			targetHumanoid.WalkSpeed = oldWalkSpeed
			targetHumanoid.JumpPower = oldJumpPower
			targetHumanoid.AutoRotate = oldAutoRotate
			targetHumanoid.PlatformStand = oldPlatformStand
		end
	end)
end

local function applyIceEffectToPart(part, duration)
	if not part or not part.Parent or not part:IsA("BasePart") then
		return
	end

	local token = os.clock()
	freezeRegistry[part] = token

	local oldColor = part.Color
	local oldMaterial = part.Material
	local oldTransparency = part.Transparency
	local oldAnchored = part.Anchored
	local oldCanCollide = part.CanCollide

	part.Color = Color3.fromRGB(170, 230, 255)
	part.Material = Enum.Material.Ice
	part.Transparency = math.clamp(oldTransparency + 0.15, 0, 0.8)
	part.Anchored = true
	part.CanCollide = true

	local iceGlow = Instance.new("PointLight")
	iceGlow.Color = Color3.fromRGB(180, 240, 255)
	iceGlow.Brightness = 1.5
	iceGlow.Range = 10
	iceGlow.Parent = part

	Debris:AddItem(iceGlow, duration)

	task.delay(duration, function()
		if not part or not part.Parent then
			return
		end
		if freezeRegistry[part] ~= token then
			return
		end

		-- Restore
		if part.Parent then
			part.Color = oldColor
			part.Material = oldMaterial
			part.Transparency = oldTransparency
			part.Anchored = oldAnchored
			part.CanCollide = oldCanCollide
		end
	end)
end

--=====================================================
-- PROJECTILE
--=====================================================
local function createProjectile(kind)
	local p = Instance.new("Part")
	p.Name = kind .. "Pea"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(0.45, 0.45, 0.45)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Material = (kind == "Fire" and Enum.Material.Neon) or (kind == "Ice" and Enum.Material.Ice) or Enum.Material.SmoothPlastic

	if kind == "Fire" then
		p.Color = Color3.fromRGB(255, 125, 40)
	elseif kind == "Ice" then
		p.Color = Color3.fromRGB(170, 230, 255)
	else
		p.Color = Color3.fromRGB(85, 255, 85)
	end

	local attachment0 = Instance.new("Attachment")
	attachment0.Position = Vector3.new(0, 0.15, 0)
	attachment0.Parent = p

	local attachment1 = Instance.new("Attachment")
	attachment1.Position = Vector3.new(0, -0.15, 0)
	attachment1.Parent = p

	local trail = Instance.new("Trail")
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Lifetime = 0.15
	trail.MinLength = 0.03
	trail.LightInfluence = 0
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.Color = ColorSequence.new(p.Color)
	trail.Parent = p

	if kind == "Fire" then
		local fire = Instance.new("Fire")
		fire.Heat = 8
		fire.Size = 5
		fire.Parent = p
	elseif kind == "Ice" then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Rate = 25
		sparkle.Lifetime = NumberRange.new(0.12, 0.2)
		sparkle.Speed = NumberRange.new(0.2, 1)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.LightEmission = 1
		sparkle.Color = ColorSequence.new(Color3.fromRGB(210, 245, 255), Color3.fromRGB(150, 210, 255))
		sparkle.Parent = p
	end

	p.Parent = Workspace
	Debris:AddItem(p, 4)
	return p
end

local function fireOnce()
	if not State.SystemEnabled then
		return
	end

	refreshCharacter()
	if not character or not head then
		return
	end

	local origin, direction = getShootOriginAndDirection()
	if not origin or not direction then
		return
	end

	local kind = "Normal"
	if State.FireMode then
		kind = "Fire"
	elseif State.IceMode then
		kind = "Ice"
	end

	local projectile = createProjectile(kind)
	local speed = 200
	local distanceLimit = 650
	local traveled = 0
	local lastPos = origin

	projectile.CFrame = CFrame.new(origin, origin + direction)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true
	rayParams.FilterDescendantsInstances = { character, projectile }

	while projectile.Parent and traveled < distanceLimit and State.SystemEnabled do
		local dt = RunService.Heartbeat:Wait()
		if not projectile.Parent or not State.SystemEnabled then
			break
		end

		local step = speed * dt
		local nextPos = lastPos + (direction * step)
		local result = Workspace:Raycast(lastPos, nextPos - lastPos, rayParams)

		if result then
			local hit = result.Instance
			local hitModel = hit and hit:FindFirstAncestorOfClass("Model")
			local hitHumanoid = hitModel and hitModel:FindFirstChildOfClass("Humanoid")

			if hitHumanoid and hitModel ~= character then
				-- Damage
				hitHumanoid:TakeDamage(State.Damage)

				-- Fire mode burns the target; Ice mode freezes the target.
				if State.FireMode then
					applyBurnEffect(hit:FindFirstAncestorWhichIsA("BasePart") or hit, 1.25)
				elseif State.IceMode then
					freezeHumanoid(hitHumanoid, getFreezeDuration())
				end
			else
				-- Object hit
				if State.FireMode and hit:IsA("BasePart") then
					applyBurnEffect(hit, 1.2)
				elseif State.IceMode and hit:IsA("BasePart") then
					applyIceEffectToPart(hit, getFreezeDuration())
				end
			end

			projectile.CFrame = CFrame.new(result.Position, result.Position + direction)
			projectile:Destroy()
			return
		end

		projectile.CFrame = CFrame.new(nextPos, nextPos + direction)
		lastPos = nextPos
		traveled += step
	end

	if projectile.Parent then
		projectile:Destroy()
	end
end

--=====================================================
-- UI
--=====================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = playerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 280, 0, 390)
MainFrame.Position = UDim2.new(0.5, -140, 0.5, -195)
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1
MainStroke.Transparency = 0.35
MainStroke.Color = Color3.fromRGB(120, 120, 135)
MainStroke.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 0, 34)
Title.Position = UDim2.new(0, 12, 0, 8)
Title.BackgroundTransparency = 1
Title.Text = "🌱 Pea Shooter Panel"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
MinimizeBtn.Position = UDim2.new(1, -38, 0, 8)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
MinimizeBtn.Text = "—"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 20
MinimizeBtn.Parent = MainFrame

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 8)
MinCorner.Parent = MinimizeBtn

local LogoButton = Instance.new("TextButton")
LogoButton.Name = "LogoButton"
LogoButton.Size = UDim2.new(0, 54, 0, 54)
LogoButton.Position = UDim2.new(0, 30, 0, 30)
LogoButton.BackgroundColor3 = Color3.fromRGB(60, 200, 80)
LogoButton.Text = "🌱"
LogoButton.TextSize = 26
LogoButton.Font = Enum.Font.GothamBold
LogoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoButton.Visible = false
LogoButton.Parent = ScreenGui

local LogoCorner = Instance.new("UICorner")
LogoCorner.CornerRadius = UDim.new(1, 0)
LogoCorner.Parent = LogoButton

local LogoStroke = Instance.new("UIStroke")
LogoStroke.Thickness = 1
LogoStroke.Transparency = 0.25
LogoStroke.Color = Color3.fromRGB(255, 255, 255)
LogoStroke.Parent = LogoButton

local function makeButton(text, y)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.9, 0, 0, 34)
	btn.Position = UDim2.new(0.05, 0, 0, y)
	btn.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(230, 230, 230)
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 14
	btn.Parent = MainFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	return btn
end

local SystemBtn = makeButton("Sistema: OFF", 52)
local ManualBtn = makeButton("Modo Manual: OFF", 96)
local AutoBtn = makeButton("Auto Disparo: OFF", 140)
local FireBtn = makeButton("Modo Fuego: OFF", 184)
local IceBtn = makeButton("Modo Hielo: OFF", 228)
local AutoKillBtn = makeButton("Auto Kill: OFF", 272)

local DamageBox = Instance.new("TextBox")
DamageBox.Size = UDim2.new(0.42, 0, 0, 28)
DamageBox.Position = UDim2.new(0.05, 0, 1, -36)
DamageBox.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
DamageBox.TextColor3 = Color3.fromRGB(255, 255, 255)
DamageBox.PlaceholderText = "Daño"
DamageBox.Text = tostring(State.Damage)
DamageBox.ClearTextOnFocus = false
DamageBox.Font = Enum.Font.Gotham
DamageBox.TextSize = 13
DamageBox.Parent = MainFrame

local DamageCorner = Instance.new("UICorner")
DamageCorner.CornerRadius = UDim.new(0, 8)
DamageCorner.Parent = DamageBox

local PowerBox = Instance.new("TextBox")
PowerBox.Size = UDim2.new(0.42, 0, 0, 28)
PowerBox.Position = UDim2.new(0.53, 0, 1, -36)
PowerBox.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
PowerBox.TextColor3 = Color3.fromRGB(255, 255, 255)
PowerBox.PlaceholderText = "Fuerza"
PowerBox.Text = tostring(State.Power)
PowerBox.ClearTextOnFocus = false
PowerBox.Font = Enum.Font.Gotham
PowerBox.TextSize = 13
PowerBox.Parent = MainFrame

local PowerCorner = Instance.new("UICorner")
PowerCorner.CornerRadius = UDim.new(0, 8)
PowerCorner.Parent = PowerBox

local Footer = Instance.new("TextLabel")
Footer.Size = UDim2.new(1, -20, 0, 18)
Footer.Position = UDim2.new(0, 10, 1, -60)
Footer.BackgroundTransparency = 1
Footer.Text = "Manual = botón flotante | Fire/Ice = efecto al frente"
Footer.TextColor3 = Color3.fromRGB(180, 180, 190)
Footer.Font = Enum.Font.Gotham
Footer.TextSize = 11
Footer.TextXAlignment = Enum.TextXAlignment.Center
Footer.Parent = MainFrame

local ActionButton = Instance.new("TextButton")
ActionButton.Name = "ActionButton"
ActionButton.Size = UDim2.new(0, 64, 0, 64)
ActionButton.Position = UDim2.new(1, -94, 1, -110)
ActionButton.BackgroundColor3 = Color3.fromRGB(70, 130, 255)
ActionButton.Text = "FIRE"
ActionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ActionButton.Font = Enum.Font.GothamBold
ActionButton.TextSize = 18
ActionButton.Visible = false
ActionButton.Parent = ScreenGui

local ActionCorner = Instance.new("UICorner")
ActionCorner.CornerRadius = UDim.new(1, 0)
ActionCorner.Parent = ActionButton

local ActionStroke = Instance.new("UIStroke")
ActionStroke.Thickness = 1
ActionStroke.Transparency = 0.25
ActionStroke.Color = Color3.fromRGB(255, 255, 255)
ActionStroke.Parent = ActionButton

--=====================================================
-- DRAGGING
--=====================================================
local function makeDraggable(guiObject)
	local dragging = false
	local dragInput = nil
	local dragStart = nil
	local startPos = nil

	guiObject.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = guiObject.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	guiObject.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input == dragInput and dragStart and startPos then
			local delta = input.Position - dragStart
			guiObject.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)
end

makeDraggable(MainFrame)
makeDraggable(LogoButton)
makeDraggable(ActionButton)

--=====================================================
-- UI STATE
--=====================================================
local function refreshUI()
	SystemBtn.Text = State.SystemEnabled and "Sistema: ON" or "Sistema: OFF"
	ManualBtn.Text = State.ManualMode and "Modo Manual: ON" or "Modo Manual: OFF"
	AutoBtn.Text = State.AutoShoot and "Auto Disparo: ON" or "Auto Disparo: OFF"
	FireBtn.Text = State.FireMode and "Modo Fuego: ON" or "Modo Fuego: OFF"
	IceBtn.Text = State.IceMode and "Modo Hielo: ON" or "Modo Hielo: OFF"
	AutoKillBtn.Text = State.AutoKill and "Auto Kill: ON" or "Auto Kill: OFF"

	SystemBtn.BackgroundColor3 = State.SystemEnabled and Color3.fromRGB(60, 140, 70) or Color3.fromRGB(55, 55, 65)
	ManualBtn.BackgroundColor3 = State.ManualMode and Color3.fromRGB(70, 110, 190) or Color3.fromRGB(55, 55, 65)
	AutoBtn.BackgroundColor3 = State.AutoShoot and Color3.fromRGB(60, 140, 70) or Color3.fromRGB(55, 55, 65)
	FireBtn.BackgroundColor3 = State.FireMode and Color3.fromRGB(180, 95, 30) or Color3.fromRGB(55, 55, 65)
	IceBtn.BackgroundColor3 = State.IceMode and Color3.fromRGB(80, 140, 200) or Color3.fromRGB(55, 55, 65)
	AutoKillBtn.BackgroundColor3 = State.AutoKill and Color3.fromRGB(140, 60, 140) or Color3.fromRGB(55, 55, 65)

	ActionButton.Visible = State.SystemEnabled and State.ManualMode
	ActionButton.Text = State.FireMode and "FIRE" or (State.IceMode and "ICE" or "SHOT")
end

local function stopAutoLoop()
	autoToken += 1
end

local function startAutoLoop()
	stopAutoLoop()
	autoToken += 1
	local myToken = autoToken

	task.spawn(function()
		while State.SystemEnabled and State.AutoShoot and autoToken == myToken do
			fireOnce()
			task.wait(State.FireMode and 0.18 or State.IceMode and 0.2 or 0.16)
		end
	end)
end

--=====================================================
-- MINIMIZE / RESTORE
--=====================================================
local function minimizeMenu()
	MainFrame.Visible = false
	LogoButton.Visible = true
end

local function restoreMenu()
	LogoButton.Visible = false
	MainFrame.Visible = true
end
MinimizeBtn.MouseButton1Click:Connect(minimizeMenu)
LogoButton.MouseButton1Click:Connect(restoreMenu)

--=====================================================
-- BUTTON EVENTS
--=====================================================
SystemBtn.MouseButton1Click:Connect(function()
	State.SystemEnabled = not State.SystemEnabled
	if not State.SystemEnabled then
		State.AutoShoot = false
		stopAutoLoop()
	end
	refreshUI()

	if State.SystemEnabled and State.AutoShoot then
		startAutoLoop()
	end
end)

ManualBtn.MouseButton1Click:Connect(function()
	State.ManualMode = not State.ManualMode
	refreshUI()
end)

AutoBtn.MouseButton1Click:Connect(function()
	State.AutoShoot = not State.AutoShoot
	refreshUI()

	if State.SystemEnabled and State.AutoShoot then
		startAutoLoop()
	else
		stopAutoLoop()
	end
end)

FireBtn.MouseButton1Click:Connect(function()
	State.FireMode = not State.FireMode
	if State.FireMode then
		State.IceMode = false
	end
	refreshUI()
	if State.SystemEnabled and State.AutoShoot then
		startAutoLoop()
	end
end)

IceBtn.MouseButton1Click:Connect(function()
	State.IceMode = not State.IceMode
	if State.IceMode then
		State.FireMode = false
	end
	refreshUI()
	if State.SystemEnabled and State.AutoShoot then
		startAutoLoop()
	end
end)

AutoKillBtn.MouseButton1Click:Connect(function()
	State.AutoKill = not State.AutoKill
	refreshUI()
end)

DamageBox.FocusLost:Connect(function()
	State.Damage = clampNumber(DamageBox.Text, 1, 1000, State.Damage)
	DamageBox.Text = tostring(State.Damage)
end)

PowerBox.FocusLost:Connect(function()
	State.Power = clampNumber(PowerBox.Text, 1, 100, State.Power)
	PowerBox.Text = tostring(State.Power)
end)

ActionButton.MouseButton1Click:Connect(function()
	if State.SystemEnabled and State.ManualMode then
		fireOnce()
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if State.SystemEnabled and not State.ManualMode then
			fireOnce()
		end
	end
end)

--=====================================================
-- AUTO-KILL SUPPORT
--=====================================================
local function freezeDeadCharacter(deadCharacter)
	if not deadCharacter or not deadCharacter.Parent then
		return
	end

	local deadHum = deadCharacter:FindFirstChildOfClass("Humanoid")
	local root = deadCharacter:FindFirstChild("HumanoidRootPart")

	if deadHum then
		deadHum.WalkSpeed = 0
		deadHum.JumpPower = 0
		deadHum.AutoRotate = false
		deadHum.PlatformStand = true
		pcall(function()
			deadHum:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end

	if root and root:IsA("BasePart") then
		root.Anchored = true
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function bindAutoKillToHumanoid(targetHumanoid)
	if not targetHumanoid then
		return
	end

	targetHumanoid.Died:Connect(function()
		if State.AutoKill then
			task.defer(function()
				local model = targetHumanoid.Parent
				freezeDeadCharacter(model)
			end)
		end
	end)
end

-- Hook current and future humanoids found in the character
task.spawn(function()
	while true do
		task.wait(1.5)
		if character and character.Parent then
			local hum = character:FindFirstChildOfClass("Humanoid")
			if hum and hum ~= humanoid then
				humanoid = hum
				bindAutoKillToHumanoid(humanoid)
			end
		end
	end
end)

--=====================================================
-- INITIAL STATE
--=====================================================
refreshUI()
refreshCharacter()
if humanoid then
	bindAutoKillToHumanoid(humanoid)
end
