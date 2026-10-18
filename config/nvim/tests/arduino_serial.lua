-- Exercises the real terminal lifecycle using cat, and captures upload arguments.
-- No hardware port or uploader is used.
-- nvim --headless '+lua dofile(vim.fn.stdpath("config") .. "/tests/arduino_serial.lua")'
local arduino = require "arduino"
local root = vim.fn.tempname() .. "/SerialLifecycle"
vim.fn.mkdir(root, "p")
root = vim.uv.fs_realpath(root)
local port = root .. "/mock-port"
vim.fn.writefile({}, port)
vim.fn.writefile({ "void setup() {}", "void loop() {}" }, root .. "/SerialLifecycle.ino")
vim.fn.writefile(
  { vim.json.encode { fqbn = "arduino:avr:uno", port = port, baud = 9600 } },
  root .. "/.nvim-arduino.json"
)
vim.cmd.cd(vim.fn.fnameescape(root))
local jobstart, system = vim.fn.jobstart, vim.system
local jobs, commands = {}, {}
vim.fn.jobstart = function(argv, opts)
  if argv[1] == "arduino-cli" and vim.tbl_contains(argv, "monitor") then
    assert(vim.tbl_contains(argv, "baudrate=9600"), "Monitor lost baud")
    local job = jobstart({ "cat" }, opts)
    jobs[#jobs + 1] = job
    return job
  end
  return jobstart(argv, opts)
end
vim.system = function(argv, opts, cb)
  if argv[1] == "arduino-cli" and vim.tbl_contains(argv, "compile") then
    assert(vim.fn.jobwait({ jobs[#jobs] }, 0)[1] ~= -1, "Upload started while monitor still owns the port")
    commands[#commands + 1] = argv
    vim.schedule(function() cb { code = 0, signal = 0 } end)
    return { kill = function() end }
  end
  return system(argv, opts, cb)
end
local ok, err = xpcall(function()
  vim.o.columns, vim.o.lines = 160, 48
  arduino.serial()
  assert(#jobs == 1 and jobs[1] > 0, "Mock terminal did not open")
  local windows = #vim.api.nvim_list_wins()
  arduino.serial()
  assert(#jobs == 1 and #vim.api.nvim_list_wins() == windows, "Serial monitor duplicated")
  arduino.build(true)
  assert(#commands == 1, "No upload command")
  assert(
    vim.tbl_contains(commands[1], "compile") and vim.tbl_contains(commands[1], "--upload"),
    "Upload omitted compile"
  )
  assert(vim.tbl_contains(commands[1], "--verify"), "Upload omitted verification")
  assert(commands[1][#commands[1]] == root, "Upload lost sketch root")
  assert(vim.tbl_contains(commands[1], port), "Upload lost selected port")
  assert(vim.wait(2000, function() return not arduino.status():find("Build + upload…", 1, true) end))
  arduino.serial()
  assert(#jobs == 2, "Serial did not reopen")
  assert(#vim.api.nvim_list_wins() == windows, "Closed serial window was not reused")
  assert(arduino.close_serial(), "Serial did not close")
  assert(vim.fn.jobwait({ jobs[2] }, 0)[1] ~= -1, "Serial child remains running")
  print "SERIAL_REUSE_RELEASE_AND_UPLOAD_DISPATCH_PASS"
end, debug.traceback)
vim.fn.jobstart, vim.system = jobstart, system
for _, job in ipairs(jobs) do
  if job > 0 and vim.fn.jobwait({ job }, 0)[1] == -1 then vim.fn.jobstop(job) end
end
if ok then
  vim.cmd "qa!"
else
  io.stderr:write(err .. "\n")
  vim.cmd "cquit 1"
end
