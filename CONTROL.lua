JSON = loadfile("dkjson.lua")()
URL = require("socket.url")
ltn12 = require("ltn12")
http = require("socket.http")
http.TIMEOUT = 10
undertesting = 1
local is_sudo
function is_sudo(msg)
  local sudoers = {}
  table.insert(sudoers, tonumber(redis:get("CONTROL:" .. CONTROL_id .. ":fullsudo")))
  local issudo = false
  for k, v in pairs(sudoers) do
    if msg.sender_user_id_ == v then
      issudo = true
    end
  end
  if redis:sismember("CONTROL:" .. CONTROL_id .. ":sudoers", msg.sender_user_id_) then
    issudo = true
  end
  return issudo
end
local is_full_sudo
function is_full_sudo(msg)
  local sudoers = {}
  table.insert(sudoers, tonumber(redis:get("CONTROL:" .. CONTROL_id .. ":fullsudo")))
  local issudo = false
  for k, v in pairs(sudoers) do
    if msg.sender_user_id_ == v then
      issudo = true
    end
  end
  return issudo
end
local save_log
function save_log(text)
  text = "[" .. os.date("%d-%b-%Y %X") .. "] Log : " .. text .. "\n"
  file = io.open("CONTROL_" .. CONTROL_id .. "_logs.txt", "w")
  file:write(text)
  file:close()
  return true
end
local writefile
function writefile(filename, input)
  local file = io.open(filename, "w")
  file:write(input)
  file:flush()
  file:close()
  return true
end
local check_link
function check_link(extra, result)
  if result.is_group_ or result.is_supergroup_channel_ then
    if not redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":notjoinlinks") then
      tdcli.importChatInviteLink(extra.link)
    end
    if not redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":notsavelinks") then
      redis:sadd("CONTROL:" .. tostring(CONTROL_id) .. ":savedlinks", extra.link)
    end
    return
  end
end
local chat_type
function chat_type(id)
  id = tostring(id)
  if id:match("-") then
    if id:match("-100") then
      return "channel"
    else
      return "group"
    end
  else
    return "private"
  end
end
local contact_list
function contact_list(extra, result)
  local count = result.total_count_
  local text = "جهات اتصال البوت : \n"
  for i = 0, tonumber(count) - 1 do
    local user = result.users_[i]
    local firstname = user.first_name_ or ""
    local lastname = user.last_name_ or ""
    local fullname = firstname .. " " .. lastname
    text = tostring(text) .. tostring(i) .. ". " .. tostring(fullname) .. " [" .. tostring(user.id_) .. "] = " .. tostring(user.phone_number_) .. "\n"
  end
  writefile("tabchi_" .. tostring(tabchi_id) .. "_contacts.txt", text)
  tdcli.send_file(extra.chat_id_, "Document", "tabchi_" .. tostring(tabchi_id) .. "_contacts.txt", "Tabchi " .. tostring(tabchi_id) .. " Contacts!")
  return io.popen("rm -rf tabchi_" .. tostring(tabchi_id) .. "_contacts.txt"):read("*all")
end

local our_id
function our_id(extra, result)
  if result then
    redis:set("CONTROL:" .. tostring(CONTROL_id) .. ":botinfo", JSON.encode(result))
  end
end
local process_links
function process_links(text)
  if text:match("https://t.me/joinchat/%S+") or text:match("https://telegram.me/joinchat/%S+") or text:match("https://t.me/joinchat/S+") then
    text = text:gsub("t.me", "telegram.me")
    local matches = {
      text:match("(https://telegram.me/joinchat/%S+)")
    }
    for i, v in pairs(matches) do
      tdcli_function({
        ID = "CheckChatInviteLink",
        invite_link_ = v
      }, check_link, {link = v})
    end
  end
end
local add
function add(id)
  chat_type_ = chat_type(id)
  if not redis:sismember("CONTROL:" .. tostring(CONTROL_id) .. ":all", id) then
    if chat_type_ == "private" then
      redis:sadd("CONTROL:" .. tostring(CONTROL_id) .. ":pvis", id)
      redis:sadd("CONTROL:" .. tostring(CONTROL_id) .. ":all", id)
    elseif chat_type_ == "group" then
      redis:sadd("CONTROL:" .. tostring(CONTROL_id) .. ":groups", id)
      redis:sadd("CONTROL:" .. tostring(CONTROL_id) .. ":all", id)
    elseif chat_type_ == "channel" then
      redis:sadd("CONTROL:" .. tostring(CONTROL_id) .. ":channels", id)
      redis:sadd("CONTROL:" .. tostring(CONTROL_id) .. ":all", id)
    end
  end
  return true
