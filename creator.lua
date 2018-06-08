redis = (loadfile "redis.lua")()
function getgoldid()
    local i, t, popen = 0, {}, io.popen
    local pfile = popen('ls')
	local last = 0
    for filename in pfile:lines() do
        if filename:match('gold%-(%d+)%.lua') and tonumber(filename:match('gold%-(%d+)%.lua')) >= last then
			last = tonumber(filename:match('gold%-(%d+)%.lua')) + 1
			end		
    end
    return last
end
local last = getgoldid()
io.write("Auto Detected gold ID : "..last)
io.write("\nEnter or set Sudo ID : ")
local sudo=io.read()
local text,ok = io.open("base.lua",'r'):read('*a'):gsub("gold%-ID",last)
io.open("gold-"..last..".lua",'w'):write(text):close()
io.open("gold-"..last..".sh",'w'):write("while true; do\n$(dirname $0)/telegram-cli-1222 -p gold-"..last.." -s gold-"..last..".lua\ndone"):close()
io.popen("chmod 777 gold-"..last..".sh")
redis:set('gold:'..last..':fullsudo',sudo)
print("Done!\nNew bot Created...\nID : "..last.."\nFull Sudo : "..sudo.."\nRun : ./gold-"..last..".sh")
