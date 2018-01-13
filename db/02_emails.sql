CREATE TYPE email_status AS ENUM ('new', 'active', 'inactive');
CREATE TYPE token_status AS ENUM ('new', 'used', 'expired');

ALTER TABLE emails ADD COLUMN status email_status DEFAULT 'new' NOT NULL;

CREATE TABLE tokens(
  token_id SERIAL PRIMARY KEY,
  email_id integer NOT NULL,
  value varchar(12) NOT NULL,
  status token_status NOT NULL,
  created timestamp NOT NULL,
  updated timestamp NOT NULL
  );
