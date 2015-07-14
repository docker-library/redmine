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

for version in "${versions[@]}"; do
	fullVersion="$(echo $versionsPage | sed -r "s/.*($version\.[0-9]+)\.tar\.gz[^.].*/\1/" | sort -V | tail -1)"
	md5="$(curl -fsSL "$relasesUrl/redmine-$fullVersion.tar.gz.md5" | cut -d' ' -f1)"
	
	(
		set -x
		cp docker-entrypoint.sh Dockerfile.template "$version/"
		mv "$version/Dockerfile.template" "$version/Dockerfile"
		sed -i 's/%%REDMINE_DOWNLOAD_MD5%%/'$md5'/g; s/%%REDMINE_VERSION%%/'$fullVersion'/g' "$version/Dockerfile"
	)
done

