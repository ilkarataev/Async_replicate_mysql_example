 ### Тестовый репозиторий для изучения работы Асинхроной репликации в mysql
* Используется percona-server:8.0  
Для работы скриптов необходимы:  
    * mysql-cli client.
    * docker, docker-compose
    * bash

 ## Запуск
1. Поднять контейнеры `docker-compose up -d`. Поднимутся два контейнера db-master, db-slave.    

Контейнеры автоматически прокидывают порты на локал хост для подключения mysql cli клиентом:  
master порт 3306  
slave порт 3307  
Пользователь root, пароль указан в .env = testpass.  

2. Запускаем скрипт init_mysql_servers.sh. Можно пропускать пункт 1 и сразу запускать его.
Он настроить нам репликацию master > slave. Все нужные комментарии о работе скрипта внутри него.  
Права на катало conf.d chmod 664 -R conf.d/
3. Для вставки записей на мастер или слейв используем скрипт query_inserts.sh.
По умолчанию будет вставлять записи на мастер 
Для вставки в реплику используем запуск с параметрами slave `query_inserts.sh slave`  
Можно ограничить количество вставок `query_inserts.sh slave 10` на мастер 10 вставок `query_inserts.sh 10`  

4. Скрипт master `replica_master_change` меняет репликации местами. Slave становится мастером, мастер реплицирует со slave.

5. Скрипт clean_mysql_servers.sh. Для очистки контейнеров.

Проверяно только на ubuntu22:04