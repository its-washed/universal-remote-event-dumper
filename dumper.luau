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
        if not success then
            warn("File error: " .. tostring(err))
        end
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

Log("UNIVERSAL REMOTE DUMPER")
Log("Game: " .. tostring(game.Name))
Log("Place ID: " .. tostring(game.PlaceId))
Log("Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
Log(string.rep("=", 60))

local Remotes = {Events = {}, Functions = {}}

for _, obj in ipairs(game:GetDescendants()) do
    if obj:IsA("RemoteEvent") then
        local name = obj:GetFullName()
        Log("[RemoteEvent] " .. name)
        table.insert(Remotes.Events, obj)
        
        local old = obj.FireServer
        obj.FireServer = function(self, ...)
            local args = {...}
            Log("[FIRE] " .. name .. " | " .. SerializeArgs(args))
            return old(self, ...)
        end
        
    elseif obj:IsA("RemoteFunction") then
        local name = obj:GetFullName()
        Log("[RemoteFunction] " .. name)
        table.insert(Remotes.Functions, obj)
        
        local old = obj.InvokeServer
        obj.InvokeServer = function(self, ...)
            local args = {...}
            Log("[INVOKE] " .. name .. " | " .. SerializeArgs(args))
            return old(self, ...)
        end
    end
end

Log("")
Log("EVENTS: " .. #Remotes.Events)
Log("FUNCTIONS: " .. #Remotes.Functions)
Log("FILE: " .. filename)
Log("Monitoring...")

game.DescendantAdded:Connect(function(obj)
    if obj:IsA("RemoteEvent") then
        local name = obj:GetFullName()
        Log("[NEW RemoteEvent] " .. name)
        table.insert(Remotes.Events, obj)
        local old = obj.FireServer
        obj.FireServer = function(self, ...)
            Log("[FIRE] " .. name .. " | " .. SerializeArgs({...}))
            return old(self, ...)
        end
    elseif obj:IsA("RemoteFunction") then
        local name = obj:GetFullName()
        Log("[NEW RemoteFunction] " .. name)
        table.insert(Remotes.Functions, obj)
        local old = obj.InvokeServer
        obj.InvokeServer = function(self, ...)
            Log("[INVOKE] " .. name .. " | " .. SerializeArgs({...}))
            return old(self, ...)
        end
    end
end)

return Remotes