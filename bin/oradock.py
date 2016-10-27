#!/usr/bin/env python
"""
 
Oradock project is an Oracle Database 11g manager system integrated with Docker, where you can easily start a database from the scratch or download & recover a backup from s3 (aws).
For more information, please visit https://github.com/rafaelmariotti/oradock

Usage:
    oradock.py (restore | restart) DATABASE MEMORY SERVICE_NAME [options]
    oradock.py create database DATABASE PASSWORD MEMORY SERVICE_NAME [options]
    oradock.py create image IMAGE_NAME PASSWORD [options]
    oradock.py (-h | --help)
    oradock.py --version

Operations:
    restore
                                        Restore and recovery database backup files.
    restart
                                        Restart and configure a container that already has datafiles restored.
    create database
                                        Create a new empty database.
    create image
                                        Create an Oracle image.
 
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
                                        Directory home path for each backup location, separate by comma [default: /backup/$DATABASE].
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
    -P PARALLEL, --parallel=PARALLEL
                                        Set the parallel level to restore backups [default: 1]. 

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
"""

__author__  = 'Rafael dos Santos Mariotti <rafael.s.mariotti@gmail.com>'
__version__ = 'oradock v1.0'

try:
    import logging
    import collections
    import sys
    import os
    import re
    import errno
    import time
    import socket
    import boto.exception
    from multiprocessing import Process, Manager
    from docopt import docopt
    from shutil import copyfile
    from shutil import copytree
    from shutil import rmtree
    from shutil import chown
    from boto.s3.connection import S3Connection
    from docker import Client
    from docker import errors as docker_error
except ImportError as error: #check for all modules
    print('ERROR: Could not find module \'%s\'' % error.name)
    sys.exit(-1)

def set_log(log_level): #set log level to print
    log_level_number = getattr(logging, log_level.upper(), None)
    if not isinstance(log_level_number, int):
        print('ERROR: Invalid log level \'%s\'' % log_level.upper())
        sys.exit(-1)
    logging.basicConfig(level=log_level.upper(), format='%(asctime)s %(levelname)s: %(message)s', datefmt='%Y-%m-%d %H:%M:%S', stream=sys.stdout)
    logging.StreamHandler(sys.stdout)


## s3 functions


def create_s3conn(access_key, secret_key): #open s3 connection
    try:
        s3connection=S3Connection(access_key, secret_key)
    except boto.exception.AWSConnectionError as error:
        logging.error('unexpected response while trying connect to aws s3 [%s]' % error.args[0])
        sys.exit(-1)
    except boto.exception.S3ResponseError as error:
        logging.error('unexpected response from s3 [%s]' % error.args[1])
        sys.exit(-1)
    return s3connection


def retrieve_s3bucket_info(s3connection, s3_bucket_name): #get s3 bucket files
    try:
        s3_bucket_conn=s3connection.lookup(s3_bucket_name)
    except boto.exception.S3ResponseError as error:
        logging.error('unexpected response from s3 [%s]' % error.args[1])
        sys.exit(-1)
    except boto.exception.S3DataError as error:
        logging.error('error while retrieving data from s3 [%s]' % error.args[0])
        sys.exit(-1)
    return s3_bucket_conn


def download_file(s3_file, file_dest_path): #download a single file from s3 bucket
    if os.path.exists(file_dest_path):
        if os.path.getsize(file_dest_path) != s3_file.size:
            logging.warning('file \'%s\' already exists and is corrupted. Downloading again (%s mb)' % (file_dest_path, str(round(int(s3_file.size)/(1024*1024),2))))
        else:
            logging.warning('file \'%s\' already exists' % file_dest_path)
            return
    else:
        logging.info('downloading file \'%s\' (%s mb)' % (file_dest_path, str(round(int(s3_file.size)/(1024*1024),2))))

    try:
        s3_file.get_contents_to_filename(file_dest_path)
    except boto.exception.S3ResponseError as error:
        logging.error('unexpected response from s3 [%s]' % error.args[1])
        sys.exit(-1)
    except boto.exception.S3DataError as error:
        logging.error('error while retrieving data from s3 [%s]' % error.args[0])
        sys.exit(-1)
    except boto.exception.S3CopyError as error:
        logging.error('error while copying data from s3 [%s]' % error.args[1])
        sys.exit(-1)
    except boto.exception.S3PermissionsError as error:
        logging.error('permission denied on s3 file \'\' [%s]' % error.args[0])
        sys.exit(-1)


