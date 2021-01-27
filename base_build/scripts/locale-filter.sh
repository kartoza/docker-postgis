#!/usr/bin/env bash

## Filter list of locales from a given filter args
## Parse into array
LANG_ARR=(${LANGS//,/ })
echo "" > /etc/locale.gen
for i in "${LANG_ARR[@]}"; do
  cat /etc/all.locale.gen | grep "$i" >> /etc/locale.gen
done
