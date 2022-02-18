#!/usr/bin/env bash
set -Eeuo pipefail

# see https://www.redmine.org/projects/redmine/wiki/redmineinstall
defaultRubyVersion='2.7'
declare -A rubyVersions=(
	[4.1]='2.6'
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

relasesUrl='https://www.redmine.org/releases'
versionsPage="$(curl -fsSL "$relasesUrl")"

passenger="$(curl -fsSL 'https://rubygems.org/api/v1/gems/passenger.json' | sed -r 's/^.*"version":"([^"]+)".*$/\1/')"

for version in "${versions[@]}"; do
	fullVersion="$(sed <<<"$versionsPage" -rn "s/.*($version\.[0-9]+)\.tar\.gz[^.].*/\1/p" | sort -V | tail -1)"
	sha256="$(curl -fsSL "$relasesUrl/redmine-$fullVersion.tar.gz.sha256" | cut -d' ' -f1)"

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

	mkdir -p "$version"
	cp docker-entrypoint.sh "$version/"
	sed "${commonSedArgs[@]}" Dockerfile-debian.template > "$version/Dockerfile"

	mkdir -p "$version/passenger"
	sed "${commonSedArgs[@]}" Dockerfile-passenger.template > "$version/passenger/Dockerfile"

	mkdir -p "$version/alpine"
	cp docker-entrypoint.sh "$version/alpine/"
	sed -i -e 's/gosu/su-exec/g' "$version/alpine/docker-entrypoint.sh"
	sed "${commonSedArgs[@]}" Dockerfile-alpine.template > "$version/alpine/Dockerfile"
done
