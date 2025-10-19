#!/usr/bin/env sh

defaults_file='default.json'

template_start='<!--BEGIN TEMPLATE-->'
template_end='<!--END TEMPLATE-->'

rel_root=''
[ -n "${1:+x}" ] && cd "${1}" && rel_root="${1%/}/"
! [ -e "$defaults_file" ] && echo "${0}: error: ${rel_root}${defaults_file} does not exist" && exit 1
defaults="$(jq -c '.' "$defaults_file")"

index_template="$(jq -r '.["$index-template"]' <<<"$defaults")"
! [ -e "$index_template" ] && echo "${0}: error: ${rel_root}${index_template} does not exist" >&2 && exit 1

# generate the code syntax highlighting css
# unfortunately pandoc did not like --template=<(echo ...)
# shellcheck disable=SC2016
echo '$highlighting-css$' > ./highlighting.css
# time to prank pandoc epic style
echo $'``` c\n```' | pandoc -f djot -t html5 \
    --template=./highlighting.css -o ./highlighting.css \
    --highlight-style=tango # to be replaced, probably

# ...because of this. and because it looks eh
cat >> ./highlighting.css <<EOF
.sourceCode { color: black; }
EOF

sed "/${template_start}/q" "${index_template}" > ./index.html

# this... thing turns the template in the html into a json string with jq string interpolation, to be passed back into jq
# thankfully this only has to be done once. cursedd
template="$(sed "/\s*${template_start}/,/\s*${template_end}/!d;//d" "${index_template}" | \
            jq -Rrs '"\"" + (gsub("(?<s>^|}})(?<p>.+?)(?<e>{{|$)"; "\(.s + (.p|@json|trimstr("\"")) + .e)"; "m") | rtrim | gsub("{{(?<p>.+?)}}"; "\\(\(.p))"; "m")) + "\""')"

find . -name meta.json -print0 | sort -r -z | while read -r -d '' post; do
    post="${post%/*}"
    echo -n "${post} "
    slashesinpath="${post//[^\/]}" # delete everything that isnt a slash
    slashesinpath="${#slashesinpath}" # count whats left (count slashes in $post)
    backtoblogroot="$(for ((i=0; i < slashesinpath; i++)); do echo -n '../'; done)"
    backtoblogroot="${backtoblogroot%/}"

    # this thing is responsible for concatenating arrays together if for example both default and meta specify $pandoc-args
    # it also replaces every instance of {{root}} in $pandoc-args with backtoblogroot
    meta="$(jq -c '$meta[0] as $meta | . as $default | $meta | [paths(type == "array")] | reduce .[] as $p ($meta; setpath($p; ($default | getpath($p) // []) + getpath($p))) | $default * . | .["$pandoc-args"] = (.["$pandoc-args"] | map(gsub("{{root}}"; $root)))' \
        --slurpfile meta "${post}/meta.json" --arg root "$backtoblogroot" <<<"$defaults")"

    jq '.title' <<<"$meta"

    # with help from domi https://donotsta.re/objects/b84298d7-582f-4b42-9bbd-bc5636a2b9fb
    pandoc_args=()
    while read -r -d '' arg; do pandoc_args+=("$arg"); done < \
        <(jq --raw-output0 '.["$pandoc-args"][], .["$input"], "-o", .["$output"]' <<<"$meta")

    pushd "$post" >/dev/null
    pandoc_error=0
    pandoc \
        --variable="root=${backtoblogroot}" \
        --variable="path=${post#./}" \
        --metadata-file=<(printf %s "$meta") \
        "${pandoc_args[@]}" || pandoc_error=$?
    popd >/dev/null
    [ "$pandoc_error" != 0 ] && echo "warning: pandoc exited with code $pandoc_error, skipping" >&2 && continue

    jq -r --arg path "${post}" "${template}" <<<"$meta" >> ./index.html
done

sed -n "/${template_end}/,\$p" "${index_template}" >> ./index.html
