import("core.project.project")
import("core.project.config")
import("core.base.option")

local options = {
    { 's', "shorten", "kv", nil,   "Shorten option names using abbreviation algorithm", values = { "project", "generic", "all" } },
    { 'p', "project", "k",  false, "Display project-specific options" },
    { 'g', "generic", "k",  false, "Show generic options (mode, plat, arch, etc.)" }
}

local known = {
    debug = "dbg",
    release = "rls",
    minsizerel = "minszrel",
    optimize = "opt",
    windows = "win",
    linux = "lnx",
    macos = "mac",
    apple = "apl",
    android = "and",
    x86_64 = "x64",
    arm64 = "a64",
    simulator = "sim",
    universal = "univ",
}

-- splits camelCase / snake_case / kebab-case / dotted.case into segments
function split_segments(s)
    local segments = {}
    local pos = 1
    while pos <= #s do
        local c = s:sub(pos, pos)
        if c:match("[%w]") then
            local word = s:match("^[%u]?[%l%d]+", pos) or s:match("^%d+", pos)
            table.insert(segments, word)
            pos = pos + #word
        else
            local sep = s:match("^[^%w]+", pos)
            table.insert(segments, sep)
            pos = pos + #sep
        end
    end
    return segments
end

-- smart fallback abbreviation
function abbreviate_word(w)
    w = w:lower()
    if known[w] then
        return known[w]
    end
    if #w <= 3 then return w end
    local first = w:sub(1, 1)
    local rest = w:sub(2):gsub("[aeiou]", "")
    return (first .. rest):sub(1, 4)
end

-- abbreviate all words, keep separators
function shorten_option(name)
    local segments = split_segments(name)
    for i, seg in ipairs(segments) do
        if seg:match("^%w+$") then
            segments[i] = abbreviate_word(seg)
        end
    end
    return table.concat(segments)
end

-- helper function containing the shared logic
-- property can be defined in multiple places: in the config or hardcoded in the xmake.lua,
-- either globally or on each target.
-- previously the script would only print the configured value
-- which was sometimes not the correct one since it was hardcoded in the xmake.lua
-- now it takes the most common one.
local function _find_most_common_prop(prop_name)
    local counts = {}
    local file_vals = {} -- Track which values came explicitly from the file

    local file = io.open("xmake.lua", "r")
    if file then
        local content = file:read("*all")
        file:close()
        for val in content:gmatch("set_" .. prop_name .. "%s*%([%s]*[\"']([^\"']+)[\"']") do
            counts[val] = (counts[val] or 0) + 1
            file_vals[val] = true -- flag this value as hardcoded
        end
    end

    local cfg_val = config[prop_name] and config[prop_name]()
    if cfg_val then
        counts[cfg_val] = (counts[cfg_val] or 0) + 1
    end

    local most_common_val = nil
    local max_count = 0

    for val, count in pairs(counts) do
        if count > max_count then
            max_count = count
            most_common_val = val
        elseif count == max_count then
            -- TIE-BREAKER: if there's a tie, and the current value was hardcoded
            -- in the file but the current 'most_common_val' was not, the file wins.
            if file_vals[val] and not file_vals[most_common_val] then
                most_common_val = val
            end
        end
    end

    return most_common_val or cfg_val
end

-- public api wrappers
function find_plat()
    return _find_most_common_prop("plat")
end

function find_arch()
    return _find_most_common_prop("arch")
end

function main(...)
    config.load()

    -- the project is not configured yet
    if not config.plat() then
        return
    end

    local args = option.parse(table.pack(...), options, "Print the options for an xmake project.", "", "")

    -- print generic config
    if args.generic then
        local short = (args.shorten == "all" or args.shorten == "generic") and shorten_option or
            function(name) return name end
        printf("%s: %s, ", "mode", short(config.mode()))
        -- only show plat when it differs from the host to save space
        local plat = find_plat()
        if os.host() ~= plat then
            printf("%s: %s, ", "plat", short(plat))
        end
        printf("%s: %s", "arch", short(find_arch()))
    end

    if args.project then
        local short = (args.shorten == "all" or args.shorten == "project") and shorten_option or
            function(name) return name end
        local first_item = not args.generic
        for _, opt in pairs(project.options()) do
            if opt:value() ~= nil then
                local value = opt:value()
                if type(value) == "string" and args.shorten then
                    value = short(value)
                end
                local prefix = (first_item and not args.generic) and "" or ", "
                printf("%s%s: %s", prefix, short(opt:name()), tostring(opt:value()))
                first_item = false
            end
        end
    end
end