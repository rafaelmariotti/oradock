python oradock.py create image img_test:1.0 pass123 --log-level=info -o /tmp/database/
python oradock.py create database dbtest1 pass123 20 srv_test1 -i img_test:1.0
python oradock.py create database dbtest1,dbtest2 pass123 20,30 srv_test1,service_test2 -i img_test:1.0 -C container-dbtest
python oradock.py restore dbtest1 50 srv_dbtest1 -b /backup/dbtest1/bkp19990101 -D /u01/oradata
python oradock.py restore dbtest1 50,20 srv_dbtest1,service_dbtest2 -b /backup/dbtest1/bkp19990101,/backup/dbtest1/bkp20001231
python oradock.py restart dbtest1 30 service_db_test_one -D /u01/oradata -p 1522
