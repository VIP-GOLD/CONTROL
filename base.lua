serpent = (loadfile "serpent.lua")()
tdcli = dofile('tdcli.lua')
redis = (loadfile "redis.lua")()
VIP-CONTROL_id = "VIP-CONTROL-ID"

function vardump(value)
  return serpent.block(value,{comment=false})
end

function reload()
  VIP-CONTROL = dofile("VIP-CONTROL.lua")
end

function dl_cb (arg, data)
end

reload()

function tdcli_update_callback(data)
  VIP-CONTROL.update(data, VIP-CONTROL_id)
  if data.message_ and data.message_.content_.text_ and data.message_.content_.text_ == "/reload" and data.message_.sender_user_id_ == tonumber(redis:get("VIP-CONTROL:" .. VIP-CONTROL_id ..":fullsudo")) then
    reload()
    tdcli.sendMessage(data.message_.chat_id_, 0, 1, "- تم اعادة التحميل ✅", 1, "md")
  elseif data.message_ and data.message_.content_.text_ and data.message_.content_.text_ == "/gitpull" and data.message_.sender_user_id_ == tonumber(redis:get("VIP-CONTROL:" .. VIP-CONTROL_id ..":fullsudo")) then
    io.popen("git fetch --all && git reset --hard origin/master && git pull origin master"):read("*all")
    reload()
    tdcli.sendMessage(data.message_.chat_id_, 0, 1, "- تم تحديث البوت واعادة التحميل ✅", 1, "md")
  end
end
