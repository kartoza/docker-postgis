-- Create a table
CREATE TABLE sweets
    (
        id SERIAL,
        name TEXT,
        price DECIMAL,
        CONSTRAINT sweets_pkey PRIMARY KEY (id)
    );

-- Add table to publication called logical_replication which is created by the scripts
ALTER PUBLICATION logical_replication ADD TABLE sweets;
-- Inserts records into the table
INSERT INTO sweets (name, price) VALUES ('strawberry', 4.50), ('Coffee', 6.20), ('lollipop', 3.80);