#!/usr/bin/env bash
set -euo pipefail
trap 'status=$?; echo "Build command failed at line ${LINENO} (exit ${status}): ${BASH_COMMAND}"; exit "${status}"' ERR

flutter_version="3.47.2"
flutter_root="${HOME}/.cache/cambodia-shop/flutter-${flutter_version}"
archive="${HOME}/.cache/cambodia-shop/flutter_linux_${flutter_version}-stable.tar.xz"
archive_url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${flutter_version}-stable.tar.xz"
archive_sha256="447878859d01ca9bfdb99a85f245af07ed8a15fedcd9d189c4749e8e92d1f185"

if [[ ! -x "${flutter_root}/bin/flutter" ]]; then
  mkdir -p "$(dirname "${flutter_root}")" "${flutter_root}"
  curl --fail --location --retry 3 --connect-timeout 30 "${archive_url}" --output "${archive}"
  echo "${archive_sha256}  ${archive}" | sha256sum --check --status
  tar -xJf "${archive}" --directory "${flutter_root}" --strip-components=1
  rm -f "${archive}"
fi

export PATH="${flutter_root}/bin:${PATH}"
flutter config --no-analytics
flutter pub get --verbose
flutter build web --release --verbose --dart-define=API_BASE_URL=https://ecommerce-backend-man4.onrender.com/api/v1
