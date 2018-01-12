local pgmoon = require("pgmoon")
local pg = pgmoon.new {
  host = "127.0.0.1";
  port = "5432";
  database = "angell";
  user = "angell";
  password = ngx.var.angell_password or "angell";
}

string.random = function(len)
  local chars = {}
  for i = string.byte('A'), string.byte('Z') do
    chars[#chars + 1] = string.char(i)
  end
  for i = string.byte('a'), string.byte('z') do
    chars[#chars + 1] = string.char(i)
  end
  for i = string.byte('0'), string.byte('9') do
    chars[#chars + 1] = string.char(i)
  end

  local res = {}
  for i = 1, len do
    res[#res + 1] = chars[math.random(#chars)]
  end
  return table.concat(res)
end

function register_email(email)
  ngx.say("'sending' email to " .. email)
  local res, err = pg:query("INSERT INTO emails (email, status, created, updated) VALUES (" .. pg:escape_literal(email) .. ", 'new', 'now', 'now') ON CONFLICT (email) DO UPDATE SET updated='now' RETURNING email_id")
  if res == nil then ngx.say("SQL ERROR: " .. tostring(err)) end
  local id = res[1].email_id
  ngx.say("email id is " .. tostring(id))

  local res, err = pg:query("INSERT INTO tokens (email_id, value, status, created, updated) VALUES (" .. tostring(id) .. ", ".. pg:escape_literal(string.random(12)) .. ", 'new', 'now', 'now') RETURNING value")
  if res == nil then ngx.say("SQL ERROR: " .. tostring(err)) end
  ngx.say("token is " .. tostring(res[1].value))
end

function dispatch() 
  email = ngx.var.request_uri:match("/api/email/(.+)/register")
  if email then
    return register_email(email)
  end
  email, token = ngx.var.request_uri:match("/api/email/(.+)/verify/(.+)")
  if email then
    ngx.say("'verifying' email to " .. email .. " with " .. token)
    return
  end
end

assert(pg:connect())
local res = assert(pg:query("SELECT * FROM classes"))
ngx.say("hi there.  Classes are:")
for _, row in ipairs(res) do
  ngx.say(tostring(row.name))
end

dispatch()

pg:keepalive()
