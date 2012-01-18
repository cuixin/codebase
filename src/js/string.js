/**
 * String functions.
 */

/**
 * Prepend value with 0 if length < precision.
 *
 * @param value
 * @param precision
 */
PK.formatNumber = function(value, precision)
{
  var parts = value.toString().split('.');
  var int_part = parts[0];
  if (parts.length > 1)
  {
    CRITICAL_ERROR("Can't format not integer number!");
  }

  if (precision === undefined)
    precision = 4;

  if (precision < 2)
    return value;

  if (int_part.length < precision)
  {
    return new Array(precision - int_part.length + 1).join('0') + int_part;
  }
  else if (int_part.length == precision)
  {
    return value;
  }
  else
  {
    CRITICAL_ERROR("Can't format big number!");
  }
}

// Based on http://javascript.crockford.com/remedial.html
PK.entityify_and_escape_quotes = function (s)
{
  if (typeof(s) == "number")
  {
    return s;
  }
  //PKLILE.timing.start("entityify_and_escape_quotes")
  var result = s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  //PKLILE.timing.stop("entityify_and_escape_quotes")
  return result;
}

/**
 * Split using placeholders like '${1}', '${2}' .. '${n}' or '${key}' (from keys).
 *
 * @param source
 * @param keys
 */
PK.split_using_placeholders = function(source, keys)
{
  var result = [];
  var pattern = '(\\$\\{[0-9]+\\})';
  if (keys && keys.length)
  {
    for (var i = 0; i < keys.length; i++)
    {
      pattern += '|(\\$\\{'+keys[i]+'\\})';
    }
  }
  var pieces = source.split(new RegExp(pattern));
  for (var n = 0; n < pieces.length; n++)
  {
    if (pieces[n] != undefined)
    {
      var item = pieces[n];
      if (item.substr(0, 2) == '${' && item.substr(item.length - 1) == '}')
      {
        var key = item.substr(2, item.length - 3);
        var key_number = Number(key);
        if (!isNaN(key_number))
        {
          if (key_number == key_number.toFixed(0))
          {
            item = key_number;
          }
        }
      }
      result.push(item);
    }
  }
  return result;
}

/**
 * Fill placeholders with values.
 *
 * @param source
 * @param ivalues Array
 * @param values Object
 */
PK.fill_placeholders = function(source, ivalues, values)
{
  var keys = undefined;
  var placeholders_values = undefined;
  if (values)
  {
    keys = [];
    placeholders_values = {};
    for (var key in values)
    {
      keys.push(key);
      placeholders_values["${"+key+"}"] = values[key];
    }
  }
  var pieces = PK.split_using_placeholders(source, keys);
  var result = [];
  for (var n = 0; n < pieces.length; n++) {
    var item = pieces[n];
    if (placeholders_values)
    {
      if (placeholders_values[item])
      {
        item = placeholders_values[item];
      }
    }
    if (typeof(item) == 'number' && ivalues)
    {
      var num = item - 1;
      if (ivalues.length > num)
      {
        item = ivalues[num];
      }
      else
      {
        CRITICAL_ERROR(
          "Too big value placeholder number: " + ivalues.length + '<=' + num
        );
        if(window.console && console.log)
        {
          console.log("[PK.fill_placeholders] failed on data:", source, ivalues, pieces);
        }

        LOG("source: " + source);
        LOG("ivalues: " + JSON.stringify(ivalues, null, 4));
        LOG("Data: " + JSON.stringify(pieces, null, 4));
      }
    }
    result.push(item);
  }
  return result.join('');
}

// Note: PK.formatString("some ${1} text ${2}", var_1, var_2) will replace ${1} by var_1 and ${2} by var_2 and etc.
PK.formatString = function()
{
  if (arguments.length < 1)
    return undefined

  var ivalues = Array.prototype.slice.call(arguments)
  var text = ivalues.shift()
  text = PK.fill_placeholders(text, ivalues)

  return text
}
