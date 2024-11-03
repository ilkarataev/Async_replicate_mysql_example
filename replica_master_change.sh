#! /usr/bin/bash

echo "Stopping master and cleaning up"
docker-compose stop db-master

docker-compose rm -vf db-master

echo "Count records slave"
mysql --defaults-extra-file=./tmp/slave.cnf -e "SELECT COUNT(*) FROM test_db.test_table;"

docker-compose up -d

echo "Start master wait for 15 seconds" 
docker start db-master

while ! mysqladmin ping -h 127.0.0.1 --silent; 
do
   sleep 3
   echo "waiting for mysql ..."
done

mysql --defaults-extra-file=./tmp/slave.cnf -e "reset master;"
mysql --defaults-extra-file=./tmp/slave.cnf -e "STOP SLAVE;RESET SLAVE ALL;"
mysql --defaults-extra-file=./tmp/slave.cnf -e "
DROP USER IF EXISTS 'master'@'%';
CREATE USER 'master'@'%' IDENTIFIED BY 'test';
GRANT REPLICATION SLAVE ON *.* TO 'master'@'%';
FLUSH PRIVILEGES;
"
echo "Inserting 10 rows into slave"
./inserts.sh slave 10
echo "Creating backup from slave"
if [ -f ./tmp/dumpslave.sql ]; then
    rm ./tmp/dumpslave.sql
fi

mysqldump --defaults-extra-file=./tmp/slave.cnf --all-databases > ./tmp/dumpslave.sql
echo "Inserting backup from slave -> master"
mysql --defaults-extra-file=./tmp/master.cnf < ./tmp/dumpslave.sql

mysql --defaults-extra-file=./tmp/master.cnf -e "
CHANGE MASTER TO MASTER_HOST='db-slave', MASTER_USER='master', MASTER_PASSWORD='test', MASTER_AUTO_POSITION = 1;
"
sleep 3
mysql --defaults-extra-file=./tmp/master.cnf -e "STOP SLAVE;START SLAVE;"
mysql --defaults-extra-file=./tmp/master.cnf -e "SHOW SLAVE STATUS \G;"

echo "Checking the number of rows in the master"
mysql --defaults-extra-file=./tmp/master.cnf -e "SELECT COUNT(*) FROM test_db.test_table;"
echo "Checking the number of rows in the slave"
mysql --defaults-extra-file=./tmp/slave.cnf -e "SELECT COUNT(*) FROM test_db.test_table;"