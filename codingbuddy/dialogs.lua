-- dialogs.lua - minimal UI wrappers for GeanyLua
local M = {}

local geany = rawget(_G, 'geany')

function M.alert(title, message)
  if geany and geany.message then
    geany.message((title or 'CodingBuddy')..': '..tostring(message))
  else
    print('[CodingBuddy] '..tostring(title)..': '..tostring(message))
  end
end

function M.show_text(title, text)
  -- For now, reuse message; later use a GTK dialog
  if geany and geany.message then
    geany.message((title or 'CodingBuddy').."\n\n"..tostring(text))
  else
    print('[CodingBuddy] '..tostring(title).."\n"..tostring(text))
  end
end

return M

