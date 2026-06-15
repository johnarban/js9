#!/bin/bash
#
# Rebuild JS9 with the SVG-XSS-patched Fabric.js (CVE-2026-27013).
# Run from the js9 repo root. The patched source js/fabric-v5.2.1-svgfix.js
# must already exist (it is the v5.2.1 copy with escapeXml applied to the SVG
# export sinks).
#
set -e

# 1. minify the patched fabric -> js/fabric-v5.2.1-svgfix.min.js
build/minify js/fabric-v5.2.1-svgfix.js

# 2. point the fabric symlinks at the patched build
ln -sf fabric-v5.2.1-svgfix.js     js/fabric.js
ln -sf fabric-v5.2.1-svgfix.min.js js/fabric.min.js

# 3. create the Makefile if it does not exist yet
[ -f Makefile ] || ./configure --with-helper=nodejs

# 4. regenerate the support bundles (js9support.js, js9support.min.js, js9-allinone)
make js9support
