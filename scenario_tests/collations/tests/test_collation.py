import unittest
import os
from utils.utils import DBConnection


class TestCollation(unittest.TestCase):

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

    def test_check_collation(self):
        # create new table
        self.db.conn.autocommit = True
        with self.db.cursor() as c:

            # Specified database created by entrypoint script should have
            # the correct collation from environment variable
            dbcollate, dbctype = self.fetch_collation(c, 'gis')
            self.assertEqual(dbcollate, os.environ.get('DEFAULT_COLLATION'))
            self.assertEqual(dbctype, os.environ.get('DEFAULT_CTYPE'))

            c.execute(
                """
                drop database if exists sample_db;
                """
            )
            c.execute(
                """
                create database sample_db;
                """
            )

            # Database created manually will have default settings
            dbcollate, dbctype = self.fetch_collation(c, 'sample_db')
            self.assertEqual(dbcollate, 'C.UTF-8')
            self.assertEqual(dbctype, 'C.UTF-8')

            # Default database created by entrypoint script have
            # default collation
            dbcollate, dbctype = self.fetch_collation(c, 'postgres')
            self.assertEqual(dbcollate, 'C.UTF-8')
            self.assertEqual(dbctype, 'C.UTF-8')
