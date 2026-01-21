#!/usr/bin/env bash

if command -v jj &> /dev/null; then
  source <(jj util completion bash)
fi