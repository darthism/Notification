local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Utilities = ReplicatedStorage
					:WaitForChild("Shared")
					:WaitForChild("Utilities")
local Debounce = require(Utilities:WaitForChild("Debounce"))
local NotificationsUI = LocalPlayer
							:WaitForChild("PlayerGui")
							:WaitForChild("Notifications")
local Boilerplate = NotificationsUI:WaitForChild("Boilerplate")
local MetaDatasInstance = script:WaitForChild("Metadata")
local MAX_NOTIFICATIONS = 5
local DISAPPEAR_TIME = 7
local SHIFT_UP_TIME = 1
local MetaDatas = nil
local function InstanceToHierarchy(Instance)
	local Hierarchy = {}
	for _, Child in Instance:GetChildren() do
		if next(Child:GetChildren()) then
			Hierarchy[Child.Name] = InstanceToHierarchy(Child)
		elseif Child:IsA("ModuleScript") then
			Hierarchy[Child.Name] = require(Child)
		end
	end
	return Hierarchy
end
local function GetFromPath(Table, Path)
	local Split = string.split(Path, "/")
	local Temp = Table
	for _, Value in Split do
		Temp = Temp[Value]
	end
	return Temp
end
MetaDatas = InstanceToHierarchy(MetaDatasInstance)
local BoilerplatePosition = Boilerplate.Position
local BoilerplateSize = Boilerplate.Size
local Queue = {}
local NotificationDebounce = Debounce.new(0.25)
local NumberOfNotifications = 0
local JustNotified = false
local VisibleNotifications = {}
local Module = {}
function Module._GetIndexFromQueue(Path)
	local Index = nil
	for _Index, Object in Queue do
		if Object.Path == Path then
			Index = _Index
		end
	end
	return Index
end
function Module._ShiftNotifications(IsDown)
	local Sign = IsDown and 1 or -1
	while true do
		for _, Notification in VisibleNotifications do
			local CurrentPosition = Notification.Position
			Notification.Position = UDim2.new(CurrentPosition.X.Scale, 0, CurrentPosition.Y.Scale + BoilerplateSize.Y.Scale * Sign, 0)
		end
		if IsDown then
			if #VisibleNotifications == MAX_NOTIFICATIONS then
				local Removed = table.remove(VisibleNotifications, 1)
				Removed:Destroy()
			end
			break
		else
			local Removed = table.remove(VisibleNotifications, #VisibleNotifications)
			Removed:Destroy()
			task.wait(SHIFT_UP_TIME)
			if JustNotified or not next(VisibleNotifications) then
				break
			end
		end
	end
end
function Module.DisplayNotification(Path, ...)
	local Formatters = {...}
	local Metadata = GetFromPath(MetaDatas, Path)
	if NotificationDebounce:IsOnCooldown() then
		local Index = Module._GetIndexFromQueue(Path)
		if Index then
			local Object = Queue[Index]
			Object.Formatters = Metadata.MergeFormatters(Object.Formatters, Formatters)
		else
			table.insert(Queue, {
				Formatters = Formatters,
				Message = Metadata.Message,
				Path = Path, 
			})
		end
	else
		NotificationDebounce:Activate()
		local ToDisplayWrapper = table.remove(Queue, 1)
		ToDisplayWrapper = ToDisplayWrapper or {
			Formatters = Formatters,
			Message = Metadata.Message
		}
		local ToDisplay = string.format(ToDisplayWrapper.Message, unpack(ToDisplayWrapper.Formatters))
		local Clone = Boilerplate:Clone()
		Clone.Position = UDim2.new(BoilerplatePosition.X.Scale, 0, BoilerplatePosition.Y.Scale, 0)
		Clone.Text = ToDisplay
		Clone.TextColor3 = Metadata.Color
		Clone.TextTransparency = 0
		Clone.Parent = NotificationsUI
		Module._ShiftNotifications(true)
		table.insert(VisibleNotifications, Clone)
		JustNotified = true
		NumberOfNotifications += 1
	end
end
local Clock = os.clock()
local Flag = true
RunService.Heartbeat:Connect(function()
	local Head = Queue[1]
	if Head and not NotificationDebounce:IsOnCooldown() then
		Module.DisplayNotification(Head.Path)
	end
	if JustNotified then
		JustNotified = false
		Clock = os.clock()
	end
	if os.clock() - Clock > DISAPPEAR_TIME and next(VisibleNotifications) and Flag then
		Flag = false
		Module._ShiftNotifications(false)
		Flag = true
	end
end)
return Module
