local pgmoon = require("pgmoon")
local random = require("resty.random")
local ck = require("resty.cookie")
local template = require("resty.template")

local pg = pgmoon.new {
  host = "127.0.0.1";
  port = "5432";
  database = "angell";
  user = "angell";
  password = ngx.var.angell_password or "angell";
}

function register_email(email)
  local res, err = pg:query("INSERT INTO emails (email, status, created, updated) VALUES (" .. pg:escape_literal(email) .. ", 'new', 'now', 'now') ON CONFLICT (email) DO UPDATE SET updated='now' RETURNING email_id")
  if res == nil then return ngx.say("SQL ERROR: " .. tostring(err)) end
  local id = res[1].email_id

  local res, err = pg:query("INSERT INTO tokens (email_id, value, status, created, updated) VALUES (" .. tostring(id) .. ", ".. pg:escape_literal(random.token(12)) .. ", 'new', 'now', 'now') RETURNING value")
  if res == nil then ngx.say("SQL ERROR: " .. tostring(err)) end
  ngx.log(ngx.ERR, "token for " .. email .. " is " .. tostring(res[1].value))
  ngx.print("OK");
end

function verify_email(email, token)
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
    httponly = true
  }
  if not ok then return ngx.print("Cookie error: ", err) end
  local ok, err = c:set {
    key = "email", value = email, path = "/",
    httponly = true
  }
  if not ok then return ngx.print("Cookie error: ", err) end
  ngx.print("OK")
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
    local c = ck:new()
    if not c then return ngx.say("Cookie error: ", err) end
    local email = c:get("email")
    local token = c:get("token")
    if email and token and email ~= "" then
      -- TODO: Check token
      ngx.header.content_type = 'text/html';
      return ngx.say(template.render("index.html", { userinfo = "Logged in as " .. email .. "&nbsp;&nbsp;<button onclick=\"logout()\">logout</button><hr />" }))
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
