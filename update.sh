#!/usr/bin/env bash
set -Eeuo pipefail

# see https://www.redmine.org/projects/redmine/wiki/redmineinstall
defaultRubyVersion='2.6'
declare -A rubyVersions=(
	[3.4]='2.4'
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

travisEnv=
for version in "${versions[@]}"; do
	fullVersion="$(echo $versionsPage | sed -r "s/.*($version\.[0-9]+)\.tar\.gz[^.].*/\1/" | sort -V | tail -1)"
	md5="$(wget -qO- "$relasesUrl/redmine-$fullVersion.tar.gz.md5" | cut -d' ' -f1)"

	rubyVersion="${rubyVersions[$version]:-$defaultRubyVersion}"

	echo "$version: $fullVersion (ruby $rubyVersion; passenger $passenger)"

	sed -e 's/%%SUDO_CMD%%/'"gosu"'/' \
		docker-entrypoint.sh > "$version/docker-entrypoint.sh"
	sed -e 's/%%REDMINE_VERSION%%/'"$fullVersion"'/' \
		-e 's/%%RUBY_VERSION%%/'"$rubyVersion"'/' \
		-e 's/%%REDMINE_DOWNLOAD_MD5%%/'"$md5"'/' \
		Dockerfile-debian.template > "$version/Dockerfile"

	mkdir -p "$version/alpine"
	sed -e 's/%%SUDO_CMD%%/'"su-exec"'/' \
		docker-entrypoint.sh > "$version/alpine/docker-entrypoint.sh"
	sed -e 's/%%REDMINE_VERSION%%/'"$fullVersion"'/' \
		-e 's/%%RUBY_VERSION%%/'"$rubyVersion"'/' \
		-e 's/%%REDMINE_DOWNLOAD_MD5%%/'"$md5"'/' \
		Dockerfile-alpine.template > "$version/alpine/Dockerfile"

	mkdir -p "$version/passenger"
	sed -e 's/%%REDMINE%%/redmine:'"$version"'/' \
		-e 's/%%PASSENGER_VERSION%%/'"$passenger"'/' \
		Dockerfile-passenger.template > "$version/passenger/Dockerfile"

	travisEnv='\n  - VERSION='"$version$travisEnv"
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
