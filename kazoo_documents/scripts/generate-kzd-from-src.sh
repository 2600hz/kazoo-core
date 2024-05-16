#!/bin/bash

pushd "$(dirname "${0}")" > /dev/null || exit 1

_clean="${1}"

if [ -n "${_clean}" ] && [ "${_clean}" = "clean" ]; then
  for erl_src in ../src/*.erl.src; do
    cmp -s "${erl_src%.src}" "${erl_src}"
    if [ $? -eq 1 ]; then
      rm "${erl_src%.src}"
    fi
  done
  exit 0
fi

for erl_src in ../src/*.erl.src; do
    cp -n "${erl_src}" "${erl_src%.src}" 2>/dev/null || true
done
