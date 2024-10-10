--[[______   __
  / ____/ | / / by: GNamimates, Discord: "@gn8.", Youtube: @GNamimates
 / / __/  |/ / Height Map to Normal Map
/ /_/ / /|  / Generates a normal map from a height map
\____/_/ |_/ Source: https://github.com/lua-gods/aseprite-scripts/blob/main/Height%20Map%20to%20Normal%20Map.lua]]
local sprite = app.sprite
if not sprite then print("Sprite Not Found") return end
local target_layer = app.layer
if not target_layer then print("No Layer Selected") return end

local preview_layer = sprite:newLayer()
preview_layer.name = "Preview"
preview_layer.isEditable = false


local function updatePreview() -- TODO: replace layer method with temporary override image method
    -- Clear Layer
    for i, preview_cel in ipairs(preview_layer.cels) do
        sprite:deleteCel(preview_cel)
    end
    
    -- Redraw Layer
    for i, target_cel in ipairs(target_layer.cels) do
        local target_img = target_cel.image
        local preview_img = Image(target_cel.image.width,target_cel.image.height)
        
        local ox,oy = target_cel.position.x,target_cel.position.y
        
        for y = 0, target_img.height-1, 1 do
            for x = 0, target_img.width-1, 1 do
                local clri = target_img:getPixel(x,y)
                local r,g,b,a =
                app.pixelColor.rgbaR(clri),
                app.pixelColor.rgbaG(clri),
                app.pixelColor.rgbaB(clri)
                app.pixelColor.rgbaA(clri)
                
                preview_img:drawPixel(x,y,app.pixelColor.rgba(r,r,r,a))
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

local function replaceTargetWithPreview()
    preview_layer.name = target_layer.name
    sprite:deleteLayer(target_layer)
end

local function deletePreview()
    sprite:deleteLayer(preview_layer)
    app:refresh() -- some regions of the image dosent update
end

updatePreview()


local dialog = Dialog("Height Map to Normal Map")

--|--- Dialog Layout ---
--|         mode
--|         strength
--|         to new layer

dialog:combobox{
    id="mode",
    label="Differentiation Bias",
    option="Lowest Adjacent",
    options={"Highest Adjacent","Lowest Adjacent","Always Top Left", "Always Top Right", "Always Bottom Left", "Always Bottom Right"},
}

dialog:slider{
    id="strength",
    label="Strength",
    min=0,
    max=200,
    value=100,
}

dialog:check{
    id="replace_layer",
    text="Replace Layer",
    selected = true,
}

dialog:separator{}
dialog:button{
   text = 'Cancel',
   onclick = function()
        deletePreview()
      dialog:close()
   end
}

dialog:button{
   text = 'Apply',
   onclick = function()
    if dialog.data.replace_layer then
        replaceTargetWithPreview()
    end
    dialog:close()
    end
}

dialog:show{wait=false}