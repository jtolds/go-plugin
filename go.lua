VERSION = "1.1.1"

go_os = import("os")
go_filepath = import("filepath")
go_time = import("time")
go_strings = import("strings")
go_ioutil = import("io/ioutil")

if GetOption("goimports") == nil then
    AddOption("goimports", false)
end
if GetOption("gofmt") == nil then
    AddOption("gofmt", true)
end
if GetOption("goreturns") == nil then
    AddOption("goreturns", false)
end

MakeCommand("goimports", "go.goimports", 0)
MakeCommand("gofmt", "go.gofmt", 0)
MakeCommand("gorename", "go.gorename", 0)
MakeCommand("godef", "go.godef", 0)
MakeCommand("goreturns", "go.goreturns", 0)
MakeCommand("gorename", "go.gorenameCmd", 0)

function onViewOpen(view)
    if view.Buf:FileType() == "go" then
        SetLocalOption("tabstospaces", "off", view)
    end
end

function onSave(view)
    if CurView().Buf:FileType() == "go" then
        if GetOption("goreturns") then
            goreturns()
        elseif GetOption("goimports") then
            goimports()
        elseif GetOption("gofmt") then
            gofmt()
        end
    end
end

function gofmt()
    CurView():Save(false)
    local handle = io.popen("gofmt -w " .. CurView().Buf.Path)
    messenger:Message(handle:read("*a"))
    handle:close()
    CurView():ReOpen()
end

function gorename()
    local res, canceled = messenger:Prompt("Rename to:", "", 0)
    if not canceled then
        gorenameCmd(res)
        CurView():Save(false)
    end
end

function gorenameCmd(res)
    CurView():Save(false)
    local v = CurView()
    local c = v.Cursor
    local buf = v.Buf
    local loc = Loc(c.X, c.Y)
    local offset = ByteOffset(loc, buf)
    if #res > 0 then
        local cmd = "gorename --offset " .. CurView().Buf.Path .. ":#" .. tostring(offset) .. " --to " .. res
        JobStart(cmd, "", "go.renameStderr", "go.renameExit")
        messenger:Message("Renaming...")
    end
end

function renameStderr(err)
    messenger:Error(err)
end

function renameExit()
    CurView():ReOpen()
    messenger:Message("Done")
end

function goimports()
    CurView():Save(false)
    local handle = io.popen("goimports -w " .. CurView().Buf.Path)
    messenger:Message(handle:read("*a"))
    handle:close()
    CurView():ReOpen()
end

function tmpfile()
    local dir = go_os.TempDir()
    -- todo: would be better if micro exposed ioutil.TempFile or
    --       even crypto/rand or something
    local name = "godef-" .. go_time.Now():UnixNano()
    local joined = go_filepath.Join(dir, name)
    return joined
end

function godef()
    local file = tmpfile()
    local v = CurView()
    go_ioutil.WriteFile(file, v.Buf:SaveString(false), tonumber("600", 8))
    local c = v.Cursor
    local offset = ByteOffset(Loc(c.X, c.Y), v.Buf)
    local handle = io.popen("godef -f " .. file .. " -o " .. offset, "r")
    local resp = handle:read("*a")
    handle:close()
    go_os.Remove(file)
    local parts = go_strings.Split(resp, ":")
    if #parts < 3 then
        messenger:Message(resp)
        return
    end
    local dest = parts[1]
    for i = 2, #parts-2, 1 do
        dest = dest .. parts[i]
    end
    local pos = Loc(tonumber(parts[#parts])-1, tonumber(parts[#parts-1])-1)
    if dest == file then
        c:GotoLoc(pos)
        v:Relocate()
        return
    end
    HandleCommand("tab")
    v = CurView()
    v:Open(dest)
    v.Cursor:GotoLoc(pos)
    v:Relocate()
end

function goreturns()
    CurView():Save(false)
    local handle = io.popen("goreturns -w " .. CurView().Buf.Path)
    messenger:Message(handle:read("*a"))
    handle:close()
    CurView():ReOpen()
end

AddRuntimeFile("go", "help", "help/go-plugin.md")
BindKey("F6", "go.gorename")
BindKey("F8", "go.godef")
