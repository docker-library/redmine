#!/bin/bash
set -eo pipefail

# see https://www.redmine.org/projects/redmine/wiki/redmineinstall
defaultRubyVersion='2.4'
declare -A rubyVersions=(
	[3.3]='2.3'
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

relasesUrl='https://www.redmine.org/releases'
versionsPage=$(curl -fsSL "$relasesUrl")

passenger="$(curl -fsSL 'https://rubygems.org/api/v1/gems/passenger.json' | sed -r 's/^.*"version":"([^"]+)".*$/\1/')"

travisEnv=
for version in "${versions[@]}"; do
	fullVersion="$(echo $versionsPage | sed -r "s/.*($version\.[0-9]+)\.tar\.gz[^.].*/\1/" | sort -V | tail -1)"
	md5="$(curl -fsSL "$relasesUrl/redmine-$fullVersion.tar.gz.md5" | cut -d' ' -f1)"

	rubyVersion="${rubyVersions[$version]:-$defaultRubyVersion}"

	(
		set -x

		cp docker-entrypoint.sh "$version/"
		sed -e 's/%%REDMINE_VERSION%%/'"$fullVersion"'/' \
			-e 's/%%RUBY_VERSION%%/'"$rubyVersion"'/' \
			-e 's/%%REDMINE_DOWNLOAD_MD5%%/'"$md5"'/' \
			Dockerfile.template > "$version/Dockerfile"

		mkdir -p "$version/passenger"
		sed -e 's/%%REDMINE%%/redmine:'"$version"'/' \
			-e 's/%%PASSENGER_VERSION%%/'"$passenger"'/' \
			Dockerfile-passenger.template > "$version/passenger/Dockerfile"
	)

	travisEnv='\n  - VERSION='"$version$travisEnv"
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
