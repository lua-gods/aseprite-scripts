local sprite = app.sprite
if not sprite then return print('No active sprite') end

local dialog = Dialog("Blockbench slices")

local compareFilePatterns = {
   {{func = 'gsub', '\\', '/'}},
   {{func = 'gsub', '\\', '/'}, {func = 'gsub', '%.[^.]*$', ''}},
   {{func = 'match', '[^/]*$'}},
   {{func = 'match', '[^/]*$'}, {func = 'gsub', '%.[^.]*$', ''}},
}

local function hexColor(hex)
   hex = hex:gsub('#', '')
   return Color{
      r = tonumber('0x'..hex:sub(1, 2)) or 0,
      g = tonumber('0x'..hex:sub(3, 4)) or 0,
      b = tonumber('0x'..hex:sub(5, 6)) or 0
   }
end

local faceColors = {
   north = hexColor('#7bd4ff'),
   south = hexColor('#fff7a0'),
   east = hexColor('#7ffea8'),
   west = hexColor('#fea7a5'),
   up = hexColor('#ecf8fd'),
   down = hexColor('#6e788c'),
}

local bbmodel = {elements = {}}
local textures = {}
local transaction = false
-- functions
local function slicesTransaction()
   -- remove old slices
   if not dialog.data.keepSlices then
      local oldSlices = {}
      for _, v in ipairs(sprite.slices) do
         table.insert(oldSlices, v)
      end
      for i = #oldSlices, 1, -1 do
         sprite:deleteSlice(oldSlices[i])
      end
   end
   -- read slices
   local slices = {}
   local textureToUse = textures[dialog.data.modelTexture].id
   for _, element in ipairs(bbmodel.elements) do
      local visible = element.visibility
      if visible == nil then visible = true end
      if visible or dialog.data.includeInvisible then
         if element.type == 'cube' then
            for faceName, face in pairs(element.faces) do
               if face.texture == textureToUse then
                  local min = {math.min(face.uv[1], face.uv[3]), math.min(face.uv[2], face.uv[4])}
                  local max = {math.max(face.uv[1], face.uv[3]), math.max(face.uv[2], face.uv[4])}
                  table.insert(slices, {
                     rectangle = Rectangle(
                        min[1],
                        min[2],
                        max[1] - min[1],
                        max[2] - min[2]
                     ),
                     name = element.name .. ' | ' .. faceName,
                     face = faceName
                  })
               end
            end
         end
      end
   end
   -- add slices
   for _, v in pairs(slices) do
      local slice = sprite:newSlice(v.rectangle)
      slice.name = v.name
      slice.color = faceColors[v.face] or Color{r = 255, g = 255, b = 255, a = 255}
   end
   -- finish transaction
   transaction = true
end

local function reloadSlices()
   if transaction then
      app.undo()
      transaction = false
   end
   app.transaction(
      'generate slices from bbmodel',
      slicesTransaction
   )
   app.refresh()
end

local function loadModel()
   -- check if correct file
   local filePath = dialog.data.file
   if type(filePath) ~= 'string' then
      print('no file found')
      return
   end
   if not filePath:match('%.bbmodel$') then
      print('file is not bbmodel')
      return
   end
   local file = io.open(filePath, "r")
   if not file then
      print('failed to open file')
      return
   end
   -- read file
   local fileContent = file:read "*a"
   file:close()
   bbmodel = json.decode(fileContent)
   -- add textures to list
   textures = {}
   local texturesList = {}
   for id, v in ipairs(bbmodel.textures) do
      local name = v.relative_path or v.path
      textures[name] = {
         id = id - 1,
         data = v
      }
      table.insert(texturesList, name)
   end
   -- find texture to use 
   local textureToUse = ''
   for _, patterns in pairs(compareFilePatterns) do
      local spritePath = sprite.filename
      for _, v in pairs(patterns) do
         spritePath = string[v.func](spritePath, table.unpack(v)) or spritePath
      end
      for name, v in pairs(textures) do
         local path = v.data.path
         for _, v2 in pairs(patterns) do
            path = string[v2.func](path, table.unpack(v2)) or path
         end
         if spritePath == path then
            textureToUse = name
            break
         end
      end
      if textureToUse then break end
   end
   -- update things
   dialog:modify{
      id = 'modelTexture',
      option = textureToUse,
      options = texturesList
   }
end

-- ui
dialog:file{
   label = 'model:',
   id = 'file',
   filename = sprite.filename,
   filetypes = {'bbmodel'},
   onchange = loadModel
}

dialog:separator{text = 'settings'}
dialog:combobox{
   label = 'texture:',
   id = 'modelTexture',
   option = '',
   options = {},
   onchange = reloadSlices
}

dialog:check{
   id = 'keepSlices',
   text = 'keep old slices',
   onclick = reloadSlices
}

dialog:newrow()
dialog:check{
   id = 'includeInvisible',
   text = 'include invisible',
   onclick = reloadSlices
}

dialog:separator{}
dialog:button{
   text = 'Cancel',
   onclick = function()
      if transaction then
         app.undo()
         transaction = false
      end
      dialog:close()
   end
}

dialog:button{
   id = 'ok',
   text = 'OK',
   onclick = function() dialog:close() end
}

dialog:show{ wait=false }