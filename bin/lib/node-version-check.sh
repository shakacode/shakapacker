readonly MIN_NODE_20="20.19.0"
readonly MIN_NODE_22="22.12.0"

# Compare two MAJOR.MINOR.PATCH version strings. Returns 0 if $1 >= $2, else 1.
# Uses awk (POSIX) for portability; macOS BSD `sort` lacks `-V` without GNU coreutils.
version_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    split(a, av, ".")
    split(b, bv, ".")
    for (i = 1; i <= 3; i++) {
      ai = (av[i] == "" ? 0 : av[i] + 0)
      bi = (bv[i] == "" ? 0 : bv[i] + 0)
      if (ai > bi) exit 0
      if (ai < bi) exit 1
    }
    exit 0
  }'
}

node_version_supported() {
  local version="$1"
  version="${version#v}"
  local major
  major=$(echo "$version" | cut -d'.' -f1)
  if [[ "$major" == "20" ]] && version_ge "$version" "$MIN_NODE_20"; then
    return 0
  fi
  if [[ "$major" =~ ^[0-9]+$ ]] && [[ "$major" -ge 22 ]] && version_ge "$version" "$MIN_NODE_22"; then
    return 0
  fi
  return 1
}
