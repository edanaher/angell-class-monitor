CREATE TABLE classes(class_id SERIAL PRIMARY KEY, name varchar UNIQUE NOT NULL);

CREATE TABLE sessions(session_id SERIAL PRIMARY KEY, class_id integer NOT NULL, week_day varchar NOT NULL, start_day varchar NOT NULL, end_time varchar NOT NULL);

GRANT SELECT, INSERT, UPDATE, DELETE ON classes TO angell;
GRANT SELECT, INSERT, UPDATE, DELETE ON sessions TO angell;
