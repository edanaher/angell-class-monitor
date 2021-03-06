#!/usr/bin/env python

import datetime
import os
import re
import sys
from collections import defaultdict
from string import Template
import urllib
import urllib.request

from email.mime.text import MIMEText
from smtplib import SMTP

import psycopg2
from docopt import docopt

usage = """Angell page generator
Usage: generate.py [-hd] -o=<outfile> -t=<templatefile> -r=<rawdir> [-m=<mailserver>]

Options:
  -h --help         show this screen
  -d                read from <rawdir> instead of pulling from source
  -o <outfile>      output html file
  -t <templatefile> output templated html file
  -r <rawdir>       directory to output saved files (or read if -d)
  -m <mailserver>   send e-mails through <mailserver>
"""

args = docopt(usage)
DEBUG=args['-d']
RAWDIR=args['-r']
OUTFILE=args['-o']
TEMPLATEFILE=args['-t']
MAILSERVER=args['-m']

if not os.path.isdir(RAWDIR):
  os.mkdir(RAWDIR)

def fetch(url):
  req = urllib.request.Request(url=url, headers = { "User-Agent": "script for angell.kdf.sh" })
  with urllib.request.urlopen(req) as resp:
    return resp.read()


def extractMatch(match, errString = "ERROR"):
  if match == None:
    return errString
  else:
    return match.group(0)


if DEBUG:
  with open(RAWDIR + "/urls", encoding="latin-1") as f:
    urls = f.read().splitlines()
else:
  page = fetch('https://www.mspca.org/animal_care/boston-dog-training/')
  all_urls = { re.search('https://secure2.convio.net[^"]*', str(l)).group(0) for l in page.splitlines() if(b"See Dates" in l) }
  urls = sorted(all_urls)
  with open(RAWDIR + "/urls", "w") as f:
    f.write("\n".join(urls))

