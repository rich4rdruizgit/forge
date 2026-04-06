#!/usr/bin/env bash
# forge-scan.sh — "El Arqueólogo"
# Static analyzer for legacy Android projects.
# Runs WITHOUT compiling or Gradle sync. Uses fd + rg only.
# Generates .forge/project-dna.yaml
#
# Usage:
#   forge-scan.sh                    # Nivel 1 + ALL modules (full scan)
#   forge-scan.sh app feature-login  # Nivel 1 + only those modules
#   forge-scan.sh --interactive      # Nivel 1 + interactive module selector
#   forge-scan.sh --project-only     # Nivel 1 only (no modules)
#
# Compatible with bash 3.2+ (macOS default)

set -uo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
SCAN_VERSION="1.0"
STEP_TIMEOUT=5
DNA_FILE=".forge/project-dna.yaml"
SCAN_DATE="$(date '+%Y-%m-%d')"
SCAN_TIMESTAMP="$(date '+%Y-%m-%dT%H:%M:%S')"

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { printf "${CYAN}▸${NC} %s\n" "$1"; }
success() { printf "${GREEN}✔${NC} %s\n" "$1"; }
warn()    { printf "${YELLOW}⚠${NC} %s\n" "$1"; }
errlog()  { printf "${RED}✖${NC} %s\n" "$1" >&2; }
header()  { printf "\n${BOLD}${CYAN}━━━ %s ━━━${NC}\n" "$1"; }

# Safe rg wrapper — returns empty on no match
srg() {
    rg "$@" 2>/dev/null || true
}

# Safe fd wrapper
sfd() {
    fd "$@" 2>/dev/null || true
}

# Escape YAML string value
yaml_escape() {
    local val="$1"
    if [[ -z "$val" ]]; then
        printf '""'
    elif printf '%s' "$val" | rg -q '[:\#\[\]\{\},&*!|><%@`"'"'"'\\]' 2>/dev/null; then
        printf '"%s"' "$(printf '%s' "$val" | sed 's/"/\\"/g')"
    else
        printf '%s' "$val"
    fi
}

# Count rg matches in a path (returns number)
count_matches() {
    local pattern="$1"
    local path="$2"
    local count
    count=$(rg -c "$pattern" --type kotlin "$path" 2>/dev/null | awk -F: '{s+=$NF}END{print s+0}')
    printf '%d' "${count:-0}"
}

# Format LOC for display
format_loc() {
    local loc=$1
    if [[ $loc -ge 1000 ]]; then
        printf '%s.%sK' $((loc / 1000)) $(( (loc % 1000) / 100 ))
    else
        printf '%d' "$loc"
    fi
}

# ---------------------------------------------------------------------------
# KV Store — bash 3.2 compatible key-value store using flat arrays
# Usage:
#   kv_set "store" "key" "value"
#   val=$(kv_get "store" "key")
#   keys=$(kv_keys "store")
# ---------------------------------------------------------------------------
_KV_KEYS=""
_KV_VALS=""

KV_STORE_FILE=$(mktemp /tmp/_forge_kv_store.XXXXXX)

kv_set() {
    local store="$1" key="$2" val="$3"
    local tag="${store}::${key}"
    # Check if key exists — update in place via temp file
    local tmpf
    tmpf=$(mktemp /tmp/_forge_kv.XXXXXX)
    local found=false
    if [[ -f "$KV_STORE_FILE" ]]; then
        while IFS=$'\t' read -r k v; do
            if [[ "$k" == "$tag" ]]; then
                printf '%s\t%s\n' "$tag" "$val"
                found=true
            else
                printf '%s\t%s\n' "$k" "$v"
            fi
        done < "$KV_STORE_FILE" > "$tmpf"
        mv "$tmpf" "$KV_STORE_FILE"
    fi
    if ! $found; then
        printf '%s\t%s\n' "$tag" "$val" >> "$KV_STORE_FILE"
    fi
}

kv_get() {
    local store="$1" key="$2"
    local tag="${store}::${key}"
    if [[ -f "$KV_STORE_FILE" ]]; then
        while IFS=$'\t' read -r k v; do
            if [[ "$k" == "$tag" ]]; then
                printf '%s' "$v"
                return
            fi
        done < "$KV_STORE_FILE"
    fi
}

kv_keys() {
    local store="$1"
    local prefix="${store}::"
    if [[ -f "$KV_STORE_FILE" ]]; then
        while IFS=$'\t' read -r k v; do
            case "$k" in
                ${prefix}*) printf '%s\n' "${k#${prefix}}" ;;
            esac
        done < "$KV_STORE_FILE"
    fi
}

kv_cleanup() {
    rm -f "$KV_STORE_FILE"
}
trap kv_cleanup EXIT

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
preflight() {
    local missing=""
    command -v fd  >/dev/null 2>&1 || missing="$missing fd"
    command -v rg  >/dev/null 2>&1 || missing="$missing rg"

    if [[ -n "$missing" ]]; then
        errlog "Faltan dependencias:$missing"
        errlog "Instalalas con: brew install$missing"
        exit 1
    fi

    # Check we're in an Android project
    if [[ ! -f "build.gradle" && ! -f "build.gradle.kts" && ! -f "settings.gradle" && ! -f "settings.gradle.kts" ]]; then
        errlog "No parece un proyecto Android. No encontré build.gradle ni settings.gradle."
        errlog "Ejecutá este script desde la raíz del proyecto."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
MODE="full"
SELECTED_MODULES=""  # space-separated

parse_args() {
    if [[ $# -eq 0 ]]; then
        MODE="full"
        return
    fi

    case "$1" in
        --interactive|-i)
            MODE="interactive"
            ;;
        --project-only|-p)
            MODE="project-only"
            ;;
        --help|-h)
            printf "Uso: forge-scan.sh [modulos...] [--interactive|--project-only]\n\n"
            printf "  Sin argumentos          Nivel 1 + todos los módulos (scan completo)\n"
            printf "  modulo1 modulo2         Nivel 1 + solo esos módulos\n"
            printf "  --interactive, -i       Nivel 1 + selector interactivo de módulos\n"
            printf "  --project-only, -p      Solo Nivel 1 (ficha técnica, sin módulos)\n"
            printf "  --help, -h              Mostrar esta ayuda\n"
            exit 0
            ;;
        *)
            MODE="selective"
            SELECTED_MODULES="$*"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Nivel 1 — Project-wide scan
# ---------------------------------------------------------------------------

ALL_MODULES=""       # space-separated module names
ALL_MODULES_COUNT=0

GRADLE_VERSION=""
COMPILE_SDK=""
MIN_SDK=""
TARGET_SDK=""
DI_FRAMEWORK=""
DI_PROCESSOR=""
KOTLIN_VERSION=""
AGP_VERSION=""
HAS_VERSION_CATALOG=false
VERSION_CATALOG_SOURCE=""
BUILD_FLAVORS=""
HAS_KSP=false
HAS_KAPT=false
PROJECT_TYPE="greenfield"
PROJECT_AGE="unknown"

# Module paths stored in KV store "modpath"
# Version catalog stored in KV store "catalog"

detect_modules() {
    info "Detectando módulos..."
    local raw_modules
    raw_modules=$(sfd -t d "src" --max-depth 3 | sed 's|/src.*||' | sort -u)

    while IFS= read -r mod_path; do
        [[ -z "$mod_path" ]] && continue
        if [[ -d "${mod_path}/src/main" ]]; then
            local mod_name
            mod_name=$(basename "$mod_path")
            ALL_MODULES="$ALL_MODULES $mod_name"
            kv_set "modpath" "$mod_name" "$mod_path"
            ALL_MODULES_COUNT=$((ALL_MODULES_COUNT + 1))
        fi
    done <<< "$raw_modules"

    # Also check root project if it has src/main
    if [[ -d "src/main" ]]; then
        local has_app=false
        for m in $ALL_MODULES; do
            [[ "$m" == "app" ]] && { has_app=true; break; }
        done
        if ! $has_app; then
            ALL_MODULES="$ALL_MODULES app"
            kv_set "modpath" "app" "."
            ALL_MODULES_COUNT=$((ALL_MODULES_COUNT + 1))
        fi
    fi

    # Trim leading space
    ALL_MODULES="${ALL_MODULES# }"

    if [[ $ALL_MODULES_COUNT -eq 0 ]]; then
        warn "No se detectaron módulos con src/main. Proyecto vacío o estructura no estándar."
    else
        success "Detectados $ALL_MODULES_COUNT módulo(s): $ALL_MODULES"
    fi
}

detect_gradle_version() {
    local props_file="gradle/wrapper/gradle-wrapper.properties"
    if [[ -f "$props_file" ]]; then
        GRADLE_VERSION=$(srg 'distributionUrl' "$props_file" | sed -E 's/.*gradle-([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/')
    fi
    [[ -n "$GRADLE_VERSION" ]] && info "Gradle wrapper: $GRADLE_VERSION" || true
}