end
local rem
function rem(id)
  if redis:sismember("CONTROL:" .. tostring(CONTROL_id) .. ":all", id) then
    if msg.chat_type_ == "private" then
      redis:srem("CONTROL:" .. tostring(CONTROL_id) .. ":pvis", id)
      redis:srem("CONTROL:" .. tostring(CONTROL_id) .. ":all", id)
    elseif msg.chat_type_ == "group" then
      redis:srem("CONTROL:" .. tostring(CONTROL_id) .. ":groups", id)
      redis:srem("CONTROL:" .. tostring(CONTROL_id) .. ":all", id)
    elseif msg.chat_type_ == "channel" then
      redis:srem("CONTROL:" .. tostring(CONTROL_id) .. ":channels", id)
      redis:srem("CONTROL:" .. tostring(CONTROL_id) .. ":all", id)
    end
  end
  return true
end
local process_updates
function process_updates()
  if not redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":gotupdated") then
    local info = redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":botinfo")
    if info then
      botinfo = JSON.decode(info)
    else
      tdcli_function({ID = "GetMe"}, our_id, nil)
      botinfo = JSON.decode(info)
    end
  end
end
local process
function process(msg)
  local text_ = msg.content_.text_
  process_updates()
  if is_sudo(msg) then
    if is_full_sudo(msg) then
      if text_:match("^[!/#](addsudo) (%d+)") then
        local matches = {
          text_:match("^[!/#](addsudo) (%d+)")
        }
        if #matches == 2 then
          redis:sadd("CONTROL:" .. tostring(CONTROL_id) .. ":sudoers", tonumber(matches[2]))
          save_log("User " .. msg.sender_user_id_ .. ", Added " .. matches[2] .. " As Sudo")
          return tostring(matches[2]) .. " صاحب هذا الايدي تم اضافته الى قائمة مطورين البوت ✅"
        end