days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
months = [ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" ]

def prefixIndex(needle, haystack):
  for i in range(0, len(haystack)):
    if haystack[i].startswith(needle):
      return i
  return -1

def checkDate(strDate):
  r = re.match("([A-Z][a-z]+)\s*([0-9]+)", strDate)
  if r == None:
    return None
  month = 1 + prefixIndex(r.group(1), months)
  if month == 0:
    return 99
  day = int(r.group(2))
  now = datetime.date.today()
  date = datetime.date(now.year, month, day)
  delta = date - now
  if delta > datetime.timedelta(6*30):
    date = datetime.date(now.year - 1, month, day)
    delta = date - now
  if delta < datetime.timedelta(-6*30):
    date = datetime.date(now.year + 1, month, day)
    delta = date - now

  if delta < datetime.timedelta(-7):
    return -2
  if delta < datetime.timedelta(0):
    return -1
  if delta == datetime.timedelta(0):
    return 0
  if delta > datetime.timedelta(7):
    return 2
  if delta > datetime.timedelta(0):
    return 1

def classify(session):
  startDiff = checkDate(session.startDay)
  endDiff = checkDate(session.endDay)
  if startDiff == None or endDiff == None:
    return 'class="unscheduled"'
  if startDiff == None and endDiff == None:
    return 'class="error"'
  if startDiff > 0:
    return 'class="future"'
  if startDiff == -1:
    return 'class="recent"'
  if endDiff < 0:
    return 'class="past"'
  if endDiff == 1:
    return 'class="almost-done"'
  return ''

class Class:
  def __init__(self, url):
    self.url = url
    self.sessions = []

class Session:
  prefix = ""

classes = {}
for u in urls:
  if DEBUG:
    with open(RAWDIR + "/" + re.sub("/", "_", u), encoding="latin-1") as f:
      lines = f.read()
  else:
    lines = str(fetch(u))
    with open(RAWDIR + "/" + re.sub("/", "_", u), "w", encoding="latin-1") as f:
      f.write(lines)
  title_line = re.search('product_image.*?alt="([^"]*)"', lines)
  if title_line == None:
    continue
  name = title_line.group(1)
  classes[name] = Class(u)
  for c in re.finditer('option value=[^>]*>([^<]*)<', lines):
    session = Session()
    desc = c.group(1)
    session.day = extractMatch(re.search("|".join(days), desc))
    dateRegex = "[A-Z][a-z]+\s*[0-9][0-9]?[a-z]*"
    session.period = extractMatch(re.search(dateRegex + "\s*-\s*" + dateRegex + "|[Nn]ot [Cc]urrently [Aa]vailable|TBD|See you [^)]*|rolling|[Cc]urrently [Uu]navailable", desc))
    session.startDay = extractMatch(re.search("^" + dateRegex, session.period))
    session.endDay = extractMatch(re.search(dateRegex + "$", session.period))
    timeRegex = "[0-9]+(:[0-9]+)?[\sAPM]*"
    session.timeString = extractMatch(re.search(timeRegex + "\s*-\s*" + timeRegex, desc), "Unknown")
    endTimeSp = extractMatch(re.search(timeRegex + "$", session.timeString), "NoEndTime")
    session.endTime = re.sub("^([0-9]*)([AP]M)", r"\1:00\2", re.sub("\s", "", endTimeSp))
    session.noClass = extractMatch(re.search("[Nn]o\s*[Cc]lass\s*[^)]*", desc), "")
    used = [session.day, session.timeString, session.period, session.noClass]
    remainder = re.split("|".join([s for s in used if s]), desc)
    if len(remainder[0]) > 2:
      session.prefix = re.sub(":$", "", remainder[0].rstrip())
    remainder = re.sub("|".join([session.day, session.timeString, session.period, session.prefix, session.noClass]), "", desc)
    session.remainders = [r.group(0) for r in re.finditer('\w\w\w[^)]*', remainder)]
    session.desc = desc
    classes[name].sessions.append(session)

def render_html(classes):
  classData = []
  for c in sorted(classes):
    classData.append('<h2><a href="' + classes[c].url + '">' + c + '</a></h2>')
    sessions = classes[c].sessions
    if len(sessions) == 0:
      continue
    classData.append('<table>')
    columnAppears = {}
    displayColumns = [ "prefix", "day", "timeString", "period", "noClass" ]
    for s in sessions:
      for i in displayColumns:
        if getattr(s, i):
          columnAppears[i] = True
    for s in sorted(sessions, key = lambda s: (s.prefix, days.index(s.day), s.timeString)):
      columns = [getattr(s, i) for i in displayColumns if i in columnAppears]
      classed = classify(s)
      if s.period == 'rolling':
        classed = ''
      watchString = '{* "<td id=\\"session-' + str(s.session_id) + '\\" class=\\"watch-cell\\">" .. toggle_watch_session(watches, ' + str(s.session_id) + ') .. "</td>" *}'
      classData.append('<tr ' + classed + '>' + "\n".join([ '<td>' + c + '</td>' for c in columns]) + watchString + '</tr>')
    classData.append('</table>')

  with open(os.path.dirname(os.path.abspath(__file__)) + "/template.html") as f:
    templateContents = f.read()
  template = Template(templateContents)
  now = list(os.popen('TZ=America/New_York date'))[0].rstrip()
  output = template.substitute(now=now, classes = "\n".join(classData))
  with open(OUTFILE, "w") as outfile:
    outfile.write(re.sub("\*{|}\*|{\*[^}]*\*}", "", output))
  with open(TEMPLATEFILE, "w") as outfile:
    outfile.write(re.sub("\*{[^}]*}\*", "", output, flags=re.DOTALL))

def write_sql(classes):
  conn = psycopg2.connect(dbname = "angell", user = "angell", password = "@PASSWORD");
  cur = conn.cursor()

  emails = defaultdict(list)
  for c in classes:
    cur.execute("""INSERT INTO classes(name, created, updated) VALUES(%s, 'now', 'now') ON CONFLICT(name) DO UPDATE SET updated='now' RETURNING class_id""", (c,))
    class_id = cur.fetchone()[0]
    print("inserting ", c, " to ", class_id)
    for s in classes[c].sessions:
      cur.execute("""INSERT INTO sessions(class_id, week_day, end_time, created, updated) VALUES (%s, %s, %s, 'now', 'now') ON CONFLICT (class_id, week_day, end_time) DO UPDATE SET updated='now' RETURNING session_id""", (class_id, s.day, s.endTime))
      s.session_id = cur.fetchone()[0]
      cur.execute("""SELECT period_id FROM periods WHERE session_id=%s AND start_day=%s""", (s.session_id, s.startDay))
      if cur.rowcount == 0:
        print("new period: ", c, s.day, s.timeString, s.startDay)
        if MAILSERVER:
          emails['test@angell.kdf.sh'].append((c, s))
          cur.execute("""SELECT email FROM emails JOIN emails_sessions USING (email_id) WHERE session_id = %s""", (s.session_id,))
          for email in cur:
            emails[email[0]].append((c, s))

      cur.execute("""INSERT INTO periods(session_id, start_day, created, updated) VALUES (%s, %s, 'now', 'now') ON CONFLICT (session_id, start_day) DO UPDATE SET updated='now'""", (s.session_id, s.startDay))

  cur.close()
  conn.commit()
  conn.close()


SINGLE_EMAIL_MESSAGE = """
Your class "$clas" at $time has been updated; the current session starts on $date

Go to $url to register

Visit $me to change or delete notifications
"""
SINGLE_EMAIL_TEMPLATE = Template(SINGLE_EMAIL_MESSAGE)

MULTI_EMAIL_MESSAGE = """
The following classes have been updated:

$classes

Visit $me to change or delete notifications
"""
MULTI_EMAIL_TEMPLATE = Template(MULTI_EMAIL_MESSAGE)

MULTI_CLASS_MESSAGE = """
"$clas" at $time: starting $date
Register at $url
"""

MULTI_CLASS_TEMPLATE = Template(MULTI_CLASS_MESSAGE)

def send_emails(classes):
  if MAILSERVER:
    with SMTP(MAILSERVER) as smtp:
      for email in emails:
        updates = emails[email]
        if len(updates) == 1:
          print(updates)
          values = {}
          values['clas'] = updates[0][0]
          values['time'] = updates[0][1].timeString
          values['date'] = updates[0][1].startDay
          values['url'] = classes[updates[0][0]].url
          values['me'] = 'http://angell.kdf.sh'
          msg = MIMEText(SINGLE_EMAIL_TEMPLATE.substitute(**values))
          msg['Subject'] = 'Updated Angell class time for ' + updates[0][0]
        else:
          print(updates)
          msgs = map(lambda u: MULTI_CLASS_TEMPLATE.substitute(clas=u[0], time=u[1].timeString, date=u[1].startDay, url=classes[u[0]].url), updates)
          values = {}
          values['classes'] = "\n".join(msgs)
          values['me'] = 'http://angell.kdf.sh'
          msg = MIMEText(MULTI_EMAIL_TEMPLATE.substitute(**values))
          msg['Subject'] = 'Updated Angell class time for multiple classes'
        msg['From'] = 'notifications@angell.kdf.sh'
        msg['To'] = email
        #smtp.set_debuglevel(1)
        smtp.send_message(msg)
      smtp.quit()

write_sql(classes)
render_html(classes)
send_emails(classes)
