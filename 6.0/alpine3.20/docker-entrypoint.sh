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
	rails | rake ) isLikelyRedmine=1 ;;
esac

_fix_permissions() {
	# https://www.redmine.org/projects/redmine/wiki/RedmineInstall#Step-8-File-system-permissions
	local dirs=( config log public/assets public/plugin_assets tmp ) args=()
	if [ "$(id -u)" = '0' ]; then
		args+=( ${args[@]:+,} '(' '!' -user redmine -exec chown redmine:redmine '{}' + ')' )

		# https://github.com/docker-library/redmine/issues/268 - scanning "files" might be *really* expensive, so we should skip it if it seems like it's "already correct"
		local filesOwnerMode
		filesOwnerMode="$(stat -c '%U:%a' files)"
		if [ "$filesOwnerMode" != 'redmine:755' ]; then
			dirs+=( files )
		fi
	fi
	# directories 755, files 644:
	args+=( ${args[@]:+,} '(' -type d '!' -perm 755 -exec sh -c 'chmod 755 "$@" 2>/dev/null || :' -- '{}' + ')' )
	args+=( ${args[@]:+,} '(' -type f '!' -perm 644 -exec sh -c 'chmod 644 "$@" 2>/dev/null || :' -- '{}' + ')' )
	find "${dirs[@]}" "${args[@]}"
}

# allow the container to be started with `--user`
if [ -n "$isLikelyRedmine" ] && [ "$(id -u)" = '0' ]; then
	_fix_permissions
	exec gosu redmine "$BASH_SOURCE" "$@"
fi

if [ -n "$isLikelyRedmine" ]; then
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
			if [ "$var" != 'adapter' ]; then
				# https://github.com/docker-library/redmine/issues/353 🙃
				val='"'"$val"'"'
				# (only add double quotes to every value *except* `adapter: xxx`)
			fi
			echo "  $var: $val" >> config/database.yml
		done
	fi

	# Create and fill smtp config/configuration.yml
	if [ ! -f './config/configuration.yml' ]; then
		# NOW ONLY SMTP SETTINGS AVAILABLE!!!
		if [ "$REDMINE_EMAIL_DELIVERY_METHOD" == "smtp" ]; then
			echo "$RAILS_ENV:" > config/configuration.yml
			echo "  email_delivery:" >> config/configuration.yml
			echo "    delivery_method: :$REDMINE_EMAIL_DELIVERY_METHOD" >> config/configuration.yml
			echo "    smtp_settings:" >> config/configuration.yml
			for var in \
				address \
				port \
				ssl \
				enable_starttls_auto \
				openssl_verify_mode \
				authentication \
				user_name \
				password \
			; do
				env="REDMINE_EMAIL_DELIVERY_SMTP_${var^^}"
				val="${!env}"
				[ -n "$val" ] || continue

				if [ "$var" == 'authentication' ]; then
					# add `:` prefix for field `authentication`
					val=":$val"
				fi

				echo "      $var: $val" >> config/configuration.yml
			done
		else
			echo >&2
			echo >&2 'warning: missing REDMINE_EMAIL_DELIVERY_METHOD environment variable. File ./config/configuration.yml not created.'
			echo >&2
		fi
	fi

	# install additional gems for Gemfile.local and plugins
	bundle check || bundle install

	file_env 'REDMINE_SECRET_KEY_BASE'
	# just use the rails variable rather than trying to put it into a yml file
	# https://github.com/rails/rails/blob/6-1-stable/railties/lib/rails/application.rb#L438
	# https://github.com/rails/rails/blob/1aa9987169213ce5ce43c20b2643bc64c235e792/railties/lib/rails/application.rb#L484 (rails 7.1-stable)
	if [ -n "${SECRET_KEY_BASE}" ] && [ -n "${REDMINE_SECRET_KEY_BASE}" ]; then
		echo >&2
		echo >&2 'warning: both SECRET_KEY_BASE and REDMINE_SECRET_KEY_BASE{_FILE} set, only SECRET_KEY_BASE will apply'
		echo >&2
	fi
	: "${SECRET_KEY_BASE:=$REDMINE_SECRET_KEY_BASE}"
	export SECRET_KEY_BASE
	# generate SECRET_KEY_BASE if not set; this is not recommended unless the secret_token.rb is saved when container is recreated
	if [ -z "$SECRET_KEY_BASE" ] && [ ! -f config/initializers/secret_token.rb ]; then
		echo >&2 'warning: no *SECRET_KEY_BASE set; running `rake generate_secret_token` to create one in "config/initializers/secret_token.rb"'
		unset SECRET_KEY_BASE # just in case
		rake generate_secret_token
	fi

	if [ "$1" != 'rake' -a -z "$REDMINE_NO_DB_MIGRATE" ]; then
		rake db:migrate
	fi

	if [ "$1" != 'rake' -a -n "$REDMINE_PLUGINS_MIGRATE" ]; then
		rake redmine:plugins:migrate
	fi

	# remove PID file to enable restarting the container
	rm -f tmp/pids/server.pid
fi

exec "$@"
