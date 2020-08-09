import unittest
from utils.utils import DBConnection


class TestReplicationPublisher(unittest.TestCase):

    def setUp(self):
        self.db = DBConnection()

    def test_create_new_data(self):
        # create new table
        self.db.conn.autocommit = True
        with self.db.cursor() as c:
            c.execute(
                """
                CREATE TABLE IF NOT EXISTS block (
                    id serial NOT NULL,
                    geom geometry(Polygon,4326),
                    tile_name character varying,
                    location character varying
                );
                """
            )

            c.execute(
                """
                ALTER PUBLICATION logical_replication ADD TABLE block;
                """
            )

            c.execute(
                """
                INSERT INTO block (geom, tile_name, location)
                VALUES 
                (
                    st_setsrid(st_makepoint(107.6097, 6.9120),4326),
                    '2956BC',
                    'Oceanic'                     
                ) ON CONFLICT DO NOTHING;
                """
            )



class TestReplicationSubscriber(unittest.TestCase):

    def setUp(self):
        self.db = DBConnection()

    def test_read_data(self):
        # create new table
        self.db.conn.autocommit = True
        with self.db.cursor() as c:
            c.execute(
                """
                CREATE TABLE IF NOT EXISTS public.block (
                id serial NOT NULL,
                geom public.geometry(Polygon,4326),
                fid bigint,
                tile_name character varying,
                location character varying
                );
                """
            )

            c.execute(
                """
                SELECT * FROM block;
                """
            )

            rows = c.fetchall()
            self.assertEqual(len(rows), 1)