detect_sdk_versions() {
    # Search module-level gradle files first (shallow)
    local gradle_files
    gradle_files=$(sfd -e gradle -e kts --max-depth 2 -t f)

    # Also search build-logic/ and buildSrc/ for convention plugins
    local convention_files=""
    if [[ -d "build-logic" ]]; then
        convention_files=$(sfd -e gradle -e kts -t f . "build-logic" 2>/dev/null || true)
    fi
    if [[ -d "buildSrc" ]]; then
        local buildsrc_files
        buildsrc_files=$(sfd -e gradle -e kts -t f . "buildSrc" 2>/dev/null || true)
        convention_files="${convention_files}${convention_files:+$'\n'}${buildsrc_files}"
    fi

    # Combine all gradle files for searching
    local all_gradle_files="${gradle_files}${gradle_files:+$'\n'}${convention_files}"
    all_gradle_files=$(printf '%s' "$all_gradle_files" | sed '/^$/d')

    if [[ -z "$all_gradle_files" ]]; then
        return
    fi

    # Classic format: compileSdk = 34 / compileSdk(34) / compileSdkVersion 34
    if [[ -z "$COMPILE_SDK" ]]; then
        COMPILE_SDK=$(echo "$all_gradle_files" | xargs rg '(compileSdk|compileSdkVersion)\s*[=( ]\s*([0-9]+)' -o --no-filename 2>/dev/null | head -1 | sed -E 's/.*[=( ]+\s*([0-9]+).*/\1/' || true)
    fi
    # New format (Android 16+): compileSdk { version = release(36) { ... } }
    if [[ -z "$COMPILE_SDK" ]]; then
        COMPILE_SDK=$(echo "$all_gradle_files" | xargs rg 'release\(([0-9]+)\)' -o --no-filename 2>/dev/null | head -1 | sed -E 's/.*release\(([0-9]+)\).*/\1/' || true)
    fi
    if [[ -z "$MIN_SDK" ]]; then
        MIN_SDK=$(echo "$all_gradle_files" | xargs rg '(minSdk|minSdkVersion)\s*[=( ]\s*([0-9]+)' -o --no-filename 2>/dev/null | head -1 | sed -E 's/.*[=( ]+\s*([0-9]+).*/\1/' || true)
    fi
    if [[ -z "$TARGET_SDK" ]]; then
        TARGET_SDK=$(echo "$all_gradle_files" | xargs rg '(targetSdk|targetSdkVersion)\s*[=( ]\s*([0-9]+)' -o --no-filename 2>/dev/null | head -1 | sed -E 's/.*[=( ]+\s*([0-9]+).*/\1/' || true)
    fi

    [[ -n "$COMPILE_SDK" ]] && info "compileSdk: $COMPILE_SDK" || true
    [[ -n "$MIN_SDK" ]]     && info "minSdk: $MIN_SDK" || true
    [[ -n "$TARGET_SDK" ]]  && info "targetSdk: $TARGET_SDK" || true
}

detect_version_catalog() {
    local toml_file="gradle/libs.versions.toml"
    if [[ -f "$toml_file" ]]; then
        HAS_VERSION_CATALOG=true
        VERSION_CATALOG_SOURCE="gradle/libs.versions.toml"
        info "Version catalog encontrado: $toml_file"

        # Parse [versions] section
        local in_versions=false
        while IFS= read -r line; do
            line=$(printf '%s' "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            [[ -z "$line" || "$line" == \#* ]] && continue
            if [[ "$line" == "[versions]" ]]; then
                in_versions=true
                continue
            elif [[ "$line" == \[* ]]; then
                in_versions=false
                continue
            fi
            if $in_versions; then
                local key="" val=""
                # Parse: key = "value"
                key=$(printf '%s' "$line" | sed -E 's/^([a-zA-Z0-9_-]+)[[:space:]]*=.*/\1/')
                val=$(printf '%s' "$line" | sed -E 's/^[^"]*"([^"]+)".*/\1/')
                if [[ -n "$key" && -n "$val" && "$val" != "$line" ]]; then
                    kv_set "catalog" "$key" "$val"
                fi
            fi
        done < "$toml_file"

        # Extract kotlin and agp from catalog
        local v
        v=$(kv_get "catalog" "kotlin")
        [[ -n "$v" ]] && KOTLIN_VERSION="$v" || true
        v=$(kv_get "catalog" "agp")
        [[ -n "$v" ]] && AGP_VERSION="$v" || true
        # Common aliases
        if [[ -z "$KOTLIN_VERSION" ]]; then
            v=$(kv_get "catalog" "kotlinVersion"); [[ -n "$v" ]] && KOTLIN_VERSION="$v" || true
            v=$(kv_get "catalog" "kotlin-version"); [[ -n "$v" ]] && KOTLIN_VERSION="$v" || true
        fi
        if [[ -z "$AGP_VERSION" ]]; then
            v=$(kv_get "catalog" "agpVersion"); [[ -n "$v" ]] && AGP_VERSION="$v" || true
            v=$(kv_get "catalog" "agp-version"); [[ -n "$v" ]] && AGP_VERSION="$v" || true
            v=$(kv_get "catalog" "androidGradlePlugin"); [[ -n "$v" ]] && AGP_VERSION="$v" || true
        fi
    else
        VERSION_CATALOG_SOURCE="build.gradle ext"
        info "No hay libs.versions.toml — buscando versiones en build.gradle..."

        local root_gradle=""
        [[ -f "build.gradle" ]]     && root_gradle="build.gradle"
        [[ -f "build.gradle.kts" ]] && root_gradle="build.gradle.kts" || true

        if [[ -n "$root_gradle" ]]; then
            # Kotlin version
            if [[ -z "$KOTLIN_VERSION" ]]; then
                KOTLIN_VERSION=$(srg -o "(kotlin_version|kotlinVersion)\s*[=:]\s*[\"'][0-9][0-9.]+[\"']" "$root_gradle" | head -1 | sed -E "s/.*[\"']([0-9][0-9.]+)[\"'].*/\1/")
            fi
            # AGP version
            if [[ -z "$AGP_VERSION" ]]; then
                AGP_VERSION=$(srg -o 'com\.android\.tools\.build:gradle:([0-9][0-9.]+)' --replace '$1' "$root_gradle" | head -1)
                if [[ -z "$AGP_VERSION" ]]; then
                    AGP_VERSION=$(srg -o "(agp_version|agpVersion)\s*[=:]\s*[\"'][0-9][0-9.]+[\"']" "$root_gradle" | head -1 | sed -E "s/.*[\"']([0-9][0-9.]+)[\"'].*/\1/")
                fi
            fi

            # Try to extract version variables from ext blocks
            local ext_content
            ext_content=$(srg -U 'ext\s*\{[^}]+\}' --multiline "$root_gradle")
            if [[ -n "$ext_content" ]]; then
                while IFS= read -r line; do
                    local key="" val=""
                    if printf '%s' "$line" | rg -q '[a-zA-Z_][a-zA-Z0-9_]*\s*=\s*["\x27][0-9]' 2>/dev/null; then
                        key=$(printf '%s' "$line" | sed -E 's/.*\b([a-zA-Z_][a-zA-Z0-9_]*)\s*=.*/\1/')
                        val=$(printf '%s' "$line" | sed -E "s/.*[\"']([0-9][0-9.]*(-[a-zA-Z0-9._]+)?)[\"'].*/\1/")
                        if [[ -n "$key" && -n "$val" && "$val" != "$line" ]]; then
                            # Normalize key
                            local norm_key
                            norm_key=$(printf '%s' "$key" | sed -E 's/(_version|Version)$//' | sed 's/_/-/g' | tr '[:upper:]' '[:lower:]')
                            kv_set "catalog" "$norm_key" "$val"
                        fi
                    fi
                done <<< "$ext_content"
            fi
        fi
    fi

    [[ -n "$KOTLIN_VERSION" ]] && info "Kotlin: $KOTLIN_VERSION" || true
    [[ -n "$AGP_VERSION" ]]    && info "AGP: $AGP_VERSION" || true
    local cat_count
    cat_count=$(kv_keys "catalog" | wc -l | tr -d ' ')
    [[ $cat_count -gt 0 ]] && info "Versiones detectadas en catálogo: $cat_count" || true
}

detect_di_framework() {
    local hilt_count koin_count dagger_count
    hilt_count=$(srg -l '(@Module|@InstallIn|@HiltAndroidApp|@HiltViewModel)' --type kotlin . 2>/dev/null | wc -l | tr -d ' ')
    hilt_count="${hilt_count:-0}"
    koin_count=$(srg -l '\b(single|factory|viewModel)\s*\{' --type kotlin . 2>/dev/null | wc -l | tr -d ' ')
    koin_count="${koin_count:-0}"
    dagger_count=$(srg -l '(@Component|@Subcomponent|@Provides)' --type kotlin . 2>/dev/null | wc -l | tr -d ' ')
    dagger_count="${dagger_count:-0}"

    if [[ $hilt_count -gt 0 ]]; then
        DI_FRAMEWORK="hilt"
    elif [[ $koin_count -gt 2 ]]; then
        DI_FRAMEWORK="koin"
    elif [[ $dagger_count -gt 0 ]]; then
        DI_FRAMEWORK="dagger"
    else
        DI_FRAMEWORK="manual"
    fi
    info "DI framework: $DI_FRAMEWORK"
}

detect_ksp_kapt() {
    local gradle_files
    gradle_files=$(sfd -e gradle -e kts --max-depth 3 -t f 2>/dev/null)
    [[ -z "$gradle_files" ]] && return

    if echo "$gradle_files" | xargs rg -q '\bksp\b' 2>/dev/null; then
        HAS_KSP=true
    fi
    if echo "$gradle_files" | xargs rg -q '\bkapt\b' 2>/dev/null; then
        HAS_KAPT=true
    fi

    if $HAS_KSP && $HAS_KAPT; then
        DI_PROCESSOR="ksp+kapt"
        info "Procesador: KSP + KAPT (migración parcial)"
    elif $HAS_KSP; then
        DI_PROCESSOR="ksp"
        info "Procesador: KSP"
    elif $HAS_KAPT; then
        DI_PROCESSOR="kapt"
        info "Procesador: KAPT"
    else
        DI_PROCESSOR="none"
    fi
}

detect_build_flavors() {
    local has_flavors
    has_flavors=$(srg -l 'productFlavors\s*\{' --type gradle 2>/dev/null || true)
    if [[ -n "$has_flavors" ]]; then
        local flavor_names
        # Extract lines after productFlavors { that look like "name {" but aren't keywords
        flavor_names=$(srg -A 20 'productFlavors\s*\{' --type gradle --no-filename 2>/dev/null \
            | srg '^\s+(\w+)\s*\{' --replace '$1' 2>/dev/null \
            | rg -v '(productFlavors|dimension|buildConfigField|resValue|manifestPlaceholders)' 2>/dev/null \
            || true)
        if [[ -n "$flavor_names" ]]; then
            BUILD_FLAVORS="$flavor_names"
        fi
        info "Build flavors: ${BUILD_FLAVORS:-detectados pero nombres no parseables}"
    fi
}

estimate_project_age() {
    local age_signals=0

    [[ -n "$(srg -l 'AsyncTask' --type kotlin --type java . 2>/dev/null | head -1)" ]] && age_signals=$((age_signals + 2)) || true
    [[ -n "$(srg -l 'IntentService' --type kotlin --type java . 2>/dev/null | head -1)" ]] && age_signals=$((age_signals + 2)) || true
    [[ -n "$(srg -l 'EventBus' --type kotlin --type java . 2>/dev/null | head -1)" ]] && age_signals=$((age_signals + 1)) || true
    # Android Loader — match standalone Loader usage, not compound names like ImageLoader
    [[ -n "$(srg -l '(extends Loader|: Loader[^a-zA-Z]|LoaderManager|LoaderCallbacks|CursorLoader|AsyncTaskLoader)' --type kotlin --type java . 2>/dev/null | head -1)" ]] && age_signals=$((age_signals + 1)) || true
    local java_files
    java_files=$(sfd -e java --type f . 2>/dev/null | wc -l | tr -d ' ')
    [[ $java_files -gt 10 ]] && age_signals=$((age_signals + 1)) || true
    [[ $java_files -gt 50 ]] && age_signals=$((age_signals + 1)) || true
    [[ -n "$(srg -l 'android\.support\.' --type kotlin --type java . 2>/dev/null | head -1)" ]] && age_signals=$((age_signals + 2)) || true
    $HAS_KAPT && ! $HAS_KSP && age_signals=$((age_signals + 1)) || true

    if [[ $age_signals -ge 4 ]]; then
        PROJECT_TYPE="brownfield"
        PROJECT_AGE="5+ years"
    elif [[ $age_signals -ge 2 ]]; then
        PROJECT_TYPE="brownfield"
        PROJECT_AGE="2-5 years"
    elif [[ $age_signals -ge 1 ]]; then
        PROJECT_TYPE="brownfield"
        PROJECT_AGE="1-2 years"
    else
        PROJECT_TYPE="greenfield"
        PROJECT_AGE="< 1 year"
    fi
}

PROJECT_NAME=""

detect_project_name() {
    # Try settings.gradle(.kts) rootProject.name
    local settings_file=""
    [[ -f "settings.gradle.kts" ]] && settings_file="settings.gradle.kts"
    [[ -f "settings.gradle" ]]     && settings_file="settings.gradle"

    if [[ -n "$settings_file" ]]; then
        PROJECT_NAME=$(srg -o 'rootProject\.name\s*=\s*"([^"]+)"' --replace '$1' "$settings_file" | head -1)
        # Also try single quotes
        if [[ -z "$PROJECT_NAME" ]]; then
            PROJECT_NAME=$(srg -o "rootProject\.name\s*=\s*'([^']+)'" --replace '$1' "$settings_file" | head -1)
        fi
    fi

    # Fallback: directory name
    if [[ -z "$PROJECT_NAME" ]]; then
        PROJECT_NAME=$(basename "$PWD")
    fi

    if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._[:space:]\-]{0,99}$ ]]; then
        PROJECT_NAME="unknown-project"
    fi
    PROJECT_NAME=$(printf '%s' "$PROJECT_NAME" | tr -d '\n\r\t' | cut -c1-100)

    [[ -n "$PROJECT_NAME" ]] && info "Proyecto: $PROJECT_NAME" || true
}

