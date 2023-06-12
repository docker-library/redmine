#!/usr/bin/env bash
set -Eeuo pipefail

# see https://www.redmine.org/projects/redmine/wiki/redmineinstall
defaultRubyVersion='3.1'
declare -A rubyVersions=(
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

# https://github.com/docker-library/redmine/issues/256
downloadsPage="$(curl -fsSL 'https://redmine.org/projects/redmine/wiki/Download')"

releasesUrl='https://www.redmine.org/releases'
versionsPage="$(curl -fsSL "$releasesUrl")"

allVersions="$(
	sed <<<"$versionsPage"$'\n'"$downloadsPage" \
		-rne 's/.*redmine-([0-9.]+)[.]tar[.]gz.*/\1/p' \
		| sort -ruV
)"

for version in "${versions[@]}"; do
	ourVersions="$(grep -E "^$version[.]" <<<"$allVersions")"
	fullVersion=
	for tryVersion in $ourVersions; do
		url="$releasesUrl/redmine-$tryVersion.tar.gz"
		if sha256="$(curl -fsSL "$url.sha256" 2>/dev/null)" && sha256="$(cut -d' ' -f1 <<<"$sha256")" && [ -n "$sha256" ]; then
			fullVersion="$tryVersion"
			break
		fi
		if urlLine="$(grep -oEm1 'href="https?://[^"]+/'"redmine-$tryVersion.tar.gz"'".*sha256:.*' <<<"$downloadsPage")" && url="$(cut -d'"' -f2 <<<"$urlLine")" && [ -n "$url" ] && sha256="$(grep -oEm1 'sha256:[[:space:]]*[a-f0-9]{64}' <<<"$urlLine")" && [ -n "$sha256" ] && sha256="${sha256: -64}"; then
			fullVersion="$tryVersion"
			break
		fi
	done
	if [ -z "$fullVersion" ]; then
		echo >&2 "error: failed to find full version for '$version'"
		exit 1
	fi

	rubyVersion="${rubyVersions[$version]:-$defaultRubyVersion}"

	text="ruby $rubyVersion"

	echo "$version: $fullVersion ($text)"

	commonSedArgs=(
		-r
		-e 's/%%REDMINE_VERSION%%/'"$fullVersion"'/'
		-e 's/%%RUBY_VERSION%%/'"$rubyVersion"'/'
		-e 's!%%REDMINE_DOWNLOAD_URL%%!'"$url"'!'
		-e 's/%%REDMINE_DOWNLOAD_SHA256%%/'"$sha256"'/'
		-e 's/%%REDMINE%%/redmine:'"$version"'/'
	)

	mkdir -p "$version"
	cp docker-entrypoint.sh "$version/"
	sed "${commonSedArgs[@]}" Dockerfile-debian.template > "$version/Dockerfile"

	mkdir -p "$version/alpine"
	cp docker-entrypoint.sh "$version/alpine/"
	sed -i -e 's/gosu/su-exec/g' "$version/alpine/docker-entrypoint.sh"
	sed "${commonSedArgs[@]}" Dockerfile-alpine.template > "$version/alpine/Dockerfile"
done