def get_s3_full_path_dir(s3_bucket):
    s3_bucket_name=s3_bucket.split('/')[2]
    s3_full_path_dir='/'.join(s3_bucket.split('/')[s3_bucket.split('/').index(s3_bucket_name)+1:])
    return s3_full_path_dir,s3_bucket_name


def download_s3(database_list, backup_dir, access_key, secret_key): #download all files from s3 bucket
    s3connection=create_s3conn(access_key, secret_key)
    for database, info in database_list.items():
        memory = info.get('memory')
        service_name = info.get('service_name')
        s3_bucket = info.get('s3_bucket')
        backup_dir = info.get('backup_directory')
        logging.debug('looking for backup files in s3 bucket \'%s\' for database %s' % (s3_bucket, database))

        (s3_full_path_dir,s3_bucket_name)=get_s3_full_path_dir(s3_bucket)
        s3_bucket_conn=retrieve_s3bucket_info(s3connection, s3_bucket_name)
        create_directory(backup_dir)

        for s3_file in s3_bucket_conn.list(s3_full_path_dir,''):
            s3_file_name = s3_file.name.split('/')[-1]
            file_dest_path = backup_dir +'/'+ s3_file_name
            download_file(s3_file, file_dest_path)
    s3connection.close


## all preprocess


def preprocess_restore_args(args):
    if args['--s3-bucket'] is None:
        args['--s3-bucket']='-'+',-'*args['DATABASE'].count(',')
    else:
        args['--s3-bucket']=args['--s3-bucket'].replace('/,',',').rstrip('/')
    args['--datafile-dir']=args['--datafile-dir'].replace('/,',',').rstrip('/')
    args['--backup-directory']=args['--backup-directory'].replace('/,',',').rstrip('/')
    args['--oradock-home']=args['--oradock-home'].rstrip('/')
    

def preprocess_restart_args(args):
    args['--s3-bucket']='-'+',-'*args['DATABASE'].count(',')
    args['--backup-directory']='-'+',-'*args['DATABASE'].count(',')
    args['--datafile-dir']=args['--datafile-dir'].replace('/,',',').rstrip('/')
    args['--oradock-home']=args['--oradock-home'].rstrip('/')


def preprocess_create_image_args(args):
    args['--oradock-home']=args['--oradock-home'].rstrip('/')

def preprocess_create_database_args(args):
    args['--s3-bucket']='-'+',-'*args['DATABASE'].count(',')
    args['--backup-directory']='-'+',-'*args['DATABASE'].count(',')
    args['--oradock-home']=args['--oradock-home'].rstrip('/')
    args['--datafile-dir']=args['--datafile-dir'].replace('/,',',').rstrip('/')
    

## all params check


def check_args_count(arg1, arg2): #check 2 input options
    if arg1.count(',')!=arg2.count(','):
        logging.error('missing arguments - number of databases does not match with arguments info')
        sys.exit(-1)


