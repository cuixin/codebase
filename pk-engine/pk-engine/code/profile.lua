--------------------------------------------------------------------------------
-- pk-engine.lua: pk-engine exports profile
--------------------------------------------------------------------------------

local tset = import 'lua-nucleo/table-utils.lua' { 'tset' }

--------------------------------------------------------------------------------

local PROFILE = { }

--------------------------------------------------------------------------------

declare 'wsapi' -- TODO: Uberhack! :(

PROFILE.skip = setmetatable(tset
{
  "pk-engine/webservice/init/init.lua"; -- Too low-level
  "pk-engine/webservice/init/require.lua"; -- Too low-level
  "pk-engine/fake_uuids.lua"; -- Contains linear data array
  "pk-engine/srv/channel/main.lua"; -- Too low-level
  "pk-engine/module.lua"; -- Too low-level
}, {
  __index = function(t, k)
    -- Excluding files outside of pk-engine/ and inside pk-engine/code
    -- and inside pk-engine/test

    local v = (not k:match("^pk%-engine/"))
      or k:match("^pk%-engine/code/")
      or (k:sub(1, #"pk-engine/test/") == "pk-engine/test/")

    t[k] = v
    return v
  end;
})

--------------------------------------------------------------------------------

return PROFILE