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

	sedExpr='
			s/%%REDMINE_VERSION%%/'"$fullVersion"'/;
			s/%%RUBY_VERSION%%/'"$rubyVersion"'/;
			s/%%REDMINE_DOWNLOAD_MD5%%/'"$md5"'/;
			s/%%REDMINE%%/redmine:'"$version"'/;
			s/%%PASSENGER_VERSION%%/'"$passenger"'/;
		'
	sedAlpineExpr="$sedExpr"
	sedDebianExpr="$sedExpr"

	if [ "$version" = 3.4 ] || [ "$version" = 4.0 ]; then
		sedAlpineExpr+='
			s/imagemagick /imagemagick6 /;
			/ghostscript /d;
			/gcc/a \\t\timagemagick6-dev \\
		'
		sedDebianExpr+='
			/ghostscript /d;
			/gcc/a \\t\tlibmagickcore-dev \\
			/gcc/a \\t\tlibmagickwand-dev \\
		'
	fi

	cp docker-entrypoint.sh "$version/"
	sed -r "$sedDebianExpr" Dockerfile-debian.template > "$version/Dockerfile"

	mkdir -p "$version/passenger"
	sed -r "$sedExpr" Dockerfile-passenger.template > "$version/passenger/Dockerfile"

	mkdir -p "$version/alpine"
	cp docker-entrypoint.sh "$version/alpine/"
	sed -i -e 's/gosu/su-exec/g' "$version/alpine/docker-entrypoint.sh"
	sed -r "$sedAlpineExpr" Dockerfile-alpine.template > "$version/alpine/Dockerfile"

	travisEnv='\n  - VERSION='"$version/alpine$travisEnv"
	travisEnv='\n  - VERSION='"$version$travisEnv"
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
