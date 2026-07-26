#!/bin/bash

set -euo pipefail

mode="${1:-check}"
if [[ "$mode" != "check" && "$mode" != "update" ]]; then
    echo "usage: $0 [check|update]" >&2
    exit 64
fi

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
derived_data="${DERIVED_DATA_PATH:-$repository_root/.build/api-derived-data}"
temporary_root="$(mktemp -d)"
trap 'rm -rf "$temporary_root"' EXIT

xcodebuild build \
    -scheme Refreshable-Package \
    -destination "generic/platform=iOS" \
    -configuration Release \
    -derivedDataPath "$derived_data" \
    IPHONEOS_DEPLOYMENT_TARGET=13.0 \
    CODE_SIGNING_ALLOWED=NO \
    -quiet

products="$derived_data/Build/Products/Release-iphoneos"
sdk_path="$(xcrun --sdk iphoneos --show-sdk-path)"

for module in Refreshable RefreshableStyles; do
    output_directory="$temporary_root/$module"
    mkdir -p "$output_directory"
    xcrun swift-symbolgraph-extract \
        -module-name "$module" \
        -I "$products" \
        -target arm64-apple-ios13.0 \
        -sdk "$sdk_path" \
        -output-dir "$output_directory" \
        -minimum-access-level public

    generated_baseline="$temporary_root/$module.sha256"
    while IFS= read -r graph; do
        hash="$(
            jq -S -c \
                '{
                    module: .module,
                    symbols: (
                        [.symbols[] | del(.docComment, .location)]
                        | sort_by([
                            (.identifier.precise // ""),
                            ((.pathComponents // []) | join(".")),
                            (.kind.identifier // "")
                        ])
                    ),
                    relationships: (
                        .relationships
                        | sort_by([
                            (.kind // ""),
                            (.source // ""),
                            (.target // ""),
                            (.targetFallback // "")
                        ])
                    )
                }' \
                "$graph" \
                | shasum -a 256 \
                | cut -d ' ' -f 1
        )"
        printf '%s %s\n' "$(basename "$graph")" "$hash" >> "$generated_baseline"
    done < <(find "$output_directory" -name '*.symbols.json' -type f | LC_ALL=C sort)

    checked_in_baseline="$repository_root/API-Baselines/$module.sha256"
    if [[ "$mode" == "update" ]]; then
        cp "$generated_baseline" "$checked_in_baseline"
    else
        diff -u "$checked_in_baseline" "$generated_baseline"
    fi
done
