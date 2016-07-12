#!/bin/bash

###########################################
# script: calculate statistics from db    #
# date: 01/07/2016                        #
# version: 1.0                            #
# developed by: Rafael Mariotti           #
###########################################
source ~/.bash_profile

check_parameters(){
  echo "checking parameters... (statistic_percentage)"
  if [ $# -le 2 ] && [ $# -gt 0 ]; then
    if [ $2 -gt 100 ] || [ $2 -le 0 ]; then
      echo "  ERROR(2): statistic percentage not valid (must be between 1 and 100)"
      exit 2
    fi
  else
    echo "  ERROR(1): wrong argument number (SID PERCENTAGE)"
    exit 1
  fi

  echo "  Ok."
  return 0
}

run_statistic(){
  PERCENT=$1
  export ORACLE_SID=$2
  echo "Starting statistic process.. ($(date +"%d/%m/%Y %H:%M"))"

  sqlplus / as sysdba <<EOF
SET serveroutput ON;
DECLARE
BEGIN
  FOR object_info IN
  (SELECT dt.owner,
    dt.table_name
  FROM dba_tables dt
  WHERE lower(owner) NOT IN ('system', 'sys', 'outln', 'dip', 'oracle_ocm', 'dbsnmp', 'appqossys', 'wmsys', 'exfsys', 'xdb', 'anonymous', 'xs\$null', 'sysman', 'mgmt_view')
  AND TEMPORARY       = 'N'
  AND (dt.iot_type   IS NULL
  OR dt.iot_type     != 'IOT_OVERFLOW')
  AND table_name NOT IN
    (SELECT table_name FROM dba_external_tables det WHERE det.owner = dt.owner
    )
  ORDER BY owner,
    table_name
  )
  LOOP
    BEGIN
      dbms_stats.gather_table_stats(ownname=> object_info.owner, tabname=> object_info.table_name , CASCADE=> true, method_opt => 'for all columns size skewonly', estimate_percent=>$PERCENT);
      dbms_output.put_line('(success) statistic from ' || lower(object_info.owner || '.' || object_info.table_name));
    EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('error calculating statistic from ' || object_info.owner ||'.' || object_info.table_name || ': ' || sqlerrm);
    END;
  END LOOP;
END;
/
EOF
  echo "Done ($(date +"%d/%m/%Y %H:%M"))"
}

main(){
  check_parameters $1 $2
  run_statistic $1 $2
}

main $1 $2
