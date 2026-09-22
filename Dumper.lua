local filename = "RemoteDump_" .. game.PlaceId .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"

local function Log(msg)
	print(msg)
	if writefile then
		local success, err = pcall(function()
			if readfile and pcall(readfile, filename) then
				if appendfile then
					appendfile(filename, msg .. "\n")
				else
					local old = readfile(filename)
					writefile(filename, old .. msg .. "\n")
				end
			else
				writefile(filename, msg .. "\n")
			end
		end)
		if not success then warn("File error: " .. tostring(err)) end
	end
end

local function SerializeArgs(args)
	local result = {}
	for i = 1, #args do
		if i > 10 then
			table.insert(result, "...")
			break
		end
		local arg = args[i]
		local t = type(arg)
		if t == "string" then
			table.insert(result, '"' .. arg:sub(1, 50) .. '"')
		elseif t == "number" then
			table.insert(result, tostring(arg))
		elseif t == "boolean" then
			table.insert(result, tostring(arg))
		elseif t == "table" then
			table.insert(result, "{table}")
		else
			table.insert(result, "[" .. t .. "]")
		end
	end
	return table.concat(result, ", ")
end

-- Weakly reference our collections so transient parts don't clog memory
local Events   = setmetatable({}, { __mode = "k" })
local Functions = setmetatable({}, { __mode = "k" })

-- Grab ALL current instances of each class (handles things created via GetDescendants later too)
function Events:GetAllInstances(cls) cls = cls or nil; return cls and cls:IsA("RemoteEvent") and true else false end
for _, obj in ipairs(game:GetDescendants()) do
	if obj:IsA("RemoteEvent") then
		Log("[RemoteEvent]" .. obj:GetFullName())
		Events[obj] = obj -- insert directly into the weak-set
	elseif obj:IsA("RemoteFunction") then
		Log("[RemoteFunction]" .. obj:GetFullName())
		Functions[obj] = obj
	end
end

-- Wrap FireServer/InvokeServer so every call logs nicely
for obj, _ in pairs(Events) do
	obj.FireServer = function(self, ...)
		Log("[FIRE]" .. obj:GetFullName() .. "|" .. SerializeArgs({...}))
		return obj._orig(self, ...)
	end
	obj._orig = obj.FireServer -- stash original handler
end

for obj, _ in pair(Functions) do
	obj.InvokeServer = function(self, ...)
		Log("[INVOKE]" .. obj:GetFullName() .. "|" .. SerializeArgs({...}))
		return obj._orig(self, ...)
	end
	obj._orig = obj.InvokeServer
end

Log("")
Log("Total Events captured:" .. #Events)
Log("Total Functions captured:" .. #Functions)
Log("Output file:" .. filename)
Log("Watching for new spawns...")

game.DescendantAdded:Connect(function(obj)
	if obj:IsA("RemoteEvent") then
		Log("[NEW Event]" .. obj:GetFullName())
		Events[obj] = obj
		obj.FireServer = function(self, ...)
			Log("[FIRE]" .. obj:GetFullName() .. "|" .. SerializeArgs({...}))
			return obj._orig(self, ...)
		end
		obj._orig = obj.FireServer
	elseif obj:IsA("RemoteFunction") then
		Log("[NEW Function]" .. obj:GetFullName())
		Functions[obj] = obj
		obj.InvokeServer = function(self, ...)
			Log("[INVOKE]" .. obj:GetFullName() .. "|" .. SerializeArgs({...}))
			return obj._orig(self, ...)
		end
		obj._orig = obj.InvokeServer
	end
end)

return Events, Functions