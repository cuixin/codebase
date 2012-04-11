--------------------------------------------------------------------------------
-- generate_exports_list.lua: api exports list generator
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments'
      }

local make_concatter
      = import 'lua-nucleo/string.lua'
      {
        'make_concatter'
      }

local create_path_to_file,
      write_file
      = import 'lua-aplicado/filesystem.lua'
      {
        'create_path_to_file',
        'write_file'
      }

local walk_tagged_tree
      = import 'pk-core/tagged-tree.lua'
      {
        'walk_tagged_tree'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("generate_exports_list", "GEL")

--------------------------------------------------------------------------------

local generate_exports_list
do
  local down = { }

  local up = { }
  do
    up["api:export"] = function(walkers, data)
      if data.filename then
        local filename = --[[walkers.out_file_root_ ..]] walkers.handlers_dir_name_ ..
          "/" .. data.filename
        log("processing", data.filename)
        assert(create_path_to_file(filename))
        for i = 1, #data.exports do
          walkers.cat_ [[
  ]](data.exports[i])[[ = { ]](("%q"):format(filename)) [[ };
]]
        end
      end
    end
  end

  generate_exports_list = function(
      schema,
      file_name,
      out_file_root,
      handlers_dir_name,
      file_header
    )
    arguments(
        "table", schema,
        "string", file_name,
        "string", out_file_root,
        "string", handlers_dir_name,
        "string", file_header
      )
    local cat, concat = make_concatter()
    local walkers =
    {
      down = down;
      up = up;
      --
      cat_ = cat;
      concat_ = concat;
      export_names_ = nil;
      out_file_name_ = file_name;
      out_file_root_ = out_file_root;
      handlers_dir_name_ = handlers_dir_name;
    }
    for i = 1, #schema do
      walk_tagged_tree(schema[i], walkers, "id")
    end
    schema.header = schema.header or ""

    log("generating exports list to", file_name)
    assert(create_path_to_file(file_name))
    assert(
        write_file(
            file_name,
            [[
--------------------------------------------------------------------------------
-- generated exports list for client api
]] .. file_header .. [[
--------------------------------------------------------------------------------
-- WARNING! Do not change manually.
--          Generated by apigen.lua
--------------------------------------------------------------------------------

return
{
]] .. walkers.concat_() .. [[}
]]
          )
      )
  end
end

--------------------------------------------------------------------------------

return
{
  generate_exports_list = generate_exports_list;
}