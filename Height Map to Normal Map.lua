--[[______   __
  / ____/ | / /  by: GNanimates / https://gnon.top / Discord: @gn68s
 / / __/  |/ / name: Height Map to Normal Map
/ /_/ / /|  /  desc: Generates a normal map from a height map
\____/_/ |_/ source: https://github.com/lua-gods/aseprite-scripts/blob/main/Height%20Map%20to%20Normal%20Map.lua ]]
--[[ KNOWN ISSUES --
 -it requires two undos to remove the applied laye
	- this is the fault of the preview layer being a different transaction from the final layer.

	--TODO
	 - add a non linear strength filter to normalize the normals in the normal map
	 - bring back the bias slider somehow
	
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

local kernels = {
	["Adjacents & Diagonals"] = {
		{-1,-1},
		{0,-1},
		{1,-1},
		{-1,0},
		{1,0},
		{-1,1},
		{0,1},
		{1,1},
	},
	["Adjacents"] = {
		{-1,0},
		{1,0},
		{0,1},
		{0,-1},
	},
	["Diagonals"] = {
		{-1,-1},
		{1,-1},
		{-1,1},
		{1,1},
	}
}

local function lerp(a,b,w)
	return a + (b - a) * w
end

local function clamp(v,min,max)
	return math.min(math.max(v,min),max)
end


---@param img Image
---@param x integer
---@param y integer
---@return integer
---@return integer
local function height(img,x,y)
	local r,g,b,a = rgba(clr(img,x,y))
	return grayscale(r,g,b) / 255,a
end

---@param img Image
---@param x integer
---@param y integer
---@param bias integer
---@param offsets {[1]:integer, [2]:integer}[]
local function getNormal(img,x,y,offsets,bias)
	local nx,ny = 0,0
	local root_height,alpha = height(img,x,y)
	local contributed = 0
	for i, o in pairs(offsets) do
		local snlen = math.sqrt(o[1]^2 + o[2]^2)
		local sample_height,sampled_alpha = height(img,x+o[1],y+o[2])
		if sampled_alpha ~= 0 then
			local delta = sample_height - root_height
			if bias == -1 then delta = clamp(delta,-1,0)
			elseif bias == 1 then delta = clamp(delta,0,1)
			end
			contributed = contributed + snlen
			nx = nx + o[1] / snlen * delta
			ny = ny + o[2] / snlen * delta
		end
	end
	local clen = math.max(contributed,1)
	nx = nx / clen
	ny = ny / clen
	
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
					
					local _,_,_,a = rgba(clr(target_img,x,y))
					local dx,dy
					
---@diagnostic disable-next-line: param-type-mismatch
					dx,dy = getNormal(target_img,x,y,kernels[dialog.data.kernel],dialog.data.bias or 0)
					
					local s = dialog.data.normalize / 100
					local f = (dialog.data.flip_y and -1 or 1)
					
					dx = dx * (dialog.data.xinv and -1 or 1)
					dy = dy * f * (dialog.data.yinv and -1 or 1)
					
					local len = math.sqrt(dx^2 + dy^2)
					local w = lerp(1,len,s*0.9999)
					local nx = (dx / w + 1) / 2
					local ny = (dy / w + 1) / 2
					local nz = lerp(1 - len,1,s)
					preview_img:drawPixel(x,y,app.pixelColor.rgba(
					nx*255,
					ny*255,
					nz*255,
					255))
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
	label="Bias",
	min=-1,
	max=1,
	value=0,
	onchange = updatePreview,
}

dialog:slider{
	id="normalize",
	label="Normalize",
	min=0,
	max=100,
	value=95,
	onchange = updatePreview,
}

dialog:combobox({
	id = "kernel",
	label = "Kernel",
	option = "Adjacents & Diagonals",
	options = {"Adjacents","Adjacents & Diagonals", "Diagonals"}
})

dialog:newrow { always = false }
dialog:check {
	id = "xinv",
	label = "Invert",
	text = "X",
	selected = false,
	onclick = updatePreview
}

dialog:check {
	id = "yinv",
	text = "Y",
	selected = false,
	onclick = updatePreview
}

dialog:newrow { always = false }

dialog:check{
	id="replace_layer",
	text="Replace Layer",
	onclick = updatePreview,
}

local function cancel()
	sprite:deleteLayer(preview_layer)
	app:refresh() -- some regions of the image dosent update
	dialog:close()
 end

dialog:separator{}
dialog:button{
	text = 'Cancel',
	onclick = cancel
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