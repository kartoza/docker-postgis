import unittest
import os
from utils.utils import DBConnection


class TestUpgradeBase(unittest.TestCase):

    def setUp(self):
        self.db = DBConnection()


class TestUpgradeInit(TestUpgradeBase):

    def test_upgrade_init(self):
        # create new table
        self.db.conn.autocommit = True
        with self.db.cursor() as c:
            c.execute(
                """
                create table if not exists layer (
                    id integer not null primary key,
                    value integer,
                    geometry geometry(Point, 4326)
                );
                insert into layer values (1, 10, st_setsrid(st_makepoint(100, 6), 4326)) on conflict (id) do nothing;
                """
            )


class TestUpgradeResult(TestUpgradeBase):

    def test_upgrade_result(self):
        self.db.conn.autocommit = True
        with self.db.cursor() as c:
            c.execute(
                """
                select id, value, st_astext(geometry) geometry from layer;
                """
            )
            rows = c.fetchall()
            self.assertTrue(rows)
            row = rows[0]
            self.assertEqual(row[1], 10)
            self.assertEqual(row[2], 'POINT(100 6)')

            # Check upgrade hook executed
            self.assertTrue(os.path.exists('/tmp/pre.lock'))
            self.assertTrue(os.path.exists('/tmp/post.lock'))
