--[[ The Catalogue -- a sanity check on the translation JSON files.

     Not a full parser, deliberately. These files are flat objects of string-to-string,
     and the two ways they actually break are the two checked here:

     UNBALANCED. A hand edit or a sed insertion that loses a brace or a quote. The game
     answers this by loading no translations at all and rendering every string as its
     raw key, which looks like a totally different bug.

     DUPLICATE KEYS. Appending a key that is already further up the file is valid JSON
     and silently keeps the last one, so the mod goes on showing the old text while the
     file plainly contains the new. Nothing in the game complains, which is what makes
     it worth a check.

     Usage: luajit tools/json_check.lua <file.json>
]]

local path = arg[1]
if not path then
    io.stderr:write("usage: json_check.lua <file.json>\n")
    os.exit(2)
end

local handle = io.open(path, "r")
if not handle then
    io.stderr:write("cannot open " .. path .. "\n")
    os.exit(2)
end
local text = handle:read("*a")
handle:close()

-- Balance, tracking string state so a brace inside a value is not counted.
local depth, inString, escaped = 0, false, false
for i = 1, #text do
    local c = text:sub(i, i)
    if inString then
        if escaped then escaped = false
        elseif c == "\\" then escaped = true
        elseif c == '"' then inString = false end
    elseif c == '"' then inString = true
    elseif c == "{" or c == "[" then depth = depth + 1
    elseif c == "}" or c == "]" then depth = depth - 1
    end
    if depth < 0 then
        io.stderr:write(path .. ": a closing brace with nothing open\n")
        os.exit(1)
    end
end

if inString then
    io.stderr:write(path .. ": a string is never closed\n")
    os.exit(1)
end
if depth ~= 0 then
    io.stderr:write(path .. ": " .. depth .. " brace(s) left open\n")
    os.exit(1)
end

local seen, duplicates = {}, {}
for key in text:gmatch('"([%w_]+)"%s*:') do
    if seen[key] then table.insert(duplicates, key) else seen[key] = true end
end

if #duplicates > 0 then
    io.stderr:write(path .. ": duplicate key(s): " .. table.concat(duplicates, ", ") .. "\n")
    os.exit(1)
end
