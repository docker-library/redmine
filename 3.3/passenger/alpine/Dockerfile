FROM redmine:3.3-alpine

ENV PASSENGER_VERSION 5.1.1
RUN buildDeps=' \
		make \
		wget \
		linux-headers \
		gcc \
		g++ \
		openssl-dev \
		zlib-dev \
		curl-dev \
		pcre-dev \
	' \
	&& set -x \
	&& apk add --no-cache --virtual .build-deps ${buildDeps} \
	&& gem install passenger --version "$PASSENGER_VERSION" \
	&& passenger-config install-standalone-runtime \
	&& passenger-config build-native-support \
	&& rm -fr /tmp/passenger* ${HOME}/.[^.]* \
	&& apk del .build-deps

CMD ["passenger", "start"]
