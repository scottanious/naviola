#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Naviola"
SRC_DIR="."
BUILD_DIR="./build"
TEAM_ID="${TEAM_ID:-635H9TYSZJ}"
CODE_SIGN_IDENTITY="Developer ID Application: Alex Sokolov (635H9TYSZJ)"
NOTARY_KEYCHAIN_PROFILE="NotaryTool"
PROVISIONING_PROFILE="com.naviola.app"

##############################
SCHEME="${APP_NAME}"
ARCHIVE_PATH="${BUILD_DIR}/${SCHEME}.xcarchive"
CONFIGURATION="Release"
EXPORT_OPTIONS_PLIST="${BUILD_DIR}/ExportOptions.plist"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"

function getVersion() {
    if [[ "${GITHUB_REF_TYPE-}"  = "tag" ]]; then
        #VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" ${APP_PATH}/Contents/Info.plist)
        echo ${GITHUB_REF_NAME:1}
    else
        date +%Y.%m.%d_%H.%M.%S
    fi
}

function prepare() {
    ##############################
    # Ensure build dir
    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}"
}

function build() {
    echo ""
    echo "***********************************"
    echo "** Building project..."
    echo "***********************************"

    ARGS=(
        -project "./${APP_NAME}.xcodeproj"
        -scheme "${APP_NAME}"
        -configuration "${CONFIGURATION}"
        -derivedDataPath ./build
        CODE_SIGN_IDENTITY=""
        CODE_SIGNING_REQUIRED=NO
        CODE_SIGNING_ALLOWED=NO
    )

    xcodebuild clean build "${ARGS[@]}" | tee "${BUILD_DIR}/01-build.log"
}

function copyApp() {
    echo ""
    echo "***********************************"
    echo "** Copying the bundle..."
    echo "***********************************"
    rm -rf "${APP_PATH}"
    cp -a "${BUILD_DIR}/Build/Products/${CONFIGURATION}/${APP_NAME}.app" "${APP_PATH}"
    echo "  OK"
}

function sign() {
    echo ""
    echo "***********************************"
    echo "Removing quarantine flag..."
    echo "***********************************"
    xattr -r -d com.apple.quarantine "${APP_PATH}"
    echo "  OK"

    echo ""
    echo "***********************************"
    echo "Signing the bundle..."
    echo "***********************************"
    codesign --force --options runtime --deep --verify --sign  "${CODE_SIGN_IDENTITY}" "${APP_PATH}"
    echo "  OK"
    echo ""

}

function verifyCodesign() {
    echo ""
    echo "***********************************"
    echo "** Verifying codesign and entitlements..."
    echo "***********************************"
    codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

    echo ""
    echo "** VERIFICATION SUCCEEDED **"
}

function createDmg() {
    echo ""
    echo "***********************************"
    echo "** Build DMG file"
    echo "***********************************"

    VERSION=$(getVersion)
    DMG_NAME="${APP_NAME}-${VERSION}.dmg"

    cat "${SRC_DIR}/.github/workflows/dmg_settings.json" > "${BUILD_DIR}/dmg_settings.json"
    cp  "${SRC_DIR}/.github/workflows/dmgbuild" "${BUILD_DIR}/dmgbuild"
    (cd "${BUILD_DIR}" && ./dmgbuild -s dmg_settings.json "${APP_NAME}" "${DMG_NAME}")

    echo ""
    echo "** DMG CREATION SUCCEEDED ${DMG_NAME} **"
}

function notarize() {
    echo ""
    echo "***********************************"
    echo "Submitting to Apple notary service..."
    echo "***********************************"

    DMG_PATH=$(ls ${BUILD_DIR}/*.dmg)
    echo "DMG FILE: ${DMG_PATH}"

    ARGS=(
        --wait
        --output-format json
    )

    if [ "${GITHUB_ACTIONS-}" = "true" ]; then
        ARGS+=(
            --key "./AuthKey.p8"
            --key-id "${AC_KEY_ID}"
            --issuer "${AC_ISSUER_ID}"
        )
    else
        ARGS+=(
            --keychain-profile "${NOTARY_KEYCHAIN_PROFILE}"
        )
    fi

    xcrun notarytool submit "${ARGS[@]}" "${DMG_PATH}" | tee "${BUILD_DIR}/03-notarize.log"

    echo ""
    echo "** WAITING RESULT .... **"
    xcrun stapler staple "${DMG_PATH}"

    echo ""
    echo "***********************************"
    echo "** Verifying..."
    echo "***********************************"
    spctl -a -vvv -t install "${APP_PATH}" || spctl --assess --type execute --verbose=4 "${APP_PATH}"

    echo ""
    echo "** NOTARIZATION SUCCEEDED **"
}

DEFAULT_STEPS=""
DEFAULT_STEPS+=" prepare"
DEFAULT_STEPS+=" build"
DEFAULT_STEPS+=" copyApp"
DEFAULT_STEPS+=" sign"
DEFAULT_STEPS+=" verifyCodesign"
DEFAULT_STEPS+=" createDmg"
DEFAULT_STEPS+=" notarize"

args="${@:-${DEFAULT_STEPS}}"
for func in $args; do
    $func
done