def check_s3_bucket(s3_access_key, s3_secret_key, s3_bucket, database):
    if (s3_access_key is None and not s3_secret_key is None):# or (not args['--s3-access-key'] is None and args['--s3-secret-key'] is None):
        logging.error('please provide a valid s3 access and secret key')
        sys.exit(-1)
    s3connection=create_s3conn(s3_access_key,s3_secret_key)
    if not s3_bucket is None:
        for s3_bucket_list in s3_bucket.split(','): #check conn to s3 and if bucket exists
            s3_bucket_name=s3_bucket_list.split('/')[2]
            s3_full_path_dir='/'.join(s3_bucket_list.split('/')[s3_bucket_list.split('/').index(s3_bucket_name)+1:])
            logging.debug('checking for bucket \'%s\'' % s3_bucket_name)
            try:
                s3_bucket_conn=s3connection.lookup(s3_bucket_name)
            except boto.exception.S3PermissionsError as error:
                logging.error('permission denied at bucket %s [%s]' % (s3_bucket_name, error.args[0]))
                sys.exit(-1)
            except boto.exception.S3ResponseError as error:
                logging.error('unexpected response from s3 [%s]' % error.args[1])
                sys.exit(-1)
            except boto.exception.S3DataError as error:
                logging.error('error while retrieving data from s3 [%s]' % error.args[0])
                sys.exit(-1)

            if s3_bucket_conn is None:
                logging.error('s3 bucket \'%s\' does not exists. Please, review your bucket name and access/secret key' % s3_bucket_name)
                sys.exit(-1)
            if len(list(s3_bucket_conn.list(s3_full_path_dir,'/')))==0:
                logging.error('s3 backup directory \'%s\' does not exists' % s3_bucket_name)
        check_args_count(database, s3_bucket)
    s3connection.close


def check_file_or_directories_warn(file_or_dir, database):
    if file_or_dir.find('/backup/$DATABASE')==0:
        file_or_dir=''
        for database_name in database.split(','):
            file_or_dir+='/backup/'+database_name+','
        file_or_dir=file_or_dir.rstrip(',')
    
    for path in file_or_dir.split(','):
        if not os.path.exists(path):
            logging.warn('file or directory \'%s\' does not exists' % path)


def check_file_or_directories_error(file_or_dir, database):
    if file_or_dir.find('/backup/$DATABASE')==0:
        file_or_dir=''
        for database_name in database.split(','):
            file_or_dir+='/backup/'+database_name+','
        file_or_dir=file_or_dir.rstrip(',')

    for path in file_or_dir.split(','):
        if not os.path.exists(file_or_dir):
            logging.error('file or directory \'%s\' does not exists' % file_or_dir)
            sys.exit(-1)


def check_memory(memory):
    total_percent_memory=0
    for each_memory_percent in memory.split(','): #validating memory sum percent
        total_percent_memory = total_percent_memory+int(each_memory_percent)
    if total_percent_memory > 100 or total_percent_memory < 0:
        logging.error('memory exceeds server capacity')
        sys.exit(-1)


def check_port(port):
    sock=socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    result=sock.connect_ex(('127.0.0.1',int(port)))
    if int(port) < 1 or int(port) > 65535:
        logging.error('port number exceeds the OS limit')
        sys.exit(-1)
    elif result==0:
        logging.error('port is already in use. Please change port number to a free socket')
        sys.exit(-1)


def check_and_create_oinstall_dir(oradock_home, oinstall_dir):
    oinstall_dir_default=oradock_home+'/conf/dockerfile/config_files/database'
    if not os.path.exists(oinstall_dir_default):
        if oinstall_dir.find('$ORADOCK_HOME')==0:
            logging.error('directory with Oracle Install binary files does not exists [ %s ]' % oinstall_dir_default)
            sys.exit(-1)
        elif not os.path.exists(oinstall_dir):
            logging.error('directory with Oracle Install binary files does not exists [ %s ]' % oinstall_dir)
            sys.exit(-1)
        logging.info('copying install directory at \'%s\' to \'%s\'' % (oinstall_dir, oinstall_dir_default))
        copytree(oinstall_dir, oinstall_dir_default)


def check_dockerfile_template(dockerfile):
    if dockerfile.find('$ORADOCK_HOME')==-1 and not os.path.exists(dockerfile): #check if dockerfile has default value
        logging.error('dockerfile does not exists')
        sys.exit(-1)


