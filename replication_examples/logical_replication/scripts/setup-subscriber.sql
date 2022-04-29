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
-- Create a publication
CREATE SUBSCRIPTION logical_subscription
    CONNECTION 'host=pg-publisher port=5432 password=docker user=docker dbname=gis'
    PUBLICATION logical_replication;
