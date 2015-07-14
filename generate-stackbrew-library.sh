#!/bin/bash
set -e

declare -A aliases
aliases=(
	[3.0]='3 latest'
	[2.6]='2'
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( */ )
versions=( "${versions[@]%/}" )
url='git://github.com/docker-library/redmine'

echo '# maintainer: InfoSiftr <github@infosiftr.com> (@infosiftr)'

for version in "${versions[@]}"; do
	commit="$(git log -1 --format='format:%H' -- "$version")"
	fullVersion="$(grep -m1 'ENV REDMINE_VERSION ' "$version/Dockerfile" | cut -d' ' -f3 | cut -d- -f1)"
	versionAliases=( $fullVersion $version ${aliases[$version]} )
	
	echo
	for va in "${versionAliases[@]}"; do
		echo "$va: ${url}@${commit} $version"
	done
done
