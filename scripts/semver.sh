#!/usr/bin/env bash
# semver.sh  - Calcula la próxima versión semántica leyendo los commits
# desde el último tag vX.Y.Z hasta HEAD usando Conventional Commits.
#
# Reglas de bump:
#   BREAKING CHANGE | feat! | fix!  →  MAJOR
#   feat:                           →  MINOR
#   fix: | cualquier otro           →  PATCH
#
# Uso: VERSION=$(bash scripts/semver.sh)
#      git tag "$VERSION"
set -euo pipefail

# 1. Encontrar el último tag con formato vX.Y.Z
LAST_TAG=$(git describe --tags --match "v[0-9]*.[0-9]*.[0-9]*" --abbrev=0 2>/dev/null || echo "")

if [ -z "$LAST_TAG" ]; then
    # Sin tags previos: partir de v0.0.0
    BASE="v0.0.0"
    RANGE="HEAD"
    echo "semver: sin tag previo, base v0.0.0" >&2
else
    BASE="$LAST_TAG"
    RANGE="${LAST_TAG}..HEAD"
    echo "semver: tag anterior = ${LAST_TAG}, analizando ${RANGE}" >&2
fi

# 2. Parsear la versión base
VERSION_STRIP="${BASE#v}"
MAJOR=$(echo "$VERSION_STRIP" | cut -d. -f1)
MINOR=$(echo "$VERSION_STRIP" | cut -d. -f2)
PATCH=$(echo "$VERSION_STRIP" | cut -d. -f3)

# 3. Detectar el nivel de bump más alto en el rango de commits
BUMP="patch"  # default

# MAJOR: BREAKING CHANGE en cuerpo/pie, o tipo con '!'
if git log ${RANGE} --pretty=format:"%s%n%b" --no-merges 2>/dev/null \
    | grep -qE "(BREAKING CHANGE|^feat!|^fix!|^refactor!|^[a-z]+!(\([^)]+\))?:)"; then
    BUMP="major"
# MINOR: nuevas funcionalidades
elif git log ${RANGE} --pretty=format:"%s" --no-merges 2>/dev/null \
    | grep -qE "^feat(\([^)]+\))?:"; then
    BUMP="minor"
fi

# Si RANGE es "HEAD" (sin tag previo), siempre empieza en 0.1.0
if [ "$RANGE" = "HEAD" ]; then
    BUMP="minor"
fi

echo "semver: bump = ${BUMP}" >&2

# 4. Calcular nueva versión
case "$BUMP" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
esac

NEW_VERSION="v${MAJOR}.${MINOR}.${PATCH}"
echo "semver: nueva versión = ${NEW_VERSION}" >&2

# 5. Imprimir solo la versión por stdout (para captura con $(...))
echo "$NEW_VERSION"