run_nivel1() {
    header "NIVEL 1 — Ficha técnica del proyecto"

    detect_project_name
    detect_modules
    detect_gradle_version
    detect_sdk_versions
    detect_version_catalog
    detect_di_framework
    detect_ksp_kapt
    detect_build_flavors
    estimate_project_age

    success "Nivel 1 completo"
}

# ---------------------------------------------------------------------------
# Nivel 2 — Per-module scan
# ---------------------------------------------------------------------------

# Per-module data stored in KV stores:
#   "mod_meta"  -> key: "modname/field" value: string
#   "arch_mods" -> key: pattern value: "mod1, mod2"

# Aggregated results
ALL_BASE_CLASSES=""      # newline-separated
ALL_FORBIDDEN_ENTRIES="" # newline-separated "mod:patterns"
TOTAL_LOC=0
TOTAL_XML=0
TOTAL_COMPOSABLES=0
TOTAL_RX=0
TOTAL_COROUTINES=0

scan_module() {
    local mod="$1"
    local mod_path
    mod_path=$(kv_get "modpath" "$mod")

    if [[ -z "$mod_path" ]]; then
        warn "Módulo '$mod' no encontrado en el proyecto. Skipping."
        return 1
    fi

    printf "${CYAN}▸${NC} Escaneando módulo: ${BOLD}%s${NC}\n" "$mod"

    # --- Capa 2a: File-system heuristics ---

    # Module type — detect both direct plugin ID and version catalog alias
    local is_app=false
    local build_f=""
    [[ -f "$mod_path/build.gradle" ]]     && build_f="$mod_path/build.gradle"
    [[ -f "$mod_path/build.gradle.kts" ]] && build_f="$mod_path/build.gradle.kts" || true
    if [[ -n "$build_f" ]]; then
        # Direct: id("com.android.application") or apply plugin: 'com.android.application'
        rg -q 'com\.android\.application' "$build_f" 2>/dev/null && is_app=true || true
        # Catalog alias: alias(libs.plugins.android.application)
        ! $is_app && rg -q 'android\.application' "$build_f" 2>/dev/null && is_app=true || true
    fi
    if $is_app; then
        kv_set "mod_meta" "$mod/tipo" "application"
    else
        kv_set "mod_meta" "$mod/tipo" "library"
    fi

    # LOC count (kotlin files)
    local loc=0
    local kotlin_files
    kotlin_files=$(sfd -e kt -t f . "$mod_path/src" 2>/dev/null)
    if [[ -n "$kotlin_files" ]]; then
        loc=$(echo "$kotlin_files" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
    fi
    kv_set "mod_meta" "$mod/loc" "$loc"
    TOTAL_LOC=$((TOTAL_LOC + loc))

    # XML layouts count
    local xml_count=0
    xml_count=$(sfd -e xml -t f . "$mod_path/src/main/res/layout" 2>/dev/null | wc -l | tr -d ' ')
    kv_set "mod_meta" "$mod/xml_layouts" "$xml_count"
    TOTAL_XML=$((TOTAL_XML + xml_count))

    # Composable count
    local comp_count=0
    comp_count=$(count_matches '@Composable' "$mod_path/src")
    kv_set "mod_meta" "$mod/composables" "$comp_count"
    TOTAL_COMPOSABLES=$((TOTAL_COMPOSABLES + comp_count))

    # RxJava vs Coroutines
    local rx_count=0 co_count=0
    rx_count=$(count_matches '(Observable|Single|Completable|Flowable)' "$mod_path/src")
    co_count=$(count_matches '(suspend fun|\.collect|\.flow\b|StateFlow|SharedFlow|MutableStateFlow)' "$mod_path/src")
    kv_set "mod_meta" "$mod/rx_count" "$rx_count"
    kv_set "mod_meta" "$mod/coroutines_count" "$co_count"
    TOTAL_RX=$((TOTAL_RX + rx_count))
    TOTAL_COROUTINES=$((TOTAL_COROUTINES + co_count))

    # Architecture pattern detection
    local has_presenter=false has_viewmodel=false has_mvi=false
    [[ -n "$(srg -l 'class\s+\w*Presenter' --type kotlin "$mod_path/src" 2>/dev/null | head -1)" ]] && has_presenter=true || true
    [[ -n "$(srg -l 'class\s+\w*ViewModel' --type kotlin "$mod_path/src" 2>/dev/null | head -1)" ]] && has_viewmodel=true || true
    [[ -n "$(srg -l '(sealed\s+(class|interface)\s+\w*(Intent|Action|Effect|SideEffect)|MviViewModel|MviStore)' --type kotlin "$mod_path/src" 2>/dev/null | head -1)" ]] && has_mvi=true || true

    local pattern="unknown"
    if $has_mvi; then
        pattern="mvi"
    elif $has_viewmodel; then
        pattern="mvvm"
    elif $has_presenter; then
        pattern="mvp"
    fi
    kv_set "mod_meta" "$mod/arch_pattern" "$pattern"

    # Aggregate arch patterns
    if [[ "$pattern" != "unknown" ]]; then
        local existing
        existing=$(kv_get "arch_mods" "$pattern")
        if [[ -n "$existing" ]]; then
            kv_set "arch_mods" "$pattern" "$existing, \"$mod\""
        else
            kv_set "arch_mods" "$pattern" "\"$mod\""
        fi
    fi

    # Test frameworks
    local test_path="$mod_path/src/test"
    local test_frameworks="none"
    if [[ -d "$test_path" ]]; then
        test_frameworks=""
        [[ -n "$(srg -l 'import org\.junit\.jupiter' "$test_path" --type kotlin 2>/dev/null | head -1)" ]] && test_frameworks="${test_frameworks}junit5 " || true
        [[ -n "$(srg -l 'import org\.junit\.' "$test_path" --type kotlin 2>/dev/null | head -1)" ]] && test_frameworks="${test_frameworks}junit4 " || true
        [[ -n "$(srg -l 'import io\.mockk' "$test_path" --type kotlin 2>/dev/null | head -1)" ]] && test_frameworks="${test_frameworks}mockk " || true
        [[ -n "$(srg -l 'import org\.mockito' "$test_path" --type kotlin 2>/dev/null | head -1)" ]] && test_frameworks="${test_frameworks}mockito " || true
        [[ -n "$(srg -l 'import io\.kotest' "$test_path" --type kotlin 2>/dev/null | head -1)" ]] && test_frameworks="${test_frameworks}kotest " || true
        [[ -n "$(srg -l 'import app\.cash\.turbine' "$test_path" --type kotlin 2>/dev/null | head -1)" ]] && test_frameworks="${test_frameworks}turbine " || true
        [[ -n "$(srg -l 'import kotlinx\.coroutines\.test' "$test_path" --type kotlin 2>/dev/null | head -1)" ]] && test_frameworks="${test_frameworks}coroutines-test " || true
        test_frameworks="${test_frameworks:-none}"
    fi
    kv_set "mod_meta" "$mod/test_frameworks" "$test_frameworks"

    # --- Capa 2b: Pattern recognition ---

    # Base classes
    local bases
    bases=$(srg -o 'abstract class (Base\w+)' --replace '$1' --no-filename --type kotlin "$mod_path/src" 2>/dev/null | sort -u)
    kv_set "mod_meta" "$mod/base_classes" "$bases"
    if [[ -n "$bases" ]]; then
        ALL_BASE_CLASSES="${ALL_BASE_CLASSES}${ALL_BASE_CLASSES:+$'\n'}${bases}"
    fi

    # Custom sealed types
    local sealed_types
    sealed_types=$(srg -o 'sealed (class|interface) (\w+)' --replace '$2' --no-filename --type kotlin "$mod_path/src" 2>/dev/null | sort -u)
    kv_set "mod_meta" "$mod/sealed_types" "$sealed_types"

    # Network error handling
    local error_handling
    error_handling=$(srg -l '(HttpException|NetworkException|ErrorHandler|ErrorMapper)' --type kotlin "$mod_path/src" 2>/dev/null | head -3)
    kv_set "mod_meta" "$mod/error_handling" "$error_handling"

    # Navigation
    local nav_pattern="none"
    [[ -n "$(srg -l 'findNavController' --type kotlin "$mod_path/src" 2>/dev/null | head -1)" ]] && nav_pattern="navigation-component" || true
    [[ -n "$(srg -l 'NavHost|NavGraph' --type kotlin "$mod_path/src" 2>/dev/null | head -1)" ]] && nav_pattern="compose-navigation" || true
    if [[ "$nav_pattern" == "none" ]]; then
        [[ -n "$(srg -l '(Router|Navigator)' --type kotlin "$mod_path/src" 2>/dev/null | head -1)" ]] && nav_pattern="custom-router" || true
    fi
    kv_set "mod_meta" "$mod/nav_pattern" "$nav_pattern"

    # Event bus / legacy comms
    local event_bus
    event_bus=$(srg -o '(EventBus|Otto|LocalBroadcastManager|LiveDataBus)' --no-filename --type kotlin "$mod_path/src" 2>/dev/null | sort -u | tr '\n' ',' | sed 's/,$//')
    kv_set "mod_meta" "$mod/event_bus" "$event_bus"

    # Forbidden patterns — AsyncTask and IntentService are always forbidden
    local forbidden
    forbidden=$(srg -o '(AsyncTask|IntentService)' --no-filename --type kotlin --type java "$mod_path/src" 2>/dev/null | sort -u | tr '\n' ',' | sed 's/,$//')
    # Android Loader — only match actual Loader API usage, not compound names like ImageLoader/DataLoader
    local loader_hits
    loader_hits=$(srg -o '(extends Loader|: Loader[^a-zA-Z]|LoaderManager|LoaderCallbacks|CursorLoader|AsyncTaskLoader)' --no-filename --type kotlin --type java "$mod_path/src" 2>/dev/null | head -1)
    if [[ -n "$loader_hits" ]]; then
        if [[ -n "$forbidden" ]]; then
            forbidden="${forbidden},Loader"
        else
            forbidden="Loader"
        fi
    fi
    kv_set "mod_meta" "$mod/forbidden" "$forbidden"
    if [[ -n "$forbidden" ]]; then
        ALL_FORBIDDEN_ENTRIES="${ALL_FORBIDDEN_ENTRIES}${ALL_FORBIDDEN_ENTRIES:+$'\n'}${mod}:${forbidden}"
    fi

    # Module dependencies from build.gradle
    local build_file=""
    [[ -f "$mod_path/build.gradle" ]]     && build_file="$mod_path/build.gradle"
    [[ -f "$mod_path/build.gradle.kts" ]] && build_file="$mod_path/build.gradle.kts" || true
    if [[ -n "$build_file" ]]; then
        local mod_deps
        mod_deps=$(srg -o '(implementation|api|kapt|ksp)\s*[( ]+["'"'"']([^"'"'"']+)["'"'"']' --replace '$1: $2' "$build_file" 2>/dev/null | head -30)
        kv_set "mod_meta" "$mod/deps" "$mod_deps"
    fi

    local loc_fmt
    loc_fmt=$(format_loc "$loc")
    success "  $mod: ${loc_fmt} LOC, ${xml_count} XML layouts, ${comp_count} composables, arch=$pattern"
}

quick_loc_estimate() {
    local mod="$1"
    local mod_path
    mod_path=$(kv_get "modpath" "$mod")
    [[ -z "$mod_path" ]] && { printf "0"; return; }
    local kt_files
    kt_files=$(sfd -e kt -t f . "$mod_path/src" 2>/dev/null | wc -l | tr -d ' ')
    printf '%d' $((kt_files * 80))
}

# ---------------------------------------------------------------------------
# Interactive module selector
# ---------------------------------------------------------------------------
interactive_select() {
    # Convert ALL_MODULES to indexed arrays
    local i=0
    local mod_arr=""
    local sel_arr=""
    for m in $ALL_MODULES; do
        mod_arr="${mod_arr}${mod_arr:+ }$m"
        if [[ "$m" == "app" ]]; then
            sel_arr="${sel_arr}${sel_arr:+ }1"
        else
            sel_arr="${sel_arr}${sel_arr:+ }0"
        fi
        i=$((i + 1))
    done

    while true; do
        printf "\n${BOLD}Proyecto: %d módulos detectados${NC}\n\n" "$ALL_MODULES_COUNT"
        i=0
        for m in $mod_arr; do
            i=$((i + 1))
            local loc_est
            loc_est=$(quick_loc_estimate "$m")
            local loc_fmt
            loc_fmt=$(format_loc "$loc_est")
            local sel
            sel=$(echo "$sel_arr" | awk -v n="$i" '{print $n}')
            local marker="[ ]"
            [[ "$sel" == "1" ]] && marker="[x]" || true
            printf "  ${BOLD}%2d.${NC} %s %s ${DIM}(%s LOC est.)${NC}\n" "$i" "$marker" "$m" "$loc_fmt"
        done
        printf "\n"
        printf "Ingresá números separados por espacio para toggle (Enter = confirmar): "
        read -r input

        if [[ -z "$input" ]]; then
            break
        fi

        for num in $input; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le $ALL_MODULES_COUNT ]]; then
                # Toggle the selection
                local new_sel=""
                local j=0
                for s in $sel_arr; do
                    j=$((j + 1))
                    if [[ $j -eq $num ]]; then
                        if [[ "$s" == "1" ]]; then
                            new_sel="${new_sel}${new_sel:+ }0"
                        else
                            new_sel="${new_sel}${new_sel:+ }1"
                        fi
                    else
                        new_sel="${new_sel}${new_sel:+ }$s"
                    fi
                done
                sel_arr="$new_sel"
            else
                warn "Número inválido: $num"
            fi
        done
    done

    SELECTED_MODULES=""
    i=0
    for m in $mod_arr; do
        i=$((i + 1))
        local sel
        sel=$(echo "$sel_arr" | awk -v n="$i" '{print $n}')
        if [[ "$sel" == "1" ]]; then
            SELECTED_MODULES="${SELECTED_MODULES}${SELECTED_MODULES:+ }$m"
        fi
    done

    if [[ -z "$SELECTED_MODULES" ]]; then
        warn "No se seleccionó ningún módulo. Solo se generará Nivel 1."
        MODE="project-only"
    else
        success "Módulos seleccionados: $SELECTED_MODULES"
    fi
}

