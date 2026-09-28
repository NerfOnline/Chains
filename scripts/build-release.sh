#!/usr/bin/env bash
# Build Retail, Horizon, and Phoenix Chains zips, then publish a GitHub release
# after confirmation. Uses bash, awk, and sed.

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

if [[ ! -f chains/chains.lua || ! -f chains/pets.lua || ! -f scripts/skills-data.lua || ! -f scripts/skills-data-horizon.lua || ! -f scripts/skills-data-phoenix.lua ]]; then
    echo "Run this from the Chains repository. chains/chains.lua, chains/pets.lua, or a skills-data file is missing." >&2
    exit 1
fi

append_le() {
    local file=$1
    local value=$2
    local width=$3
    local i byte
    for ((i = 0; i < width; i++)); do
        byte=$((value & 255))
        printf "\\$(printf '%03o' "$byte")" >> "$file"
        value=$((value >> 8))
    done
}

file_crc32() {
    if command -v gzip >/dev/null 2>&1; then
        gzip -c "$1" | tail -c 8 | od -An -tu1 -v | awk '
            { for (i = 1; i <= NF; i++) b[n++] = $i }
            END { print b[0] + b[1] * 256 + b[2] * 65536 + b[3] * 16777216 }
        '
        return
    fi
    od -An -tu1 -v "$1" | awk '
        function bxor(a, b,    r, bit) {
            r = 0
            bit = 1
            while (a > 0 || b > 0) {
                if ((a % 2) != (b % 2)) r += bit
                a = int(a / 2)
                b = int(b / 2)
                bit *= 2
            }
            return r
        }
        BEGIN { crc = 4294967295 }
        {
            for (i = 1; i <= NF; i++) {
                crc = bxor(crc, $i + 0)
                for (b = 0; b < 8; b++) {
                    if (crc % 2) crc = bxor(int(crc / 2), 3988292384)
                    else crc = int(crc / 2)
                }
            }
        }
        END { print bxor(crc, 4294967295) }
    '
}

