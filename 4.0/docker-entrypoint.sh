#!/usr/bin/env bash
set -Eeo pipefail
# TODO add "-u"

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

isLikelyRedmine=
case "$1" in
	rails | rake | passenger ) isLikelyRedmine=1 ;;
esac

_fix_permissions() {
	# https://www.redmine.org/projects/redmine/wiki/RedmineInstall#Step-8-File-system-permissions
	if [ "$(id -u)" = '0' ]; then
		find config files log public/plugin_assets \! -user redmine -exec chown redmine:redmine '{}' +
	fi
	# directories 755, files 644:
	find config files log public/plugin_assets tmp -type d \! -perm 755 -exec chmod 755 '{}' + 2>/dev/null || :
	find config files log public/plugin_assets tmp -type f \! -perm 644 -exec chmod 644 '{}' + 2>/dev/null || :
}

# allow the container to be started with `--user`
if [ -n "$isLikelyRedmine" -o -n "$PREPARE_ENVIRONMENT" ] && [ "$(id -u)" = '0' ]; then
	_fix_permissions
	exec gosu redmine "$BASH_SOURCE" "$@"
fi

if [ -n "$isLikelyRedmine" -o -n "$PREPARE_ENVIRONMENT" ]; then
	_fix_permissions
	if [ ! -f './config/database.yml' ]; then
		file_env 'REDMINE_DB_MYSQL'
		file_env 'REDMINE_DB_POSTGRES'
		file_env 'REDMINE_DB_SQLSERVER'

		if [ "$MYSQL_PORT_3306_TCP" ] && [ -z "$REDMINE_DB_MYSQL" ]; then
			export REDMINE_DB_MYSQL='mysql'
		elif [ "$POSTGRES_PORT_5432_TCP" ] && [ -z "$REDMINE_DB_POSTGRES" ]; then
			export REDMINE_DB_POSTGRES='postgres'
		fi

		if [ "$REDMINE_DB_MYSQL" ]; then
			adapter='mysql2'
			host="$REDMINE_DB_MYSQL"
			file_env 'REDMINE_DB_PORT' '3306'
			file_env 'REDMINE_DB_USERNAME' "${MYSQL_ENV_MYSQL_USER:-root}"
			file_env 'REDMINE_DB_PASSWORD' "${MYSQL_ENV_MYSQL_PASSWORD:-${MYSQL_ENV_MYSQL_ROOT_PASSWORD:-}}"
			file_env 'REDMINE_DB_DATABASE' "${MYSQL_ENV_MYSQL_DATABASE:-${MYSQL_ENV_MYSQL_USER:-redmine}}"
			file_env 'REDMINE_DB_ENCODING' ''
		elif [ "$REDMINE_DB_POSTGRES" ]; then
			adapter='postgresql'
			host="$REDMINE_DB_POSTGRES"
			file_env 'REDMINE_DB_PORT' '5432'
			file_env 'REDMINE_DB_USERNAME' "${POSTGRES_ENV_POSTGRES_USER:-postgres}"
			file_env 'REDMINE_DB_PASSWORD' "${POSTGRES_ENV_POSTGRES_PASSWORD}"
			file_env 'REDMINE_DB_DATABASE' "${POSTGRES_ENV_POSTGRES_DB:-${REDMINE_DB_USERNAME:-}}"
			file_env 'REDMINE_DB_ENCODING' 'utf8'
		elif [ "$REDMINE_DB_SQLSERVER" ]; then
			adapter='sqlserver'
			host="$REDMINE_DB_SQLSERVER"
			file_env 'REDMINE_DB_PORT' '1433'
			file_env 'REDMINE_DB_USERNAME' ''
			file_env 'REDMINE_DB_PASSWORD' ''
			file_env 'REDMINE_DB_DATABASE' ''
			file_env 'REDMINE_DB_ENCODING' ''
		else
			echo >&2
			echo >&2 'warning: missing REDMINE_DB_MYSQL, REDMINE_DB_POSTGRES, or REDMINE_DB_SQLSERVER environment variables'
			echo >&2
			echo >&2 '*** Using sqlite3 as fallback. ***'
			echo >&2

			adapter='sqlite3'
			host='localhost'
			file_env 'REDMINE_DB_PORT' ''
			file_env 'REDMINE_DB_USERNAME' 'redmine'
			file_env 'REDMINE_DB_PASSWORD' ''
			file_env 'REDMINE_DB_DATABASE' 'sqlite/redmine.db'
			file_env 'REDMINE_DB_ENCODING' 'utf8'

			mkdir -p "$(dirname "$REDMINE_DB_DATABASE")"
			if [ "$(id -u)" = '0' ]; then
				find "$(dirname "$REDMINE_DB_DATABASE")" \! -user redmine -exec chown redmine '{}' +
			fi
		fi

		REDMINE_DB_ADAPTER="$adapter"
		REDMINE_DB_HOST="$host"
		echo "$RAILS_ENV:" > config/database.yml
		for var in \
			adapter \
			host \
			port \
			username \
			password \
			database \
			encoding \
		; do
			env="REDMINE_DB_${var^^}"
			val="${!env}"
			[ -n "$val" ] || continue
			echo "  $var: \"$val\"" >> config/database.yml
		done
	else
		# parse the database config to get the database adapter name
		# so we can use the right Gemfile.lock
		# (https://github.com/redmine/redmine/blob/dd24d5a004c6f0e137f0a3520d77ca3d704f1d66/Gemfile#L42-L71)
		adapter="$(ruby -e "
			require 'yaml'
			require 'erb'
			conf = YAML.load(ERB.new(File.read('./config/database.yml')).result)
			puts conf[ENV['RAILS_ENV']]['adapter']
		")"
	fi

	# ensure the right database adapter is active in the Gemfile.lock
	cp "Gemfile.lock.${adapter}" Gemfile.lock
	# install additional gems for Gemfile.local and plugins
	bundle check || bundle install --without development test

	if [ ! -s config/secrets.yml ]; then
		file_env 'REDMINE_SECRET_KEY_BASE'
		if [ -n "$REDMINE_SECRET_KEY_BASE" ]; then
			cat > 'config/secrets.yml' <<-YML
				$RAILS_ENV:
				  secret_key_base: "$REDMINE_SECRET_KEY_BASE"
			YML
		elif [ ! -f config/initializers/secret_token.rb ]; then
			rake generate_secret_token
		fi
	fi
	if [ "$1" != 'rake' -a -z "$REDMINE_NO_DB_MIGRATE" ]; then
		rake db:migrate
	fi

	if [ "$1" != 'rake' -a -n "$REDMINE_PLUGINS_MIGRATE" ]; then
		rake redmine:plugins:migrate
	fi

	# remove PID file to enable restarting the container
	rm -f tmp/pids/server.pid

	if [ "$1" = 'passenger' ]; then
		# Don't fear the reaper.
		set -- tini -- "$@"
	fi
fi

exec "$@"
