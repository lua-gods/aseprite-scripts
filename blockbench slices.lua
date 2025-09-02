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
   mesh = hexColor('#f9c4ff')
}

math.randomseed(os.time())

local bbmodel
local textures = {}
local transaction = false
local suggestedModelsPaths = {}
local lastLoadPath = ''
local lastLoadTime = -1
-- functions
local sortMeshVertices
do -- why are points in blockbench not sorted already
   local function cross(a, b)
      return {
         x = a.y * b.z - a.z * b.y,
         y = a.z * b.x - a.x * b.z,
         z = a.x * b.y - a.y * b.x
      }
   end

   local function test(a, b, c, d)
      b = {x = b.x - a.x, y = b.y - a.y, z = b.z - a.z}
      c = {x = c.x - a.x, y = c.y - a.y, z = c.z - a.z}
      d = {x = d.x - a.x, y = d.y - a.y, z = d.z - a.z}

      a = {x = b.x, y = b.y, z = b.z}
      a = cross(a, c)
      a = cross(a, d)

      return a.x * b.x + a.y * b.y + a.z * b.z > 0
   end
   function sortMeshVertices(tbl)
      if #tbl <= 3 then return end

      if test(tbl[2].pos, tbl[3].pos, tbl[1].pos, tbl[4].pos) then
         tbl[1], tbl[2], tbl[3] = tbl[3], tbl[1], tbl[2]
      elseif test(tbl[1].pos, tbl[2].pos, tbl[3].pos, tbl[4].pos) then
         tbl[2], tbl[3] = tbl[3], tbl[2]
      end
   end
end

local function newReferenceLayer(s, name)
   local layerId = tostring(math.random())
   app.command.newLayer{
      name = layerId,
      reference = true,
   }
   local layer ---@type Layer -- find the layer
   for _, v in ipairs(s.layers) do
      if v.name == layerId then
         layer = v
         break
      end
   end
   if name then
      layer.name = name
   end
   return layer
end

local function generateMeshSlices(shapes)
   local width = sprite.width
   local height = sprite.height
   local scale = dialog.data.meshesQuality
   local brush = Brush{
      size = dialog.data.meshesLineWidth --[[@as number]]
   }
   -- create reference layer for mesh slices
   local layer = newReferenceLayer(sprite, 'mesh slices')
   layer.stackIndex = #sprite.layers + 1 -- move to top
   local image = Image(width * scale, height * scale)
   -- add image to reference, i couldnt find better way to scale the reference
   sprite:resize(width * scale, height * scale)
   sprite:newCel(
      layer,
      app.frame,
      image
   )
   local cel = layer:cel(app.frame)
   -- render mesh
   for _, shape in pairs(shapes) do
      local points = {}
      for _, v in ipairs(shape) do
         table.insert(points, Point(v.uv.x * scale, v.uv.y * scale))
      end
      table.insert(points, points[1]) -- make loop
      for i = 1, #points - 1 do
         app.useTool{
            tool = 'line',
            color = faceColors.mesh,
            points = {points[i], points[i + 1]},
            cel = cel,
            brush = brush
         }
      end
   end
   sprite:resize(width, height)
   -- force layers to be reloaded
   sprite:deleteLayer(sprite:newLayer())
end

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
   local meshShapes = {}
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
                     color = faceColors[faceName] or Color{r = 255, g = 255, b = 255, a = 255}
                  })
               end
            end
         elseif element.type == 'mesh' then
            for _, face in pairs(element.faces) do
               if face.texture == textureToUse then
                  local shape = {
                     name = element.name .. ' | ' .. 'mesh'
                  }
                  for _, vertexId in ipairs(face.vertices) do
                     local uv = {x = face.uv[vertexId][1], y = face.uv[vertexId][2]}
                     local pos = element.vertices[vertexId]
                     table.insert(shape, {
                        uv = uv,
                        pos = {x = pos[1], y = pos[2], z = pos[3]}
                     })
                  end
                  -- sort vertices
                  sortMeshVertices(shape)
                  table.insert(meshShapes, shape)
               end
            end
         end
      end
   end
   -- add mesh slices
   for i = 1, #meshShapes do
      local v = meshShapes[i]
      if
         (
            #v == 4
            and
            (
               ( -- check if shape is axis aligned rectangle
               v[1].uv.x == v[2].uv.x and v[3].uv.x == v[4].uv.x and
               v[1].uv.y == v[4].uv.y and v[2].uv.y == v[3].uv.y
               ) or (
               v[1].uv.y == v[2].uv.y and v[3].uv.y == v[4].uv.y and
               v[1].uv.x == v[4].uv.x and v[2].uv.x == v[3].uv.x
               )
            )
            and
            ( -- check if shape is aligned to grid
               v[1].uv.x % 1 == 0 and v[1].uv.y % 1 == 0 and
               v[2].uv.x % 1 == 0 and v[2].uv.y % 1 == 0 and
               v[3].uv.x % 1 == 0 and v[3].uv.y % 1 == 0 and
               v[4].uv.x % 1 == 0 and v[4].uv.y % 1 == 0
            )
         )
         or
         dialog.data.meshBoundingBox
      then
         local min = {v[1].uv.x, v[1].uv.y}
         local max = {v[1].uv.x, v[1].uv.y}
         for k = 2, #v do
            min[1] = math.min(min[1], v[k].uv.x)
            min[2] = math.min(min[2], v[k].uv.y)
            max[1] = math.max(max[1], v[k].uv.x)
            max[2] = math.max(max[2], v[k].uv.y)
         end
         table.insert(slices, {
            rectangle = Rectangle(
               min[1],
               min[2],
               max[1] - min[1],
               max[2] - min[2]
            ),
            name = v.name,
            color = faceColors.mesh
         })
         meshShapes[i] = nil
      end
   end
   -- add slices
   for _, v in pairs(slices) do
      local slice = sprite:newSlice(v.rectangle)
      slice.name = v.name
      slice.color = v.color
   end
   if dialog.data.renderMeshes and next(meshShapes) then
      generateMeshSlices(meshShapes)
   end
   -- finish transaction
   transaction = true
