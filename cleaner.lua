redis = (loadfile "redis.lua")()
io.write("Enter or Set Bot ID:-")
local last = io.read()
io.popen('rm -rf ~/.telegram-cli/VIP-CONTROL-'..last..' VIP-CONTROL-'..last..'.lua VIP-CONTROL-'..last..'.sh VIP-CONTROL_'..last..'_logs.txt')
redis:del('VIP-CONTROL:'..last..':*')
print("Done!\nAll Data/Files Of gold Deleted\nVIP-CONTROL ID : "..last)
