FROM ruby:2.7-slim-bullseye

# explicitly set uid/gid to guarantee that it won't change in the future
# the values 999:999 are identical to the current user/group id assigned
RUN groupadd -r -g 999 redmine && useradd -r -g redmine -u 999 redmine

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		curl \
		wget \
		\
		bzr \
		git \
		mercurial \
		openssh-client \
		subversion \
		\
# we need "gsfonts" for generating PNGs of Gantt charts
# and "ghostscript" for creating PDF thumbnails (in 4.1+)
		ghostscript \
		gsfonts \
		imagemagick \
# grab gosu for easy step-down from root
		gosu \
# grab tini for signal processing and zombie killing
		tini \
	; \
# allow imagemagick to use ghostscript for PDF -> PNG thumbnail conversion (4.1+)
	sed -ri 's/(rights)="none" (pattern="PDF")/\1="read" \2/' /etc/ImageMagick-6/policy.xml; \
	rm -rf /var/lib/apt/lists/*

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

ENV REDMINE_VERSION 4.2.8
ENV REDMINE_DOWNLOAD_URL https://www.redmine.org/releases/redmine-4.2.8.tar.gz
ENV REDMINE_DOWNLOAD_SHA256 0b431c052d8fd36b93201dafaf3615cdb8d03460efcf2400e7d32662b2ab6272

RUN set -eux; \
# if we use wget here, we get certificate issues (https://github.com/docker-library/redmine/pull/249#issuecomment-984176479)
	curl -fL -o redmine.tar.gz "$REDMINE_DOWNLOAD_URL"; \
	echo "$REDMINE_DOWNLOAD_SHA256 *redmine.tar.gz" | sha256sum -c -; \
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
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		default-libmysqlclient-dev \
		freetds-dev \
		gcc \
		libpq-dev \
		libsqlite3-dev \
		make \
		patch \
		xz-utils \
	; \
	rm -rf /var/lib/apt/lists/*; \
	\
	gosu redmine bundle config --local without 'development test'; \
# https://github.com/redmine/redmine/commit/23dc108e70a0794f444803ac827a690085dcd557
# ("gem puma" already exists in the Gemfile, but under "group :test" and we want it all the time)
	puma="$(grep -E "^[[:space:]]*gem [:'\"]puma['\",[:space:]].*\$" Gemfile)"; \
	{ echo; echo "$puma"; } | sed -re 's/^[[:space:]]+//' >> Gemfile; \
# fill up "database.yml" with bogus entries so the redmine Gemfile will pre-install all database adapter dependencies
# https://github.com/redmine/redmine/blob/e9f9767089a4e3efbd73c35fc55c5c7eb85dd7d3/Gemfile#L50-L79
	echo '# the following entries only exist to force `bundle install` to pre-install all database adapter dependencies -- they can be safely removed/ignored' > ./config/database.yml; \
	for adapter in mysql2 postgresql sqlserver sqlite3; do \
		echo "$adapter:" >> ./config/database.yml; \
		echo "  adapter: $adapter" >> ./config/database.yml; \
	done; \
	gosu redmine bundle install --jobs "$(nproc)"; \
	rm ./config/database.yml; \
# fix permissions for running as an arbitrary user
	chmod -R ugo=rwX Gemfile.lock "$GEM_HOME"; \
	rm -rf ~redmine/.bundle; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
	find /usr/local -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { print $(NF-1) }' \
		| sort -u \
		| grep -v '^/usr/local/' \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

VOLUME /usr/src/redmine/files

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
