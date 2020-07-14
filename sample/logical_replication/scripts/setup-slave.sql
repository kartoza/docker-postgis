-- Create a table
CREATE TABLE sweets
    (
        id SERIAL,
        name TEXT,
        price DECIMAL,
        CONSTRAINT sweets_pkey PRIMARY KEY (id)
    );

-- Create a publication
CREATE SUBSCRIPTION logical_subscription
    CONNECTION 'host=pg-master port=5432 password=docker user=docker dbname=gis'
    PUBLICATION logical_replication;
