-- Editor interface for Geany integration
-- Safely bridges editor state without relying on undocumented APIs

local geany = rawget(_G, 'geany')
local M = {}

-- Get the currently active file path
-- Returns: string|nil - absolute path to active file or nil if no file is open
function M.get_active_file()
  if not geany then return nil end
  if geany.filename then return geany.filename() end
  return nil
end

-- Get the current buffer text content
-- Returns: string|nil - full buffer content or nil if no buffer is available
function M.get_buffer_text()
  if not geany then return nil end
  if geany.text then return geany.text() end
  return nil
end

-- Set the current buffer text content
-- Args: text (string) - new text content for the buffer
-- Returns: boolean - true if successful, false otherwise
function M.set_buffer_text(text)
  if not geany then return false end
  if geany.text and type(text) == 'string' then
    geany.text(text)
    return true
  end
  return false
end

-- Check if Geany editor interface is available
-- Returns: boolean - true if Geany interface is accessible
function M.is_available()
  return geany ~= nil
end

-- Get editor status information
-- Returns: table - status information about the editor state
function M.get_status()
  return {
    available = M.is_available(),
    has_active_file = M.get_active_file() ~= nil,
    has_buffer_content = M.get_buffer_text() ~= nil
  }
end

return M
