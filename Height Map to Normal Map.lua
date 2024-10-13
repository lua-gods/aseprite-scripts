--[[______   __
  / ____/ | / / by: GNamimates, Discord: "@gn8.", Youtube: @GNamimates
 / / __/  |/ / Height Map to Normal Map
/ /_/ / /|  / Generates a normal map from a height map
\____/_/ |_/ Source: https://github.com/lua-gods/aseprite-scripts/blob/main/Height%20Map%20to%20Normal%20Map.lua]]
--[[ KNOWN ISSUES --
 -it requires two undos to remove the applied laye
  - this is the fault of the preview layer being a different transaction from the final layer.

  --TODO
   - unify how the selected height is gathered.
   - un hard code normal map code
  
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
  return math.floor(0.299*r + 0.587*g + 0.114*b + 0.5)
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

local lookup = {
  ["Always Top Left"] = {-1,-1},
   ["Always Top Right"] = { 1,-1},
 ["Always Bottom Left"] = {-1, 1},
["Always Bottom Right"] = { 1, 1},
}


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
          
          if (dialog.data.mode or "") == "Lowest Adjacent" then
            do
              local r,g,b,a = rgba(clr(target_img,x+1,y))
              local height1 = grayscale(r,g,b)
              dx = main_height-height1
              
              r,g,b,a = rgba(clr(target_img,x-1,y))
              local height2 = grayscale(r,g,b)
              height2 = grayscale(r,g,b)
              if height2 < height1 then dx = height2-main_height end
            end
            
            do
              local r,g,b,a = rgba(clr(target_img,x,y+1))
              local height1 = grayscale(r,g,b)
              dy = main_height-height1
              
              r,g,b,a = rgba(clr(target_img,x,y-1))
              local height2 = grayscale(r,g,b)
              if height2 < height1 then dy = height2-main_height end
            end
          elseif (dialog.data.mode or "") == "Highest Adjacent" then
            do
              local r,g,b,a = rgba(clr(target_img,x+1,y))
              local height1 = grayscale(r,g,b)
              dx = main_height-height1
              
              r,g,b,a = rgba(clr(target_img,x-1,y))
              local height2 = grayscale(r,g,b)
              height2 = grayscale(r,g,b)
              if height2 > height1 then dx = height2-main_height end
            end
            
            do
              local r,g,b,a = rgba(clr(target_img,x,y+1))
              local height1 = grayscale(r,g,b)
              dy = main_height-height1
              
              r,g,b,a = rgba(clr(target_img,x,y-1))
              local height2 = grayscale(r,g,b)
              if height2 > height1 then dy = height2-main_height end
            end
          else
            local ox,oy = table.unpack(lookup[dialog.data.mode])
            local r,g,b,a = rgba(clr(target_img,x+ox,y))
            if a > 0 then dx = (grayscale(r,g,b) - main_height) * ox end
            local r,g,b,a = rgba(clr(target_img,x,y+oy))
            if a > 0 then dy = (grayscale(r,g,b) - main_height) * oy end
          end
          
          local strength = dialog.data.strength / 100
          
          dx = dx
          dy = dy * (dialog.data.flip_y and -1 or 1)
          
          local len = math.sqrt(((dx*dx) + (dy*dy)) * math.abs(strength)) / 255
          local nx = dx * strength / (len == 0 and 1 or len) * 0.5 + 128
          local ny = dy * strength / (len == 0 and 1 or len) * 0.5 + 128
          local nz = (1-len)*255
          
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

dialog:combobox{
  id="mode",
  label="Differentiation Bias",
  option="Lowest Adjacent",
  options={
    "Highest Adjacent",
    "Lowest Adjacent",
    "Always Top Left",
    "Always Top Right",
    "Always Bottom Left",
    "Always Bottom Right",
    onchange = updatePreview},
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