#!/bin/bash
set -eo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

relasesUrl='https://www.redmine.org/releases'
versionsPage=$(curl -fsSL "$relasesUrl")

passenger="$(curl -fsSL 'https://rubygems.org/api/v1/gems/passenger.json' | sed -r 's/^.*"version":"([^"]+)".*$/\1/')"
( set -x && sed -ri 's/^(ENV PASSENGER_VERSION) .*/\1 '"$passenger"'/;' Dockerfile*.template )

for version in "${versions[@]}"; do
	fullVersion="$(echo $versionsPage | sed -r "s/.*($version\.[0-9]+)\.tar\.gz[^.].*/\1/" | sort -V | tail -1)"
	md5="$(curl -fsSL "$relasesUrl/redmine-$fullVersion.tar.gz.md5" | cut -d' ' -f1)"
	
	(
		set -x
		
		cp docker-entrypoint.sh "$version/"
		sed 's/%%REDMINE_DOWNLOAD_MD5%%/'"$md5"'/; s/%%REDMINE_VERSION%%/'"$fullVersion"'/' Dockerfile.template > "$version/Dockerfile"
		
		mkdir -p "$version/passenger"
		sed 's/%%REDMINE%%/redmine:'"$version"'/' Dockerfile-passenger.template > "$version/passenger/Dockerfile"
	)
done

