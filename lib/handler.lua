local pgmoon = require("pgmoon")
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
  if res == nil then ngx.say("SQL ERROR: " .. tostring(err)) end
  local id = res[1].email_id
  ngx.say("email id is " .. tostring(id))
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
