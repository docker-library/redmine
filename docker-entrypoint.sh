#!/bin/bash
set -e

case "$1" in
	rails|rake|passenger)
		if [ ! -f './config/database.yml' ]; then
			if [ "$MYSQL_PORT_3306_TCP" ]; then
				adapter='mysql2'
				host='mysql'
				port="${MYSQL_PORT_3306_TCP_PORT:-3306}"
				username="${MYSQL_ENV_MYSQL_USER:-root}"
				password="${MYSQL_ENV_MYSQL_PASSWORD:-$MYSQL_ENV_MYSQL_ROOT_PASSWORD}"
				database="${MYSQL_ENV_MYSQL_DATABASE:-${MYSQL_ENV_MYSQL_USER:-redmine}}"
				encoding=
			elif [ "$POSTGRES_PORT_5432_TCP" ]; then
				adapter='postgresql'
				host='postgres'
				port="${POSTGRES_PORT_5432_TCP_PORT:-5432}"
				username="${POSTGRES_ENV_POSTGRES_USER:-postgres}"
				password="${POSTGRES_ENV_POSTGRES_PASSWORD}"
				database="${POSTGRES_ENV_POSTGRES_DB:-$username}"
				encoding=utf8
			else
				echo >&2 'warning: missing MYSQL_PORT_3306_TCP or POSTGRES_PORT_5432_TCP environment variables'
				echo >&2 '  Did you forget to --link some_mysql_container:mysql or some-postgres:postgres?'
				echo >&2
				echo >&2 '*** Using sqlite3 as fallback. ***'
				
				adapter='sqlite3'
				host='localhost'
				username='redmine'
				database='sqlite/redmine.db'
				encoding=utf8
				
				mkdir -p "$(dirname "$database")"
				chown -R redmine:redmine "$(dirname "$database")"
			fi
			
			cat > './config/database.yml' <<-YML
				$RAILS_ENV:
				  adapter: $adapter
				  database: $database
				  host: $host
				  username: $username
				  password: "$password"
				  encoding: $encoding
				  port: $port
			YML
		fi
		
		# ensure the right database adapter is active in the Gemfile.lock
		bundle install --without development test
		
		if [ ! -s config/secrets.yml ]; then
			if [ "$REDMINE_SECRET_KEY_BASE" ]; then
				cat > 'config/secrets.yml' <<-YML
					$RAILS_ENV:
					  secret_key_base: "$REDMINE_SECRET_KEY_BASE"
				YML
			elif [ ! -f /usr/src/redmine/config/initializers/secret_token.rb ]; then
				rake generate_secret_token
			fi
		fi
		if [ "$1" != 'rake' -a -z "$REDMINE_NO_DB_MIGRATE" ]; then
			gosu redmine rake db:migrate
		fi
		
		chown -R redmine:redmine files log public/plugin_assets
		
		if [ "$1" = 'passenger' ]; then
			# Don't fear the reaper.
			set -- tini -- "$@"
		fi
		
		set -- gosu redmine "$@"
		;;
esac

exec "$@"
