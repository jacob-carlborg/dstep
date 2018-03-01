cd "%DUB_PACKAGE_DIR%"

if exist .git (
  git describe --tags > resources\VERSION
) else (
  echo unknown > resources\VERSION
)