# ---------------------------------------------------------------------------
# Resolve modules to scan
# ---------------------------------------------------------------------------
resolve_modules() {
    case "$MODE" in
        full)
            SELECTED_MODULES="$ALL_MODULES"
            ;;
        interactive)
            interactive_select
            ;;
        selective)
            # Validate selected modules exist
            local valid=""
            for m in $SELECTED_MODULES; do
                local mp
                mp=$(kv_get "modpath" "$m")
                if [[ -n "$mp" ]]; then
                    valid="${valid}${valid:+ }$m"
                else
                    warn "Módulo '$m' no encontrado en el proyecto. Ignorando."
                fi
            done
            SELECTED_MODULES="$valid"
            if [[ -z "$SELECTED_MODULES" ]]; then
                errlog "Ninguno de los módulos especificados existe."
                exit 1
            fi
            ;;
        project-only)
            SELECTED_MODULES=""
            ;;
    esac
}

run_nivel2() {
    [[ -z "$SELECTED_MODULES" ]] && return

    header "NIVEL 2 — Análisis por módulo"

    local count=0
    for mod in $SELECTED_MODULES; do
        scan_module "$mod" || true
        count=$((count + 1))
    done

    success "Nivel 2 completo — $count módulo(s) escaneados"
}

# ---------------------------------------------------------------------------
# Confidence scoring
# ---------------------------------------------------------------------------
CONFIDENCE="high"

