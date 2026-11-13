# Sourced by Alpine's wg-quick at its documented override insertion point.
# Preserve upstream auto detection; only explicit modes override interface creation.
eval "$(declare -f add_if | sed '1s/add_if/add_if_auto/')"
add_if() {
  case "${WG_IMPLEMENTATION:-auto}" in
    auto) add_if_auto ;;
    kernel) cmd ip link add dev "$INTERFACE" type wireguard ;;
    userspace) cmd wireguard-go "$INTERFACE" ;;
    *) echo 'WG_IMPLEMENTATION must be auto, kernel or userspace.' >&2; return 1 ;;
  esac
}
