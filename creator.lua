redis = (loadfile "redis.lua")()
function getCONTROLid()
    local i, t, popen = 0, {}, io.popen
    local pfile = popen('ls')
	local last = 0
    for filename in pfile:lines() do
        if filename:match('CONTROL%-(%d+)%.lua') and tonumber(filename:match('CONTROL%-(%d+)%.lua')) >= last then
			last = tonumber(filename:match('CONTROL%-(%d+)%.lua')) + 1
			end		
    end
    return last
end
local last = getCONTROLid()
io.write("Auto Detected CONTROL ID : "..last)
io.write("\nEnter or set Sudo ID : ")
local sudo=io.read()
local text,ok = io.open("base.lua",'r'):read('*a'):gsub("CONTROL%-ID",last)
io.open("CONTROL-"..last..".lua",'w'):write(text):close()
io.open("CONTROL-"..last..".sh",'w'):write("while true; do\n$(dirname $0)/telegram-cli-1222 -p CONTROL-"..last.." -s CONTROL-"..last..".lua\ndone"):close()
io.popen("chmod 777 CONTROL-"..last..".sh")
redis:set('CONTROL:'..last..':fullsudo',sudo)
print("Done!\nNew bot Control Created...\nID : "..last.."\nFull Sudo : "..sudo.."\nRun : ./CONTROL-"..last..".sh")
