#!/bin/bash

# Default number of rows to insert
num_rows=100

# Check if the first parameter is a number
if [[ "$1" =~ ^[0-9]+$ ]]; then
    num_rows=$1
    mysql_cmd="mysql --defaults-extra-file=./tmp/master.cnf"
else
    if [ -z "$1" ]; then
        mysql_cmd="mysql --defaults-extra-file=./tmp/master.cnf"
    else
        mysql_cmd="mysql --defaults-extra-file=./tmp/slave.cnf"
    fi
fi

# Override num_rows if the second parameter is provided
if [ ! -z "$2" ]; then
    num_rows=$2
fi

echo "Inserting $num_rows rows using command: $mysql_cmd"

# Loop to insert rows
for ((i=1; i<=num_rows; i++))
do
    $mysql_cmd -e "
    USE test_db;
    INSERT INTO test_table (name, date) 
    VALUES 
        (CONCAT('Name_', FLOOR(1 + RAND() * 100)), CURDATE());
    "
done

echo "Insertion complete"