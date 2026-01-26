#!/usr/bin/env bash

if command -v kwctl &> /dev/null; then
  source <(kwctl completions -s bash)
fi
