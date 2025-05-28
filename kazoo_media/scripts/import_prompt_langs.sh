#!/bin/bash

KAZOO_GIT_URL="https://raw.githubusercontent.com/2600hz/kazoo-sounds/refs/heads/master/kazoo-core"

PROMPT_DIR="priv/prompts/kazoo"

mkdir -p ${PROMPT_DIR}
wget -qO ${PROMPT_DIR}/de-de.txt ${KAZOO_GIT_URL}/de/de/prompts.txt
wget -qO ${PROMPT_DIR}/en-us.txt ${KAZOO_GIT_URL}/en/us/prompts.txt
wget -qO ${PROMPT_DIR}/en-gb.txt ${KAZOO_GIT_URL}/en/gb/prompts.txt
wget -qO ${PROMPT_DIR}/es-es.txt ${KAZOO_GIT_URL}/es/es/prompts.txt
wget -qO ${PROMPT_DIR}/es-us.txt ${KAZOO_GIT_URL}/es/us/prompts.txt
wget -qO ${PROMPT_DIR}/fr-ca.txt ${KAZOO_GIT_URL}/fr/ca/prompts.txt
wget -qO ${PROMPT_DIR}/fr-fr.txt ${KAZOO_GIT_URL}/fr/fr/prompts.txt
wget -qO ${PROMPT_DIR}/nl-be.txt ${KAZOO_GIT_URL}/nl/be/prompts.txt
wget -qO ${PROMPT_DIR}/ru-ru.txt ${KAZOO_GIT_URL}/ru/ru/prompts.txt

