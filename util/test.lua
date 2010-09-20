-- TODO: Generalize with test.lua from lua-nucleo

local lfs = require 'lfs'

-- WARNING: do not use import in this file for the test purity reasons.
local run_tests = assert(assert(assert(loadfile('lua-nucleo/suite.lua'))()).run_tests)

local find_all_files = assert(assert(assert(loadfile('lua-aplicado/filesystem.lua'))()).find_all_files)

-- TODO: Ensure each test is run in pristine environment!
--       In particular that import does not leak in from other tests.
--       Use (but ensure it is compatible with strict module):
--         setfenv(
--             setmetatable(
--                 { },
--                 { __index = _G; __newindex = _G; __metatable = true; }
--               )
--           )

-- TODO: Also preserve random number generator's seed
--       (save it and restore between suites)

local strict_mode = false
local n = 1
if select(n, ...) == "--strict" then
  strict_mode = true
  n = 2
end

local CASES_PATH = "./cases"

local tests_pr = find_all_files(CASES_PATH, ".*%.lua$")

local pattern = select(n, ...) or ""
assert(type(pattern) == "string")

local test_r = {}
for _, v in ipairs(tests_pr) do
  -- Checking directly to avoid escaping special characters (like '-')
  -- when running specific test
  if v == pattern or string.match(v, pattern) then
    test_r[#test_r + 1] = v
  end
end

table.sort(test_r)

if #test_r == 0 then
  error("no tests match pattern `" .. pattern .. "'")
end

if pattern ~= "" then
  print(
      "Running " .. #test_r .. " test(s) matching pattern `" .. pattern .. "'"
     )
end

local nok, errs = run_tests(test_r, strict_mode)

if #errs > 0 then
  error("Failed tests detected") -- So that lua executable would return non-zero code
end
