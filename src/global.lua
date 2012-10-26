local Global = {}
Global.__index = Global

function Global.deepcopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

--child inherits the members of parent if child doesn't
-- have a member by the same name
-- only copies members that aren't referenced by __index
function Global.inherits(child,parent)
    for k,v in pairs(parent) do
        if not child[k] then
            child[k] = v
        end
    end
    for k,v in pairs(parent["__index"]) do
        if not child[k] then
            child[k] = v
        end
    end
    return child
end



function Global.retrieveItemClass(itemName)
    Item = require ('items/'..itemName..'Item')
    return Item
end

return Global