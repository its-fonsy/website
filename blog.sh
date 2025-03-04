#!/bin/env sh

set -e

PUBLIC=public
HTML_TEMPLATE=template.html
LOWDOWN_FLAGS="--html-no-skiphtml --html-no-escapehtml -s --template $HTML_TEMPLATE"

rm -rf $PUBLIC
mkdir -p $PUBLIC
cp -r static/* $PUBLIC/

post_list=""
for file in $(ls -r -1 posts)
do
    html_filename=$(basename $file | cut -c 12- | cut -d "." -f 1).html
    date=$(basename $file | cut -c -10)
    title=$(grep '^# ' posts/$file | cut -c 3-)
    
    lowdown $LOWDOWN_FLAGS posts/$file -o $PUBLIC/$html_filename
    post_list=$"${post_list}<div style=\"margin: 0.4rem 0;\"><a href=\"$html_filename\"><small><tt>$date</tt></small> \&ndash; $title</a></div>\n"
done

lowdown $LOWDOWN_FLAGS index.md -o $PUBLIC/index.html
sed -i "s|{{ POST_LIST }}|$post_list|" $PUBLIC/index.html

exit 0