write_zip() {
    local dest=$1
    shift
    local -a names=() paths=() crcs=() sizes=() offsets=()
    local entry name path crc size name_len offset=0 index=0
    local year month day hour minute second dos_time dos_date
    read -r year month day hour minute second <<< "$(date '+%Y %m %d %H %M %S')"
    dos_time=$(( (10#$hour << 11) | (10#$minute << 5) | (10#$second / 2) ))
    dos_date=$(( ((year - 1980) << 9) | (10#$month << 5) | 10#$day ))
    : > "$dest"
    for entry in "$@"; do
        name=${entry%%:*}
        path=${entry#*:}
        crc=$(file_crc32 "$path")
        size=$(wc -c < "$path" | tr -d '[:space:]')
        name_len=${#name}
        names[index]=$name
        paths[index]=$path
        crcs[index]=$crc
        sizes[index]=$size
        offsets[index]=$offset
        printf 'PK\003\004' >> "$dest"
        append_le "$dest" 20 2
        append_le "$dest" 0 2
        append_le "$dest" 0 2
        append_le "$dest" "$dos_time" 2
        append_le "$dest" "$dos_date" 2
        append_le "$dest" "$crc" 4
        append_le "$dest" "$size" 4
        append_le "$dest" "$size" 4
        append_le "$dest" "$name_len" 2
        append_le "$dest" 0 2
        printf '%s' "$name" >> "$dest"
        cat "$path" >> "$dest"
        offset=$((offset + 30 + name_len + size))
        index=$((index + 1))
    done

    local central_start=$offset
    local count=${#names[@]}
    local i
    for ((i = 0; i < count; i++)); do
        name=${names[i]}
        name_len=${#name}
        printf 'PK\001\002' >> "$dest"
        append_le "$dest" 20 2
        append_le "$dest" 20 2
        append_le "$dest" 0 2
        append_le "$dest" 0 2
        append_le "$dest" "$dos_time" 2
        append_le "$dest" "$dos_date" 2
        append_le "$dest" "${crcs[i]}" 4
        append_le "$dest" "${sizes[i]}" 4
        append_le "$dest" "${sizes[i]}" 4
        append_le "$dest" "$name_len" 2
        append_le "$dest" 0 2
        append_le "$dest" 0 2
        append_le "$dest" 0 2
        append_le "$dest" 0 2
        append_le "$dest" 0 4
        append_le "$dest" "${offsets[i]}" 4
        printf '%s' "$name" >> "$dest"
        offset=$((offset + 46 + name_len))
    done

    printf 'PK\005\006' >> "$dest"
    append_le "$dest" 0 2
    append_le "$dest" 0 2
    append_le "$dest" "$count" 2
    append_le "$dest" "$count" 2
    append_le "$dest" $((offset - central_start)) 4
    append_le "$dest" "$central_start" 4
    append_le "$dest" 0 2
}

read_required() {
    local prompt=$1
    local value=""
    while [[ -z "$value" ]]; do
        read -r -p "$prompt" value
        value=${value#"${value%%[![:space:]]*}"}
        value=${value%"${value##*[![:space:]]}"}
        if [[ -z "$value" ]]; then
            echo "A value is required." >&2
        fi
    done
    printf '%s' "$value"
}

render_skills() {
    local server=$1
    local out=$2
    local body data_file
    body=$(mktemp)
    case "$server" in
        retail) data_file="scripts/skills-data.lua" ;;
        horizon) data_file="scripts/skills-data-horizon.lua" ;;
        phoenix) data_file="scripts/skills-data-phoenix.lua" ;;
        *)
            echo "Unknown server ${server}." >&2
            exit 1
            ;;
    esac

    awk -v server="$server" '
        { sub(/\r$/, "") }
        function open_table(key) {
            print preamble[key]
            start = 1
            if (lead_count > 0 && lead[1] == preamble[key]) {
                start = 2
            }
            for (i = start; i <= lead_count; i++) {
                print lead[i]
            }
            delete lead
            lead_count = 0
            print "skills" key " = {"
            opened = 1
        }
        BEGIN {
            preamble["[3]"] = "-- Player Weaponskills"
            preamble["[13]"] = "-- Summoner Blood Pacts"
            preamble["[14]"] = "-- Samurai and Dancer Chainbound Abilities"
            preamble[".immanence"] = "-- Scholar Immanence Element Properties"
            preamble["[4]"] = "-- Blue Mage and Scholar Spells"
            preamble[".pup"] = "-- Puppetmaster Automaton Weaponskills"
            preamble[".bst"] = "--Beastmaster"
            preamble["[11]"] = "-- NPC Weaponskills"
            capturing = 0
            in_table = 0
            found = 0
            lead_count = 0
        }
        $0 == "sets." server " = {}" {
            capturing = 1
            found = 1
            next
        }
        capturing && $0 ~ /^sets\.[A-Za-z]+ = \{\}$/ {
            capturing = 0
            next
        }
        !capturing { next }
        $0 ~ /^sets\./ && $0 ~ / = \{$/ {
            prefix = "sets." server
            key = substr($0, length(prefix) + 1)
            sub(/ = \{.*/, "", key)
            if (!(key in preamble)) {
                printf "Unknown skill table %s\n", key > "/dev/stderr"
                exit 1
            }
            table_key = key
            in_table = 1
            opened = 0
            pending = ""
            next
        }
        in_table && $0 == "}" {
            if (!opened) {
                open_table(table_key)
            }
            print "};"
            in_table = 0
            next
        }
        capturing && !in_table && $0 ~ /^[[:space:]]*$/ {
            print ""
            next
        }
        capturing && !in_table && $0 ~ /^--/ {
            lead[++lead_count] = $0
            next
        }
        in_table && $0 ~ /^--/ {
            pending = $0
            next
        }
        in_table && index($0, "skillchain=") > 0 {
            if (!opened) {
                open_table(table_key)
            }
            if (pending != "") {
                print pending
                pending = ""
            }
            print
            next
        }
        END {
            if (!found) {
                printf "Dataset %s was not found\n", server > "/dev/stderr"
                exit 1
            }
            print "return skills"
        }
    ' "$data_file" > "$body"

    local staged
    staged=$(mktemp)
    {
        awk '{ sub(/\r$/, ""); print } $0 == "local skills = {};" { exit }' chains/skills.lua
        echo
        cat "$body"
    } > "$staged"
    mv "$staged" "$out"
    rm -f "$body"
}

main() {
    local version channel label base zip_dir work
    version=$(read_required "Version (example: 0.92c): ")
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+[A-Za-z]?$ ]]; then
        echo "Version must look like 0.92c." >&2
        exit 1
    fi

    channel=""
    while [[ "$channel" != "Release" && "$channel" != "Pre-release" ]]; do
        channel=$(read_required "Release or Pre-release: ")
        if [[ "$channel" != "Release" && "$channel" != "Pre-release" ]]; then
            echo "Type Release or Pre-release." >&2
            channel=""
        fi
    done

    label="$version"
    if [[ "$channel" == "Pre-release" ]]; then
        label="${version}-Pre-release"
    fi
    base="Chains-v${label}"

    if ! grep -q "addon\.version" chains/chains.lua; then
        echo "Could not find addon.version in chains/chains.lua." >&2
        exit 1
    fi
    sed -E -i.bak "s/addon\.version[[:space:]]*=[[:space:]]*'[^']*'/addon.version  = '${label}'/" chains/chains.lua
    rm -f chains/chains.lua.bak
    echo "Set addon.version to ${label}"

    zip_dir="${root}/dist"
    work=$(mktemp -d)
    mkdir -p "$zip_dir"
    trap 'rm -rf "$work"' EXIT

    local -a servers=("retail" "horizon" "phoenix")
    local -a zips=()
    local server zip_name stage chains_dir zip_path
    for server in "${servers[@]}"; do
        case "$server" in
            retail) zip_name="${base}.zip" ;;
            horizon) zip_name="${base}-Horizon.zip" ;;
            phoenix) zip_name="${base}-Phoenix.zip" ;;
        esac
        stage="${work}/${server}"
        chains_dir="${stage}/chains"
        mkdir -p "$chains_dir"
        cp chains/chains.lua "${chains_dir}/chains.lua"
        cp chains/pets.lua "${chains_dir}/pets.lua"
        render_skills "$server" "${chains_dir}/skills.lua"
        zip_path="${zip_dir}/${zip_name}"
        rm -f "$zip_path"
        write_zip "$zip_path" \
            "chains/chains.lua:${chains_dir}/chains.lua" \
            "chains/skills.lua:${chains_dir}/skills.lua" \
            "chains/pets.lua:${chains_dir}/pets.lua"
        zips+=("$zip_path")
        echo "Wrote ${zip_name}"
    done

    echo
    echo "Zips contain only chains/chains.lua, chains/skills.lua, and chains/pets.lua:"
    local zip
    for zip in "${zips[@]}"; do
        echo "  ${zip}"
    done

    local title tag last_tag message submit
    tag="v${label}"
    title=$(read_required "GitHub release title: ")

    # The notes are every commit message since the last release or pre-release tag.
    git fetch --tags --quiet origin 2>/dev/null || true
    last_tag=$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)
    if [[ -n "$last_tag" ]]; then
        message=$(git log --format='%B' "${last_tag}..HEAD")
    else
        message=$(git log --format='%B')
    fi
    if [[ -z "${message//[[:space:]]/}" ]]; then
        echo "There are no commits since ${last_tag}." >&2
        exit 1
    fi

    echo
    echo "Title: ${title}"
    echo "Tag: ${tag}"
    echo "Commits since: ${last_tag:-the first commit}"
    echo "Message:"
    echo "$message"
    echo "Files:"
    for zip in "${zips[@]}"; do
        echo "  ${zip}"
    done
    read -r -p "Submit this GitHub release? (y/N): " submit
    if [[ "$submit" != "y" && "$submit" != "Y" ]]; then
        echo "Release was not submitted. The zips are in dist/."
        exit 0
    fi
    if ! command -v gh >/dev/null 2>&1; then
        echo "The gh command is required to submit the GitHub release. The zips are in dist/." >&2
        exit 1
    fi
    local -a release_flags=()
    if [[ "$channel" == "Pre-release" ]]; then
        release_flags+=("--prerelease")
    fi
    gh release create "$tag" "${zips[@]}" --title "$title" --notes "$message" ${release_flags[@]+"${release_flags[@]}"}
    echo "GitHub release submitted."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
