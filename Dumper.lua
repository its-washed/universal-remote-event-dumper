local folder = "washedsdumper"

if not isfolder(folder) then
	makefolder(folder)
end

local found = {}

for _, v in ipairs(game:GetDescendants()) do
	local cn = v.ClassName
	if cn == "RemoteEvent" or cn == "RemoteFunction" or cn == "UnreliableRemoteEvent" then
		table.insert(found, v)
	end
end

table.sort(found, function(a, b)
	return a:GetFullName() < b:GetFullName()
end)

local lines = {}
for _, v in ipairs(found) do
	table.insert(lines, v.ClassName .. " " .. v:GetFullName())
end

local path = folder .. "/dump_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
writefile(path, table.concat(lines, "\n"))

print("dump complete " .. path)
