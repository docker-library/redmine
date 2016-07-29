#!/bin/bash -e

if test -z "$MYSQL_ENV_MYSQL_DATABASE" -o -z "$MYSQL_ENV_MYSQL_USER" -o -z "$MYSQL_ENV_MYSQL_PASSWORD" -a "$MYSQL_ENV_MYSQL_MAJOR" = "5.6"; then
    echo "**** ERROR: you must link to a MySQL container: --link container:mysql" 1>&2
    echo "            the MySQL container must have set the following environment variables:" 1>&2
    echo "             - MYSQL_DATABASE" 1>&2
    echo "             - MYSQL_USER" 1>&2
    echo "             - MYSQL_PASSWORD" 1>&2
    echo "            Redmine only supports MySQL 5.6, not 5.7" 1>&2
    exit 1
fi
if test -f /firstrun; then
    mkdir -p /etc/redmine/default
    cat > /etc/redmine/default/database.yml <<EOF
production:
  adapter: mysql
  database: ${MYSQL_ENV_MYSQL_DATABASE}
  host: mysql
  port: 
  username: ${MYSQL_ENV_MYSQL_USER}
  password: ${MYSQL_ENV_MYSQL_PASSWORD}
  encoding: utf8
EOF
    debconf-set-selections <<EOF
redmine redmine/instances/default/dbconfig-install      boolean false
redmine redmine/instances/default/dbconfig-reinstall    boolean false
redmine redmine/instances/default/dbconfig-remove       boolean false
redmine redmine/instances/default/dbconfig-upgrade      boolean false
EOF
    DEBIAN_FRONTEND=noninteractive apt-get install --no-download -y redmine-mysql
    chown -R www-data:www-data /usr/share/redmine
    rm /firstrun
fi

if test -f /run/apache2/apache2.pid; then
    rm /run/apache2/apache2.pid;
fi;
apache2ctl -DFOREGROUND
