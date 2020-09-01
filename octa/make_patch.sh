#!/bin/sh

if [ -d octa-8.3.orig -a -d octa-8.3 ]; then
  diff -crN octa-8.3.orig octa-8.3 > octa-8.3.patch
else
  echo "Error: source directory not found"
  exit 127
fi