def check_container(docker_client, args):
    if args['--container-name'].find('oradock-db-$DATABASE')==0:
        args['--container-name']='oradock-db-'+args['DATABASE'].replace(',', '-')
    if len(docker_client.containers(all=True, filters={'name':args['--container-name']}))!=0:
        logging.error('container \'%s\' already exists' % args['--container-name'])
        sys.exit(-1)


def check_image(image_name, docker_client):
    if len(docker_client.images(name=image_name))!=0:
        logging.error('image \'%s\' already exists' % image_name)
        sys.exit(-1)


def check_restore_params(args, docker_client):
    check_s3_bucket(args['--s3-access-key'], args['--s3-secret-key'], args['--s3-bucket'], args['DATABASE'])
    check_args_count(args['DATABASE'], args['MEMORY'])
    check_args_count(args['DATABASE'], args['SERVICE_NAME'])
    check_args_count(args['DATABASE'], args['--backup-directory'])
    check_file_or_directories_warn(args['--backup-directory'], args['DATABASE'])
    check_file_or_directories_error(args['--oradock-home'], args['DATABASE'])
    check_memory(args['MEMORY'])
    check_port(args['--port'])
    check_container(docker_client, args)


def check_restart_params(args, docker_client):
    check_args_count(args['DATABASE'], args['MEMORY'])
    check_args_count(args['DATABASE'], args['SERVICE_NAME'])
    check_file_or_directories_error(args['--oradock-home'], args['DATABASE'])
    check_memory(args['MEMORY'])
    check_port(args['--port'])
    check_container(docker_client, args)


def check_create_image_params(args, docker_client):
    check_and_create_oinstall_dir(args['--oradock-home'], args['--oinstall-dir'])
    check_dockerfile_template(args['--dockerfile-template'])
    check_image(args['IMAGE_NAME'], docker_client)


def check_create_database_params(args, docker_client):
    check_args_count(args['DATABASE'], args['MEMORY'])
    check_args_count(args['DATABASE'], args['SERVICE_NAME'])
    check_file_or_directories_error(args['--oradock-home'], args['DATABASE'])
    check_memory(args['MEMORY'])
    check_port(args['--port'])
    check_container(docker_client, args)


## auxiliary function


def create_database_settings(args): #create a dict with database infos
    database = {}
    if args['--backup-directory'].find('/backup/$DATABASE')==0:
        args['--backup-directory']=''
        for database_name in args['DATABASE'].split(','):
            args['--backup-directory']+='/backup/'+database_name+','
        args['--backup-directory']=args['--backup-directory'].rstrip(',')

    for database_name, memory, service_name, s3_bucket, backup_dir in zip(  args['DATABASE'].split(','), 
                                                                            args['MEMORY'].split(','),
                                                                            args['SERVICE_NAME'].split(','), 
                                                                            args['--s3-bucket'].split(','), 
                                                                            args['--backup-directory'].split(',')):
        database[database_name] = {'memory':memory, 'service_name':service_name, 's3_bucket':s3_bucket, 'backup_directory':backup_dir}
    logging.debug('database info: %s' % database)
    return database


def create_directory(directory): #create directory to save s3 files
    if not os.path.exists(directory):
        try:
            os.makedirs(directory)
        except OSError as error:
            if error.errno == errno.ENOENT :
                logging.error('error creating directory \'%s\'. No such file or directory' % directory)
                sys.exit(-1)
            elif error.errno == errno.EACCES:
                logging.error('error creating directory \'%s\'. Permission denied' % directory)
                sys.exit(-1)
            else:
                logging.error('error creating directory \'%s\'. %s' % (directory, str(error)))
                sys.exit(-1)


