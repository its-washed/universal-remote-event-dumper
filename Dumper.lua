local dateStr = (os.date and os.date("%Y%m%d_%H%M%S")) or tostring(os.time())
local filename = "RemoteDump_" .. dateStr .. ".txt"
local function Log(msg)
	print(msg)
	if writefile then
		local ok, err = pcall(function()
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
		if not ok then warn("File glitch: " .. tostring(err)) end
	end
end

local function SerializeArgs(args)
	local result = {}
	for i = 1, #args do
		local val = args[i]
		if val == nil then
			table.insert(result, "#nil")
			goto continue
		end
		
		local t = type(val)
		
		if t == "string" then
			table.insert(result, '"' .. val:sub(1, math.min(#val, 50)) .. '"')
			goto continue
		end
		
		if t == "number" then
			table.insert(result, tostring(val))
			goto continue
		end
		

		if t == "boolean" then
			table.insert(result, tostring(val))
			goto continue
		end
		
	
		if t == "table" then
			local tblStr = "{"
			
			tblStr = tblStr .. tostring((val[1])) 
			
			for j = 2, #val do
				tblStr = tblStr .. "," .. tostring(val[j])
			end
			
			tblStr = tblStr .. "}"
			result[#result + 1] = tblStr
			goto continue
		end
		
		
		table.insert(result, "[" .. t .. "]")
	
	::continue::
	end
	
	return table.concat(result, ", ")


local Remotes = { Events = {}, Functions = {} }

for _, obj in ipairs(game:GetDescendants()) do
	if obj:IsA("RemoteEvent") then
		Log("[RemoteEvent]" .. obj:GetFullName())
		table.insert(Remotes.Events, obj)
		
		local orig = obj.FireServer
		obj.FireServer = function(self, ...)
			Log("[FIRE]" .. obj:GetFullName() .. "|" .. SerializeArgs({ ... }))
			return orig(self, ...)
		end
		
	elseif obj:IsA("RemoteFunction") then
		Log("[RemoteFunction]" .. obj:GetFullName())
		table.insert(Remotes.Functions, obj)
		
		local orig = obj.InvokeServer
		obj.InvokeServer = function(self, ...)
			Log("[INVOKE]" .. obj:GetFullName() .. "|" .. SerializeArgs({ ... }))
			return orig(self, ...)
		end
	end
end

Log("")
Log("Events:" .. #Remotes.Events)
Log("Functions:" .. #Remotes.Functions)
Log("Target file:" .. filename)
Log("Live monitoring enabled...")

-- Hook new descendants as they appear
game.DescendantAdded:Connect(function(obj)
	if obj:IsA("RemoteEvent") then
		Log("[New Event]" .. obj:GetFullName())
		table.insert(Remotes.Events, obj)
		
		local orig = obj.FireServer
		obj.FireServer = function(self, ...)
			Log("[FIRE]" .. obj:GetFullName() .. "|" .. SerializeArgs({ ... }))
			return orig(self, ...)
		end
		
	elseif obj:IsA("RemoteFunction") then
		Log("[New Function]" .. obj:GetFullName())
		table.insert(Remotes.Functions, obj)
		
		local orig = obj.InvokeServer
		obj.InvokeServer = function(self, ...)
			Log("[INVOKE]" .. obj:GetFullName() .. "|" .. SerializeArgs({ ... }))
			return orig(self, ...)
		end
	end
end)

return Remotes