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
local MetaDatas = nil
local function InstanceToHierarchy(Instance)
	local Hierarchy = {}
	for _, Child in Instance:GetChildren() do
		if next(Child:GetChildren()) then
			Hierarchy[Child.Name] = InstanceToHierarchy(Child)
		else
			if Child:IsA("ModuleScript") then
				Hierarchy[Child.Name] = require(Child)
			else
				Hierarchy[Child.Name] = Child
			end
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
		for _, Notification in VisibleNotifications do
			local CurrentPosition = Notification.Position
			Notification.Position = UDim2.new(CurrentPosition.X.Scale, 0, CurrentPosition.Y.Scale + BoilerplateSize.Y.Scale, 0)
		end
		if #VisibleNotifications == MAX_NOTIFICATIONS then
			local Removed = table.remove(VisibleNotifications, 1)
			Removed:Destroy()
		end
		table.insert(VisibleNotifications, Clone)
		JustNotified = true
		NumberOfNotifications += 1
	end
end
local Clock = os.clock()
RunService.Heartbeat:Connect(function()
	local Head = Queue[1]
	if Head and not NotificationDebounce:IsOnCooldown() then
		Module.DisplayNotification(Head.Path)
	end
	if JustNotified then
		JustNotified = false
		Clock = os.clock()
	end
	if os.clock() - Clock > DISAPPEAR_TIME then
		local Size = #VisibleNotifications
		local Tail = VisibleNotifications[Size]
		if Tail then
			local Removed = table.remove(VisibleNotifications, Size)
			Removed:Destroy()
		end
	end
end)
return Module
