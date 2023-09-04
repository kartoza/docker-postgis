-- Create a table
CREATE TABLE IF NOT EXISTS sweets
    (
        id SERIAL,
        name TEXT,
        price DECIMAL,
        CONSTRAINT sweets_pkey PRIMARY KEY (id)
    );

-- Inserts records into the table
INSERT INTO sweets (name, price) VALUES ('strawberry', 4.50), ('Coffee', 6.20), ('lollipop', 3.80);
