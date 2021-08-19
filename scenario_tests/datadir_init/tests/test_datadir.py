import unittest
import os
from utils.utils import DBConnection
from pathlib import Path


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


class TestCustomWALdir(TestCollationBase):

    def test_check_pg_wal_symlink(self):
        self.db.conn.autocommit = True
        postgres_initdb_waldir = os.environ.get('POSTGRES_INITDB_WALDIR')
        with self.db.cursor() as c:
            datadir_location = self.fetch_datadir_location(c)
            pg_wal_symlink = os.path.join(datadir_location, 'pg_wal')
            # In this correct setup, pg_wal symlink must resolve to the 
            # correct POSTGRES_INITDB_WALDIR location
            self.assertTrue(
                Path(pg_wal_symlink).resolve().match(postgres_initdb_waldir))


class TestCustomWALdirNotMatch(TestCollationBase):

    def test_check_pg_wal_symlink(self):
        self.db.conn.autocommit = True
        postgres_initdb_waldir = os.environ.get('POSTGRES_INITDB_WALDIR')
        with self.db.cursor() as c:
            datadir_location = self.fetch_datadir_location(c)
            pg_wal_symlink = os.path.join(datadir_location, 'pg_wal')
            # In this wrong setup, pg_wal symlink and POSTGRES_INITDB_WALDIR
            # must resolve to a different path to raise the warning
            self.assertFalse(
                Path(pg_wal_symlink).resolve().match(postgres_initdb_waldir))

            # It has different path, but if this unittests runs, that means
            # postgres was able to start and the pg_wal symlink contains correct
            # data
            self.assertTrue(os.listdir(pg_wal_symlink))