def change_directory_owner(directory, uid, gid):
    if os.path.exists(directory):
        msg_flag=0

        for root, directories, files in os.walk(directory):
            try:
                os.chown(root, uid, gid)
                for each_directory in directories:
                    os.chown(root +'/'+ each_directory, uid, gid)
                for each_files in files:
                    os.chown(root + '/'+ each_files, uid, gid)
            except OSError as error:
                if msg_flag==0:
                    if error.errno == errno.EPERM:
                        logging.warn('could not change permissions on directory \'%s\'. Permission denied' % directory)
                    else:
                        logging.warn('could not change permissions on directory\'%s\'. %s' % (directory, str(error)))
                    msg_flag=1


def set_docker_volumes(database_list, datafile_dir, oradock_home): #configure all volumes required to start the container
    container_volumes=[]
    container_volumes_config=[]

    for database, info in database_list.items():
        container_volumes.append(datafile_dir + '/' + database)
        container_volumes.append('/u01/app/oracle/diag/rdbms/' + database)

        container_volumes_config.append(datafile_dir +'/'+ database +':'+ datafile_dir +'/'+ database)
        container_volumes_config.append('/var/log/oracle/' + database + ':/u01/app/oracle/diag/rdbms/' + database)
        if info.get('backup_directory')!='-':
            container_volumes.append(info.get('backup_directory'))
            container_volumes_config.append(info.get('backup_directory') +':'+ info.get('backup_directory'))

    container_volumes.append(oradock_home + '/conf')
    container_volumes.append(oradock_home + '/database')
    container_volumes.append(oradock_home + '/consume')

    container_volumes_config.append(oradock_home + '/conf:' + oradock_home + '/conf')
    container_volumes_config.append(oradock_home + '/database:' + oradock_home + '/database')
    container_volumes_config.append(oradock_home + '/consume:' + oradock_home + '/consume')
    return container_volumes, container_volumes_config


def prepare_dockerfile(dockerfile_name, str_source, str_dest):
    try:
        dockerfile_template=open(dockerfile_name, 'r').read()
        dockerfile=open(dockerfile_name+'.new','w')
        sed_process=re.compile(str_source, re.MULTILINE)
        dockerfile.write(sed_process.sub(str_dest, dockerfile_template))
        dockerfile.close()
        copyfile(dockerfile_name+'.new', dockerfile_name)
        os.remove(dockerfile_name+'.new')
    except OSError as error:
        if error.errno == errno.ENOENT :
            logging.error('error to create dockerfile \'%s\'. No such file or directory' % dockerfile_name)
            sys.exit(-1)
        elif error.errno == errno.EACCES:
            logging.error('error to create dockerfile \'%s\'. Permission denied' % dockerfile_name)
            sys.exit(-1)
        else:
            logging.error('error to create directory \'%s\'. %s' % (dockerfile_name, str(error)))
            sys.exit(-1)


def call_process_build(function_name, arguments, animation):
    docker_build_log=Manager().list()
    arguments+=(docker_build_log,)

    process=Process(name=function_name, target=function_name, args=arguments)
    process.start()
    animation = '-\\|/'
    idx=0

    man_animation=['(>\'.\')>', '<(\'.\'<)']
    if(animation=='2'):
        man_animation=['\\o/', '|o|', '\\o/', '|o|']

    if (logging.getLogger().getEffectiveLevel()!=logging.DEBUG):
        while process.exitcode is None:
            print('\r' + animation[idx % len(animation)] + ' Executing... ' + man_animation[idx % len(man_animation)] + '', end='')
            idx = idx + 1
            time.sleep(0.2)
    else:
        process.join()
    print('\r', end='')
    return docker_build_log


## docker function


def docker_build(docker_client, image_name, dockerfile_dir, docker_image):
    try:
        oradock_image=[line for line in docker_client.build(path=dockerfile_dir, stream=True, rm=True, tag=image_name)]
        docker_image.append(oradock_image)
    except docker_error.APIError as error:
        logging.error('error creating image \'%s\' [%s]' % (image_name, error.args[0]))
        sys.exit(-1)
    except TypeError as error:
        logging.error('error creating image \'%s\' [%s]' % (image_name, error.args[0]))
        sys.exit(-1)
    except KeyboardInterrupt as error:
        sys.exit(-1)
   

