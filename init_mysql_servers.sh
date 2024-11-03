#! /usr/bin/bash

# Функция для создания файла my.cnf
if [ ! -d "./tmp" ]; then
    mkdir ./tmp
    echo "Directory ./tmp created."
fi

create_my_cnf() {
    local filename=$1
    local port=$2
    cat <<EOF > $filename
[client]
user=root
password=${MYSQL_ROOT_PASSWORD}
host=127.0.0.1
port=$port
[mysqldump]
user=root
port=$port
password=${MYSQL_ROOT_PASSWORD}
host=127.0.0.1
EOF
}
#Поднимаем контейнеры
docker-compose up -d

# Load environment variables from .env file
export $(grep -v '^#' .env | xargs)
echo "MYSQL_ROOT_PASSWORD is $MYSQL_ROOT_PASSWORD"
# Функция для создания файла my.cnf
create_my_cnf ./tmp/master.cnf 3306
create_my_cnf ./tmp/slave.cnf 3307

# Ждем когда mysql будет доступен
while ! mysqladmin --defaults-extra-file=./tmp/master.cnf ping -s -h 127.0.0.1; 
do
   sleep 3
   echo "waiting for mysql ..."
done
#Создаем тестовую базу данных и таблицу
mysql --defaults-extra-file=./tmp/master.cnf  -e "
CREATE DATABASE IF NOT EXISTS test_db;
USE test_db;

CREATE TABLE IF NOT EXISTS test_table (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50),
    date DATE
);

INSERT INTO test_table (name, date) 
VALUES 
    (CONCAT('Name_', FLOOR(1 + RAND() * 100)), CURDATE()),
    (CONCAT('Name_', FLOOR(1 + RAND() * 100)), CURDATE()),
    (CONCAT('Name_', FLOOR(1 + RAND() * 100)), CURDATE());
"
# Создаем пользователя для репликации
mysql --defaults-extra-file=./tmp/master.cnf -e "
CREATE USER 'repl'@'%' IDENTIFIED BY 'test';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
"

# Создаем бэкап и восстанавливаем его на slave
if [ -f ./tmp/dumpmaster.sql ]; then
    rm ./tmp/dumpmaster.sql
fi
mysqldump --defaults-extra-file=./tmp/master.cnf --all-databases > ./tmp/dumpmaster.sql

#Настраиваем репликацию
mysql --defaults-extra-file=./tmp/slave.cnf  -e "reset master;"
mysql --defaults-extra-file=./tmp/slave.cnf  -e "STOP SLAVE;"
mysql --defaults-extra-file=./tmp/slave.cnf  < ./tmp/dumpmaster.sql
mysql --defaults-extra-file=./tmp/slave.cnf  -e "
CHANGE MASTER TO MASTER_HOST='db-master', MASTER_USER='repl', MASTER_PASSWORD='test', MASTER_AUTO_POSITION = 1;
"
mysql --defaults-extra-file=./tmp/slave.cnf  -e "START SLAVE;"
# Проверяем статус репликации
mysql --defaults-extra-file=./tmp/slave.cnf  -e "SHOW SLAVE STATUS \G;"

# Проверяем что данные с реплицированы на slave
mysql --defaults-extra-file=./tmp/master.cnf -e "SELECT * FROM test_db.test_table;"
mysql --defaults-extra-file=./tmp/slave.cnf  -e "SELECT * FROM test_db.test_table;"