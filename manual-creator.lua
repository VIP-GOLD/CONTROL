redis = (loadfile "redis.lua")()
io.write("Enter or set bot ID : ")
local last = io.read()
io.write("\nEnter or set Sudo ID : ")
local sudo=io.read()
local text,ok = io.open("base.lua",'r'):read('*a'):gsub("CONTROL%-ID",last)
io.open("CONTROL-"..last..".lua",'w'):write(text):close()
io.open("CONTROL-"..last..".sh",'w'):write("while true; do\n./telegram-cli-1222 -p CONTROL-"..last.." -s CONTROL-"..last..".lua\ndone"):close()
io.popen("chmod 777 CONTROL-"..last..".sh")
redis:set('gold:'..last..':fullsudo',sudo)
print("✔️ THANK YOU FOR INSTALL CONTROL BOT ✔️\n♛ Source Created By @amody7 On Telegram ♛\nDone!\nNew bot Control Created...\nID : "..last.."\nFull Sudo : "..sudo.."\nRun : ./CONTROL-"..last..".sh")
