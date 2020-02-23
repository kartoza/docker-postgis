sudo apt-get -y update
sudo apt-get -y install software-properties-common gnupg2
sudo add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main"
sudo apt-get -y install wget
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get -y update
sudo apt-get -y install postgresql-9.6
sudo apt-get -y install postgresql-9.6-postgis-2.4
sudo apt-get -y install postgresql-9.6-pgrouting
sudo add-apt-repository ppa:ubuntugis/ubuntugis-unstable
sudo apt-get -y update
sudo apt -y install gdal-bin python3-gdal
sudo apt-get -y install python3-pip
python3 -m pip install
python3 -m pip install --upgrade pip
python3 -m pip install pytest
sudo apt-get -y install python3-venv
