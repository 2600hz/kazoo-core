#!/bin/bash

pushd "$(dirname "${0}")" > /dev/null || exit 1

_clean="${1}"

GEN_URL="https://raw.githubusercontent.com/apache/httpd/trunk/docs/conf/mime.types"
GEN_FILE="../mime.types"
GEN_ERL_SRC="../src/kz_mime.erl.src"
GEN_ERL="../src/kz_mime.erl"

if [ -n "${_clean}" ] && [ "${_clean}" = "clean" ]; then
    rm -rf "${GEN_ERL}"
    exit 0
fi

if [ ! -f "${GEN_FILE}" ]; then
    wget -qO "${GEN_FILE}" "${GEN_URL}"
fi

ERL_SRC_SEPERATOR="$(grep -n '%% GENERATED' "${GEN_ERL_SRC}" | cut -d: -f1)"

if [ ! -f "${GEN_ERL}" ]; then
   { head -n "${ERL_SRC_SEPERATOR}" "${GEN_ERL_SRC}";
       echo 'from_extension(Ext) when not is_binary(Ext) -> from_extension(kz_term:to_lower_binary(Ext));';
       echo 'from_extension(<<$., Ext/binary>>) -> from_extension(kz_term:to_lower_binary(Ext));';
       grep -v '^#' "${GEN_FILE}" \
           | awk '{for (i=2; i<=NF; i++) if ($i != "" && $i != "wav") { print "from_extension(<<\"" $i "\">>) -> <<\"" $1 "\">>;"}}' \
           | sort -u -t' ' -k1,1;
       echo 'from_extension(<<"pem">>) -> <<"application/x-pem-file">>;';
       echo 'from_extension(<<"wav">>) -> <<"audio/wav">>;' ;
       echo 'from_extension(_) -> <<"application/octet-stream">>.' ;
       echo ;
       echo '-spec to_extensions(binary()) -> [binary()].' ;
       echo 'to_extensions(<<"audio/mp3">>) -> [<<"mp3">>];' ;
       echo 'to_extensions(<<"audio/wav">>) -> [<<"wav">>];' ;
       echo 'to_extensions(<<"audio/x-wave">>) -> [<<"wav">>];' ;
       echo 'to_extensions(<<"application/x-pem-file">>) -> [<<"pem">>];' ;
       grep -v '^#' "${GEN_FILE}" \
           | awk '{ \
           printf("to_extensions(<<\"%s\">>) -> [", $1); \
           if ($1 == "audio/mpeg") { \
               printf("<<\"mp3\">>") \
           } \
           for (i=2; i<=NF; i++) \
               if ($i != "" && $i != "mp3") { \
                   if (i >= 3 || (i >= 2 && $1 == "audio/mpeg") ){printf(",")} \
                       printf("<<\"%s\">>",  $i) \
                   } \
                   print "];" \
               }' \
           | sort ;
       echo 'to_extensions(_) -> [<<>>].' ;
       tail -n +"${ERL_SRC_SEPERATOR}" "${GEN_ERL_SRC}" ;
   } > "${GEN_ERL}"
fi
