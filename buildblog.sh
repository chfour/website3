#!/usr/bin/env sh

template_start='<!--BEGIN TEMPLATE-->'
template_end='<!--END TEMPLATE-->'

[ -n "$1" ] && cd "$1"

sed "/${template_start}/q" ./index_template.html > ./index.html

# this... thing turns the template in the html into a json string with jq string interpolation, to be passed back into jq
# thankfully this only has to be done once. cursedd
template="$(sed "/\s*${template_start}/,/\s*${template_end}/!d;//d" ./index_template.html | \
            jq -Rs '"\"" + (gsub("(?<s>^|}})(?<p>.+?)(?<e>{{|$)"; "\(.s + (.p|@json|trimstr("\"")) + .e)"; "m") | rtrim | gsub("{{(?<p>.+?)}}"; "\\(\(.p))"; "m")) + "\""' -r)"

find . -name content.djot -print0 | sort -r -z | while read -r -d '' post; do
    post="${post%/*}"
    echo -n "${post} "
    jq -r '.title' "${post}/meta.json"
    jq -r --arg path "${post#./*/*/}" "${template}" "${post}/meta.json" >> ./index.html
    pandoc -f djot -t html5 \
        --mathml \
        --highlight-style=kate \
        --standalone \
        --metadata-file="${post}/meta.json" \
        "${post}/content.djot" -o "${post}/index.html"
done

sed -n "/${template_end}/,\$p" ./index_template.html >> ./index.html
