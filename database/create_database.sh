#!/bin/bash
source ~/.bash_profile

create_database(){
  sys_password=$1
  db_create=$(echo "$2" | sed 's/,/ /g')
  db_memory_distribution=$3
  db_main_service=$4
  script_home=$5
  data_dir=$6
  position=1

  cp ${script_home}/conf/listener/listener_template.ora $ORACLE_HOME/network/admin/listener.ora
  sed -i "s|\${hostname}|$(hostname)|g" $ORACLE_HOME/network/admin/listener.ora

  for database in ${db_create}
  do
    echo "$(date +"%Y-%m-%d %H:%M:%S") INFO: Creating ${database} database"

    export ORACLE_SID=${database}
    memory_distribution=$(echo "${db_memory_distribution}" | awk -F"," '{print $'${position}'}')
    main_service=$(echo "${db_main_service}" | awk -F"," '{print $'${position}'}')

    mkdir -p /u01/app/oracle/admin/${database}/adump
    chown -R oracle:oinstall /u01/app/oracle/admin/${database}/adump
    #mkdir -p ${data_dir}/${database}
    chown -R oracle:oinstall ${data_dir}/${database}
    rm -rf ${data_dir}/${database}/*
    mkdir -p ${data_dir}/${database}/controlfile
    mkdir -p ${data_dir}/${database}/spfile
    mkdir -p ${data_dir}/${database}/datafile
    mkdir -p ${data_dir}/${database}/redolog
    mkdir -p ${data_dir}/${database}/fast_recovery_area
    mkdir -p /u01/app/oracle/admin/${database}/adump

    if [ $(find ${data_dir}/${database}/ -type f | wc -l) -gt 0 ];
    then
      echo "$(date +"%Y-%m-%d %H:%M:%S") WARN: The directory '${data_dir}/${database}' is not empty."
    fi

    cp /u01/pfile_template.ora /u01/pfile.ora
    sed -i "s|\${database}|${database}|g" /u01/pfile.ora
    sed -i "s|\${data_dir}|${data_dir}|g" /u01/pfile.ora

    total_mem_gb=$(free -m | grep "Mem:" | awk '{print $2}')
    sga_and_process_size=$(echo "scale=1; ${total_mem_gb}*${memory_distribution}/100*0.6" | bc -l | awk -F. '{print $1}')
    echo "sga_max_size=${sga_and_process_size}M" >> /u01/pfile.ora
    echo "sga_target=${sga_and_process_size}M" >> /u01/pfile.ora
    pga_size=$(echo "scale=1; ${total_mem_gb}*${memory_distribution}/100*0.4" | bc -l | awk -F. '{print $1}')
    echo "pga_aggregate_target=${pga_size}M" >> /u01/pfile.ora
    echo "processes=${sga_and_process_size}" >> /u01/pfile.ora

    spfile="${data_dir}/${database}/spfile/spfile${database}.ora"
    echo "SPFILE='${spfile}'" > $ORACLE_HOME/dbs/init${database}.ora

	echo "$(date +"%Y-%m-%d %H:%M:%S") INFO: executing create database. Log will be save at '/tmp/create_${database}.log' on inside container"
    sqlplus / as sysdba > /tmp/create_${database}.log << EOF
      create spfile='${spfile}' from pfile='/u01/pfile.ora';
      startup nomount;

      CREATE DATABASE ${database}
      USER SYS IDENTIFIED BY ${sys_password}
      USER SYSTEM IDENTIFIED BY ${sys_password}
      LOGFILE GROUP 1 ('${data_dir}/${database}/redolog/redo01.log') SIZE 100M,
        GROUP 2 ('${data_dir}/${database}/redolog/redo02.log') SIZE 100M,
        GROUP 3 ('${data_dir}/${database}/redolog/redo03.log') SIZE 100M
      MAXLOGFILES 5
      MAXLOGMEMBERS 5
      MAXLOGHISTORY 1
      MAXDATAFILES 100
      CHARACTER SET AL32UTF8
      NATIONAL CHARACTER SET UTF8
      EXTENT MANAGEMENT LOCAL
      DATAFILE '${data_dir}/${database}/datafile/system01.dbf' SIZE 325M REUSE
      SYSAUX DATAFILE '${data_dir}/${database}/datafile/sysaux01.dbf' SIZE 325M REUSE
      DEFAULT TABLESPACE users
        DATAFILE '${data_dir}/${database}/datafile/users01.dbf'
        SIZE 500M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED
      DEFAULT TEMPORARY TABLESPACE tempts1
        TEMPFILE '${data_dir}/${database}/datafile/temp01.dbf'
        SIZE 20M REUSE
      UNDO TABLESPACE undotbs1
        DATAFILE '${data_dir}/${database}/datafile/undotbs01.dbf'
        SIZE 200M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;

      @?/rdbms/admin/catalog.sql;
      @?/rdbms/admin/catproc.sql;
      @?/sqlplus/admin/pupbld.sql;

      alter system set service_names='${main_service}';

      shutdown immediate;
      startup mount;
      alter database archivelog;
      alter database open;
EOF

    position=$((position+1))
    if [ $(grep -e "^ORA-" /tmp/create_${database}.log | wc -l) -ne 583 ] #number of errors when executing scripts to create database. lol?
    then
      echo "$(date +"%Y-%m-%d %H:%M:%S") ERROR: fail to create database ${database}. Please check logfile /tmp/create_${database}.log"
      continue
    fi

    echo "${database}:$ORACLE_HOME:Y            # line added by Agent" >> /etc/oratab
    echo "$(date +"%Y-%m-%d %H:%M:%S") INFO: ${database} database created"
  done

  echo "$(date +"%Y-%m-%d %H:%M:%S") INFO: starting listener, logfile '/tmp/start_listener.log' inside container"
  lsnrctl start > /tmp/start_listener.log
  crontab_config ${script_home}
  echo "$(date +"%Y-%m-%d %H:%M:%S") INFO: Container ready to use"
}

crontab_config(){
  echo "$(date +"%Y-%m-%d %H:%M:%S") INFO: configuring crontab"
  crontab ${script_home}/conf/cron/crontab.config
}

main(){
  sys_password=$1
  db_create=$2
  db_memory_distribution=$3
  db_main_service=$4
  script_home=$5
  data_dir=$6

  create_database ${sys_password} ${db_create} ${db_memory_distribution} ${db_main_service} ${script_home} ${data_dir}
}

main $1 $2 $3 $4 $5 $6
