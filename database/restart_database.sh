#!/bin/bash
source ~/.bash_profile

recreate(){
  db_restart=$(echo "$1" | sed 's/,/ /g')
  db_memory_distribution=$2
  db_main_service=$3
  position=1

  memory_check=$(echo "${db_memory_distribution}" | sed 's/,/+/g')
  if [ $(echo ${memory_check} | bc) -gt 100 ]
  then
    echo "$(date +"%Y-%m-%d %H:%M:%S") WARN: memory parameter is higher than 100 (%)."
  fi

  for database in ${db_restart}
  do
    echo -e "$(date +"%Y-%m-%d %H:%M:%S") INFO: starting ${database} database. Log will be save at '/tmp/restart_${database}.log' on inside container"
    export ORACLE_SID=${database}

    spfile="${data_dir}/${database}/spfile/spfile${database}.ora"
    memory_distribution=$(echo "${db_memory_distribution}" | awk -F"," '{print $'${position}'}')
    main_service=$(echo "${db_main_service}" | awk -F"," '{print $'${position}'}')

    mkdir -p /u01/app/oracle/admin/${database}/adump
    cp ${script_home}/conf/listener/listener_template.ora $ORACLE_HOME/network/admin/listener.ora
    sed -i "s|\${hostname}|$(hostname)|g" $ORACLE_HOME/network/admin/listener.ora

    if [ -e ${spfile} ]; then
      sqlplus / as sysdba > /tmp/restart_${database}.log << EOF
        create pfile='/tmp/old_pfile${database}.ora' from spfile='${spfile}';
        exit;
EOF
      cat /tmp/old_pfile${database}.ora | grep -v -e "^*.sga_max_size=" -e "^*.sga_target=" -e "^*.pga_aggregate_target=" -e "^*.processes=" > /tmp/new_pfile${database}.ora

      rm -f ${spfile}
    else
      echo "$(date +"%Y-%m-%d %H:%M:%S") WARN: there are no spfile restored. Recreating spfile to startup instance."

      rm -f /tmp/new_pfile${database}.ora
      echo "*.db_name='${database}'" > /tmp/new_pfile${database}.ora
      echo "*.control_files='${data_dir}/${database}/controlfile/control01.ctl','${data_dir}/${database}/controlfile/control02.ctl'" >> /tmp/new_pfile${database}.ora
      echo "*.db_create_file_dest='${data_dir}/${database}/datafile'" >> /tmp/new_pfile${database}.ora
      #echo "*.db_file_name_convert='+DATA','${data_dir}/${database}/datafile','+RECO','${data_dir}/${database}/fast_recovery_area','+REDO','${data_dir}/${database}/redolog'" >> /tmp/new_pfile${database}.ora
      echo "*.db_create_online_log_dest_1='${data_dir}/${database}/redolog'" >> /tmp/new_pfile${database}.ora
      echo "*.db_create_online_log_dest_2='${data_dir}/${database}/redolog'" >> /tmp/new_pfile${database}.ora
      echo "*.db_create_online_log_dest_3='${data_dir}/${database}/redolog'" >> /tmp/new_pfile${database}.ora
      echo "*.db_create_online_log_dest_4='${data_dir}/${database}/redolog'" >> /tmp/new_pfile${database}.ora
      echo "*.db_create_online_log_dest_5='${data_dir}/${database}/redolog'" >> /tmp/new_pfile${database}.ora
      echo "*.db_recovery_file_dest='${data_dir}/${database}/fast_recovery_area'" >> /tmp/new_pfile${database}.ora
      echo "*.db_recovery_file_dest_size=50G" >> /tmp/new_pfile${database}.ora
    fi

    total_mem_gb=$(free -m | grep "Mem:" | awk '{print $2}')
    sga_and_process_size=$(echo "scale=1; ${total_mem_gb}*${memory_distribution}/100*0.6" | bc -l | awk -F. '{print $1}')
    echo "*.sga_max_size=${sga_and_process_size}M" >> /tmp/new_pfile${database}.ora
    echo "*.sga_target=${sga_and_process_size}M" >> /tmp/new_pfile${database}.ora
    pga_size=$(echo "scale=1; ${total_mem_gb}*${memory_distribution}/100*0.4" | bc -l | awk -F. '{print $1}')
    echo "*.pga_aggregate_target=${pga_size}M" >> /tmp/new_pfile${database}.ora
    echo "*.processes=${sga_and_process_size}" >> /tmp/new_pfile${database}.ora

    echo "SPFILE='${spfile}'" > $ORACLE_HOME/dbs/init${database}.ora
    sqlplus / as sysdba >> /tmp/restart_${database}.log << EOF
      create spfile='${spfile}' from pfile='/tmp/new_pfile${database}.ora';
      startup nomount;
      alter database mount;
      alter database flashback off;
      alter database open;
      alter system set service_names='${main_service}';

      shutdown immediate;
      startup mount;
      alter database archivelog;
      alter database open;
EOF

    position=$((position+1))
    if [ $(grep -e "^ORA-" /tmp/restart_${database}.log | wc -l) -ne 0 ]
    then
      echo "$(date +"%Y-%m-%d %H:%M:%S") ERROR: fail to start database ${database}. Please check logfile"
      continue
    fi

    echo "${database}:$ORACLE_HOME:Y            # line added by Agent" >> /etc/oratab
    echo "$(date +"%Y-%m-%d %H:%M:%S") INFO: database ${database} startup finished"
  done

  echo "$(date +"%Y-%m-%d %H:%M:%S") INFO: starting listener, logfile '/tmp/start_listener.log' inside container"
  lsnrctl start > /tmp/start_listener.log
  crontab_config ${script_home}
  echo "$(date +"%Y-%m-%d %H:%M:%S") INFO: container ready to use"
}

crontab_config(){
  echo "$(date +"%Y-%m-%d %H:%M:%S") INFO: configuring crontab"
  crontab ${script_home}/conf/cron/crontab.config
}

main(){
  db_restart=$1
  db_memory_distribution=$2
  db_main_service=$3
  script_home=$4
  data_dir=$5

  recreate ${db_restart} ${db_memory_distribution} ${db_main_service} ${script_home} ${data_dir}
}

main $1 $2 $3 $4 $5
