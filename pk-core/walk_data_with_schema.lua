--------------------------------------------------------------------------------
-- walk_data_with_schema.lua: data walking based on tagged-tree schemas
--------------------------------------------------------------------------------
-- Sandbox warning: alias all globals!
--------------------------------------------------------------------------------

local assert, rawget, tostring, setmetatable
    = assert, rawget, tostring, setmetatable

local table_concat, table_insert, table_remove
    = table.concat, table.insert, table.remove

--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "pk-core/walk_data_with_schema", "WDS"
        )

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

local is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_table'
      }

local assert_is_nil,
      assert_is_function
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_nil',
        'assert_is_function'
      }

local tkeys,
      tclone
      = import 'lua-nucleo/table-utils.lua'
      {
        'tkeys',
        'tclone'
      }

local do_nothing
      = import 'lua-nucleo/functional.lua'
      {
        'do_nothing'
      }

local make_checker
      = import 'lua-nucleo/checker.lua'
      {
        'make_checker'
      }

local walk_tagged_tree
      = import 'pk-core/tagged-tree.lua'
      {
        'walk_tagged_tree'
      }

local common_load_schema
      = import 'pk-core/common_load_schema.lua'
      {
        'common_load_schema'
      }

--------------------------------------------------------------------------------

local load_data_schema = common_load_schema

--------------------------------------------------------------------------------

