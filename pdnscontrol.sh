#!/bin/bash
set -e
set -x
set -u

cd ~pdnscontrol/pdnscontrol
cat > instance/pdnscontrol.conf << __EOF__
DATABASE_URI = 'mysql://pdnscontrol@${MYSQL_1_PORT_3306_TCP_ADDR}/pdnscontrol'
GRAPHITE_SERVER = 'http://127.0.0.1/render/'
SECRET_KEY = 'supersecretdemokey'
SECURITY_PASSWORD_SALT = 'supersecretdemosalt'
SECURITY_PASSWORD_HASH='pbkdf2_sha512'
__EOF__

cat > /etc/powerdns/pdns.conf << __EOF__
experimental-json-interface=yes
experimental-logfile=/var/log/messages
webserver=yes
webserver-password=pdnscontrol

gmysql-dbname=pdns
gmysql-host=${MYSQL_1_PORT_3306_TCP_ADDR}
gmysql-user=pdns
gmysql-password=
launch=gmysql

carbon-server=127.0.0.1
carbon-ourname=auth

default-soa-name=ns.example.com
__EOF__

cat > /etc/powerdns/recursor.conf << __EOF__
auth-zones=
experimental-api-config-dir=/etc/powerdns/recursor.conf.d
experimental-logfile=/var/log/messages
experimental-webserver-port=8082
experimental-webserver=yes
experimental-webserver-password=pdnscontrol
include-dir=/etc/powerdns/recursor.conf.d

local-address=0.0.0.0
local-port=54

carbon-server=127.0.0.1
carbon-ourname=recursor
__EOF__

mkdir /etc/powerdns/recursor.conf.d

echo CARBON_CACHE_ENABLED=true > /etc/default/graphite-carbon

service carbon-cache start
service apache2 start

sleep 10

for db in pdnscontrol pdns
do
	mysql -h ${MYSQL_1_PORT_3306_TCP_ADDR} -u root --password=${MYSQL_1_ENV_MYSQL_ROOT_PASSWORD} -e "drop database if exists ${db}; create database ${db}; grant all on ${db}.* to '${db}'@'%';"
done

mysql -h ${MYSQL_1_PORT_3306_TCP_ADDR} -u pdns pdns < /schema.mysql.sql

su - pdnscontrol -c 'cd pdnscontrol ; . venv-pdnscontrol/bin/activate ; python install.py ; python manage.py assets --parse-templates build'

service pdns start
service pdns-recursor start

echo root:root | chpasswd
sed -i -e s/without-password/yes/ /etc/ssh/sshd_config
service ssh start

/opt/pdnscontrol/pdnscontrol/venv-pdnscontrol/bin/gunicorn --chdir /opt/pdnscontrol/pdnscontrol/ -u pdnscontrol -w 5 -b :8000 --log-level debug  --error-logfile /dev/stderr pdnscontrol:app
