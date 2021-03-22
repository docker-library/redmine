#!/usr/bin/env bash
set -Eeuo pipefail

# see https://www.redmine.org/projects/redmine/wiki/redmineinstall
defaultRubyVersion='2.6'
declare -A rubyVersions=(
	#[3.4]='2.4'
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

relasesUrl='https://www.redmine.org/releases'
versionsPage="$(wget -qO- "$relasesUrl")"

passenger="$(wget -qO- 'https://rubygems.org/api/v1/gems/passenger.json' | sed -r 's/^.*"version":"([^"]+)".*$/\1/')"

for version in "${versions[@]}"; do
	fullVersion="$(echo $versionsPage | sed -r "s/.*($version\.[0-9]+)\.tar\.gz[^.].*/\1/" | sort -V | tail -1)"
	sha256="$(wget -qO- "$relasesUrl/redmine-$fullVersion.tar.gz.sha256" | cut -d' ' -f1)"

	rubyVersion="${rubyVersions[$version]:-$defaultRubyVersion}"

	echo "$version: $fullVersion (ruby $rubyVersion; passenger $passenger)"

	commonSedArgs=(
		-r
		-e 's/%%REDMINE_VERSION%%/'"$fullVersion"'/'
		-e 's/%%RUBY_VERSION%%/'"$rubyVersion"'/'
		-e 's/%%REDMINE_DOWNLOAD_SHA256%%/'"$sha256"'/'
		-e 's/%%REDMINE%%/redmine:'"$version"'/'
		-e 's/%%PASSENGER_VERSION%%/'"$passenger"'/'
	)
	alpineSedArgs=()

	# https://github.com/docker-library/redmine/pull/184
	# https://www.redmine.org/issues/22481
	# https://www.redmine.org/issues/30492
	if [ "$version" = 4.0 ]; then
		commonSedArgs+=(
			-e '/ghostscript /d'
		)
		alpineSedArgs+=(
			-e 's/imagemagick/imagemagick6/g'
		)
	else
		commonSedArgs+=(
			-e '/imagemagick-dev/d'
			-e '/libmagickcore-dev/d'
			-e '/libmagickwand-dev/d'
		)
	fi

	cp docker-entrypoint.sh "$version/"
	sed "${commonSedArgs[@]}" Dockerfile-debian.template > "$version/Dockerfile"

	mkdir -p "$version/passenger"
	sed "${commonSedArgs[@]}" Dockerfile-passenger.template > "$version/passenger/Dockerfile"

	mkdir -p "$version/alpine"
	cp docker-entrypoint.sh "$version/alpine/"
	sed -i -e 's/gosu/su-exec/g' "$version/alpine/docker-entrypoint.sh"
	sed "${commonSedArgs[@]}" "${alpineSedArgs[@]}" Dockerfile-alpine.template > "$version/alpine/Dockerfile"
done
