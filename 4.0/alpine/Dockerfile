FROM ruby:2.6-alpine

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN addgroup -S redmine && adduser -S -G redmine redmine

RUN set -eux; \
	apk add --no-cache \
		bash \
		ca-certificates \
		su-exec \
		tini \
		tzdata \
		wget \
		\
		bzr \
		git \
		mercurial \
		openssh-client \
		subversion \
		\
# https://github.com/docker-library/redmine/issues/132
# (without "ghostscript-fonts" we get "Magick::ImageMagickError (non-conforming drawing primitive definition `text' @ error/draw.c/DrawImage/3265):")
		ghostscript-fonts \
		imagemagick6 \
	;

ENV RAILS_ENV production
WORKDIR /usr/src/redmine

# https://github.com/docker-library/redmine/issues/138#issuecomment-438834176
# (bundler needs this for running as an arbitrary user)
ENV HOME /home/redmine
RUN set -eux; \
	mkdir -p "$HOME"; \
	chown redmine:redmine "$HOME"; \
	chmod 1777 "$HOME"

ENV REDMINE_VERSION 4.0.4
ENV REDMINE_DOWNLOAD_MD5 35a4f60b35fed2b10d14cb12fc8aef50

RUN set -eux; \
	wget -O redmine.tar.gz "https://www.redmine.org/releases/redmine-${REDMINE_VERSION}.tar.gz"; \
	echo "$REDMINE_DOWNLOAD_MD5 *redmine.tar.gz" | md5sum -c -; \
	tar -xf redmine.tar.gz --strip-components=1; \
	rm redmine.tar.gz files/delete.me log/delete.me; \
	mkdir -p log public/plugin_assets sqlite tmp/pdf tmp/pids; \
	chown -R redmine:redmine ./; \
# fix permissions for running as an arbitrary user
	chmod -R ugo=rwX config db sqlite; \
	find log tmp -type d -exec chmod 1777 '{}' +

RUN set -eux; \
	\
	apk add --no-cache --virtual .build-deps \
		freetds-dev \
		gcc \
		imagemagick6-dev \
		make \
		mariadb-dev \
		musl-dev \
		patch \
		postgresql-dev \
		sqlite-dev \
		zlib-dev \
		\
# tiny_tds 1.0.x requires OpenSSL 1.0
# see https://github.com/rails-sqlserver/tiny_tds/commit/3269dd3bcfbe4201ab51aa2870a6aaddfcbdfa5d (tiny_tds 1.2.x+ is required for OpenSSL 1.1 support)
		openssl-dev \
	; \
#	su-exec redmine bundle config build.tiny_tds --enable-system-freetds; \
	\
	su-exec redmine bundle install --without development test; \
	for adapter in mysql2 postgresql sqlserver sqlite3; do \
		echo "$RAILS_ENV:" > ./config/database.yml; \
		echo "  adapter: $adapter" >> ./config/database.yml; \
		su-exec redmine bundle install --without development test; \
		cp Gemfile.lock "Gemfile.lock.${adapter}"; \
	done; \
	rm ./config/database.yml; \
# fix permissions for running as an arbitrary user
	chmod -R ugo=rwX Gemfile.lock "$GEM_HOME"; \
	chmod +x /usr/local/bundle/bin/*; \
	rm -rf ~redmine/.bundle

# Todo: remove build dependencies
#	runDeps="$( \
#		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/bundle/gems \
#		| tr ',' '\n' \
#		| sort -u \
#		| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
#	)"; \
#	apk add --virtual .redmine-rundeps $runDeps; \
#	apk del .build-deps

VOLUME /usr/src/redmine/files

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
