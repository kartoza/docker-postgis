import unittest
import os
from utils.utils import DBConnection
from pprint import pprint

class TestExtensionsBase(unittest.TestCase):
    SPECIFIED_EXT = os.getenv('POSTGRES_MULTIPLE_EXTENSIONS').split(',')
    DEFAULT_EXT = ['plpgsql', 'pg_cron']  # get installed in any case

    def setUp(self):
        self.db = DBConnection()

    def fetch_extensions(self, cursor):
        cursor.execute(
            """
            SELECT extname FROM pg_extension;
            """.format()
        )

        # ignore extensions which are not user-defined
        installed_ext = [row[0] for row in cursor.fetchall() if row[0] not in self.DEFAULT_EXT]

        return installed_ext


class TestExtensions(TestExtensionsBase):

    def test_check_extensions(self):
        # create new table
        self.db.conn.autocommit = True
        with self.db.cursor() as c:
            installed_ext = self.fetch_extensions(c)

            print(f"installed: {installed_ext}, specified: {self.SPECIFIED_EXT}")

            # Check if specified is equal to installed
            assert set(installed_ext) == set(self.SPECIFIED_EXT)
