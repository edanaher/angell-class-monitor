local pgmoon = require("pgmoon")
local random = require("resty.random")
local ck = require("resty.cookie")
local template = require("resty.template")
local mail = require("resty.mail")

local pg = pgmoon.new {
  host = "127.0.0.1";
  port = "5432";
  database = "angell";
  user = "angell";
  password = ngx.var.angell_password or "angell";
}

template.caching(false)

EMAIL_TEMPLATE =
[[To sign into angell.kdf.sh to manage your subscriptions, either enter the
token below or visit the link.  This will sign you in indefinetely on that
device.

{* verify_link *}
Token: {{ token }}]]

function register_email(email)
  local res, err = pg:query("INSERT INTO emails (email, status, created, updated) VALUES (" .. pg:escape_literal(email) .. ", 'new', 'now', 'now') ON CONFLICT (email) DO UPDATE SET updated='now' RETURNING email_id")
  if res == nil then return ngx.say("SQL ERROR: " .. tostring(err)) end
  local id = res[1].email_id

  local res, err = pg:query("INSERT INTO tokens (email_id, value, status, created, updated) VALUES (" .. tostring(id) .. ", ".. pg:escape_literal(random.token(6)) .. ", 'new', 'now', 'now') RETURNING value")
  if res == nil then ngx.say("SQL ERROR: " .. tostring(err)) end
  local token = res[1].value
  ngx.log(ngx.ERR, "token for " .. email .. " is " .. tostring(token))

  if ngx.var.mail_host then
    local mailer, err = mail.new {
      host = ngx.var.mail_host,
      port = ngx.var.mail_port or 25
    }
    if err then return ngx.say("Error setting up e-mail: " .. err) end
    local t = template.new(EMAIL_TEMPLATE)
    t.token = token
    t.verify_link = "http://" .. ngx.var.host .. (ngx.var.server_port == "80" and "" or ":" .. ngx.var.server_port) .. "/api/email/" .. email .. "/verifyemail/" .. token
    local ok, err = mailer:send {
      from = "registration@angell.kdf.sh";
      to = { email };
      subject = "Registration for angell.kdf.sh";
      text = tostring(t)
    }
    if not ok then return ngx.say("Error sending e-mail: " .. err) end
  end

  ngx.print("OK");
end

function verify_email(email, token, redirect)
  local res, err = pg:query("SELECT email_id FROM emails WHERE email = " .. pg:escape_literal(email))
  if res == nil then return ngx.print("SQL ERROR: " .. tostring(err)) end
  if #res == 0 then return ngx.print("No such e-mail registered: " .. email) end
  local id = res[1].email_id
  local res, err = pg:query("SELECT COUNT(*) FROM tokens WHERE email_id = " .. pg:escape_literal(id) .. " AND value = " .. pg:escape_literal(token) .. " AND status = 'new'")
  if res == nil then return ngx.print("SQL ERROR: " .. tostring(err)) end
  if res[1].count == 0 then return ngx.print("Invalid token " .. token .. " for e-mail address " .. email) end

  local cookie = random.token(32)
  local res, err = pg:query("UPDATE tokens SET status = 'used', cookie = '" .. cookie  .. "', updated = 'now' WHERE email_id = " .. pg:escape_literal(id) .. " AND value = " .. pg:escape_literal(token) .. " AND status = 'new'")
  if res == nil then return ngx.print("SQL ERROR: " .. tostring(err)) end


  local c = ck:new()
  if not c then return ngx.print("Cookie error: ", err) end
  --if not cookie then return ngx.log(ngx.ERR, err) end
  local ok, err = c:set {
    key = "token", value = cookie, path = "/",
    httponly = true, max_age = 2^31 - 1
  }
  if not ok then return ngx.print("Cookie error: ", err) end
  local ok, err = c:set {
    key = "email", value = email, path = "/",
    httponly = true, max_age = 2^31 - 1
  }
  if not ok then return ngx.print("Cookie error: ", err) end
  if redirect then
    ngx.redirect("/")
  else
    ngx.print("OK")
  end
end

function verify_cookie(optional)
  local c = ck:new()
  if not c and optional then return nil end
  if not c then return ngx.say("Cookie error: " .. err) end
  local email, err = c:get "email"
  if err and optional then return nil end
  if err then return ngx.say("Cookie error: " .. err) end
  local token, err = c:get "token"
  if err and optional then return nil end
  if err then return ngx.say("Cookie error: " .. err) end

  local res, err = pg:query("SELECT COUNT(*) FROM tokens JOIN emails USING (email_id) WHERE email=" .. pg:escape_literal(email) .. " AND cookie=" .. pg:escape_literal(token) )
  if not res then return ngx.say("SQL error: " .. err) end
  if res[1].count == 0 and optional then return nil end
  if res[1].count == 0 then ngx.say("Invalid session") end
  return email
