local config = import("micro/config")
local shell = import("micro/shell")

function init()
    config.MakeCommand("run", run, config.NoComplete)
    config.TryBindKey("F5", "command:run", false)
end

function shellescape(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

function basename(path)
    return path:match("^.+/(.+)$") or path
end

function run(bp)
    local buf = bp.Buf
    buf:Save()
    local path = buf.Path
    local ft = buf.Settings["filetype"]
    local cmd = nil

    if ft == "python" then
        cmd = "python3 " .. shellescape(path)
    elseif ft == "shell" then
        cmd = "bash " .. shellescape(path)
    elseif ft == "c++" then
        local bin = "/tmp/run_" .. basename(path):gsub("%W", "_")
        cmd = "g++ -std=c++17 -Wall " .. shellescape(path) .. " -o " .. bin .. " && " .. bin
    elseif ft == "html" then
        cmd = "xdg-open " .. shellescape(path)
    else
        -- fallback: try as executable script (#!/usr/bin/...)
        cmd = "chmod +x " .. shellescape(path) .. " && " .. shellescape(path)
    end

    shell.RunInteractiveShell(cmd, true, false)
end

