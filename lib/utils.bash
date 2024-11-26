#!/usr/bin/env bash

set -euo pipefail

# TODO: Ensure this is the correct GitHub homepage where releases can be downloaded for harbor-cli.
GH_REPO="https://github.com/TwiggyWan/harbor-cli"
TOOL_NAME="harbor-cli"
TOOL_TEST="harbor --help"

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if harbor-cli is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
	# TODO: Adapt this. By default we simply list the tag names from GitHub releases.
	# Change this function if harbor-cli has other means of determining installable versions.
	list_github_tags
}

get_platform() {
    local -r kernel="$(uname -s)"
    if [[ ${OSTYPE} == "msys" || ${kernel} == "CYGWIN"* || ${kernel} == "MINGW"* ]]; then
        echo windows
    else
        uname | tr '[:upper:]' '[:lower:]'
    fi
}

get_arch() {
    # cf https://github.com/asdf-community/asdf-hashicorp/blob/22eb1c4a16adcde39aaaf89fbb5d9404a1601fce/bin/install#L112C1-L128C5
    local -r machine="$(uname -m)"
    local -r upper_toolname=$(echo "${toolname//-/_}" | tr '[:lower:]' '[:upper:]')

    # no need for arch override, harbor-cli already ships arm64 and amd64 for both linux and mac
    if [[ ${machine} == "arm64" ]] || [[ ${machine} == "aarch64" ]]; then
        echo "arm64"
    elif [[ ${machine} == *"arm"* ]] || [[ ${machine} == *"aarch"* ]]; then
        echo "arm"
    elif [[ ${machine} == *"386"* ]]; then
        echo "386"
    else
        echo "amd64"
    fi
}
download_release() {
	local version filename url
	version="$1"
	filename="$2"

	# TODO: Adapt the release URL convention for harbor-cli
	url="$GH_REPO/archive/harbor_${version}_$(get_platform)_$(get_arch).tar.gz"

	echo "* Downloading $TOOL_NAME release $version..."
	curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}/bin"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path"
		cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

		# TODO: Assert harbor-cli executable exists.
		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}
