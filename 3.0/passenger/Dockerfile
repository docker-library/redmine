FROM redmine:3.0

ENV PASSENGER_VERSION 5.0.20
RUN buildDeps=' \
		make \
	' \
	&& set -x \
	&& apt-get update && apt-get install -y --no-install-recommends $buildDeps && rm -rf /var/lib/apt/lists/* \
	&& gem install passenger --version "$PASSENGER_VERSION" \
	&& apt-get purge -y --auto-remove $buildDeps
RUN set -x \
	&& passenger-config install-agent \
	&& passenger-config install-standalone-runtime

CMD ["passenger", "start"]
