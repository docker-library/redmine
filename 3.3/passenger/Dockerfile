FROM redmine:3.3

ENV PASSENGER_VERSION 5.3.5

RUN set -eux; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		gcc \
		make \
	; \
	rm -rf /var/lib/apt/lists/*; \
	\
	gem install passenger --version "$PASSENGER_VERSION"; \
# pre-build "passenger_native_support.so" while we have the compiler toolchain available
	passenger-config build-native-support; \
# the above command always exits with a zero exit code, but if we run it again and it was successful, it'll have empty output (that's the best way I can find to verify that it's worked)
	if [ -n "$(passenger-config build-native-support 2>&1)" ]; then cat /tmp/passenger_native_support-*.log; false; fi; \
	\
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

# pre-download the PassengerAgent and the NGINX engine
RUN set -eux; \
	passenger-config install-agent; \
	passenger-config download-nginx-engine

# adjust Passenger to write the PID to the same file as "rails server"
ENV PASSENGER_PID_FILE tmp/pids/server.pid

CMD ["passenger", "start"]
