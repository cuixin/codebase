--------------------------------------------------------------------------------
-- util.lua: hiredis utilities
--------------------------------------------------------------------------------

local hiredis = require 'hiredis'

--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "pk-engine/hiredis/util", "HRU"
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

local try
      = import 'pk-core/error.lua'
      {
        'try'
      }

--------------------------------------------------------------------------------

local try_unwrap = function(error_id, res, ...)
  return try(
      error_id,
      hiredis.unwrap_reply(
          try(error_id, res, ...)
        )
    )
end

--------------------------------------------------------------------------------

return
{
  try_unwrap = try_unwrap;
}
