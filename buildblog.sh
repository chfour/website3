#!/usr/bin/env sh

index_template='template_index.html'
page_template='template_page.html'
template_start='<!--BEGIN TEMPLATE-->'
template_end='<!--END TEMPLATE-->'

[ -n "${1}" ] && cd "${1}"
! [ -e "$index_template" ] && echo "${0}: error: ${1%/}/${index_template} does not exist" >&2 && exit 1
! [ -e "$page_template" ] && echo "${0}: error: ${1%/}/${page_template} does not exist" >&2 && exit 1

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
            jq -Rs '"\"" + (gsub("(?<s>^|}})(?<p>.+?)(?<e>{{|$)"; "\(.s + (.p|@json|trimstr("\"")) + .e)"; "m") | rtrim | gsub("{{(?<p>.+?)}}"; "\\(\(.p))"; "m")) + "\""' -r)"

find . -name content.djot -print0 | sort -r -z | while read -r -d '' post; do
    post="${post%/*}"
    echo -n "${post} "
    slashesinpath="${post//[^\/]}" # delete everything that isnt a slash
    slashesinpath="${#slashesinpath}" # count whats left (count slashes in $post)
    backtoblogroot="$(for ((i=0; i < slashesinpath; i++)); do echo -n '../'; done)"
    backtoblogroot="${backtoblogroot%/}"
    jq '.title' "${post}/meta.json"
    jq -r --arg path "${post#./*/*/}" "${template}" "${post}/meta.json" >> ./index.html
    pandoc -f djot -t html5 \
        --mathml \
        --template="${page_template}" \
        --variable="backtoblogroot=${backtoblogroot}" \
        --metadata-file="${post}/meta.json" \
        "${post}/content.djot" -o "${post}/index.html"
done

sed -n "/${template_end}/,\$p" "${index_template}" >> ./index.html