elseif text_:match("^الاوامر") and is_sudo(msg) then
local text1 = [[
  اهلا صديقي جميع الاوامر تعمل ب (/#!)
━━━━━━━━━━━━━━━━━
/send <userid> <text>
- لارسال رسالة الى صاحب الايدي ، ⚜️'
━━━━━━━━━━━━━━━━━      
/bc <text>
- لعمل اذاعه ملاحظة هذه الخاصية تشمل جميع المحادثات (الخاص - مجموعات - قنوات - بوتات) ، ☯️'
━━━━━━━━━━━━━━━━━
/fwd <all/users/gps/sgps> (on reply)
- لعمل توجيه لرسالة على الخاص او المجموعات ، ⚜️'
━━━━━━━━━━━━━━━━━
/addcontacts <on/off>
- عندما ترسل قناة او احد الاشخاص جهة اتصال الى خاص البوت او في مجموعة سيتم حفظ الجهة تلقائيا، ⚡️'
━━━━━━━━━━━━━━━━━
/autochat <on/off>
- لتفعيل المحادثة التلقائية ، 💭'
━━━━━━━━━━━━━━━━━
/joinlinks <on/off>
- عندما ترسل قناة او احد الاشخاص رابط الى البوت سيتم الدخول الى الرابط تلقائيا والانضمام ، 🔻'
طريقة الاستخدام (فقط ارسل الرابط الى البوت- ولكن يجب ان يكون بصيغة -telegram.me- وليس t.me)
━━━━━━━━━━━━━━━━━
/savelinks <on/off>
- عندما ترسل قناة او احد الاشخاص رابط الى البوت سيتم حفظ الرابط في ملف في السيرفر ، ⚡️'
━━━━━━━━━━━━━━━━━
/block <userid>
- لحظر الحساب صاحب الايدي ، 📵'
━━━━━━━━━━━━━━━━━
/addedmsg <on/off>
- تفعيل وتعطيل ميزة الرد على الجهة عند الاضافة
عندما شخص يرسل الجهة والبوت يقوم بحفظها يقوم بأرسال له رسالة مثلا:- تم دز نقطة خاص
يجب تحديد الرسال بأمر
/setaddedmsg والرسالة
━━━━━━━━━━━━━━━━━
/unblock <userid>
- لالغا حظر الحساب صاحب الايدي ، 📵'
━━━━━━━━━━━━━━━━━
/addmembers
-  لاضافة جهات الاتصال والاشخاص المتواصلين مع البوت والبوتات الى المجموعة  ، 🚸'
━━━━━━━━━━━━━━━━━
/addsudo <userid>
- لاضافة مطور من البوت من خلال الايدي ،🚱'
━━━━━━━━━━━━━━━━━
/remsudo <userid>
- لازالة مطور من البوت من خلال الايدي ،🚱'
━━━━━━━━━━━━━━━━━
/sudolist
- لعرض قائمة مطورين البوت، ⚡️'
━━━━━━━━━━━━━━━━━
/panel
- لاظهار معلومات الحساب كـ (عدد الاشخاص الذي تم التواصل معهم- وعدد المجموعات العادية - وعدد المجموعات الخارقة - وعدد الروابط التي تم حفظها - وعدد الجهات التي تم حفظها ، 🚸'
━━━━━━━━━━━━━━━━━
/setname 'firstname' 'lastname'
- لالغا حظر الحساب صاحب الايدي ، 📵'
━━━━━━━━━━━━━━━━━
/addedcontact <on/off>
- عندما شخص يرسل جهة البوت سيرسل له جهته ايضا
━━━━━━━━━━━━━━━━━
/addsudo <userid>
- لاضافة مطور من البوت من خلال الايدي ،🚱'
طريقة الاستخدام (/addsudo - ايدي الحساب)
━━━━━━━━━━━━━━━━━
/remsudo <userid>
- لازالة مطور من البوت من خلال الايدي ،🚱'
طريقة الاستخدام (/remsudo - ايدي الحساب)
 ━━━━━━━━━━━━━━━━━
/sudolist
- لعرض قائمة مطورين البوت، ⚡️'
 ━━━━━━━━━━━━━━━━━
/reload
- لتحديث البوت وحل المشاكل  ، ♻️'
━━━━━━━━━━━━━━━━━
/gitpull
- تحديث ملفات السيرفر ،📟'
 ━━━━━━━━━━━━━━━━━
- المطور ،♥️' :- @amody7
- قناة البوت ،🥀' :- @zhrf7]]
    return tdcli.sendMessage(msg.chat_id_, 0, 1, text1, 1, "")
      elseif text_:match("^[!/#](remsudo) (%d+)") then
        local matches = {
          text_:match("^[!/#](remsudo) (%d+)")
        }
        if #matches == 2 then
          redis:srem("CONTROL:" .. tostring(CONTROL_id) .. ":sudoers", tonumber(matches[2]))
          save_log("User " .. msg.sender_user_id_ .. ", Removed " .. matches[2] .. " From Sudoers")
          return tostring(matches[2]) .. " صاحب هذا الايدي تم ازالته من قائمة مطورين البوت ✅"
        end
      elseif text_:match("^[!/#]sudolist$") then
        local sudoers = redis:smembers("CONTROL:" .. tostring(CONTROL_id) .. ":sudoers")
        local text = " قائمة مطورين البوت ، 🚸\n"
        for i, v in pairs(sudoers) do
          text = tostring(text) .. tostring(i) .. ". " .. tostring(v)
        end
        save_log("User " .. msg.sender_user_id_ .. ", Requested Sudo List")
        return text
      elseif text_:match("^[!/#](sendlogs)$") then
        tdcli.send_file(msg.chat_id_, "Document", "CONTROL_" .. tostring(CONTROL_id) .. "_logs.txt", "CONTROL " .. tostring(CONTROL_id) .. " Logs!")
        save_log("User " .. msg.sender_user_id_ .. ", Requested Logs")
      elseif text_:match("^[!/#](setname) '(.*)' '(.*)'$") then
        local matches = {
          text_:match("^[!/#](setname) '(.*)' '(.*)'$")
        }
        if #matches == 3 then
          tdcli.changeName(matches[2], matches[3])
          save_log("User " .. msg.sender_user_id_ .. ", Changed Name To " .. matches[2] .. " " .. matches[3])
          return "♥️ ¦ اهلا صديقي\n☑️  ¦  تم تغيير اسم البوت الى  ، 🖤:- " .. matches[2] .. " " .. matches[3]
        end
      elseif text_:match("^[!/#](setusername) (.*)$") then
        local matches = {
          text_:match("^[!/#](setusername) (.*)$")
        }
        if #matches == 2 then
          tdcli.changeUsername(matches[2])
          save_log("User " .. msg.sender_user_id_ .. ", Changed Username To " .. matches[2])
          return "♥️ ¦ اهلا صديقي\n☑️  ¦  تم تغيير معرف البوت الى  ، 🖤:- @" .. matches[2]
        end
      elseif text_:match("^[!/#](delusername)$") then
        tdcli.changeUsername()
        save_log("User " .. msg.sender_user_id_ .. ", Deleted Username")
        return "- تم حذف معرف البوت ، 🔖'"
      else
        local matches = {
          text_:match("^[$](.*)")
        }
        if text_:match("^[$](.*)") and #matches == 1 then
          save_log("User " .. msg.sender_user_id_ .. ", Used Terminal Command")
          return io.popen(matches[1]):read("*all")
        end
      end
    end
    if text_:match("^[!/#](send
