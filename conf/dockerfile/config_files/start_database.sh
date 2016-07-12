#!/bin/bash
source ~/.bash_profile

total_mem_bytes=$(free -b | grep "Mem:" | awk '{print $2}')
shmall_total_mem_parcial=$(echo "(${total_mem_bytes}/100)*90" | bc -l)
page_size=$(getconf PAGE_SIZE)
shmall_env=$(echo "scale=0; ${shmall_total_mem_parcial}/${page_size}" | bc -l)

shmmax_env=$(printf "%0.0f" $(echo "(${total_mem_bytes}/100)*80" | bc -l))

total_mem_kbytes=$(free -k | grep "Mem:" | awk '{print $2}')
memlock_env=$(echo "scale=0; (${total_mem_kbytes}/100)*90" | bc -l)

sudo sysctl -w kernel.shmall=${shmall_env} > /dev/null
sudo sysctl -w kernel.shmmax=${shmmax_env} > /dev/null

cat /etc/security/limits.conf | grep -v -e "^oracle soft memlock" -e "oracle hard memlock" > /tmp/new_limits.conf
echo "oracle soft memlock ${memlock_env}" >> /tmp/new_limits.conf
echo "oracle hard memlock ${memlock_env}" >> /tmp/new_limits.conf
sudo mv /tmp/new_limits.conf /etc/security/limits.conf

if [ -e /etc/oratab ] && [ $(cat /etc/oratab | grep -v -e "^#" -e "^$" | wc -l) -eq 0 ];
then
  echo "$(date +"%Y-%m-%d %H:%M:%S") INFO: There are no databases installed to startup."
else
  for database in $(cat /etc/oratab | grep -v -e "^#" -e "^$" | awk -F: '{print $1}')
  do
    export ORACLE_SID=${database}
    sqlplus -S / as sysdba > /tmp/startup_${database}.log << EOF
    startup;
EOF

    if [ -n "$(cat /tmp/startup_${database}.log | grep "Database opened.")" ];
    then
      echo "$(date +"%Y-%m-%d %H:%M:%S") INFO: Database ${database} opened."
      rm -f /tmp/startup_${database}.log
    else
      echo "$(date +"%Y-%m-%d %H:%M:%S") ERROR: Error at startup. Please, check log file /tmp/startup_${database}.log"
    fi
  done

  lsnrctl start >> /tmp/start_listener.log
fi

sudo /etc/init.d/crond restart
tail -f /dev/null
