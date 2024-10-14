--[[______   __
  / ____/ | / / by: GNamimates, Discord: "@gn8.", Youtube: @GNamimates
 / / __/  |/ / Height Map to Normal Map
/ /_/ / /|  / Generates a normal map from a height map
\____/_/ |_/ Source: https://github.com/lua-gods/aseprite-scripts/blob/main/Height%20Map%20to%20Normal%20Map.lua]]
--[[ KNOWN ISSUES --
 -it requires two undos to remove the applied laye
  - this is the fault of the preview layer being a different transaction from the final layer.

  --TODO
   - add a non linear strength filter to normalize the normals in the normal map
  
------------------------------]]

local sprite = app.sprite
if not sprite then print("Sprite Not Found") return end
local target_layer = app.layer
if not target_layer then print("No Layer Selected") return end


---@param r integer
---@param g integer
---@param b integer
---@return integer
local function grayscale(r,g,b)
  return 0.299*r + 0.587*g + 0.114*b + 0.5
end

---@param clri integer
---@return integer
---@return integer
---@return integer
---@return integer
local function rgba(clri)
  return
  app.pixelColor.rgbaR(clri),
  app.pixelColor.rgbaG(clri),
  app.pixelColor.rgbaB(clri),
  app.pixelColor.rgbaA(clri)
end

--- Samples color, but clamped to the image bounds
---@param img Image
---@param x integer
---@param y integer
local function clr(img,x,y)
  x = math.max(0,math.min(img.width-1,x))
  y = math.max(0,math.min(img.height-1,y))
  return img:getPixel(x,y)
end


-- warn about using the wrong color mode
if sprite.colorMode ~= ColorMode.RGB then
  local color_mode_dialog = Dialog({title = "Height Map to Normal Map",})
  local abort = true
  color_mode_dialog:label({text = "This script was written for RGB color mode only."}):newrow()
  color_mode_dialog:label({text = "Change the Color Mode at Sprite > Color Mode > RGB Color"})
  color_mode_dialog:button({text = "OK"})
  color_mode_dialog:button({text = "Ignore",onclick = function() abort = false color_mode_dialog:close() end})
  color_mode_dialog:show()
  if abort then return end
end

local dialog = Dialog("Height Map to Normal Map")
local preview_layer



app.transaction("Normal Map Preview",function ()
  preview_layer = sprite:newLayer()
  preview_layer.name = "Preview"
  preview_layer.isEditable = false

local offsets = {
  {-1,-1},
  {0,-1},
  {1,-1},
  {-1,0},
  {1,0},
  {-1,1},
  {0,1},
  {1,1},
}

local lookup = {
    ["Always Top Left"] = {{-1,-1}},
   ["Always Top Right"] = {{ 1,-1}},
 ["Always Bottom Left"] = {{-1, 1}},
["Always Bottom Right"] = {{ 1, 1}},
}



---@param img Image
---@param x integer
---@param y integer
---@return integer
---@return integer
local function height(img,x,y)
  local r,g,b,a = rgba(clr(img,x,y))
  return grayscale(r,g,b),a
end


---@param img Image
---@param x integer
---@param y integer
---@param bias number
---@param offsets {[1]:integer, [2]:integer}[]
local function getNormal(img,x,y,offsets,bias)
  local nx,ny = 0,0
  local root_height,alpha = height(img,x,y)
  local contributed = 0
  if alpha == 0 then return 0,0 end
  for i, o in pairs(offsets) do
    local snlen = math.sqrt(o[1]^2 + o[2]^2)
    local sample_height,sampled_alpha = height(img,x+o[1],y+o[2])
    if sampled_alpha ~= 0 then
      local delta = sample_height - root_height
      contributed = contributed + delta * bias
      nx = nx + o[1] / snlen * delta
      ny = ny + o[2] / snlen * delta
    end
  end
  local clen = math.max(contributed,1)
  nx = math.max(math.min(nx / clen,254),-254)
  ny = math.max(math.min(ny / clen,254),-254)
  
  return nx,ny
end


local function updatePreview()
  -- Clear Layer
  for i, preview_cel in ipairs(preview_layer.cels) do
    sprite:deleteCel(preview_cel)
  end
  
  -- Redraw Layer
  for i, target_cel in ipairs(target_layer.cels) do
    local target_img = target_cel.image
    local preview_img = Image(target_cel.image.width,target_cel.image.height)
    
    
    if dialog.data then
      for y = 0, target_img.height-1, 1 do
        for x = 0, target_img.width-1, 1 do
          
          
          local r,g,b,a = rgba(clr(target_img,x,y))
          local main_height = grayscale(rgba(clr(target_img,x,y)))
          local dx,dy
          
          dx,dy = getNormal(target_img,x,y,offsets,dialog.data.bias / 10)
          
          local strength = dialog.data.strength / 100
          
          dx = dx
          dy = dy * (dialog.data.flip_y and -1 or 1)
          
          local len = math.sqrt(((dx*dx) + (dy*dy)) * math.abs(strength))
          local nx = dx * strength * 0.5 + 128
          local ny = dy * strength * 0.5 + 128
          local nz = (255-len)
          preview_img:drawPixel(x,y,app.pixelColor.rgba(nx,ny,nz,a))
        end
      end
      sprite:newCel(
      preview_layer,
      app.frame,
      preview_img,
      target_cel.position
      )
    end
  end
  app:refresh()
end

dialog:slider{
  id="bias",
  label="bias",
  min=-1,
  max=1,
  value=1,
  onchange = updatePreview,
}

dialog:check{
  id="flip_y",
  text="Flip Y",
  selected = true,
  label="OpenGL / DirectX",
  onclick = updatePreview,
}

dialog:slider{
  id="strength",
  label="Strength",
  min=-100,
  max=100,
  value=100,
  onchange = updatePreview,
}

dialog:check{
  id="replace_layer",
  text="Replace Layer",
  onclick = updatePreview,
}

dialog:separator{}
dialog:button{
  text = 'Cancel',
  onclick = function()
    sprite:deleteLayer(preview_layer)
    app:refresh() -- some regions of the image dosent update
    dialog:close()
   end
}

dialog:button{
  text = 'Apply',
  onclick = function()
  updatePreview()
  app.transaction("Converted to Normal Map",function ()
    if dialog.data.replace_layer then
      for key, cel in pairs(target_layer.cels) do
        sprite:deleteCel(cel)
      end
      for key, cel in pairs(target_layer.cels) do
        sprite:newCel(preview_layer,cel.frame,cel.image,cel.position)
      end
      sprite:deleteLayer(preview_layer)
    else
      preview_layer.name = target_layer.name .. " Normal Map"
      preview_layer.isEditable = true
    end
  end)
  dialog:close()
  end
}

updatePreview()
end)


dialog:show{wait=false}