calculate_confidence() {
    local score=100

    [[ -z "$KOTLIN_VERSION" ]] && score=$((score - 15)) || true
    [[ -z "$AGP_VERSION" ]]    && score=$((score - 10)) || true
    [[ -z "$MIN_SDK" ]]        && score=$((score - 10)) || true
    [[ -z "$GRADLE_VERSION" ]] && score=$((score - 5)) || true
    [[ $ALL_MODULES_COUNT -eq 0 ]] && score=$((score - 20)) || true

    # Mixed architecture signals reduce confidence
    local pattern_count=0
    for p in mvp mvvm mvi; do
        local v
        v=$(kv_get "arch_mods" "$p")
        [[ -n "$v" ]] && pattern_count=$((pattern_count + 1)) || true
    done
    [[ $pattern_count -gt 1 ]] && score=$((score - 10)) || true

    local cat_count
    cat_count=$(kv_keys "catalog" | wc -l | tr -d ' ')
    [[ $cat_count -eq 0 ]] && score=$((score - 15)) || true

    if [[ $score -ge 80 ]]; then
        CONFIDENCE="high"
    elif [[ $score -ge 50 ]]; then
        CONFIDENCE="medium"
    else
        CONFIDENCE="low"
    fi
}

# ---------------------------------------------------------------------------
# Compute aggregated analysis
# ---------------------------------------------------------------------------
DOMINANT_PATTERN="unknown"
HAS_COROUTINES=false
HAS_RXJAVA=false
ASYNC_MIGRATION="none"
HTTP_CLIENT=""
API_LAYER=""
LOCAL_DB=""
IMAGE_LOADING=""
NAV_TYPE="none"
ESTRUCTURA_TYPE="single-module"
UI_XML_PCT=0
UI_COMPOSE_PCT=0
UI_MIGRATION_STATE="none"
TEST_UNIT_FRAMEWORK="none"
TEST_MOCK_FRAMEWORK="none"
TEST_RATIO=0

compute_aggregates() {
    # Structure type
    [[ $ALL_MODULES_COUNT -gt 1 ]] && ESTRUCTURA_TYPE="multi-module" || true

    # Dominant architecture pattern (prefer mvvm > mvi > mvp on tie)
    local max_count=0
    for p in mvp mvi mvvm; do
        local mods
        mods=$(kv_get "arch_mods" "$p")
        if [[ -n "$mods" ]]; then
            local count
            count=$(printf '%s' "$mods" | tr ',' '\n' | wc -l | tr -d ' ')
            if [[ $count -ge $max_count && $count -gt 0 ]]; then
                max_count=$count
                DOMINANT_PATTERN="$p"
            fi
        fi
    done

    # Async patterns
    [[ $TOTAL_COROUTINES -gt 0 ]] && HAS_COROUTINES=true || true
    [[ $TOTAL_RX -gt 0 ]]         && HAS_RXJAVA=true || true
    if $HAS_COROUTINES && $HAS_RXJAVA; then
        ASYNC_MIGRATION="parcial"
    elif $HAS_COROUTINES; then
        ASYNC_MIGRATION="coroutines-only"
    elif $HAS_RXJAVA; then
        ASYNC_MIGRATION="rxjava-only"
    fi

    # UI paradigm percentages
    local total_ui=$((TOTAL_XML + TOTAL_COMPOSABLES))
    if [[ $total_ui -gt 0 ]]; then
        UI_XML_PCT=$((TOTAL_XML * 100 / total_ui))
        UI_COMPOSE_PCT=$((TOTAL_COMPOSABLES * 100 / total_ui))
        if [[ $UI_XML_PCT -gt 0 && $UI_COMPOSE_PCT -gt 0 ]]; then
            UI_MIGRATION_STATE="parcial"
        elif [[ $UI_COMPOSE_PCT -gt 0 ]]; then
            UI_MIGRATION_STATE="compose"
        else
            UI_MIGRATION_STATE="xml"
        fi
    fi

    # Detect networking, DB, image loading from all deps and catalog
    local all_deps=""
    for mod in $SELECTED_MODULES; do
        local d
        d=$(kv_get "mod_meta" "$mod/deps")
        all_deps="$all_deps $d"
    done
    # Add catalog keys
    local cat_keys
    cat_keys=$(kv_keys "catalog")
    all_deps="$all_deps $cat_keys"

    printf '%s' "$all_deps" | rg -qi 'okhttp' 2>/dev/null    && HTTP_CLIENT="okhttp" || true
    printf '%s' "$all_deps" | rg -qi 'retrofit' 2>/dev/null   && API_LAYER="retrofit" || true
    printf '%s' "$all_deps" | rg -qi 'ktor' 2>/dev/null       && { [[ -z "$API_LAYER" ]] && API_LAYER="ktor" || true; } || true
    printf '%s' "$all_deps" | rg -qi 'room' 2>/dev/null       && LOCAL_DB="room" || true
    printf '%s' "$all_deps" | rg -qi 'realm' 2>/dev/null      && { [[ -z "$LOCAL_DB" ]] && LOCAL_DB="realm" || true; } || true
    printf '%s' "$all_deps" | rg -qi 'sqldelight' 2>/dev/null && { [[ -z "$LOCAL_DB" ]] && LOCAL_DB="sqldelight" || true; } || true
    printf '%s' "$all_deps" | rg -qi 'coil' 2>/dev/null       && IMAGE_LOADING="coil" || true
    printf '%s' "$all_deps" | rg -qi 'glide' 2>/dev/null      && { [[ -z "$IMAGE_LOADING" ]] && IMAGE_LOADING="glide" || true; } || true
    printf '%s' "$all_deps" | rg -qi 'picasso' 2>/dev/null    && { [[ -z "$IMAGE_LOADING" ]] && IMAGE_LOADING="picasso" || true; } || true

    # Test frameworks aggregate
    local has_junit5=false has_junit4=false has_mockk=false has_mockito=false
    for mod in $SELECTED_MODULES; do
        local tf
        tf=$(kv_get "mod_meta" "$mod/test_frameworks")
        [[ "$tf" == *junit5* ]]          && has_junit5=true
        [[ "$tf" == *junit4* ]]          && has_junit4=true
        [[ "$tf" == *mockk* ]]           && has_mockk=true
        [[ "$tf" == *mockito* ]]         && has_mockito=true
    done

    if $has_junit5; then TEST_UNIT_FRAMEWORK="junit5"
    elif $has_junit4; then TEST_UNIT_FRAMEWORK="junit4"
    fi
    if $has_mockk; then TEST_MOCK_FRAMEWORK="mockk"
    elif $has_mockito; then TEST_MOCK_FRAMEWORK="mockito"
    fi

    # Navigation aggregate
    for mod in $SELECTED_MODULES; do
        local np
        np=$(kv_get "mod_meta" "$mod/nav_pattern")
        if [[ -n "$np" && "$np" != "none" ]]; then
            NAV_TYPE="$np"
            break
        fi
    done

    # Test ratio estimate
    local total_test_files=0 total_src_files=0
    for mod in $SELECTED_MODULES; do
        local mp
        mp=$(kv_get "modpath" "$mod")
        [[ -z "$mp" ]] && continue
        local tc sc
        tc=$(sfd -e kt -t f . "$mp/src/test" 2>/dev/null | wc -l | tr -d ' ')
        sc=$(sfd -e kt -t f . "$mp/src/main" 2>/dev/null | wc -l | tr -d ' ')
        total_test_files=$((total_test_files + tc))
        total_src_files=$((total_src_files + sc))
    done
    if [[ $total_src_files -gt 0 ]]; then
        TEST_RATIO=$((total_test_files * 100 / total_src_files))
    fi

    # Deduplicate base classes
    if [[ -n "$ALL_BASE_CLASSES" ]]; then
        ALL_BASE_CLASSES=$(printf '%s\n' "$ALL_BASE_CLASSES" | sort -u | tr '\n' ' ' | sed 's/ $//')
    fi
}