end

function watch_session(session)
  local email = verify_cookie()
  if not email then return ngx.say("Invalid cookie; not signed in or expired") end

  local res, err = pg:query("SELECT email_id FROM emails WHERE email=" .. pg:escape_literal(email))
  if not res then return ngx.say("SQL error: " .. err) end
  if #res ~= 1 then ngx.say("No such email: " .. email) end
  email_id = res[1].email_id

  local res, err = pg:query("SELECT COUNT(*) FROM sessions WHERE session_id=" .. pg:escape_literal(tonumber(session)))
  if not res then return ngx.say("SQL error: " .. err) end
  if res.count == 0 then return ngx.say("No such session: " .. session) end

  local res, err = pg:query("INSERT INTO emails_sessions (email_id, session_id, created, updated) VALUES (" .. pg:escape_literal(email_id) .. ", " .. pg:escape_literal(tonumber(session)) .. ", 'now', 'now')")
  if not res then return ngx.say("SQL error: " .. err) end

  ngx.say(toggle_watch_session({ [session] = true}, session))
end

function unwatch_session(session)
  local email = verify_cookie()
  if not email then return ngx.say("Invalid cookie; not signed in or expired") end

  local res, err = pg:query("SELECT email_id FROM emails WHERE email=" .. pg:escape_literal(email))
  if not res then return ngx.say("SQL error: " .. err) end
  if #res ~= 1 then ngx.say("No such email: " .. email) end
  email_id = res[1].email_id

  local res, err = pg:query("SELECT COUNT(*) FROM sessions WHERE session_id=" .. pg:escape_literal(tonumber(session)))
  if not res then return ngx.say("SQL error: " .. err) end
  if res.count == 0 then return ngx.say("No such session: " .. session) end

  local res, err = pg:query("DELETE FROM emails_sessions WHERE email_id = " .. pg:escape_literal(email_id) .. " AND session_id = " .. pg:escape_literal(tonumber(session)))
  if not res then return ngx.say("SQL error: " .. err) end

  ngx.say(toggle_watch_session({}, session))
end

function watches_for_email(email)
  local res, err = pg:query("SELECT session_id FROM emails_sessions JOIN emails USING (email_id) WHERE email = " .. pg:escape_literal(email))
  if res == nil then ngx.say("SQL ERROR: " .. tostring(err)) return {} end
  watches = {}
  for _, row in ipairs(res) do
    watches[row.session_id] = true
  end
  return watches
end

function toggle_watch_session(watches, session_id)
  local prefix = '<button onclick="'
  local callback = ""
  local infix = '">'
  local text = ""
  local suffix = '</button>'
  if watches[session_id] then
    callback = 'unwatch_session(' .. tostring(session_id) .. ')'
    text = "stop watching"
  else
    callback = 'watch_session(' .. tostring(session_id) .. ')'
    text = "watch"
  end
  return prefix .. callback .. infix .. text .. suffix
end

function dispatch() 
  email = ngx.var.request_uri:match("/api/email/(.+)/register")
  if email then
    return register_email(email)
  end
  email, token = ngx.var.request_uri:match("/api/email/(.+)/verify/(.+)")
  if email and token then
    return verify_email(email, token)
  end
  email, token = ngx.var.request_uri:match("/api/email/(.+)/verifyemail/(.+)")
  if email and token then
    return verify_email(email, token, true)
  end
  session = ngx.var.request_uri:match("/api/watch/(.+)")
  if session then
    return watch_session(session)
  end
  session = ngx.var.request_uri:match("/api/unwatch/(.+)")
  if session then
    return unwatch_session(session)
  end
  if(ngx.var.request_uri:match("/api/logout")) then
    local c = ck:new()
    if not c then return ngx.say("Cookie error: ", err) end
    --if not cookie then return ngx.log(ngx.ERR, err) end
    local ok, err = c:set {
      key = "email", value = "", path = "/",
      httponly = true
    }
    if not ok then return ngx.say("Cookie error: ", err) end
    local ok, err = c:set {
      key = "token", value = "", path = "/",
      httponly = true
    }
    if not ok then return ngx.say("Cookie error: ", err) end
    return ngx.say("OK")
  end
  if ngx.var.request_uri == "/" then
    local email = verify_cookie(true)
    if email and email ~= "" then
      ngx.header.content_type = 'text/html';
      return template.render("index.html", {
        watches = watches_for_email(email);
        email = email;
      })
    end
  end
  return ngx.exec("/_static" .. ngx.var.request_uri)
end

assert(pg:connect())
local res = assert(pg:query("SELECT * FROM classes"))
--[[ngx.say("hi there.  Classes are:")
for _, row in ipairs(res) do
  ngx.say(tostring(row.name))
end]]

dispatch()

pg:keepalive()
