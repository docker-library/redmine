#!/bin/bash
set -e

if [ "$1" = 'rails' ]; then
	if [ ! -f './config/database.yml' ]; then
		if [ "$MYSQL_PORT_3306_TCP" ]; then
			adapter='mysql'
			host="${MYSQL_PORT_3306_TCP_ADDR:-mysql}"
			port="${MYSQL_PORT_3306_TCP_PORT:-3306}"
			username="${MYSQL_ENV_MYSQL_USER:-root}"
			password="${MYSQL_ENV_MYSQL_PASSWORD:-$MYSQL_ENV_MYSQL_ROOT_PASSWORD}"
			database="${MYSQL_DATABASE:-${MYSQL_ENV_MYSQL_USER:-redmine}}"
			encoding=
		elif [ "$POSTGRES_PORT_5432_TCP" ]; then
			adapter='postgresql'
			host="${POSTGRES_PORT_5432_TCP_ADDR:-postgres}"
			port="${POSTGRES_PORT_5432_TCP_PORT:-5432}"
			username="${POSTGRES_ENV_POSTGRES_USER:-postgres}"
			password="${POSTGRES_ENV_POSTGRES_PASSWORD}"
			database="${POSTGRES_ENV_POSTGRES_DB:-$username}"
			encoding=utf8
		else
			echo >&2 'error: missing MYSQL_PORT_3306_TCP or POSTGRES_PORT_5432_TCP environment variables'
			echo >&2 '  Did you forget to --link some_mysql_container:mysql or some-postgres:postgres?'
			exit 1
		fi
		cat > './config/database.yml' <<-YML
			production:
			  adapter: $adapter
			  database: $database
			  host: $host
			  username: $username
			  password: "$password"
			  encoding: $encoding
		YML
	fi
fi

exec "$@"