# ---------------------------------------------------------------------------
# Incremental merge — preserve existing DNA data
# ---------------------------------------------------------------------------
EXISTING_TRIBAL_KNOWLEDGE=""

load_existing_dna() {
    if [[ ! -f "$DNA_FILE" ]]; then
        return
    fi

    info "DNA existente encontrado — modo incremental"

    local in_tribal=false
    local tribal=""
    while IFS= read -r line; do
        if [[ "$line" == "tribal_knowledge:"* ]]; then
            in_tribal=true
        elif $in_tribal; then
            # Exit tribal section when we hit a non-indented, non-empty top-level key
            if [[ -n "$line" && "$line" != " "* && "$line" != "	"* && "$line" != "#"* ]]; then
                in_tribal=false
                continue
            fi
        fi
        if $in_tribal; then
            tribal="${tribal}${line}
"
        fi
    done < "$DNA_FILE"
    local tk_size
    tk_size=$(printf '%s' "$tribal" | wc -c)
    if [[ $tk_size -gt 5000 ]]; then
        tribal=""
    fi
    tribal=$(printf '%s' "$tribal" | tr -d '\r' | grep -v '^\s*system:\|^\s*instructions:\|^\s*SYSTEM:\|^\s*INSTRUCTIONS:')
    EXISTING_TRIBAL_KNOWLEDGE="$tribal"
}

