redis = (loadfile "redis.lua")()
function getVIP-CONTROLid()
    local i, t, popen = 0, {}, io.popen
    local pfile = popen('ls')
	local last = 0
    for filename in pfile:lines() do
        if filename:match('VIP-CONTROL%-(%d+)%.lua') and tonumber(filename:match('VIP-CONTROL%-(%d+)%.lua')) >= last then
			last = tonumber(filename:match('VIP-CONTROL%-(%d+)%.lua')) + 1
			end		
    end
    return last
end
local last = getVIP-CONTROLid()
io.write("Auto Detected VIP-CONTROL ID : "..last)
io.write("\nEnter or set Sudo ID : ")
local sudo=io.read()
local text,ok = io.open("base.lua",'r'):read('*a'):gsub("VIP-CONTROL%-ID",last)
io.open("VIP-CONTROL-"..last..".lua",'w'):write(text):close()
io.open("VIP-CONTROL-"..last..".sh",'w'):write("while true; do\n$(dirname $0)/telegram-cli-1222 -p VIP-CONTROL-"..last.." -s VIP-CONTROL-"..last..".lua\ndone"):close()
io.popen("chmod 777 VIP-CONTROL-"..last..".sh")
redis:set('VIP-CONTROL:'..last..':fullsudo',sudo)
print("Done!\nNew bot Control Created...\nID : "..last.."\nFull Sudo : "..sudo.."\nRun : ./VIP-CONTROL-"..last..".sh")
