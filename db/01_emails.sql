CREATE TABLE emails(
  email_id SERIAL PRIMARY KEY,
  email varchar UNIQUE NOT NULL,
  created timestamp NOT NULL,
  updated timestamp NOT NULL);

CREATE TABLE emails_sessions(
  email_id integer NOT NULL,
  session_id integer NOT NULL,
  created timestamp NOT NULL,
  updated timestamp NOT NULL,
  UNIQUE (email_id, session_id));
