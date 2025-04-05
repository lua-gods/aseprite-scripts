local sprite = app.sprite
if not sprite then return print('No active sprite') end

local dlg = Dialog("repl")

local env = {}
for i, v in pairs(_G) do
   env[i] = v
end

function env.print(...)
   local tbl = table.pack(...)
   local output = {}
   for i = 1, tbl.n do
      if i ~= 1 then
      table.insert(output, '   ')
      end
      table.insert(output, tostring(tbl[i]))
   end
   print(table.concat(output))
end

local function runCode()
   local codeToRun = dlg.data.code --[[@as string]]

   print('> '..codeToRun)
   local func, err = load('return '..codeToRun, 'run', "t", env)
   if not func then
      func, err = load(codeToRun, 'run', "t", env)
   end
   if func then
      local runData = table.pack(pcall(func))
      if runData[1] then
         if runData.n >= 2 then
            env.print(table.unpack(runData, 2, runData.n))
         end
      else
         env.print(runData[2])
      end
   else
      env.print(err)
   end
end

dlg:label{
   text = "code:"
}

dlg:entry{
   id = "code",
   text = 'print("Hello World")'
}

dlg:button{
   text = "run",
   onclick = runCode
}

dlg:button{
   text = "show output",
   onclick = function()
      print(".")
   end
}

dlg:show({wait = false})