local pgmoon = require("pgmoon")
local pg = pgmoon.new {
  host = "127.0.0.1";
  port = "5432";
  database = "angell";
  user = "angell";
  password = ngx.var.angell_password or "angell";
}


function dispatch() 
  email = ngx.var.request_uri:match("/api/email/register/(.+)")
  if email then
    ngx.say("'sending' email to " .. email)
    return
  end
  email, token = ngx.var.request_uri:match("/api/email/verify/(.+)/(.+)")
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
