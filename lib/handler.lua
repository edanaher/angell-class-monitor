local pgmoon = require("pgmoon")
local random = require("resty.random")
local pg = pgmoon.new {
  host = "127.0.0.1";
  port = "5432";
  database = "angell";
  user = "angell";
  password = ngx.var.angell_password or "angell";
}

function register_email(email)
  ngx.say("'sending' email to " .. email)
  local res, err = pg:query("INSERT INTO emails (email, status, created, updated) VALUES (" .. pg:escape_literal(email) .. ", 'new', 'now', 'now') ON CONFLICT (email) DO UPDATE SET updated='now' RETURNING email_id")
  if res == nil then return ngx.say("SQL ERROR: " .. tostring(err)) end
  local id = res[1].email_id
  ngx.say("email id is " .. tostring(id))

  local res, err = pg:query("INSERT INTO tokens (email_id, value, status, created, updated) VALUES (" .. tostring(id) .. ", ".. pg:escape_literal(random.token(12)) .. ", 'new', 'now', 'now') RETURNING value")
  if res == nil then ngx.say("SQL ERROR: " .. tostring(err)) end
  ngx.say("token is " .. tostring(res[1].value))
end

function verify_email(email, token)
  local res, err = pg:query("SELECT email_id FROM emails WHERE email = " .. pg:escape_literal(email))
  if res == nil then return ngx.say("SQL ERROR: " .. tostring(err)) end
  if #res == 0 then return ngx.say("No such e-mail registered: " .. email) end
  local id = res[1].email_id
  ngx.say("Found e-mail " .. tostring(id))
  ngx.say("SELECT COUNT(*) FROM tokens WHERE email_id = " .. pg:escape_literal(id) .. " AND value = " .. pg:escape_literal(token))
  local res, err = pg:query("SELECT COUNT(*) FROM tokens WHERE email_id = " .. pg:escape_literal(id) .. " AND value = " .. pg:escape_literal(token) .. " AND status = 'new'")
  if res == nil then return ngx.say("SQL ERROR: " .. tostring(err)) end
  if res[1].count == 0 then return ngx.say("Invalid token " .. token .. " for e-mail address " .. email) end

  local cookie = random.token(32)
  local res, err = pg:query("UPDATE tokens SET status = 'used', cookie = '" .. cookie  .. "', updated = 'now' WHERE email_id = " .. pg:escape_literal(id) .. " AND value = " .. pg:escape_literal(token) .. " AND status = 'new'")
  if res == nil then return ngx.say("SQL ERROR: " .. tostring(err)) end

  ngx.say("Verified e-mail: " .. email)
  ngx.say("Cookie is: " .. cookie)
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
end

assert(pg:connect())
local res = assert(pg:query("SELECT * FROM classes"))
ngx.say("hi there.  Classes are:")
for _, row in ipairs(res) do
  ngx.say(tostring(row.name))
end

dispatch()

pg:keepalive()
