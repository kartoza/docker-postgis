import unittest
import os
from utils.utils import DBConnection


class TestCollationBase(unittest.TestCase):

    def setUp(self):
        self.db = DBConnection()

    def fetch_collation(self, cursor, dbname):
        cursor.execute(
            """
            select datcollate, datctype from pg_database where datname = '{}';
            """.format(dbname)
        )

        row = cursor.fetchone()
        return row

    def fetch_datadir_location(self, cursor):
        cursor.execute(
            """
            show data_directory;
            """
        )
        row = cursor.fetchone()
        return row[0]


class TestDefault(TestCollationBase):

    def test_check_collation(self):
        # create new table
        self.db.conn.autocommit = True
        with self.db.cursor() as c:

            # Check datadir locations
            self.assertTrue(
                self.fetch_datadir_location(c).startswith(
                    '/var/lib/postgresql'
                )
            )


class TestNew(TestCollationBase):

    def test_check_collation_in_new_datadir(self):
        # create new table
        self.db.conn.autocommit = True
        with self.db.cursor() as c:

            # Check datadir locations
            self.assertTrue(
                self.fetch_datadir_location(c).startswith(
                    os.environ.get('DATADIR')
                )
            )


class TestRecreate(TestCollationBase):

    def test_check_collation_in_new_datadir(self):
        # create new table
        self.db.conn.autocommit = True
        with self.db.cursor() as c:

            # Check datadir locations
            self.assertTrue(
                self.fetch_datadir_location(c).startswith(
                    '/var/lib/postgresql'
                )
            )

            # Check that the new cluster is not the default cluster
            # from it's collations
            dbcollate, dbctype = self.fetch_collation(c, 'gis')
            self.assertEqual(dbcollate, os.environ.get('DEFAULT_COLLATION'))
            self.assertEqual(dbctype, os.environ.get('DEFAULT_CTYPE'))

