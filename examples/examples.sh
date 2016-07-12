./oradock.py create image img_test:1.0 pass123 --log-level=info -o /tmp/database/
./oradock.py create database dbtest1,dbtest2 pass123 20,30 srv_test1,service_test2 -i img_test:1.0 -C container-dbtest
./oradock.py restore dbtest1,dbtest2 50,20 srv_dbtest1,service_dbtest2 -b /backup/dbtest1/bkp19990101,/backup/dbtest1/bkp20001231 -D /u01/oradata -A abc123 -S xyz456 -B s3://backups/dbtest1/bkp19990101_0000,s3://backups/dbtest2/backup20001231_1200 -s dbtest2_spfile.bkp
./oradock.py restart dbtest1 30 service_db_test_one -D /database -p 1522