def docker_start(docker_client, image_name, container_name, container_volumes, container_volumes_config, container_port_config): #starts a container
    try:
        oradock_container=docker_client.create_container(image=image_name, 
                                                        name=container_name, 
                                                        hostname=os.uname()[1] , 
                                                        user='oracle', 
                                                        detach=True, 
                                                        ports=[1521],
                                                        tty=True, 
                                                        volumes=container_volumes, 
                                                        host_config = 
                                                            docker_client.create_host_config(
                                                                                            binds=container_volumes_config, 
                                                                                            port_bindings=container_port_config, 
                                                                                            privileged=True)
                                                        )
        docker_client.start(oradock_container)
    except docker_error.APIError as error:
        logging.error('error while trying to start container [%s]' % error.args[0])
        sys.exit(-1)
    return oradock_container


def docker_run(docker_client, oradock_container, command, log): #executes a command inside the container
    try:
        logging.debug('executing bash inside container: %s' % command)

        config_exec=docker_client.exec_create(  container=oradock_container['Id'], 
                                                cmd=command, 
                                                user='oracle', 
                                                stdout=True, 
                                                stderr=True, 
                                                tty=False)

        for exec_log in docker_client.exec_start(  exec_id=config_exec['Id'],
                                                                tty=False,
                                                                detach=False,
                                                                stream=True):
            exec_output = ''.join(chr(x) for x in exec_log)
            exec_output = exec_output.strip()
            print('\r'+exec_output)
    except docker_error.APIError as error:
        logging.error('error while trying to execute command \'%s\' on container: %s ' % (command, error.args[0]))
    except docker_error.DockerException as error:
        logging.error('error while trying to execute docker command: %s ' % error.args[0])


def docker_pull(docker_client, image_name, log):
    try:
        docker_client.pull(repository=image_name, stream=False)
    except docker_error.DockerException as error:
        logging.error('error while trying to download docker image: %s ' % error.args[0])
        sys.exit(-1)


#oradock argument final function


def restore_or_restart_or_create_database(args, database_list, docker_client): #restore all databases inside the container
    if len(docker_client.images(name=args['--image-name']))==0 or args['--force-pull']==True:
        logging.info('Downloading or updating image \'%s\'' % args['--image-name'])
        process_args=(docker_client, args['--image-name'])
        call_process_build(docker_pull, process_args, args['--animation'])

    logging.debug('defining volumes to mount into container')

    for database, info in database_list.items():
        create_directory(args['--datafile-dir']+'/'+database)    
        create_directory('/var/log/oracle/' + database)
        change_directory_owner(args['--datafile-dir']+'/'+database, 501, 503)
        change_directory_owner('/var/log/oracle/' + database, 501, 503)
        change_directory_owner(info.get('backup_directory'), 501, 503)
    (container_volumes, container_volumes_config)=set_docker_volumes(database_list, args['--datafile-dir'], args['--oradock-home'])
    container_port_config={1521 : args['--port']}

    logging.info('creating & starting container \'%s\'' % args['--container-name'])
    oradock_container=docker_start(docker_client, args['--image-name'], args['--container-name'], container_volumes, container_volumes_config, container_port_config)

    logging.info('container started')
    logging.info('executing database script inside container')

    command_args=[]
    if args['restore']==True:
        command_args.append(args['--backup-directory'])
        script_name='restore'
    elif args['restart']==True:
        script_name='restart'
    elif args['create']==True and args['database']==True:
        command_args.append(args['PASSWORD'])
        script_name='create'

    command_args.append(args['DATABASE'])
    command_args.append(args['MEMORY'])
    command_args.append(args['SERVICE_NAME'])
    command_args.append(args['--oradock-home'])
    command_args.append(args['--datafile-dir'])
    command_args.append(args['--spfile-name'])
    command_args.append(args['--control-file-name'])
    command_args.append(args['--parallel'])
    command_args.append(' > /tmp/'+script_name+'_database.log')

    command = '/bin/bash '+ args['--oradock-home'] +'/database/'+ script_name + '_database.sh '+ ' '.join(command_args)
    process_args=(docker_client, oradock_container, command)
    docker_exec_log=call_process_build(docker_run, process_args, args['--animation'])


