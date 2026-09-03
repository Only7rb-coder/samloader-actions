#!/bin/bash
set -euo pipefail

# Import GoFile uploader
source "$WDIR/tools/gofile.sh"

# Required image files for the normal workflow
REQUIRED_IMAGES=(
    "boot.img"
    "xbl_config.img"
    "init_boot.img"
    "recovery.img"
    "vbmeta.img"
    "dt.img"
    "dtbo.img"
    "dtb.img"
    "vendor_boot.img"
    "vbmeta_system.img"
)

extract() {
    cd "$WDIR/Downloads"

    echo -e "\n${MINT_GREEN}[+] Extracting the firmware Zip...${RESET}\n"
    unzip -q firmware.zip
    rm -f firmware.zip

    shopt -s nullglob
    local tar_files=(*.tar.md5 *.tar)
    if ((${#tar_files[@]} == 0)); then
        echo "[x] No firmware TAR archive was found after ZIP extraction." >&2
        exit 1
    fi

    for file in "${tar_files[@]}"; do
        tar -xf "$file"
    done
    rm -f -- *.md5

    echo -e "\n${LIGHT_YELLOW}[i] Zip extraction completed.${RESET}"

    # Decompress every LZ4 image wherever it was extracted. The .lz4 source is
    # removed only after successful decompression, leaving the raw .img file.
    mapfile -t lz4_files < <(find . -type f -name '*.lz4' -print)
    if ((${#lz4_files[@]} > 0)); then
        echo -e "${MINT_GREEN}[i] Decompressing LZ4 images...${RESET}"
        for file in "${lz4_files[@]}"; do
            lz4 -f "$file" "${file%.lz4}"
            rm -f -- "$file"
        done
    fi
}

upload_boot_only() {
    local boot_img
    boot_img=$(find "$WDIR/Downloads" -type f -name 'boot.img' -print -quit)
    if [[ -z "$boot_img" || ! -s "$boot_img" ]]; then
        echo "[x] boot.img was not found after extraction." >&2
        exit 1
    fi

    mkdir -p "$WDIR/Dist"
    # Copy the image as-is. No tar, zip, gzip, or other compression is used.
    cp -- "$boot_img" "$WDIR/Dist/boot.img"
    echo -e "\n${LIGHT_YELLOW}[i] Raw boot.img prepared: $(du -h "$WDIR/Dist/boot.img" | cut -f1)${RESET}"
    upload_to_gofile "$WDIR/Dist/boot.img"
}

collect_and_package_files() {
    if [[ "${BOOT_ONLY:-false}" == "true" ]]; then
        upload_boot_only
        return
    fi

    echo -e "${MINT_GREEN}[+] Copying the required stock files for Magisk...${RESET}\n"
    mkdir -p "$WDIR/output" "$WDIR/Dist"
    cd "$WDIR/Downloads"
    for img in "${REQUIRED_IMAGES[@]}"; do
        if [[ -e "$img" ]]; then
            echo -e "${LIGHT_YELLOW}[i] Copying $img${RESET}"
            cp -- "$img" "$WDIR/output/"
        fi
    done

    cd "$WDIR/output"
    shopt -s nullglob
    images=( *.img )
    if ((${#images[@]} == 0)); then
        echo "[x] No required image files were found." >&2
        exit 1
    fi
    TAR_NAME="${MODEL}-Magisk-files.tar"
    tar -cf "$TAR_NAME" -- "${images[@]}"
    rm -f -- "${images[@]}"
    zip -9 -q "$WDIR/Dist/${TAR_NAME}.zip" "$TAR_NAME"
    rm -f -- "$TAR_NAME"

    echo -e "\n${LIGHT_YELLOW}[i] Zip file created: ${TAR_NAME}.zip${RESET}\n"
    upload_to_gofile "$WDIR/Dist/${TAR_NAME}.zip"
}

extract
collect_and_package_files
