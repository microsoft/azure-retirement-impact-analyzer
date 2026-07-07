#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Get Retirement Impacted Resources
# Queries Azure Resource Graph to identify retiring Azure resources
# Output: CSV file with all impacted resources across all queries

set -o pipefail

QueriesFile="queries.txt"
OutputFile="impactedresources.csv"

# Colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================================================
# Validate Dependencies
# ============================================================================
if ! command -v az >/dev/null 2>&1; then
    echo -e "${RED}Error: Azure CLI 'az' is not installed or not found in PATH.${NC}"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo -e "${RED}Error: 'jq' is required but not installed.${NC}"
    echo "Install using: sudo apt-get install jq"
    exit 1
fi

if [ ! -f "$QueriesFile" ]; then
    echo -e "${RED}Error: Queries file not found: $QueriesFile${NC}"
    exit 1
fi

# ============================================================================
# Setup and Configuration
# ============================================================================
az extension add -n resource-graph --only-show-errors 2>/dev/null
az config set extension.dynamic_install_allow_preview=true --only-show-errors 2>/dev/null

TempDir="${TMPDIR:-/tmp}"
TempFile="$TempDir/arg-query-temp.kql"
AllResultsFile="$(mktemp "$TempDir/arg-results-XXXXXX.jsonl")"

# ============================================================================
# Process All Queries
# ============================================================================
mapfile -t Queries < "$QueriesFile"
QueryCount=0
TotalImpacted=0

for Query in "${Queries[@]}"; do
    if [[ -z "${Query//[[:space:]]/}" ]]; then
        continue
    fi

    Query="$(echo "$Query" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    
    RetiringFeature="Unknown"
    if [[ "$Query" =~ RetiringFeature[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
        RetiringFeature="${BASH_REMATCH[1]}"
    fi

    echo ""
    echo -e "${CYAN}=========== RetiringFeature : \"$RetiringFeature\" ===========${NC}"
    echo "$Query"
    echo "================================================================"

    printf "%s" "$Query" > "$TempFile"
    SkipToken=""
    QueryResultsFile="$(mktemp "$TempDir/arg-query-results-XXXXXX.jsonl")"

    while true; do
        if [ -n "$SkipToken" ]; then
            Result="$(az graph query -q "@$TempFile" --skip-token "$SkipToken" -o json 2>/dev/null)"
        else
            Result="$(az graph query -q "@$TempFile" -o json 2>/dev/null)"
        fi

        if [ -z "$Result" ]; then
            break
        fi

        echo "$Result" | jq -c '.data[]?' >> "$QueryResultsFile"
        SkipToken="$(echo "$Result" | jq -r '.skipToken // .skip_token // empty')"

        if [ -z "$SkipToken" ]; then
            break
        fi
    done

    ImpactedCount=0
    if [ -f "$QueryResultsFile" ] && [ -s "$QueryResultsFile" ]; then
        ImpactedCount="$(wc -l < "$QueryResultsFile" 2>/dev/null | tr -d ' ')"
        echo -e "${GREEN}$ImpactedCount resources impacted${NC}"
        jq -r '.' "$QueryResultsFile"
        TotalImpacted=$((TotalImpacted + ImpactedCount))
        cat "$QueryResultsFile" >> "$AllResultsFile"
    else
        echo -e "${GREEN}No resources impacted${NC}"
    fi

    rm -f "$QueryResultsFile"
    QueryCount=$((QueryCount + 1))
done

rm -f "$TempFile"

# ============================================================================
# Export Results to CSV
# ============================================================================
TotalResults=0
if [ -f "$AllResultsFile" ] && [ -s "$AllResultsFile" ]; then
    TotalResults="$(wc -l < "$AllResultsFile" | tr -d ' ')"
fi

if [ "$TotalResults" -gt 0 ]; then
    jq -r -s '
        (reduce .[] as $obj ({}; . + $obj) | keys_unsorted) as $keys |
        ([$keys[] | tostring] | @csv),
        (.[] | [$keys[] as $k | (.[$k] | if type == "object" or type == "array" then tojson else . end) // ""] | @csv)
    ' "$AllResultsFile" > "$OutputFile"
    
    if [ -f "$OutputFile" ] && [ -s "$OutputFile" ]; then
        OutputLineCount="$(wc -l < "$OutputFile" | tr -d ' ')"
        FileSize="$(du -h "$OutputFile" | cut -f1)"
        
        echo ""
        echo -e "${CYAN}Results exported to: $OutputFile${NC}"
        echo -e "${CYAN}Total resources: $TotalResults${NC}"
    else
        echo -e "${RED}Error: Failed to create output file${NC}"
        exit 1
    fi
else
    echo -e "${CYAN}No resources found to export${NC}"
fi

rm -f "$AllResultsFile"