def create_image(args, docker_client):
    oinstall_dir=args['--oradock-home']+'/conf/dockerfile/config_files/database'
    with open(oinstall_dir+'/install/oraparam.ini', 'r') as config_file: #search for oracle binary install version
        install_version=None
        for line in config_file:
            if line.find('OUI_VERSION')!=-1:
                install_version=line.rstrip().split('=')[1]
        if install_version is None:
            logging.error('cannot find oracle install binary versions. Please, check if file \'%s\' exists' % oinstall_dir+'/install/oraparam.ini')
            sys.exit(-1)

    dockerfile=args['--oradock-home']+'/conf/dockerfile/Dockerfile'
    if args['--dockerfile-template'].find('$ORADOCK_HOME')==0:
        copyfile(dockerfile+'.template', dockerfile) #replace password and install versions into dockerfile
    else:
        copytree(args['--dockerfile-template'], dockerfile)
    prepare_dockerfile(dockerfile, '\${password}', args['PASSWORD'])
    prepare_dockerfile(dockerfile, '\${install_version}', install_version)
    prepare_dockerfile(dockerfile, '\${oinstall_dir}', args['--oinstall-dir'])
    prepare_dockerfile(dockerfile, '\${hostname}', socket.gethostname())
    logging.info('dockerfile created at \'%s\'' % dockerfile)
    logging.info('creating image \'%s\'' % args['IMAGE_NAME'])

    process_args=(docker_client, args['IMAGE_NAME'], args['--oradock-home']+'/conf/dockerfile')
    docker_build_log=call_process_build(docker_build, process_args, args['--animation'])

    for exec_log in docker_build_log[0]:
        exec_output = ''.join(chr(x) for x in exec_log)
        exec_output = eval(exec_output.replace('\\n"}', '"}'))
        try: 
            logging.debug(exec_output['stream'])
        except KeyError as error:
            logging.error('docker build could not execute due to error [%s]' % exec_output['errorDetail']['message'])
            sys.exit(-1)

    rmtree(args['--oradock-home']+'/conf/dockerfile/config_files/database')
    logging.info('docker image successfully created')
    os.remove(args['--oradock-home']+'/conf/dockerfile/Dockerfile')


## main


if __name__ == '__main__':
    arguments = docopt(__doc__, version=__version__)
    #print(arguments)
    set_log(arguments['--log-level'])
    docker_client=Client(base_url='unix://var/run/docker.sock') 
 
    try:
        #call for restore option
        if arguments['restore']==True:
            check_restore_params(arguments, docker_client)
            preprocess_restore_args(arguments)
            database=create_database_settings(arguments)
            if arguments['--s3-bucket']!='-':
                download_s3(database, arguments['--backup-directory'], arguments['--s3-access-key'], arguments['--s3-secret-key'])
            restore_or_restart_or_create_database(arguments, database, docker_client)

        #call for restart option
        elif arguments['restart']==True:
            check_restart_params(arguments, docker_client)
            preprocess_restart_args(arguments)
            database=create_database_settings(arguments)
            restore_or_restart_or_create_database(arguments, database, docker_client)

        #call for create image/database option
        elif arguments['create']==True:
            if arguments['image']==True:
                check_create_image_params(arguments, docker_client)
                preprocess_create_image_args(arguments)
                create_image(arguments, docker_client)
            elif arguments['database']==True:
                check_create_database_params(arguments, docker_client)
                preprocess_create_database_args(arguments)
                database=create_database_settings(arguments)
                restore_or_restart_or_create_database(arguments, database, docker_client)

    except KeyboardInterrupt as error:
        print('\nSee ya! ')