# ---------------------------------------------------------------------------
# YAML generation
# ---------------------------------------------------------------------------
generate_yaml() {
    header "Generando DNA"

    mkdir -p .forge

    local scan_mode="full"
    if [[ "$MODE" == "selective" || "$MODE" == "project-only" ]]; then
        scan_mode="incremental"
    fi

    # Build scanned/pending module lists
    local scanned_list=""
    local pending_list=""
    for mod in $SELECTED_MODULES; do
        scanned_list="${scanned_list}${scanned_list:+, }\"$mod\""
    done
    for mod in $ALL_MODULES; do
        local is_scanned=false
        for s in $SELECTED_MODULES; do
            [[ "$s" == "$mod" ]] && { is_scanned=true; break; }
        done
        if ! $is_scanned; then
            pending_list="${pending_list}${pending_list:+, }\"$mod\""
        fi
    done

    {
        printf '# .forge/project-dna.yaml — Generated by forge-scan, editable by dev\n'
        printf '# Last scan: %s\n\n' "$SCAN_TIMESTAMP"

        printf 'scan_version: "%s"\n' "$SCAN_VERSION"
        printf 'scan_date: "%s"\n' "$SCAN_DATE"
        printf 'scan_mode: %s\n' "$scan_mode"
        printf 'modulos_escaneados: [%s]\n' "$scanned_list"
        printf 'modulos_pendientes: [%s]\n' "$pending_list"
        printf 'confidence: %s\n' "$CONFIDENCE"

        # --- Nivel 1: Project-wide ---
        printf '\n# --- Nivel 1: Project-wide (siempre presente) ---\n\n'

        printf 'proyecto:\n'
        printf '  nombre: %s\n' "$(yaml_escape "${PROJECT_NAME:-unknown}")"
        printf '  tipo: %s\n' "$PROJECT_TYPE"
        printf '  edad_estimada: "%s"\n' "$PROJECT_AGE"
        printf '  gradle_version: %s\n' "$(yaml_escape "${GRADLE_VERSION:-unknown}")"
        printf '  compile_sdk: %s\n' "${COMPILE_SDK:-unknown}"
        printf '  min_sdk: %s\n' "${MIN_SDK:-unknown}"
        printf '  target_sdk: %s\n' "${TARGET_SDK:-unknown}"

        printf '\nversion_catalog:\n'
        printf '  source: %s\n' "$(yaml_escape "$VERSION_CATALOG_SOURCE")"
        printf '  versions:\n'
        [[ -n "$KOTLIN_VERSION" ]] && printf '    kotlin: "%s"\n' "$KOTLIN_VERSION" || true
        [[ -n "$AGP_VERSION" ]]    && printf '    agp: "%s"\n' "$AGP_VERSION" || true
        # Output all catalog versions (skip kotlin/agp duplicates)
        local cat_keys
        cat_keys=$(kv_keys "catalog" | sort)
        if [[ -n "$cat_keys" ]]; then
            while IFS= read -r key; do
                [[ -z "$key" ]] && continue
                # Skip keys already handled
                case "$key" in
                    kotlin|agp|kotlinVersion|kotlin-version|agpVersion|agp-version|androidGradlePlugin) continue ;;
                esac
                if [[ ! "$key" =~ ^[a-zA-Z][a-zA-Z0-9_-]{0,49}$ ]]; then
                    continue
                fi
                local val
                val=$(kv_get "catalog" "$key")
                if [[ ! "$val" =~ ^[0-9a-zA-Z._\-+]{1,50}$ ]]; then
                    continue
                fi
                printf '    %s: "%s"\n' "$key" "$val"
            done <<< "$cat_keys"
        fi

        # Build flavors
        if [[ -n "$BUILD_FLAVORS" ]]; then
            printf '\nbuild_flavors:\n'
            while IFS= read -r flavor; do
                [[ -z "$flavor" ]] && continue
                if [[ ! "$flavor" =~ ^[a-zA-Z][a-zA-Z0-9_]{0,49}$ ]]; then
                    continue
                fi
                printf '  - %s\n' "$(yaml_escape "$flavor")"
            done <<< "$BUILD_FLAVORS"
        fi

        # --- Nivel 2: Per-module ---
        if [[ -n "$SELECTED_MODULES" || $ALL_MODULES_COUNT -gt 0 ]]; then
            printf '\n# --- Nivel 2: Per-module (solo modulos escaneados) ---\n\n'

            printf 'estructura:\n'
            printf '  tipo: %s\n' "$ESTRUCTURA_TYPE"
            printf '  modulos:\n'

            # Scanned modules with full data
            for mod in $SELECTED_MODULES; do
                local tipo loc xml comp
                tipo=$(kv_get "mod_meta" "$mod/tipo")
                loc=$(kv_get "mod_meta" "$mod/loc")
                xml=$(kv_get "mod_meta" "$mod/xml_layouts")
                comp=$(kv_get "mod_meta" "$mod/composables")
                printf '    - nombre: %s\n' "$mod"
                printf '      tipo: %s\n' "${tipo:-library}"
                printf '      escaneado: true\n'
                printf '      loc_kotlin: %d\n' "${loc:-0}"
                printf '      xml_layouts: %d\n' "${xml:-0}"
                printf '      composables: %d\n' "${comp:-0}"
            done

            # Unscanned modules
            for mod in $ALL_MODULES; do
                local is_scanned=false
                for s in $SELECTED_MODULES; do
                    [[ "$s" == "$mod" ]] && { is_scanned=true; break; }
                done
                if ! $is_scanned; then
                    printf '    - nombre: %s\n' "$mod"
                    printf '      tipo: library\n'
                    printf '      escaneado: false\n'
                fi
            done

            # UI paradigm
            if [[ -n "$SELECTED_MODULES" ]]; then
                printf '  ui_paradigma:\n'
                printf '    xml_pct: %d\n' "$UI_XML_PCT"
                printf '    compose_pct: %d\n' "$UI_COMPOSE_PCT"
                printf '    estado_migracion: %s\n' "$UI_MIGRATION_STATE"
            fi
        fi

        # Architecture
        if [[ -n "$SELECTED_MODULES" ]]; then
            printf '\narquitectura:\n'
            printf '  patron_dominante: %s\n' "$DOMINANT_PATTERN"
            printf '  patrones_detectados:\n'
            for p in mvp mvvm mvi; do
                local mods
                mods=$(kv_get "arch_mods" "$p")
                printf '    %s: [%s]\n' "$p" "${mods:-}"
            done

            # Base classes
            if [[ -n "$ALL_BASE_CLASSES" ]]; then
                printf '  base_classes:\n'
                for bc in $ALL_BASE_CLASSES; do
                    printf '    - "%s"\n' "$bc"
                done
            fi
        fi

        # Dependencies
        printf '\ndependencias:\n'
        printf '  di:\n'
        printf '    framework: %s\n' "$DI_FRAMEWORK"
        printf '    procesador: %s\n' "$DI_PROCESSOR"
        if [[ -n "$SELECTED_MODULES" ]]; then
            printf '  async:\n'
            printf '    coroutines: %s\n' "$HAS_COROUTINES"
            printf '    rxjava: %s\n' "$HAS_RXJAVA"
            if [[ "$ASYNC_MIGRATION" == "parcial" ]]; then
                printf '    migracion_rx_coroutines: parcial\n'
            fi
            if [[ -n "$HTTP_CLIENT" || -n "$API_LAYER" ]]; then
                printf '  networking:\n'
                [[ -n "$HTTP_CLIENT" ]] && printf '    http_client: %s\n' "$HTTP_CLIENT" || true
                [[ -n "$API_LAYER" ]]   && printf '    api_layer: %s\n' "$API_LAYER" || true
            fi
            if [[ -n "$LOCAL_DB" ]]; then
                printf '  local_db:\n'
                printf '    framework: %s\n' "$LOCAL_DB"
            fi
            if [[ "$NAV_TYPE" != "none" ]]; then
                printf '  navigation:\n'
                printf '    tipo: %s\n' "$NAV_TYPE"
            fi
            if [[ -n "$IMAGE_LOADING" ]]; then
                printf '  image_loading: %s\n' "$IMAGE_LOADING"
            fi
        fi

        # Testing
        if [[ -n "$SELECTED_MODULES" ]]; then
            printf '\ntesting:\n'
            printf '  frameworks:\n'
            printf '    unit: %s\n' "$TEST_UNIT_FRAMEWORK"
            printf '    mocking: %s\n' "$TEST_MOCK_FRAMEWORK"
            printf '  cobertura_estimada:\n'
            printf '    ratio_test_src: %d\n' "$TEST_RATIO"

            # Test infra: base test classes
            local test_bases=""
            for mod in $SELECTED_MODULES; do
                local mp
                mp=$(kv_get "modpath" "$mod")
                [[ -z "$mp" ]] && continue
                local tb
                tb=$(srg -o 'abstract class (Base\w*Test\w*)' --replace '$1' --no-filename --type kotlin "$mp/src/test" 2>/dev/null | sort -u)
                [[ -n "$tb" ]] && test_bases="${test_bases}${test_bases:+$'\n'}${tb}" || true
            done
            if [[ -n "$test_bases" ]]; then
                printf '  infra_existente:\n'
                printf '    base_test_classes:\n'
                printf '%s\n' "$test_bases" | sort -u | while IFS= read -r tb; do
                    [[ -n "$tb" ]] && printf '      - "%s"\n' "$tb" || true
                done
            fi
        fi

        # Legacy patterns
        if [[ -n "$SELECTED_MODULES" ]]; then
            local has_legacy=false
            for mod in $SELECTED_MODULES; do
                local forbidden event_bus
                forbidden=$(kv_get "mod_meta" "$mod/forbidden")
                event_bus=$(kv_get "mod_meta" "$mod/event_bus")
                if [[ -n "$forbidden" || -n "$event_bus" ]]; then
                    has_legacy=true
                    break
                fi
            done

            if $has_legacy; then
                printf '\npatrones_legacy:\n'
                printf '  activos:\n'
                for mod in $SELECTED_MODULES; do
                    local forbidden
                    forbidden=$(kv_get "mod_meta" "$mod/forbidden")
                    if [[ -n "$forbidden" ]]; then
                        local IFS=','
                        for pat in $forbidden; do
                            pat=$(printf '%s' "$pat" | sed 's/^[[:space:]]*//')
                            printf '    - pattern: "%s"\n' "$pat"
                            printf '      ubicacion: ["%s"]\n' "$mod"
                            printf '      nota: "Zombie — deberia estar muerto pero no lo esta"\n'
                        done
                        unset IFS
                    fi
                    local ebus
                    ebus=$(kv_get "mod_meta" "$mod/event_bus")
                    if [[ -n "$ebus" ]]; then
                        local IFS=','
                        for pat in $ebus; do
                            pat=$(printf '%s' "$pat" | sed 's/^[[:space:]]*//')
                            printf '    - pattern: "%s"\n' "$pat"
                            printf '      ubicacion: ["%s"]\n' "$mod"
                            printf '      nota: "Comunicacion legacy inter-componente"\n'
                        done
                        unset IFS
                    fi
                done
            fi

            # First sealed Result/Either/Resource type found
            for mod in $SELECTED_MODULES; do
                local sealed
                sealed=$(kv_get "mod_meta" "$mod/sealed_types")
                if [[ -n "$sealed" ]]; then
                    while IFS= read -r st; do
                        [[ -z "$st" ]] && continue
                        case "$st" in
                            Result|Either|Resource|UiState|State|Error)
                                printf '  resultado_custom:\n'
                                printf '    tipo: "sealed class/interface %s"\n' "$st"
                                printf '    ubicacion: "%s"\n' "$mod"
                                break 2
                                ;;
                        esac
                    done <<< "$sealed"
                fi
            done
        fi

        # Preserve tribal_knowledge from existing DNA
        if [[ -n "$EXISTING_TRIBAL_KNOWLEDGE" ]]; then
            printf '\n%s' "$EXISTING_TRIBAL_KNOWLEDGE"
        fi

    } > "$DNA_FILE"

    success "DNA generado: $DNA_FILE"
}

