/// Computes a deterministic FNV-1a 31-bit hash across Dart VM isolates
/// so main and background notification isolates derive identical IDs.
int stableHash31(String input) {
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
