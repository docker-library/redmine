FROM ruby:2.6-alpine3.13

# explicitly set uid/gid to guarantee that it won't change in the future
# the values 999:999 are identical to the current user/group id assigned
# alpine already has a gid 999, so we'll use the next id
RUN addgroup -S -g 1000 redmine && adduser -S -H -G redmine -u 999 redmine

RUN set -eux; \
	apk add --no-cache \
		bash \
		ca-certificates \
		su-exec \
		tini \
		tzdata \
		wget \
		\
		git \
		mercurial \
		openssh-client \
		subversion \
		\
# we need "gsfonts" for generating PNGs of Gantt charts
# and "ghostscript" for creating PDF thumbnails (in 4.1+)
		ghostscript \
		ghostscript-fonts \
		imagemagick \
	;

ENV RAILS_ENV production
WORKDIR /usr/src/redmine

# https://github.com/docker-library/redmine/issues/138#issuecomment-438834176
# (bundler needs this for running as an arbitrary user)
ENV HOME /home/redmine
RUN set -eux; \
	[ ! -d "$HOME" ]; \
	mkdir -p "$HOME"; \
	chown redmine:redmine "$HOME"; \
	chmod 1777 "$HOME"

ENV REDMINE_VERSION 4.1.1
ENV REDMINE_DOWNLOAD_MD5 a15a25dec7b866e213bbd4b041f05f17

RUN set -eux; \
	wget -O redmine.tar.gz "https://www.redmine.org/releases/redmine-${REDMINE_VERSION}.tar.gz"; \
	echo "$REDMINE_DOWNLOAD_MD5 *redmine.tar.gz" | md5sum -c -; \
	tar -xf redmine.tar.gz --strip-components=1; \
	rm redmine.tar.gz files/delete.me log/delete.me; \
	mkdir -p log public/plugin_assets sqlite tmp/pdf tmp/pids; \
	chown -R redmine:redmine ./; \
# log to STDOUT (https://github.com/docker-library/redmine/issues/108)
	echo 'config.logger = Logger.new(STDOUT)' > config/additional_environment.rb; \
# fix permissions for running as an arbitrary user
	chmod -R ugo=rwX config db sqlite; \
	find log tmp -type d -exec chmod 1777 '{}' +

RUN set -eux; \
	\
	apk add --no-cache --virtual .build-deps \
		coreutils \
		freetds-dev \
		gcc \
		make \
		mariadb-dev \
		musl-dev \
		patch \
		postgresql-dev \
		sqlite-dev \
		ttf2ufm \
		zlib-dev \
	; \
	\
	su-exec redmine bundle install --jobs "$(nproc)" --without development test; \
	for adapter in mysql2 postgresql sqlserver sqlite3; do \
		echo "$RAILS_ENV:" > ./config/database.yml; \
		echo "  adapter: $adapter" >> ./config/database.yml; \
		su-exec redmine bundle install --jobs "$(nproc)" --without development test; \
		cp Gemfile.lock "Gemfile.lock.${adapter}"; \
	done; \
	rm ./config/database.yml; \
# fix permissions for running as an arbitrary user
	chmod -R ugo=rwX Gemfile.lock "$GEM_HOME"; \
# this requires coreutils because "chmod +X" in busybox will remove +x on files (and coreutils leaves files alone with +X)
	rm -rf ~redmine/.bundle; \
	\
# https://github.com/naitoh/rbpdf/issues/31
	rm /usr/local/bundle/gems/rbpdf-font-1.19.*/lib/fonts/ttf2ufm/ttf2ufm; \
	\
	runDeps="$( \
		find /usr/local -type f -executable -exec ldd '{}' ';' \
			| awk '/=>/ { print $(NF-1) }' \
			| sort -u \
			| grep -v '^/usr/local/' \
			| xargs -rn1 basename \
			| grep -v 'ld-musl-' \
			| sed -e 's/^/so:/' \
			| sort -u \
	)"; \
	apk add --no-network --virtual .redmine-rundeps $runDeps; \
	apk del --no-network .build-deps

VOLUME /usr/src/redmine/files

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
