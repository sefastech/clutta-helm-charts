#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
chart_dir="$repo_root/clutta-scan"
index_file="$repo_root/index.yaml"
packages_dir="$repo_root/charts"
project_id="11111111-1111-4111-8111-111111111111"
repo_url="https://sefastech.github.io/clutta-helm-charts"

fail() {
  echo "validation failed: $*" >&2
  exit 1
}

require_text() {
  local file="$1"
  local value="$2"
  grep -Fq -- "$value" "$file" || fail "$file does not contain: $value"
}

command -v helm >/dev/null 2>&1 || fail "helm is required"
command -v tar >/dev/null 2>&1 || fail "tar is required"

tmp_dir="$(mktemp -d)"
source_render="$tmp_dir/source.yaml"
package_render="$tmp_dir/package.yaml"
trap 'rm -rf -- "$tmp_dir"' EXIT

helm lint "$chart_dir" --strict
helm template clutta-scan "$chart_dir" \
  --namespace clutta \
  --set-string scope.projectId="$project_id" > "$source_render"

current_chart_version="$(awk '/^version:/ {print $2; exit}' "$chart_dir/Chart.yaml")"
current_package="$packages_dir/clutta-scan-${current_chart_version}.tgz"
[[ -f "$current_package" ]] || fail "the current chart package is missing: ${current_package##*/}"

helm template clutta-scan "$current_package" \
  --namespace clutta \
  --set-string scope.projectId="$project_id" > "$package_render"
cmp -s "$source_render" "$package_render" || fail "the current package does not match chart source"

private_ip_pattern='(^|[^0-9])(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}|127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|169\.254\.169\.254)([^0-9]|$)'
if grep -ERnI -- "$private_ip_pattern" "$chart_dir"; then
  fail "the current chart contains a private, loopback, or metadata IPv4 address"
fi

mapfile -t index_urls < <(awk '/^[[:space:]]*- https:\/\/.*\.tgz$/ {print $2}' "$index_file")
((${#index_urls[@]} > 0)) || fail "index.yaml contains no chart URLs"

for url in "${index_urls[@]}"; do
  [[ "$url" == "$repo_url/charts/"*.tgz ]] || fail "unexpected chart URL: $url"
  package="$packages_dir/${url##*/}"
  [[ -f "$package" ]] || fail "index.yaml references missing package: ${url##*/}"
done

for package in "$packages_dir"/*.tgz; do
  package_name="${package##*/}"
  digest="$(sha256sum "$package" | awk '{print $1}')"
  require_text "$index_file" "digest: $digest"
  require_text "$index_file" "$repo_url/charts/$package_name"

  if tar -xOzf "$package" | grep -EnI -- "$private_ip_pattern"; then
    fail "$package_name contains a private, loopback, or metadata IPv4 address"
  fi
done

echo "Clutta Scan chart validation passed with $(helm version --short)."
