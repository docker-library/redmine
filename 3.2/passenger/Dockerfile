FROM redmine:3.2

ENV PASSENGER_VERSION 5.3.0

RUN buildDeps=' \
		make \
	' \
	&& set -x \
	&& apt-get update && apt-get install -y --no-install-recommends $buildDeps && rm -rf /var/lib/apt/lists/* \
	&& gem install passenger --version "$PASSENGER_VERSION" \
	&& apt-get purge -y --auto-remove $buildDeps

# pre-download the PassengerAgent and the NGINX engine
RUN set -x \
	&& passenger-config install-agent \
	&& passenger-config download-nginx-engine

CMD ["passenger", "start"]
