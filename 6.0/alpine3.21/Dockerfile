#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM ruby:3.3-alpine3.21

# explicitly set uid/gid to guarantee that it won't change in the future
# the values 999:999 are identical to the current user/group id assigned
# alpine already has a gid 999, so we'll use the next id
RUN addgroup -S -g 1000 redmine && adduser -S -H -G redmine -u 999 redmine

RUN set -eux; \
	apk add --no-cache \
		bash \
		breezy \
		ca-certificates \
		findutils \
		ghostscript \
		ghostscript-fonts \
		git \
		imagemagick \
		mercurial \
		openssh-client \
		subversion \
		tini \
		tzdata \
		wget \
	;

# grab gosu for easy step-down from root
# https://github.com/tianon/gosu/releases
ENV GOSU_VERSION 1.17
RUN set -eux; \
	\
	apk add --no-cache --virtual .gosu-deps \
		dpkg \
		gnupg \
	; \
	\
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	\
	apk del --no-network .gosu-deps; \
	\
# smoke test
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true

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

ENV REDMINE_VERSION 6.0.4
ENV REDMINE_DOWNLOAD_URL https://www.redmine.org/releases/redmine-6.0.4.tar.gz
ENV REDMINE_DOWNLOAD_SHA256 bebf8acb4fd1843f88e5f4285ff0b497fab43320c33e780a5c34e1124c5e177a
ENV RAILS_LOG_TO_STDOUT true

RUN set -eux; \
	wget -O redmine.tar.gz "$REDMINE_DOWNLOAD_URL"; \
	echo "$REDMINE_DOWNLOAD_SHA256 *redmine.tar.gz" | sha256sum -c -; \
	tar -xf redmine.tar.gz --strip-components=1; \
	rm redmine.tar.gz files/delete.me log/delete.me; \
	# https://www.redmine.org/projects/redmine/wiki/RedmineInstall#Step-8-File-system-permissions
	mkdir -p log public/assets public/plugin_assets sqlite tmp/pdf tmp/pids; \
	chown -R redmine:redmine ./; \
# fix permissions for running as an arbitrary user
	chmod -R ugo=rwX config db sqlite; \
	find log tmp -type d -exec chmod 1777 '{}' +

# build for musl-libc, not glibc (see https://github.com/sparklemotion/nokogiri/issues/2075, https://github.com/rubygems/rubygems/issues/3174)
ENV BUNDLE_FORCE_RUBY_PLATFORM 1
RUN set -eux; \
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
		yaml-dev \
		zlib-dev \
	; \
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
# https://github.com/naitoh/rbpdf/issues/31
	rm /usr/local/bundle/gems/rbpdf-font-1.19.*/lib/fonts/ttf2ufm/ttf2ufm; \
	\
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/bundle/gems \
		| tr ',' '\n' \
		| sort -u \
		| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-network --virtual .redmine-rundeps $runDeps; \
	apk del --no-network .build-deps

VOLUME /usr/src/redmine/files

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
