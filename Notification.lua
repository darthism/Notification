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
local DISAPPEAR_TIME = 3
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
local function IsMetadataMergable(MetadataTable)
	local IsMergable = false
	for _, Value in MetadataTable do
		if type(Value) == "table" then
			if Value.MergeFormatters then
				IsMergable = true
			end
			if not IsMergable then
				IsMergable = IsMetadataMergable(Value)
			end	
		end
	end
	return IsMergable
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
local IsMergable = IsMetadataMergable(MetaDatas)
local BoilerplatePosition = Boilerplate.Position
local BoilerplateSize = Boilerplate.Size
local Queue = {}
local NotificationDebounce = Debounce.new(0.25)
local JustNotified = false
local ShouldResetClock = true
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
function Module._ShiftNotifications(IsDisplay)
	local Sign = IsDisplay and 1 or -1
	while true do
		for _, Notification in VisibleNotifications do
			local CurrentPosition = Notification.Position
			Notification.Position = UDim2.new(CurrentPosition.X.Scale, 0, CurrentPosition.Y.Scale + BoilerplateSize.Y.Scale * Sign, 0)
		end
		if IsDisplay then
			if #VisibleNotifications == MAX_NOTIFICATIONS then
				local Removed = table.remove(VisibleNotifications, 1)
				Removed:Destroy()
			end
			break
		else
			local Removed = table.remove(VisibleNotifications, #VisibleNotifications)
			Removed:Destroy()
			task.wait(SHIFT_UP_TIME)
			ShouldResetClock = true
			if JustNotified or not next(VisibleNotifications) then
				JustNotified = false
				break
			end
		end
	end
end
function Module.DisplayNotification(Path, ...)
	local Formatters = {...}
	local Metadata = GetFromPath(MetaDatas, Path)
	local Flag = false
	if IsMergable then
		if NotificationDebounce:IsOnCooldown() then
			local Index = Module._GetIndexFromQueue(Path)
			if Index and Metadata.MergeFormatters then
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
			Flag = true
		end
	else
		Flag = true
	end
	if Flag then
		if IsMergable then
			NotificationDebounce:Activate()		
		end
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
		ShouldResetClock = true
	end
end
local Clock = os.clock()
local Flag = true
RunService.Heartbeat:Connect(function()
	if IsMetadataMergable then
		local Head = Queue[1]
		if Head and not NotificationDebounce:IsOnCooldown() then
			Module.DisplayNotification(Head.Path)
		end	
	end
	if JustNotified and ShouldResetClock then
		ShouldResetClock = false
		Clock = os.clock()
	end
	-- print(DISAPPEAR_TIME - (os.clock() -  Clock))
	if os.clock() - Clock > DISAPPEAR_TIME and next(VisibleNotifications) and Flag then
		Flag = false
		Module._ShiftNotifications(false)
		Flag = true
	end
end)
return Module