-- TODO: Generalize?
local make_prefix_checker
do
  local fail = function(self, msg)
    method_arguments(
        self,
        "string", msg
      )

    local errors = self.errors_
    errors[#errors + 1] = "bad `"
      .. table_concat(self.prefix_getter_(), ".") .. "': "
      .. msg
  end

  -- Imitates checker interface
  make_prefix_checker = function(prefix_getter)
    arguments("function", prefix_getter)

    local checker = make_checker()

    return setmetatable(
        {
          fail = fail;
          --
          prefix_getter_ = prefix_getter;
        },
        {
          __index = checker;
        }
      )
  end
end

--------------------------------------------------------------------------------

-- TODO: Lazy! Do not create so many closures!
-- TODO: Generalize copy-paste
local load_data_walkers = function(chunk, extra_env, ...)
  extra_env = extra_env or { }
  arguments(
      "function", chunk,
      "table", extra_env
    )

  local schema = load_data_schema(chunk, extra_env, { "types" })
  assert(#schema > 0)

  local types =
  {
    down = nil; -- See below
    up = nil;
    --
    set_data = function(self, data)
      method_arguments(
          self,
          "table", data
        )

      assert(self.data_ == nil)
      assert(#self.current_path_ == 0)
      self.data_ = data
    end;

    reset = function(self, ...)
      method_arguments(self)
      self.data_ = nil
      self.current_path_ = { }
      self.current_leaf_name_ = nil
      self.checker_ = make_prefix_checker(self.get_current_path_closure_);
      self.context_ = self.factory_(
          self.checker_,
          self.get_current_path_closure_,
          ...
        )
    end;

    get_checker = function(self)
      method_arguments(self)
      return self.checker_
    end;

    get_context = function(self)
      method_arguments(self)
      return self.context_
    end;

    get_current_path = function(self)
      method_arguments(self)
      local buf = { }
      for i = 1, #self.current_path_ do
        local name = self.current_path_[i].name
        if name ~= "" then -- To allow nameless root
          buf[#buf + 1] = self.current_path_[i].name
        end
      end
      if self.current_leaf_name_ then
        buf[#buf + 1] = self.current_leaf_name_
      end
      return buf
    end;

    -- Private method
    unset_leaf_name_ = function(self, ...)
      method_arguments(self)
      self.current_leaf_name_ = nil
      return ...
    end;

    walk_data_with_schema = function(self, schema, data)
      method_arguments(
          self,
          "table", schema,
          "table", data
        )

      assert(#schema > 0)

      self:reset()
      self:set_data(data)

      self:walk_schema_(schema)

      return self
    end;

    -- Private method
    walk_schema_ = function(self, schema)
      for i = 1, #schema do
        walk_tagged_tree(schema[i], self, "id")
      end
    end;

    --
    factory_ = nil;
    get_current_path_closure_ = nil;
    --
    data_ = nil;
    current_path_ = { };
    current_leaf_name_ = nil;
    context_ = nil;
    checker_ = nil;
  };

  types.down = setmetatable(
      { },
      {
        __index = function(t, k)
          types.checker_:fail("[down] unknown tag " .. tostring(k))
          return nil
        end;
      }
    );
  types.up = setmetatable(
      { },
      {
        __index = function(t, k)
          types.checker_:fail("[up] unknown tag " .. tostring(k))
          return nil
        end;
      }
    );

  local get_value = function(
      self,
      types_schema,
      data_schema,
      data,
      key
    )
    method_arguments(
        self,
        "table", types_schema,
        "table", data_schema,
        "table", data
        -- key may be of any type
      )
    assert(key ~= nil)

    local value = data[key]
    if value == nil and data_schema.default ~= nil then
      value = tclone(data_schema.default)
      data[key] = value -- Patch data with default value
    end
    return value
  end

  local walkers =
  {
    up =
    {
      ["types:down"] = function(self, info)
        info.handler = assert_is_function(info.handler or do_nothing)

        local old_handler = rawget(self.types_.down, info.name)
        assert(old_handler == nil or old_handler == do_nothing)

        self.types_.down[info.name] = function(self, data)
          if #self.current_path_ == 0 then
            self.checker_:fail("item must not be at root")
            return "break"
          end

          local scope = self.current_path_[#self.current_path_]
          assert(scope ~= nil)

          self.current_leaf_name_ = data.name

          return self:unset_leaf_name_(info.handler(
              self.context_,
              data,
              get_value(self, info, data, scope.node, data.name)
            ))
        end

        -- Avoiding triggering __index error handler
        self.types_.up[info.name] = do_nothing
      end;

      ["types:up"] = function(self, info)
        info.handler = assert_is_function(info.handler or do_nothing)

        local old_handler = rawget(self.types_.up, info.name)
        assert(old_handler == nil or old_handler == do_nothing)

        self.types_.up[info.name] = function(self, data)
          if #self.current_path_ == 0 then
            self.checker_:fail("item must not be at root")
            return "break"
          end

          local scope = self.current_path_[#self.current_path_]
          assert(scope ~= nil)

          self.current_leaf_name_ = data.name

          return self:unset_leaf_name_(info.handler(
              self.context_,
              data,
              get_value(self, info, data, scope.node, data.name)
            ))
        end

        -- Avoiding triggering __index error handler
        self.types_.down[info.name] = do_nothing
      end;

      ["types:variant"] = function(self, info)
        info.handler = assert_is_function(info.handler or do_nothing)

        local walkers = self -- Note alias

        local vtag_key = info.tag_key or "name"
        local vdata_key = info.data_key or "param"

        assert_is_nil(rawget(self.types_.down, info.name))
        self.types_.down[info.name] = function(self, data)
          local child_schema = data.variants
          if not child_schema then
            self.checker_:fail(
                "bad variant `" .. tostring(data.name) .. "' definition:"
             .. " missing `variants' field"
              )
            return "break"
          end

          -- Why?
          if #self.current_path_ == 0 then
            self.checker_:fail("variant must not be at root")
            return "break"
          end

          local node = get_value(
              self,
              info,
              data,
              self.current_path_[#self.current_path_].node,
              data.name
            )
          if node == nil then
            self.checker_:fail("`" .. tostring(data.name) .. "' is missing")
            return "break"
          end
          if not is_table(node) then
            self.checker_:fail("`" .. tostring(data.name) .. "' is not table")
            return "break"
          end

          local variant = node

          local vtag = variant[vtag_key]
          if vtag == nil then
            self.current_leaf_name_ = data.name -- Hack
            self.checker_:fail(
                "tag field `" .. tostring(vtag_key) .. "' is missing"
              )
            self.current_leaf_name_ = nil
            return "break"
          end

          local vdata = variant[vdata_key]
          if vdata == nil then
            self.current_leaf_name_ = data.name -- Hack
            self.checker_:fail(
                "data field `" .. tostring(vdata_key) .. "' is missing"
              )
            self.current_leaf_name_ = nil
            return "break"
          end

          local vschema = child_schema[vtag]
          if not vschema then
            self.current_leaf_name_ = data.name -- Hack
            self.checker_:fail(
                "bad tag field `" .. tostring(vtag_key) .. "' value `"
             .. tostring(vtag) .. "':" .. " expected one of { "
             .. table_concat(tkeys(child_schema), " | ") .. " }"
              )
            self.current_leaf_name_ = nil
            return "break"
          end

          local scope =
          {
            name = data.name;
            node = variant;
          }
          table_insert(self.current_path_, scope)

          self.current_leaf_name_ = nil
          self:unset_leaf_name_((info.down_handler or info.handler)(
              self.context_,
              data,
              scope.node
            ))

          do
            local scope =
            {
              name = vdata_key;
              node = vdata;
            }
            table_insert(self.current_path_, scope)
            self.current_leaf_name_ = nil

            self:walk_schema_(vschema)

            assert(table_remove(self.current_path_) == scope)
          end

          self.current_leaf_name_ = nil
          self:unset_leaf_name_((info.up_handler or do_nothing)(
              self.context_,
              data,
              scope.node
            ))

          assert(table_remove(self.current_path_) == scope)

          return "break" -- Handled child nodes manually
        end
      end;

      ["types:ilist"] = function(self, info)
        info.handler = assert_is_function(info.handler or do_nothing)

        local walkers = self -- Note alias

        assert_is_nil(rawget(self.types_.down, info.name))
        self.types_.down[info.name] = function(self, data)
          local child_schema = data

          -- Why?
          if #self.current_path_ == 0 then
            self.checker_:fail("ilist must not be at root")
            return "break"
          end

          local node = get_value(
              self,
              info,
              data,
              self.current_path_[#self.current_path_].node,
              data.name
            )
          if node == nil then
            self.checker_:fail("`" .. tostring(data.name) .. "' is missing")
            return "break"
          end
          if not is_table(node) then
            self.checker_:fail("`" .. tostring(data.name) .. "' is not table")
            return "break"
          end

          local scope =
          {
            name = data.name;
            node = node;
          }
          table_insert(self.current_path_, scope)

          self.current_leaf_name_ = nil
          self:unset_leaf_name_((info.down_handler or info.handler)(
              self.context_,
              data,
              scope.node
            ))

          local list = scope.node
          for i = 1, #list do
            local item = list[i]

            local scope =
            {
              name = tostring(i);
              node = item;
            }
            table_insert(self.current_path_, scope)
            self.current_leaf_name_ = nil

            self:walk_schema_(child_schema)

            assert(table_remove(self.current_path_) == scope)
          end

          self.current_leaf_name_ = nil
          self:unset_leaf_name_((info.up_handler or do_nothing)(
              self.context_,
              data,
              scope.node
            ))

          assert(table_remove(self.current_path_) == scope)

          return "break" -- Handled child nodes manually
        end
      end;

      ["types:node"] = function(self, info)
        info.handler = assert_is_function(info.handler or do_nothing)

        assert_is_nil(rawget(self.types_.down, info.name))
        self.types_.down[info.name] = function(self, data)
          if #self.current_path_ == 0 then
            self.checker_:fail("node must not be at root")
            return "break"
          end

          local node = get_value(
              self,
              info,
              data,
              self.current_path_[#self.current_path_].node,
              data.name
            )
          if node == nil then
            self.checker_:fail("`" .. tostring(data.name) .. "' is missing")
            return "break"
          end
          if not is_table(node) then
            self.checker_:fail("`" .. tostring(data.name) .. "' is not table")
            return "break"
          end

          local scope =
          {
            name = data.name;
            node = node;
          }

          table_insert(self.current_path_, scope)

          self.current_leaf_name_ = nil

          return self:unset_leaf_name_((info.down_handler or info.handler)(
              self.context_,
              data,
              scope.node
            ))
        end

        assert_is_nil(rawget(self.types_.up, info.name))
        self.types_.up[info.name] = function(self, data)
          assert(#self.current_path_ ~= 0)
          local scope = table_remove(self.current_path_)
          assert(scope ~= nil)
          assert(scope.name == data.name)

          self.current_leaf_name_ = nil

          return self:unset_leaf_name_((info.up_handler or do_nothing)(
              self.context_,
              data,
              scope.node
            ))
        end
      end;

      ["types:root"] = function(self, info)
        assert(not self.root_defined_, "duplicate root definition")
        self.root_defined_ = true

        info.handler = assert_is_function(info.handler or do_nothing)
        info.name = info.name or ""

        assert_is_nil(rawget(self.types_.down, info.name))
        self.types_.down[info.name] = function(self, data)
          assert(#self.current_path_ == 0)

          local scope =
          {
            name = data.name;
            node = self.data_;
          }

          table_insert(self.current_path_, scope)

          self.current_leaf_name_ = nil

          return self:unset_leaf_name_((info.down_handler or info.handler)(
              self.context_,
              data,
              scope.node
            ))
        end

        assert_is_nil(rawget(self.types_.up, info.name))
        self.types_.up[info.name] = function(self, data)
          assert(#self.current_path_ == 1)
          local scope = table_remove(self.current_path_)
          assert(scope ~= nil)
          assert(scope.name == data.name)

          self.current_leaf_name_ = nil

          return self:unset_leaf_name_((info.up_handler or do_nothing)(
              self.context_,
              data,
              scope.node
            ))
        end
     end;

     -- Factory receives two arguments:
     -- 1. checker object; prefer to use it for error handling.
     -- 2. get_current_path function,
     --    which returns as table current path in data (including leafs).
     --    Path is calculated on each call of the function.
     ["types:factory"] = function(self, data)
        assert_is_nil(self.types_.factory_)
        self.types_.factory_ = assert_is_function(data.handler)
      end;
    };
    --
    types_ = types;
    root_defined_ = false;
  }

  for i = 1, #schema do
    walk_tagged_tree(schema[i], walkers, "id")
  end

  types.factory_ = types.factory_ or function() return { } end

  types.get_current_path_closure_ = function()
    return types:get_current_path()
  end

  types:reset(...)

  assert(walkers.root_defined_, "types:root must be defined")

  return types
end

--------------------------------------------------------------------------------

--[[
-- TODO: Uncomment and move to tests
do
  local data =
  {
    ["k"] =
    {
      v = 3;
    },
    value = 12;
  }

  local types = load_data_walkers(function()
    -- TODO: `types "name" .down (function() end)' is fancier.
    types:down "schema:three" (function(self, info, value)
      self:ensure_equals(value, 3)
    end)

    types:down "schema:twelve" (function(self, info, value)
      self:ensure_equals(value, 12)
    end)

    types:node "schema:node"

    types:root "schema:root"

    types:factory (function(checker, get_current_path)

      return
      {
        ensure_equals = function(self, actual, expected)
          if actual ~= expected then
            self.checker_:fail(
                "actual: " .. tostring(actual)
             .. " expected: " .. tostring(expected)
              )
          end
          return actual
        end;
        --
        checker_ = checker;
      }
    end)
  end)

  local schema = load_data_schema(function()
    schema:root "r"
    {
      schema:node "k"
      {
        schema:three "v";
      };

      schema:twelve "value";
    }
  end)

  assert(types:walk_data_with_schema(schema, data):get_checker():result())

  error("OK")
end
--]]

--------------------------------------------------------------------------------

return
{
  load_data_walkers = load_data_walkers;
  load_data_schema = load_data_schema;
}
