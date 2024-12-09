#!/usr/bin/env bash
set -Eeuo pipefail

supportedDebianSuites=(
	bookworm
)
supportedAlpineVersions=(
	3.21
	3.20
)

defaultDebianSuite="${supportedDebianSuites[0]}"
declare -A debianSuites=(
	#[5.0]='bookworm'
)
defaultAlpineVersion="${supportedAlpineVersions[0]}"
declare -A alpineVersions=(
	#[5.0]='3.16'
)
# see https://www.redmine.org/projects/redmine/wiki/redmineinstall
defaultRubyVersion='3.3'
declare -A rubyVersions=(
	[5.0]='3.1'
	[5.1]='3.2'
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
	json='{}'
else
	json="$(< versions.json)"
fi
versions=( "${versions[@]%/}" )

releasesUrl='https://www.redmine.org/releases'

declare packages=

fetch_package_list() {
	local -; set +x # make sure running with "set -x" doesn't spam the terminal with the raw package lists

	if [ -z "${packages}" ]; then
		packages="$(curl -fsSL "$releasesUrl")"
	fi
}

get_version() {
	local version="$1"; shift
	fetch_package_list

	fullVersion="$(
		sed <<<"$packages" \
			-rne 's/.*redmine-([0-9.]+)[.]tar[.]gz.*/\1/p' \
			| cut -d/ -f3 \
			| cut -d^ -f1 \
			| grep -e "^$version" \
			| sort -urV \
			| head -1
	)"

	if [ -z "$fullVersion" ]; then
		echo >&2 "error: failed to find full version for '$version'"
		exit 1
	fi

	downloadUrl="$releasesUrl/redmine-$fullVersion.tar.gz"
	sha256="$(curl -fsSL $downloadUrl.sha256 | awk '{print $1}')"
}

for version in "${versions[@]}"; do
	export version

	versionAlpineVersion="${alpineVersions[$version]:-$defaultAlpineVersion}"
	versionDebianSuite="${debianSuites[$version]:-$defaultDebianSuite}"
	versionRubyVersion="${rubyVersions[$version]:-$defaultRubyVersion}"
	export versionAlpineVersion versionDebianSuite versionRubyVersion

	doc="$(jq -nc '{
		alpine: env.versionAlpineVersion,
		debian: env.versionDebianSuite,
	}')"

	get_version "$version"

	for suite in "${supportedDebianSuites[@]}"; do
		export suite
		doc="$(jq <<<"$doc" -c '
			.variants += [ env.suite ]
		')"
	done

	for alpineVersion in "${supportedAlpineVersions[@]}"; do
		doc="$(jq <<<"$doc" -c --arg v "$alpineVersion" '
			.variants += [ "alpine" + $v ]
		')"
	done

	echo "$version: $fullVersion"

	export fullVersion downloadUrl sha256
	json="$(jq <<<"$json" -c --argjson doc "$doc" '
		.[env.version] = ($doc + {
			version: env.fullVersion,
			downloadUrl: env.downloadUrl,
			sha256: env.sha256,
			"ruby": {
				version: env.versionRubyVersion
			}
		})
	')"

done

jq <<<"$json" -S . > versions.json
