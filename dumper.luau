local filename = string.format("RemoteDump_%d_%s.txt", game.PlaceId, os.date("%Y%m%d_%H%M%S"))
local Output = {}
local Remotes = {Events = {}, Functions = {}, All = {}}

local hasWritefile = type(writefile) == "function"
local hasAppendfile = type(appendfile) == "function"

local function Log(msg)
    table.insert(Output, msg)
    print(msg)
    if hasAppendfile then
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
            local str = tostring(arg)
            local match = str:match("^%w+")
            result[i] = "[" .. (match or "userdata") .. "]"
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
    if not obj or not obj.IsA then return false end
    
    local info = {
        Object = obj,
        Name = tostring(obj.Name),
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
    else
        return false
    end
    
    return true
end

local function RecursiveScan(parent, depth)
    depth = depth or 0
    if depth > 15 then return end
    if not parent or not parent.GetChildren then return end
    
    local children = parent:GetChildren()
    for i = 1, #children do
        local child = children[i]
        ScanObject(child)
        RecursiveScan(child, depth + 1)
    end
end

if hasWritefile then
    local header = "UNIVERSAL REMOTE DUMPER\nGame: " .. tostring(game.Name) .. "\nPlace ID: " .. tostring(game.PlaceId) .. "\nTime: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n" .. string.rep("=", 70) .. "\n\n"
    writefile(filename, header)
end

Log(string.rep("=", 70))
Log("UNIVERSAL REMOTE DUMPER")
Log(string.rep("=", 70))

local services = game:GetChildren()
for i = 1, #services do
    local success = pcall(function()
        RecursiveScan(services[i])
    end)
end

Log("\n[REMOTE EVENTS] Total: " .. tostring(#Remotes.Events))
Log(string.rep("-", 70))
for i = 1, #Remotes.Events do
    local info = Remotes.Events[i]
    Log(string.format("  %d. %s", i, info.Name))
    Log(string.format("     Path: %s", info.Path))
    Log("")
end

Log("[REMOTE FUNCTIONS] Total: " .. tostring(#Remotes.Functions))
Log(string.rep("-", 70))
for i = 1, #Remotes.Functions do
    local info = Remotes.Functions[i]
    Log(string.format("  %d. %s", i, info.Name))
    Log(string.format("     Path: %s", info.Path))
    Log("")
end

local bindables = {}
for i = 1, #Remotes.All do
    local info = Remotes.All[i]
    if info.Type == "BindableEvent" or info.Type == "BindableFunction" then
        table.insert(bindables, info)
    end
end

Log("[BINDABLES] Total: " .. tostring(#bindables))
Log(string.rep("-", 70))
for i = 1, #bindables do
    local info = bindables[i]
    Log(string.format("  %d. [%s] %s -> %s", i, info.Type, info.Name, info.Path))
end

Log("\n" .. string.rep("=", 70))
Log("TOTAL CAPTURED: " .. tostring(#Remotes.All))
Log(string.rep("=", 70))
Log("[ACTIVE] Monitoring ALL remote calls...")

if hasWritefile or hasAppendfile then
    Log("[FILE] " .. filename)
else
    Log("[WARNING] File functions not available - console only")
end

game.DescendantAdded:Connect(function(descendant)
    if ScanObject(descendant) then
        Log(string.format("[NEW %s] %s", descendant.ClassName, GetFullPath(descendant)))
    end
end)

return Remotes