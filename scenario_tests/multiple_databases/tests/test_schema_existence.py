import unittest
import psycopg2
import os


class TestSchemaExistence(unittest.TestCase):

    def setUp(self):
        self.db_host = os.environ.get('POSTGRES_HOST', 'localhost')
        self.db_port = os.environ.get('POSTGRES_PORT', '5432')
        self.db_user = os.environ.get('POSTGRES_USER', 'docker')
        self.db_pass = os.environ.get('POSTGRES_PASS', 'docker')
        self.db_names = os.environ.get('POSTGRES_DB', '').split(',')
        self.schemas = os.environ.get('SCHEMA_NAME', '').split(',')
        self.all_databases = os.environ.get('ALL_DATABASES', 'TRUE').lower() == 'true'

    def connect_to_db(self, db_name):
        try:
            conn = psycopg2.connect(
                dbname=db_name,
                user=self.db_user,
                password=self.db_pass,
                host=self.db_host,
                port=self.db_port
            )
            return conn
        except psycopg2.Error as e:
            self.fail(f"Failed to connect to the database: {e}")

    def test_schema_existence(self):
        for idx, db_name in enumerate(self.db_names):
            conn = self.connect_to_db(db_name)
            cursor = conn.cursor()

            for schema in self.schemas:
                query = f"SELECT schema_name, catalog_name FROM information_schema.schemata \
                WHERE schema_name = '{schema}' and catalog_name = '{db_name}';"
                cursor.execute(query)
                exists = cursor.fetchone()

                if not self.all_databases and idx > 0:
                    self.assertIsNone(exists, f"Schema '{schema}' should not exist in database '{db_name}'")
                else:
                    self.assertIsNotNone(exists, f"Schema '{schema}' does not exist in database '{db_name}'")

            conn.close()


if __name__ == '__main__':
    unittest.main()