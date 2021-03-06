--------------------------------------------------------------------------------
-- db-tables.lua: generate tables.lua
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments'
      }

local make_concatter
      = import 'lua-nucleo/string.lua'
      {
        'make_concatter'
      }

local do_nothing
      = import 'lua-nucleo/functional.lua'
      {
        'do_nothing'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local walk_tagged_tree
      = import 'pk-core/tagged-tree.lua'
      {
        'walk_tagged_tree'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("db-tables", "DBT")

--------------------------------------------------------------------------------

local generate_db_tables
do
  local down = { }

  down.table = function(walkers, data)
    -- TODO: Check in validation stage that data.name is a valid Lua identifier!
    walkers.cat_ [[
TABLES.]] (data.name) [[ =
{
  db_name = ']] (data.db_name) [[';
  table = ']] (data.name) [[';
]]
  end

  local up = { }

  up.primary_ref = function(walkers, data)
    -- TODO: Support custom features table.
    walkers.cat_ [[
  primary_key = ']] (data.name) [[';
]]
  end

  up.primary_key = function(walkers, data)
    -- TODO: Support custom features table.
    walkers.cat_ [[
  primary_key = ']] (data.name) [[';
]]
  end

  up.table = function(walkers, data)
    -- TODO: Support custom features table.
    walkers.cat_ [[
  features = { };
}

]]
  end

  generate_db_tables = function(tables)
    local cat, concat = make_concatter()

    local walkers =
    {
      down = down;
      up = up;
      --
      cat_ = cat;
    }

    for i = 1, #tables do
      walk_tagged_tree(tables[i], walkers, "tag")
    end

    return [[
--------------------------------------------------------------------------------
-- tables.lua: generated information on concrete DB tables
--------------------------------------------------------------------------------
-- WARNING! Do not change manually.
-- Generated by db-tables.lua
--------------------------------------------------------------------------------

local tset
      = import 'lua-nucleo/table-utils.lua'
      {
        'tset'
      }

--------------------------------------------------------------------------------

local TABLES = { }

--------------------------------------------------------------------------------

]] .. concat() .. [[
--------------------------------------------------------------------------------

return TABLES
]]
  end
end

--------------------------------------------------------------------------------

return
{
  generate_db_tables = generate_db_tables;
}
