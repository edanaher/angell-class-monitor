CREATE TABLE classes(
  class_id SERIAL PRIMARY KEY,
  name varchar UNIQUE NOT NULL,
  created timestamp NOT NULL,
  updated timestamp NOT NULL);

CREATE TABLE sessions(
  session_id SERIAL PRIMARY KEY,
  class_id integer NOT NULL,
  week_day varchar NOT NULL,
  end_time varchar NOT NULL,
  created timestamp NOT NULL,
  updated timestamp NOT NULL,
  UNIQUE (class_id, week_day, end_time)
);

CREATE TABLE periods(period_id SERIAL PRIMARY KEY,
  session_id integer NOT NULL,
  start_day varchar NOT NULL,
  created timestamp NOT NULL,
  updated timestamp NOT NULL,
  UNIQUE (session_id, start_day)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON classes TO angell;
GRANT SELECT, INSERT, UPDATE, DELETE ON sessions TO angell;
GRANT SELECT, INSERT, UPDATE, DELETE ON periods TO angell;