# ---------------------------------------------------------------------------
# Terminal summary
# ---------------------------------------------------------------------------
print_summary() {
    header "RESUMEN DEL PROYECTO"

    printf "\n"
    printf "  ${BOLD}Tipo:${NC}           %s (%s)\n" "$PROJECT_TYPE" "$PROJECT_AGE"
    printf "  ${BOLD}Kotlin:${NC}         %s\n" "${KOTLIN_VERSION:-no detectado}"
    printf "  ${BOLD}AGP:${NC}            %s\n" "${AGP_VERSION:-no detectado}"
    local compose_bom
    compose_bom=$(kv_get "catalog" "compose-bom")
    [[ -z "$compose_bom" ]] && compose_bom=$(kv_get "catalog" "composeBom") || true
    [[ -z "$compose_bom" ]] && compose_bom=$(kv_get "catalog" "androidxComposeBom") || true
    [[ -z "$compose_bom" ]] && compose_bom=$(kv_get "catalog" "compose_bom") || true
    printf "  ${BOLD}Compose BOM:${NC}    %s\n" "${compose_bom:-no detectado}"
    printf "  ${BOLD}Gradle:${NC}         %s\n" "${GRADLE_VERSION:-no detectado}"
    printf "  ${BOLD}SDK:${NC}            min=%s target=%s compile=%s\n" "${MIN_SDK:-?}" "${TARGET_SDK:-?}" "${COMPILE_SDK:-?}"
    printf "  ${BOLD}DI:${NC}             %s (%s)\n" "$DI_FRAMEWORK" "$DI_PROCESSOR"

    # Module breakdown
    printf "\n  ${BOLD}Módulos:${NC}        %d total" "$ALL_MODULES_COUNT"
    local selected_count=0
    for m in $SELECTED_MODULES; do
        selected_count=$((selected_count + 1))
    done
    if [[ $selected_count -gt 0 && $selected_count -lt $ALL_MODULES_COUNT ]]; then
        printf " (%d escaneados)" "$selected_count"
    fi
    printf "\n"

    if [[ -n "$SELECTED_MODULES" ]]; then
        for mod in $SELECTED_MODULES; do
            local loc xml comp arch_p
            loc=$(kv_get "mod_meta" "$mod/loc")
            xml=$(kv_get "mod_meta" "$mod/xml_layouts")
            comp=$(kv_get "mod_meta" "$mod/composables")
            arch_p=$(kv_get "mod_meta" "$mod/arch_pattern")
            local loc_fmt
            loc_fmt=$(format_loc "${loc:-0}")
            printf "                  ${DIM}├─${NC} %s: %s LOC, %s XML, %s composables, %s\n" \
                "$mod" "$loc_fmt" "${xml:-0}" "${comp:-0}" "${arch_p:-?}"
        done
    fi

    # Architecture
    if [[ -n "$SELECTED_MODULES" ]]; then
        printf "\n  ${BOLD}Arquitectura:${NC}   %s (dominante)\n" "$DOMINANT_PATTERN"
        for p in mvp mvvm mvi; do
            local mods
            mods=$(kv_get "arch_mods" "$p")
            [[ -n "$mods" ]] && printf "                  ${DIM}%s:${NC} [%s]\n" "$p" "$mods" || true
        done

        # Async
        printf "\n  ${BOLD}Async:${NC}          "
        if $HAS_COROUTINES && $HAS_RXJAVA; then
            printf "Coroutines + RxJava (migración parcial)\n"
        elif $HAS_COROUTINES; then
            printf "Coroutines\n"
        elif $HAS_RXJAVA; then
            printf "RxJava\n"
        else
            printf "No detectado\n"
        fi

        # UI
        printf "  ${BOLD}UI:${NC}             %d%% XML / %d%% Compose\n" "$UI_XML_PCT" "$UI_COMPOSE_PCT"

        # Testing
        printf "  ${BOLD}Testing:${NC}        %s + %s (ratio: %d%%)\n" "$TEST_UNIT_FRAMEWORK" "$TEST_MOCK_FRAMEWORK" "$TEST_RATIO"
    fi

    # Warnings for legacy/forbidden patterns
    if [[ -n "$SELECTED_MODULES" ]]; then
        local has_warnings=false
        for mod in $SELECTED_MODULES; do
            local forbidden event_bus
            forbidden=$(kv_get "mod_meta" "$mod/forbidden")
            event_bus=$(kv_get "mod_meta" "$mod/event_bus")
            if [[ -n "$forbidden" || -n "$event_bus" ]]; then
                has_warnings=true
                break
            fi
        done

        if $has_warnings; then
            printf "\n  ${YELLOW}${BOLD}ADVERTENCIAS:${NC}\n"
            for mod in $SELECTED_MODULES; do
                local forbidden event_bus
                forbidden=$(kv_get "mod_meta" "$mod/forbidden")
                event_bus=$(kv_get "mod_meta" "$mod/event_bus")
                [[ -n "$forbidden" ]] && warn "  $mod tiene patrones prohibidos: $forbidden" || true
                [[ -n "$event_bus" ]]  && warn "  $mod usa comunicación legacy: $event_bus" || true
            done
        fi
    fi

    # Base classes
    if [[ -n "$ALL_BASE_CLASSES" ]]; then
        printf "\n  ${BOLD}Base classes:${NC}   %s\n" "$ALL_BASE_CLASSES"
    fi

    # Confidence
    printf "\n  ${BOLD}Confianza:${NC}      "
    case "$CONFIDENCE" in
        high)   printf "${GREEN}ALTA${NC} — Señales claras y consistentes\n" ;;
        medium) printf "${YELLOW}MEDIA${NC} — Algunas señales ambiguas\n" ;;
        low)    printf "${RED}BAJA${NC} — Muchas señales faltantes o ambiguas\n" ;;
    esac

    # Pending modules hint
    local pending_count=$((ALL_MODULES_COUNT - selected_count))
    if [[ $pending_count -gt 0 && "$MODE" != "full" ]]; then
        printf "\n  ${DIM}Hay %d módulo(s) sin escanear. Ejecutá:${NC}\n" "$pending_count"
        printf "  ${DIM}  forge-scan.sh <modulo>   para agregar módulos al DNA${NC}\n"
    fi

    printf "\n"
}

# ---------------------------------------------------------------------------
# Update config.yaml with detected values
# ---------------------------------------------------------------------------
update_config() {
    local config_file=".forge/config.yaml"
    [[ ! -f "$config_file" ]] && return

    info "Actualizando config.yaml con valores detectados..."

    # proyecto.nombre
    if [[ -n "$PROJECT_NAME" ]]; then
        awk -v val="$PROJECT_NAME" '
            /nombre: "/ { sub(/nombre: ".*"/, "nombre: \"" val "\"") }
            { print }
        ' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
    fi

    # proyecto.descripcion — auto-generate from detected data
    local desc_parts=""
    [[ "$ESTRUCTURA_TYPE" == "multi-module" ]] && desc_parts="Multi-module" || desc_parts="Single-module"
    desc_parts="$desc_parts Android"
    if [[ -n "$DI_FRAMEWORK" && "$DI_FRAMEWORK" != "manual" ]]; then
        local di_cap
        di_cap="$(printf '%s' "$DI_FRAMEWORK" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
        desc_parts="$desc_parts + $di_cap"
    fi
    [[ $TOTAL_COMPOSABLES -gt 0 && $TOTAL_XML -eq 0 ]] && desc_parts="$desc_parts + Compose"
    [[ $TOTAL_COMPOSABLES -gt 0 && $TOTAL_XML -gt 0 ]] && desc_parts="$desc_parts + Compose/XML"
    [[ $TOTAL_XML -gt 0 && $TOTAL_COMPOSABLES -eq 0 ]] && desc_parts="$desc_parts + XML"
    $HAS_COROUTINES && desc_parts="$desc_parts + Coroutines" || true
    $HAS_RXJAVA && desc_parts="$desc_parts + RxJava" || true
    awk -v val="$desc_parts" '
        /descripcion: "/ { sub(/descripcion: ".*"/, "descripcion: \"" val "\"") }
        { print }
    ' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"

    # stack.arquitectura
    if [[ -n "$DOMINANT_PATTERN" && "$DOMINANT_PATTERN" != "unknown" ]]; then
        awk -v val="$DOMINANT_PATTERN" '
            /arquitectura:/ { sub(/arquitectura:.*/, "arquitectura: clean+" val) }
            { print }
        ' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
    fi

    # stack.di
    if [[ -n "$DI_FRAMEWORK" ]]; then
        awk -v val="$DI_FRAMEWORK" '
            /di:/ { sub(/di:.*/, "di: " val) }
            { print }
        ' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
    fi

    # stack.async
    if $HAS_COROUTINES && $HAS_RXJAVA; then
        awk '/async:/ { sub(/async:.*/, "async: coroutines+rxjava") } { print }' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
    elif $HAS_RXJAVA; then
        awk '/async:/ { sub(/async:.*/, "async: rxjava") } { print }' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
    elif $HAS_COROUTINES; then
        awk '/async:/ { sub(/async:.*/, "async: coroutines") } { print }' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
    fi

    success "config.yaml actualizado"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    printf "${BOLD}${CYAN}"
    printf '  ╔═══════════════════════════════════════╗\n'
    printf '  ║   El Arqueólogo — FORGE Legacy Scan   ║\n'
    printf '  ╚═══════════════════════════════════════╝\n'
    printf "${NC}\n"

    parse_args "$@"
    preflight

    # Load existing DNA for incremental mode
    load_existing_dna

    # Nivel 1 — always runs
    run_nivel1

    # Resolve which modules to scan
    resolve_modules

    # Nivel 2 — per-module (if applicable)
    run_nivel2

    # Aggregates and confidence
    if [[ -n "$SELECTED_MODULES" ]]; then
        compute_aggregates
    fi
    calculate_confidence

    # Generate output
    generate_yaml
    update_config
    print_summary

    printf "${GREEN}✔${NC} Listo. DNA guardado en ${BOLD}%s${NC}\n" "$DNA_FILE"
    printf "${DIM}  El DNA alimenta SPEC, BUILD y assertions automáticamente.${NC}\n\n"
}

main "$@"
