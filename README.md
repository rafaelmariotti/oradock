# ORADOCK - A COMPLETE CONTAINER SOLUTION FOR ORACLE DATABASE 11G


## 1. Introduction

Oradock is a project to help people to manage their databases using Docker containers. With this project, you can:

* Create a custom image with Oracle Database 11.2.0.1 or 11.2.0.4 installed
* Create empty databases
* Restore & recover databases
* [Re]start containers using consintent datafiles on your host


## 2. Prerequisites

This project was build with the following software versions (any difference may change the project behavior):

* Docker Engine **(version 1.10 or higher)**. For more information, check [Install Docker Engine Documentation](https://docs.docker.com/engine/installation/)

* Python **(version 3.5.1 or higher)**. As a recommendation, you can use pyenv to configure your python environment. Fore more information, check [pyenv](https://github.com/yyuu/pyenv) 

* Oracle install binary files **(only for ``create image`` command)**

## 3. Installation

* Install git:

        yum install git -y
or
        apt-get install git

* Install all python modules required:

        pip install boto docopt docker-py

* Clone the repository:

        git clone https://github.com/rafaelmariotti/oradock.git /opt/oradock

* Edit ``/etc/sysctl.conf`` and configure:

        net.ipv4.ip_forward = 1
        net.core.rmem_default = 16777216
        net.core.rmem_max = 67108864
        net.core.wmem_default = 16777216
        net.core.wmem_max = 67108864

## 4. Options

	Usage:
	    oradock2.py (restore | restart) DATABASE MEMORY SERVICE_NAME [options]
	    oradock2.py create image IMAGE_NAME PASSWORD [options]
	    oradock2.py create database DATABASE PASSWORD MEMORY SERVICE_NAME [options]
	    oradock2.py (-h | --help)
	    oradock2.py --version
	
	Arguments:
	    DATABASE
	                                        Database(s) target name to work, separate by comma.
	    MEMORY
	                                        Memory percent to reserve for each database, separate by comma.
	    PASSWORD
	                                        Single password to set oracle and sys users.
	    SERVICE_NAME
	                                        Main service name for each database, separate by comma.
	    IMAGE_NAME
	                                        Image name to build.
	
	Operations:
	    restore
	                                        Restore and recovery database backup files.
	    restart
	                                        Restart and configure a container that already has datafiles restored.
	    create image
	                                        Create an Oracle image.
		create database
											Create a new empty database.
	
	Options:
	    -k ORADOCK_HOME, --oradock-home=ORADOCK_HOME
	                                        Directory where oradock binary are located [default: /opt/oradock].
	    -l LOG_LEVEL, --log-level=LOG_LEVEL
	                                        Log level to set [default: info].
	
	Create image options:
	    -o OINSTALL_DIR, --oinstall-dir=OINSTALL_DIR
	                                        Directory with Oracle binary files to install [default: $ORADOCK_HOME/conf/dockerfile/config_files/database].
	    -d DOCKERFILE, --dockerfile-template=DOCKERFILE
	                                        Dockerfile template to build Oracle docker image [default: $ORADOCK_HOME/conf/dockerfile/Dockerfile.template].
	
	Restore options:
	    -b BACKUP_DIR, --backup-directory=BACKUP_DIR
	                                        Directory home path for each backup location [default: /backup/$DATABASE].
	    -c CFILE_NAME, --control-file-name=CFILE_NAME
	                                        Controlfile name to search among backup files to restore [default: controlfile.bkp].
	    -s SPFILE_NAME, --spfile-name=SPFILE_NAME
	                                        Spfile name to search among backup files to restore [default: spfile.bkp].
	    -A ACCESS_KEY, --s3-access-key=ACCESS_KEY
	                                        Access key to download from s3 bucket.
	    -B S3_BUCKET, --s3-bucket=S3_BUCKET
	                                        s3 bucket directory to download the backup files.
	    -S SECRET_KEY, --s3-secret-key=SECRET_KEY
	                                        Secret key to download from s3 bucket.
	
	Restore, restart & create database options:
	    -D DATAFILE_DIR, --datafile-dir=DATAFILE_DIR
	                                        Base directory where datafiles will be stored and separated by directories [default: /data].
	    -i IMAGE_NAME, --image-name=IMAGE_NAME
	                                        Set which Docker image oradock has to use [default: rafaelmariotti/oracle-ee-11g:latest].
	    -p PORT, --port=PORT
	                                        Database port which container will use [default: 1521].
	    -C CONTAINER_NAME, --container-name=CONTAINER_NAME
	                                        Set the container name to create [default: oradock-db-$DATABASE].
	    -F, --force-pull
	                                        Forces a docker pull to update the image that oradock is using.
	
	General options:
	    -h, --help
	                                        Show help menu.
	
	Funny options:
	    --animation=ANIMATION_NUMBER
	                                        Choose your own animation while creating Oracle docker image, between 1 and 2 [default: 1].

## 5. Considerations

* It is highly recommended to create partitions for each database files
* oradock has an interface with Amazon Simple Storage Service (Amazon S3), which can be very helpfull on restores if you are storing your backups in buckets
* Be careful when changing templates files. Some variables are required to exists to oradock works (check bin files to understand before making any change)
* Configure crontab before running oradock
* _**You can use the default image to create your containers, it was specially designed by me!**_
