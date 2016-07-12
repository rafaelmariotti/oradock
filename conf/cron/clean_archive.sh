#!/bin/bash

############################################
# script: Delete archives via rman         #
# date: 01/07/2016                         #
# version: 1.0                             #
# developed by: Rafael Mariotti            #
############################################

source ~/.bash_profile
export ORACLE_SID=$1

rman target / << EOF
run
{
  delete noprompt archivelog all completed before 'sysdate - 4/24';
}
EOF
