#!/bin/bash

export APP_NAME="accountManager"
app_file=$APP_NAME-0.0.1.war
app_home=/var/workcenter/$APP_NAME
app_user=ec2-user
export MODE=service
export CONF_FOLDER=$app_home/conf
export PID_FOLDER=$app_home/pid
export LOG_FOLDER=/dev
export LOG_FILENAME=null
app_jar_path="$app_home/$APP_NAME-0.0.1.war"
app_profile="dev"
app_encoding="UTF-8"
app_port_http=8989
cuser=$(id -u -n)
#---------------------------------------------------------------------------------
JAVA_OPTS="$JAVA_OPTS -server ";
JAVA_OPTS="$JAVA_OPTS -Dfile.encoding=$app_encoding ";
JAVA_OPTS="$JAVA_OPTS -Duser.timezone=GMT+09:00 ";
JAVA_OPTS="$JAVA_OPTS -DSERVER_NAME=$APP_NAME ";
JAVA_OPTS="$JAVA_OPTS -Dapp.home=$app_home ";
JAVA_OPTS="$JAVA_OPTS -DLOG_DIR=$app_home/logs ";
JAVA_OPTS="$JAVA_OPTS -Dspring.profiles.active=$app_profile ";
JAVA_OPTS="$JAVA_OPTS -Dserver.port=$app_port_http ";
JAVA_OPTS="$JAVA_OPTS -XX:+UnlockExperimentalVMOptions ";
JAVA_OPTS="$JAVA_OPTS -XX:+UseParallelGC "
JAVA_OPTS="$JAVA_OPTS -XX:ActiveProcessorCount=2 ";
JAVA_OPTS="$JAVA_OPTS -Xms128m ";
JAVA_OPTS="$JAVA_OPTS -Xms128m ";
#---------------------------------------------------------------------------------
export JAVA_OPTS="$JAVA_OPTS "
#---------------------------------------------------------------------------------
init(){
    if [ ! -d $LOG_FOLDER ]; then
        mkdir $LOG_FOLDER
        chown $app_user:$app_user $LOG_FOLDER
        chmod 755 $LOG_FOLDER
    fi
    if [ ! -d $PID_FOLDER ]; then
        mkdir $PID_FOLDER
        chown $app_user:$app_user $PID_FOLDER
        chmod 755 $PID_FOLDER
    fi
    if [ ! -d $CONF_FOLDER ]; then
        mkdir $CONF_FOLDER
        chown $app_user:$app_user $CONF_FOLDER
        chmod 755 $CONF_FOLDER
    fi
    chown -R $app_user:$app_user $app_home
}
#---------------------------------------------------------------------------------
stop(){
    if [ "$cuser" == "$app_user" ]; then
        /bin/bash $app_jar_path stop
    else
        su $app_user -s /bin/bash -c "$app_jar_path stop"
    fi
}
#---------------------------------------------------------------------------------
start(){
    if [ "$cuser" == "$app_user" ]; then
        /bin/bash $app_jar_path start
    else
        su $app_user -s /bin/bash -c "$app_jar_path start"
    fi
    #tail -f $app_home/logs/ploonet.admin.api.log
}
#---------------------------------------------------------------------------------
status(){
    if [ "$cuser" == "$app_user" ]; then
        /bin/bash $app_jar_path status
    else
        su $app_user -s /bin/bash -c "$app_jar_path status"
    fi
}
#---------------------------------------------------------------------------------
restart(){
    if [ "$cuser" == "$app_user" ]; then
        /bin/bash $app_jar_path restart
    else
        su $app_user -s /bin/bash -c "$app_jar_path restart"
    fi
}
#---------------------------------------------------------------------------------
force_reload(){
    if [ "$cuser" == "$app_user" ]; then
        /bin/bash $app_jar_path force_reload
    else
        su $app_user -s /bin/bash -c "$app_jar_path force_reload"
    fi
}
#---------------------------------------------------------------------------------
force_stop(){
    if [ "$cuser" == "$app_user" ]; then
        /bin/bash $app_jar_path force_stop
    else
        su $app_user -s /bin/bash -c "$app_jar_path force_stop"
    fi
}
#---------------------------------------------------------------------------------

case "$1" in
start)
    init
    start
;;
stop)
    stop
;;
status)
    status
;;
restart)
    init
    restart
;;
force-reload)
    force_reload
;;
force-stop)
    force_stop
;;
*)
    echo "Usage: $0 [start stop status restart]";
    exit 0;
esac
exit 0
