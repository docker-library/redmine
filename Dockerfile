FROM ruby:2.2-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
		imagemagick \
		libpq5 \
		mysql-common \
	&& rm -rf /var/lib/apt/lists/*

ENV RAILS_ENV production
WORKDIR /usr/src/redmine

ENV REDMINE_VERSION 3.0.3
ENV REDMINE_DOWNLOAD_MD5 493463eff3ba9267233648536c59eb85

RUN curl -fSL "http://www.redmine.org/releases/redmine-${REDMINE_VERSION}.tar.gz" -o redmine.tar.gz \
	&& echo "$REDMINE_DOWNLOAD_MD5 redmine.tar.gz" | md5sum -c - \
	&& tar -xvf redmine.tar.gz --strip-components=1 \
	&& rm redmine.tar.gz files/delete.me

RUN buildDeps='gcc libmagickcore-dev libmagickwand-dev libmysqlclient-dev libpq-dev patch make' \
	&& set -x \
	&& apt-get update && apt-get install -y $buildDeps --no-install-recommends \
	&& rm -rf /var/lib/apt/lists/* \
	&& bundle install --without development test \
	&& gem install mysql pg \
	&& apt-get purge -y --auto-remove $buildDeps


VOLUME /usr/src/redmine/files

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["rails", "server"]
