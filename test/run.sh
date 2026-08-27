#!/bin/bash
# Run the open-markdown-links.vim test suites headlessly.
# Usage: test/run.sh
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
vim=${VIM:-vim}
status=0

echo "== extract() unit tests =="
"$vim" -u NONE -N -e -s -S "$here/test_extract.vim" || status=1

echo
echo "== open()/plugin integration tests =="
"$vim" -u NONE -N -e -s -S "$here/test_open.vim" || status=1

echo
if [ "$status" -eq 0 ]; then
  echo "ALL SUITES PASSED"
else
  echo "SOME SUITES FAILED"
fi
exit "$status"
