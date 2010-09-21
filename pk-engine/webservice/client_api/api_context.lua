--------------------------------------------------------------------------------
-- api_context.lua: handler context wrapper for api
--------------------------------------------------------------------------------

require 'wsapi.request'
require 'socket.url'

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

local is_string
      = import 'lua-nucleo/type.lua'
      {
        'is_string'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local try,
      fail
      = import 'pk-core/error.lua'
      {
        'try',
        'fail'
      }

local make_api_db,
      destroy_api_db
      = import 'pk-engine/webservice/client_api/api_db.lua'
      {
        'make_api_db',
        'destroy_api_db'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("webservice/client_api/api_context", "APC")

--------------------------------------------------------------------------------

-- WARNING: Call methods of the context inside call() protection only!
-- NOTE: It is OK to create context object outside of call() protection.
local make_api_context
do
  -- Private method
  local get_cached_request = function(self)
    method_arguments(self)
    if not self.cached_request_ then
      self.cached_request_ = wsapi.request.new(
          self.context_.wsapi_env,
          { overwrite = true }
        )
    end
    return self.cached_request_
  end

  -- Private method
  local get_cached_db = function(self)
    method_arguments(self)
    if not self.cached_db_ then
      self.cached_db_ = make_api_db(self.tables_, self.context_.db_manager)
    end
    return self.cached_db_
  end

  local post_request = function(self)
    method_arguments(self)
    return self.param_stack_[#self.param_stack_]
        or get_cached_request(self).POST
  end

  local raw_internal_config_manager = function(self)
    method_arguments(self)
    return self.context_.config_manager
  end

  -- Private method
  local get_cached_game_config = function(self)
    method_arguments(self)
    if not self.cached_game_config_ then
      self.cached_game_config_ = try(
          "INTERNAL_ERROR",
          self.www_game_config_getter_(self.context_)
        )
    end
    return self.cached_game_config_
  end

  local game_config = function(self)
    method_arguments(self)
    return get_cached_game_config(self)
  end

  -- Private method
  local get_cached_admin_config = function(self)
    method_arguments(self)
    if not self.cached_admin_config_ then
      self.cached_admin_config_ = try(
          "INTERNAL_ERROR",
          self.www_admin_config_getter_(self.context_)
        )
    end
    return self.cached_admin_config_
  end

  local admin_config = function(self)
    method_arguments(self)
    return get_cached_admin_config(self)
  end

  local request_ip = function(self)
    method_arguments(self)

    -- WARNING: This function should not fail even if IP is unknown!

    -- TODO: If REMOTE_ADDR does not exist or is empty,
    --       or starts with '127', '10.' or '192',
    --       try to look into X-Forwarded-For header.

    return self.context_.wsapi_env.REMOTE_ADDR or ""
  end

  -- Note that we do not have anything destroyable (yet)
  -- that is not destroys itself in __gc. So no __gc here.
  -- All is done on lower level if user forgets to call destroy().
  local destroy = function(self)
    method_arguments(self)

    -- Not using get_cached_db() since we don't want to create db
    -- if it was not used
    if self.cached_db_ then
      destroy_api_db(self.cached_db_)
      self.cached_db_ = nil
    end

    assert(#self.param_stack_ == 0, "unbalanced param stack on destroy")
  end

  local db = function(self)
    method_arguments(self)
    return get_cached_db(self)
  end

  local handle_url = function(self, url, param)
    method_arguments(
        self,
        "string", url,
        "string", param
      )
    local handler = self.internal_call_handlers_[url]
    if not handler then
      return fail(
          "INTERNAL_ERROR",
          "internal call handler for " .. url .. " not found"
        )
    end

    local res, err, err_id = handler(self, param)

    return res, err, err_id
  end

  local push_param
  do
    -- Based on WSAPI 1.3.4 (in override mode)
    -- TODO: Reuse WSAPI version instead
    local function parse_qs(qs, t)
      t = t or { }
      local url_decode = socket.url.unescape
      for key, val in qs:gmatch("([^&=]+)=([^&=]*)&?") do
        t[url_decode(key)] = url_decode(val)
      end
      return t
    end

    push_param = function(self, param)
      if is_string(param) then
        param = parse_qs(param)
      end
      method_arguments(
          self,
          "table", param
        )
      table.insert(self.param_stack_, param)
    end
  end

  local pop_param = function(self)
    method_arguments(self)
    try("INTERNAL_ERROR", #self.param_stack_ > 0, "no more params to pop")
    return table.remove(self.param_stack_)
  end

  make_api_context = function(
      context,
      db_tables,
      www_game_config_getter,
      www_admin_config_getter,
      internal_call_handlers
    )
    arguments(
        "table",    context,
        "table",    db_tables,
        "function", www_admin_config_getter,
        "function", www_game_config_getter,
        "table", internal_call_handlers
      )

    return
    {
      raw_internal_config_manager = raw_internal_config_manager;
      handle_url = handle_url;
      --
      game_config = game_config;
      admin_config = admin_config;
      db = db;
      --
      request_ip = request_ip;
      post_request = post_request;
      --
      push_param = push_param; -- Private
      pop_param = pop_param; -- Private
      --
      destroy = destroy; -- Private
      --
      -- WARNING: Do not expose this variable (see push/pop_param).
      context_ = context;
      --
      cached_request_ = nil;
      cached_game_config_ = nil;
      cached_admin_config_ = nil;
      cached_db_ = nil;
      --
      tables_ = db_tables;
      www_game_config_getter_ = www_game_config_getter;
      www_admin_config_getter_ = www_admin_config_getter;
      internal_call_handlers_ = internal_call_handlers;
      --
      param_stack_ = { };
    }
  end
end

--------------------------------------------------------------------------------

return
{
  make_api_context = make_api_context;
}
