-- Create a table
CREATE TABLE IF NOT EXISTS sweets
    (
        id SERIAL,
        name TEXT,
        price DECIMAL,
        CONSTRAINT sweets_pkey PRIMARY KEY (id)
    );

CREATE TABLE IF NOT EXISTS public.block (
    id serial NOT NULL,
    geom public.geometry(Polygon,4326),
    fid bigint,
    tile_name character varying,
    location character varying
);

-- Add table to publication called logical_replication which is created by the scripts
ALTER PUBLICATION logical_replication ADD TABLE sweets;
ALTER PUBLICATION logical_replication ADD TABLE block;
-- Inserts records into the table
INSERT INTO sweets (name, price) VALUES ('strawberry', 4.50), ('Coffee', 6.20), ('lollipop', 3.80);
