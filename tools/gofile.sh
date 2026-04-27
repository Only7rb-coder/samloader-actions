#!/bin/bash

# Function to upload the releases to gofile.io
upload_to_gofile() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "❌ File not found: $file"
        return 1
    fi

    echo "📤 Uploading $file to GoFile..."

    # Perform upload and capture full response
    response=$(curl -sS -X POST 'https://upload.gofile.io/uploadfile' -F "file=@${file}")
    rc=$?
    if [[ $rc -ne 0 ]]; then
        echo "❌ curl failed with exit code $rc"
        echo "Response: $response"
        return 1
    fi

    echo "API response: $response"

    local golink=""

    # Prefer jq for robust JSON parsing when available
    if command -v jq >/dev/null 2>&1; then
        # Try several likely JSON paths
        golink=$(echo "$response" | jq -r '.data.downloadPage // .data.link // .downloadPage // .data.code // empty')
        # If we got only a code (e.g. "abcd"), construct the public page link
        if [[ -n "$golink" && "$golink" != http* && ${#golink} -le 16 ]]; then
            golink="https://gofile.io/d/${golink}"
        fi
    else
        # Fallback to regex parsing (less reliable)
        golink=$(echo "$response" | grep -oP '"downloadPage"\s*:\s*"\K[^"]+' || true)
        if [[ -z "$golink" ]]; then
            golink=$(echo "$response" | grep -oP '"link"\s*:\s*"\K[^"]+' || true)
        fi
        if [[ -z "$golink" ]]; then
            golink=$(echo "$response" | grep -oP '"code"\s*:\s*"\K[^"]+' || true)
            if [[ -n "$golink" && ${#golink} -le 16 ]]; then
                golink="https://gofile.io/d/${golink}"
            fi
        fi
    fi

    if [[ -n "$golink" ]]; then
        echo "✅ Link to Download: $golink"
        # Export to GitHub Actions environment so subsequent steps can access it
        if [[ -n "$GITHUB_ENV" ]]; then
            echo "GOLINK=$golink" >> "$GITHUB_ENV"
        fi
        export GOLINK="$golink"
    else
        echo "❌ Failed to upload or fetch link."
        echo "Full response: $response"
        return 1
    fi
}
