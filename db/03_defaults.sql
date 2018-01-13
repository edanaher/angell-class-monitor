ALTER TABLE emails ALTER COLUMN status SET DEFAULT 'new'
                   ALTER COLUMN created SET DEFAULT NOW()
                   ALTER COLUMN updated SET DEFAULT NOW();

ALTER TABLE classes ALTER COLUMN created SET DEFAULT NOW()
                    ALTER COLUMN updated SET DEFAULT NOW();

ALTER TABLE emails_sessions ALTER COLUMN created SET DEFAULT NOW()
                            ALTER COLUMN updated SET DEFAULT NOW();

ALTER TABLE periods ALTER COLUMN created SET DEFAULT NOW()
                    ALTER COLUMN updated SET DEFAULT NOW();

ALTER TABLE sessions ALTER COLUMN created SET DEFAULT NOW()
                     ALTER COLUMN updated SET DEFAULT NOW();

ALTER TABLE tokens ALTER COLUMN created SET DEFAULT NOW()
                   ALTER COLUMN updated SET DEFAULT NOW();
