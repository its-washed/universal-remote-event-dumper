local filename = string.format("RemoteDump_%d_%s.txt", game.PlaceId, os.date("%Y%m%d_%H%M%S"))
local Output = {}
local Remotes = {Events = {}, Functions = {}, All = {}}

local function Log(msg)
    table.insert(Output, msg)
    print(msg)
    if appendfile then
        appendfile(filename, msg .. "\n")
    end
end

local function GetFullPath(obj)
    local path = obj.Name
    local parent = obj.Parent
    while parent and parent ~= game do
        path = parent.Name .. "." .. path
        parent = parent.Parent
    end
    return path
end

local function SerializeArgs(args)
    local result = {}
    for i = 1, math.min(#args, 10) do
        local arg = args[i]
        local t = type(arg)
        if t == "string" then
            result[i] = '"' .. arg:sub(1, 100) .. (arg:len() > 100 and "..." or "") .. '"'
        elseif t == "number" then
            result[i] = tostring(arg)
        elseif t == "boolean" then
            result[i] = tostring(arg)
        elseif t == "table" then
            result[i] = "{table:" .. tostring(#arg) .. "}"
        elseif t == "userdata" then
            result[i] = "[" .. tostring(arg):match("^%w+") .. "]"
        else
            result[i] = "[" .. t .. "]"
        end
    end
    if #args > 10 then
        table.insert(result, "... +" .. (#args - 10) .. " more")
    end
    return table.concat(result, ", ")
end

local function ScanObject(obj)
    local info = {
        Object = obj,
        Name = obj.Name,
        Path = GetFullPath(obj),
        Calls = 0
    }
    
    if obj:IsA("RemoteEvent") then
        info.Type = "RemoteEvent"
        table.insert(Remotes.Events, info)
        table.insert(Remotes.All, info)
        
        local oldFire = obj.FireServer
        obj.FireServer = function(self, ...)
            info.Calls = info.Calls + 1
            local args = {...}
            local logMsg = string.format("[EVENT] %s | Args: %s", info.Path, SerializeArgs(args))
            Log(logMsg)
            return oldFire(self, ...)
        end
        
    elseif obj:IsA("RemoteFunction") then
        info.Type = "RemoteFunction"
        table.insert(Remotes.Functions, info)
        table.insert(Remotes.All, info)
        
        local oldInvoke = obj.InvokeServer
        obj.InvokeServer = function(self, ...)
            info.Calls = info.Calls + 1
            local args = {...}
            local logMsg = string.format("[FUNCTION] %s | Args: %s", info.Path, SerializeArgs(args))
            Log(logMsg)
            return oldInvoke(self, ...)
        end
        
    elseif obj:IsA("BindableEvent") then
        info.Type = "BindableEvent"
        table.insert(Remotes.All, info)
        
    elseif obj:IsA("BindableFunction") then
        info.Type = "BindableFunction"
        table.insert(Remotes.All, info)
    end
    
    return info.Type ~= nil
end

local function RecursiveScan(parent, depth)
    depth = depth or 0
    if depth > 15 then return end
    
    for _, child in ipairs(parent:GetChildren()) do
        ScanObject(child)
        RecursiveScan(child, depth + 1)
    end
end

if writefile then
    writefile(filename, "UNIVERSAL REMOTE DUMPER\nGame: " .. game.Name .. "\nPlace ID: " .. game.PlaceId .. "\nTime: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n" .. string.rep("=", 70) .. "\n\n")
end

Log(string.rep("=", 70))
Log("UNIVERSAL REMOTE DUMPER")
Log(string.rep("=", 70))

for _, service in ipairs(game:GetChildren()) do
    pcall(function()
        RecursiveScan(service)
    end)
end

Log("\n[REMOTE EVENTS] Total: " .. #Remotes.Events)
Log(string.rep("-", 70))
for i, info in ipairs(Remotes.Events) do
    Log(string.format("  %d. %s", i, info.Name))
    Log(string.format("     Path: %s", info.Path))
    Log("")
end

Log("[REMOTE FUNCTIONS] Total: " .. #Remotes.Functions)
Log(string.rep("-", 70))
for i, info in ipairs(Remotes.Functions) do
    Log(string.format("  %d. %s", i, info.Name))
    Log(string.format("     Path: %s", info.Path))
    Log("")
end

local bindables = {}
for _, info in ipairs(Remotes.All) do
    if info.Type == "BindableEvent" or info.Type == "BindableFunction" then
        table.insert(bindables, info)
    end
end

Log("[BINDABLES] Total: " .. #bindables)
Log(string.rep("-", 70))
for i, info in ipairs(bindables) do
    Log(string.format("  %d. [%s] %s -> %s", i, info.Type, info.Name, info.Path))
end

Log("\n" .. string.rep("=", 70))
Log(string.format("TOTAL CAPTURED: %d", #Remotes.All))
Log(string.rep("=", 70))
Log("[ACTIVE] Monitoring ALL remote calls...")
Log(string.format("[FILE] %s", filename))

game.DescendantAdded:Connect(function(descendant)
    if ScanObject(descendant) then
        Log(string.format("[NEW %s] %s", descendant.ClassName, GetFullPath(descendant)))
    end
end)

return Remotes