end

local function reloadSlices()
   if not bbmodel then
      return
   end
   if transaction then
      app.undo()
      transaction = false
   end
   local ok, err
   app.transaction(
      'generate slices from bbmodel',
      function()
         ok, err = pcall(slicesTransaction)
      end
   )
   if not ok then
      app.undo()
      print('transaction failed')
      print(err)
   end
   app.refresh()
end

---returns table with model info when read successfully or with string as second return value with error
---@param filePath string
---@return table?, string?
local function readModel(filePath)
   local file = io.open(filePath, "r")
   if not file then
      return nil, 'failed to open file'
   end
   -- read file
   local fileContent = file:read "*a"
   file:close()
   -- read json
   local success, modelJson = pcall(json.decode, fileContent) --[[@as table|string|nil]]
   if not success then
      return nil, 'reading json\n' .. tostring(modelJson)
   end
   -- add textures to list
   local myTextures = {}
   local texturesPaths = {}
   for id, v in ipairs(modelJson.textures) do
      local name = v.relative_path or v.path
      myTextures[name] = {
         id = id - 1,
         data = v
      }
      table.insert(texturesPaths, name)
   end
   -- find texture to use
   local textureToUse = nil
   for _, patterns in pairs(compareFilePatterns) do
      local spritePath = sprite.filename
      for _, v in pairs(patterns) do
         spritePath = string[v.func](spritePath, table.unpack(v)) or spritePath
      end
      for name, v in pairs(myTextures) do
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
   -- finish
   return {
      bbmodel = modelJson,
      textureToUse = textureToUse,
      texturesPaths = texturesPaths,
      textures = myTextures
   }
end

local function loadModel()
   -- check if correct file
   local filePath = dialog.data.file
   local suggestedModel = dialog.data.suggestedModels --[[@as string]]
   if suggestedModel ~= '' then
      filePath = suggestedModelsPaths[suggestedModel] or filePath
   end
   if type(filePath) ~= 'string' then
      print('no file found')
      return
   end
   if filePath == '' then
      return
   end
   if filePath == sprite.filename then -- sprite cant be model
      return
   end
   if not app.fs.isFile(filePath) then
      return
   end
   if not filePath:match('%.bbmodel$') then
      print('file is not bbmodel')
      return
   end
   local currentLoadTime = os.time()
   if lastLoadPath == filePath and currentLoadTime == lastLoadTime then
      return
   end
   lastLoadTime = currentLoadTime
   lastLoadPath = filePath
   local modelData, err = readModel(filePath)
   if err then
      print(err)
      return
   end
   -- set variables
   bbmodel = modelData.bbmodel
   textures = modelData.textures
   -- update dialog
   dialog:modify{
      id = 'modelTexture',
      option = modelData.textureToUse or '',
      options = modelData.texturesPaths
   }
end

local function searchModels()
   suggestedModelsPaths = {}
   local suggestedList = {''}
   local searchPath = app.fs.joinPath(sprite.filename, '..') -- go back to directory
   local displayPath = ''
   for _ = 1, 4 do -- depth
      local finishSearch = false
      for _, filename in pairs(app.fs.listFiles(searchPath)) do
         if filename:match('^avatar%.jsonc?$') then
            finishSearch = true
         elseif filename:match('%.bbmodel$') then
            local path = app.fs.joinPath(searchPath, filename)
            local success, modelData, err = pcall(readModel, path)
            if success and modelData then
               if modelData.textureToUse then
                  local myDisplayPath = displayPath..filename
                  suggestedModelsPaths[myDisplayPath] = path
                  table.insert(suggestedList, myDisplayPath)
               end
            else -- elseif success
               -- maybe consider doing something?
            end
         end
      end
      if finishSearch then
         break
      end
      displayPath = displayPath..'../'
      searchPath = app.fs.joinPath(searchPath, '..')
   end
   dialog:modify{
      id = "suggestedModels",
      option = suggestedList[1] or '',
      options = suggestedList
   }
end

local function loadModelFromFile()
   dialog:modify{
      id = "suggestedModels",
      option = ''
   }
   loadModel()
end

-- ui
dialog:file{
   label = 'model:',
   id = 'file',
   -- filename = sprite.filename, -- not needed anymore
   filetypes = {'bbmodel'},
   onchange = loadModelFromFile
}

dialog:combobox{
   label = "suggested:",
   id = "suggestedModels",
   option = '',
   options = {},
   onchange = loadModel
}

searchModels()

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

dialog:separator{text = 'mesh settings'}
dialog:check{
   id = 'meshBoundingBox',
   text = 'render bounding boxes',
   onclick = reloadSlices
}

dialog:newrow()
dialog:check{
   id = 'renderMeshes',
   text = 'render meshes (slow)',
   onclick = reloadSlices
}

dialog:slider{
   id = 'meshesLineWidth',
   label = 'line width:',
   value = 1,
   min = 1,
   max = 16,
   onrelease = reloadSlices
}

local spriteSize = math.sqrt(sprite.width ^ 2 + sprite.height ^ 2)
dialog:slider{
   id = 'meshesQuality',
   label = 'quality:',
   value = spriteSize > 1024 and 2 or spriteSize > 512 and 3 or spriteSize > 256 and 4 or 6,
   min = 1,
   max = 16,
   onrelease = reloadSlices
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