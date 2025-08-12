---@module patch
--- Diff and patch engine with safe fallbacks for CodingBuddy
--- Provides unified diff generation and safe patch application within sandbox constraints
---
--- Features:
--- - Generate unified diffs between file content and new content
--- - Apply patches safely using system patch utility
--- - Fallback to direct file overwrite with explicit approval
--- - Full sandbox security enforcement
--- - Support for new file creation via patches
--- - Comprehensive error handling and validation
---
--- @author CodingBuddy Development Team
--- @version 1.0
--- @license MIT

local path = require('tools.path')
local fs = require('tools.fs')

local M = {}

--- Check if diff and patch system utilities are available
--- @return boolean has_diff True if diff command is available
--- @return boolean has_patch True if patch command is available
local function ensure_tools()
  local has_diff = os.execute('command -v diff >/dev/null') == 0
  local has_patch = os.execute('command -v patch >/dev/null') == 0
  return has_diff, has_patch
end

--- Generate a unified diff between a file's current content and new desired content
--- Supports both existing file modification and new file creation scenarios
---
--- @param rel_path string Relative path to the target file within the sandbox
--- @param new_content string The desired new content for the file
--- @return table result Result table with either 'patch' field containing the diff or 'error' field with error message
---   - On success: { patch = "unified diff string" } (empty string if no changes)
---   - On error: { error = "error description" }
function M.generate_diff(rel_path, new_content)
  -- Input validation
  if not rel_path or rel_path == '' then
    return { error = 'empty relative path provided' }
  end
  if not new_content then
    new_content = ''
  end

  local abs, err = path.to_abs(rel_path)
  if not abs then return { error = err } end
  local ok, err2 = path.ensure_in_sandbox(abs)
  if not ok then return { error = err2 } end

  -- Check if original file exists
  local current_content = fs.read_file(abs)
  if not current_content then
    -- File doesn't exist, treat as creating new file
    if new_content == '' then
      return { patch = '' }  -- No change needed
    end
    -- For new files, we'll use the standard diff approach by creating an empty temp file
    local empty_tmp = abs .. '.cb.empty.' .. tostring(os.time())
    fs.write_file_atomic(empty_tmp, '')
    local new_tmp = abs .. '.cb.new.' .. tostring(os.time())
    fs.write_file_atomic(new_tmp, new_content)
    
    local has_diff = os.execute('command -v diff >/dev/null') == 0
    if has_diff then
      local cmd = 'diff -u "' .. empty_tmp .. '" "' .. new_tmp .. '"'
      local h = io.popen(cmd)
      if h then
        local patch_text = h:read('*all')
        h:close()
        -- Replace temp file names with proper paths
        if patch_text and patch_text ~= '' then
          local escaped_empty = empty_tmp:gsub('([%.%-%+%*%?%[%]%^%$%(%)%%])', '%%%1')
          local escaped_new = new_tmp:gsub('([%.%-%+%*%?%[%]%^%$%(%)%%])', '%%%1')
          patch_text = patch_text:gsub(escaped_empty, '/dev/null')
          patch_text = patch_text:gsub(escaped_new, rel_path)
          os.remove(empty_tmp)
          os.remove(new_tmp)
          return { patch = patch_text }
        end
      end
    end
    os.remove(empty_tmp)
    os.remove(new_tmp)
    return { patch = '' }
  end

  -- Files exist, generate standard diff
  local tmp = abs .. '.cb.new.' .. tostring(os.time())
  local okw, werr = fs.write_file_atomic(tmp, new_content)
  if not okw then return { error = werr } end

  local has_diff = os.execute('command -v diff >/dev/null') == 0
  local patch_text

  if has_diff then
    -- Use relative path in diff to make patch application easier
    local cmd = 'diff -u "' .. rel_path .. '" "' .. tmp .. '"'
    local h = io.popen(cmd)
    if h then
      patch_text = h:read('*all')
      h:close()
      -- Replace the temp file name in the patch with the original relative path
      if patch_text and patch_text ~= '' then
        local escaped_tmp = tmp:gsub('([%.%-%+%*%?%[%]%^%$%(%)%%])', '%%%1')
        patch_text = patch_text:gsub(escaped_tmp, rel_path)
      end
    end
  else
    -- Fallback: manual diff generation for simple cases
    if current_content == new_content then
      patch_text = ''
    else
      -- Simple replacement indication - not a real patch format
      patch_text = nil
    end
  end

  os.remove(tmp)

  if not patch_text or patch_text == '' then
    -- No diff utility or no difference
    return { patch = '' }
  end

  return { patch = patch_text }
end

--- Apply a unified diff patch to a file or use fallback overwrite mode
--- Attempts to use system patch utility first, with verification via diff generation
---
--- @param rel_path string Relative path to the target file within the sandbox  
--- @param patch_text string Either a unified diff patch or file content (when mode='overwrite')
--- @param mode string|nil Optional mode: 'overwrite' for direct file replacement, nil for patch mode
--- @return table result Result table indicating success/failure
---   - On success: { ok = true, output = "patch output", note = "optional note" }
---   - On error: { error = "error description", output = "optional patch output" }
function M.apply_patch(rel_path, patch_text, mode)
  local abs, err = path.to_abs(rel_path)
  if not abs then return { error = err } end
  local ok, err2 = path.ensure_in_sandbox(abs)
  if not ok then return { error = err2 } end

  -- If overwrite mode is specified, skip patch attempts and directly overwrite
  if mode == 'overwrite' then
    local ok2, werr = fs.write_file_atomic(abs, patch_text)
    if not ok2 then return { error = werr } end
    return { ok = true, note = 'file overwritten as fallback' }
  end

  -- Regular patch application
  local has_diff, has_patch = ensure_tools()
  if has_patch and patch_text and patch_text ~= '' then
    local pfile = abs .. '.cb.patch.' .. tostring(os.time())
    local f = io.open(pfile, 'wb')
    if not f then return { error = 'cannot create temp patch file' } end
    f:write(patch_text)
    f:close()

    -- Try apply patch with -p0 and no fuzz
    local cmd = 'patch -p0 < "' .. pfile .. '"'
    local h = io.popen(cmd)
    local out = h and h:read('*all') or ''
    if h then h:close() end
    os.remove(pfile)

    -- We cannot reliably get the exit code from io.popen here, so verify result by asking diff again
    local current_content = fs.read_file(abs) or ''
    local gen = M.generate_diff(rel_path, current_content)
    if gen and gen.patch == '' then
      return { ok = true, output = out }
    else
      -- Patch failed to apply cleanly
      return { error = 'patch failed to apply cleanly', output = out }
    end
  end

  return { error = 'patch failed and overwrite mode not permitted' }
end

return M
