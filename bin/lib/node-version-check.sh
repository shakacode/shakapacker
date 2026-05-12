MIN_NODE_20="20.19.0"
MIN_NODE_22="22.12.0"

node_version_supported() {
  local version="$1"
  local major
  major=$(echo "$version" | cut -d'.' -f1)
  if [[ "$major" == "20" ]] && [[ $(printf '%s\n' "$MIN_NODE_20" "$version" | sort -V | head -n1) == "$MIN_NODE_20" ]]; then
    return 0
  fi
  if [[ "$major" =~ ^[0-9]+$ ]] && [[ "$major" -ge 22 ]] && [[ $(printf '%s\n' "$MIN_NODE_22" "$version" | sort -V | head -n1) == "$MIN_NODE_22" ]]; then
    return 0
  fi
  return 1
}
