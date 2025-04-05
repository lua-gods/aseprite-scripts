local searchButtonCount = 5
local commandsRaw = {
   -- add here if needed so they are listed
   -- default aseprite commands
   "About", "AddColor", "AdvancedMode", "AutocropSprite", "BackgroundFromLayer", "BrightnessContrast", "Cancel", "CanvasSize",
   "CelOpacity", "CelProperties", "ChangeBrush", "ChangeColor", "ChangePixelFormat", "ClearCel", "Clear", "CloseAllFiles",
   "CloseFile", "ColorCurve", "ColorQuantization", "ContiguousFill", "ConvolutionMatrix", "CopyCel", "CopyColors", "CopyMerged", "Copy",
   "CropSprite", "Cut", "DeselectMask", "Despeckle", "DeveloperConsole", "DiscardBrush", "DuplicateLayer", "DuplicateSprite", "DuplicateView",
   "Exit", "ExportSpriteSheet", "ExportTileset", "Eyedropper", "Fill", "FitScreen", "FlattenLayers", "Flip", "FrameProperties", "FrameTagProperties",
   "FullscreenPreview", "GotoFirstFrameInTag", "GotoFirstFrame", "GotoFrame", "GotoLastFrameInTag", "GotoLastFrame", "GotoNextFrameWithSameTag",
   "GotoNextFrame", "GotoNextLayer", "GotoNextTab", "GotoPreviousFrameWithSameTag", "GotoPreviousFrame", "GotoPreviousLayer", "GotoPreviousTab",
   "GridSettings", "Home", "HueSaturation", "ImportSpriteSheet", "InvertColor", "InvertMask", "KeyboardShortcuts", "Launch", "LayerFromBackground",
   "LayerLock", "LayerOpacity", "LayerProperties", "LayerVisibility", "LinkCels", "LoadMask", "LoadPalette", "MaskAll", "MaskByColor", "MaskContent",
   "MergeDownLayer", "ModifySelection", "MoveCel", "MoveColors", "MoveMask", "NewBrush", "NewFile", "NewFrameTag", "NewFrame", "NewLayer",
   "NewSpriteFromSelection", "OpenBrowser", "OpenFile", "OpenGroup", "OpenInFolder", "OpenScriptFolder", "OpenWithApp", "Options", "Outline",
   "PaletteEditor", "PaletteSize", "PasteText", "Paste", "PixelPerfectMode", "PlayAnimation", "PlayPreviewAnimation", "Redo", "Refresh",
   "RemoveFrameTag", "RemoveFrame", "RemoveLayer", "RemoveSlice", "RepeatLastExport", "ReplaceColor", "ReselectMask", "ReverseFrames", "Rotate",
   "RunScript", "SaveFile", "SaveFileAs", "SaveFileCopyAs", "SaveMask", "SavePalette", "ScrollCenter", "Scroll", "SelectTile", "SelectionAsGrid",
   "SetColorSelector", "SetInkType", "SetLoopSection", "SetPaletteEntrySize", "SetPalette", "SetSameInk", "ShowAutoGuides", "ShowBrushPreview",
   "ShowExtras", "ShowGrid", "ShowLayerEdges", "ShowOnionSkin", "ShowPixelGrid", "ShowSelectionEdges", "ShowSlices", "SliceProperties",
   "SnapToGrid", "SpriteProperties", "SpriteSize", "Stroke", "SwitchColors", "SymmetryMode", "TiledMode", "Timeline", "TogglePreview",
   "ToggleTimelineThumbnails", "UndoHistory", "Undo", "UnlinkCel", "Zoom",
}

local function checkCommand(cmd)
   if app.command[cmd] then
      return true
   end
end

local commands = {}
for _, cmd in pairs(commandsRaw) do
   local success, found = pcall(checkCommand, cmd)
   if success and found then
      local name = cmd:gsub('%u', ' %1')
      name = name:lower():gsub('^%s+', ''):gsub('%s+$', '')
      name = name:sub(1, 1):upper() .. name:sub(2, -1)
      table.insert(commands, {
         name = name,
         cmd = cmd,
         search1 = name:lower()
      })
   end
end

local dlg = Dialog("Search")
local searchResults = {}

local function selectResult(i)
   local result = searchResults[i]
   if result then
      app.command[result.cmd]()
   end
   dlg:close()
end

local function search()
   local queryRaw = dlg.data.query --[[@as string]]
   local query = queryRaw:gsub('%d$', '')
   local buttonToSelect = tonumber(queryRaw:match('%d$'))
   local queryPattern = query:lower():gsub('[-+*?.%%^$[%]()]', '%%%1')
   local results = {}
   for _, v in pairs(commands) do
      local a, b = v.search1:find(queryPattern)
      if a and b then
      local score = #query / #v.search1
         table.insert(results, {
            score = score,
            cmd = v
         })
      end
   end
   -- get best results and update buttons
   searchResults = {}
   local ignoredResults = {}
   for i = 1, searchButtonCount do
      local bestScore = -1
      for k, v in pairs(results) do
         if not ignoredResults[k] and v.score > bestScore then
            ignoredResults[k] = true
            searchResults[i] = v.cmd
            bestScore = v.score
         end
      end

      dlg:modify{
         id = "result"..i,
         text = searchResults[i] and searchResults[i].name or ""
      }
   end
   -- click button
   if buttonToSelect then
      selectResult(buttonToSelect)
   end
end

dlg:entry{
   id = "query",
   focus = true,
   onchange = function()
      search()
   end
}

for i = 1, searchButtonCount do
   dlg:button{
      id = "result"..i,
      name = "meow",
      onclick = function()
         selectResult(i)
      end
   }
   dlg:newrow()
end

search() -- do empty search to load first queries

dlg:show()