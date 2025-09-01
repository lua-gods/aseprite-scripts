-- SelectionBoundsToClipboard.lua
local spr = app.sprite
if not spr then
  return app.alert("No active sprite")
end

local sel = spr.selection
if sel.isEmpty then
  return app.alert("No selection made")
end

-- Bounds of the selection
local b = sel.bounds
local x1, y1 = b.x, b.y
local x2, y2 = b.x + b.width - 1, b.y + b.height - 1

local text = string.format("%d,%d,%d,%d", x1, y1, x2, y2)

-- Copy to clipboard
app.clipboard.text = text

-- Optional alert (can remove if you want it silent)
app.alert("Copied to clipboard:\n" .. text)
