#!/bin/bash

base_helper_url="https://9anime.eltik.net"

[ -z "$*" ] && printf '\033[1;35m=> ' && read -r user_query || user_query=$*
query=$(printf "%s" "$user_query" | tr " " "+")

imdb_html_content=$(curl -s "https://www.imdb.com/find/?q=$query" -A "uwu")

#imdb ids
ids=$(echo "$imdb_html_content" | pup "li.find-title-result a attr{href}" | sed -n 's/\/title\/\([a-zA-Z0-9]*\)\/.*/\1/p')

#To preview images, Also, it seems while fetching imdb image url, imdb intenionally adds a low res image but removing everything after ._ in the url gives us a high res image
image_urls=$(echo "$imdb_html_content" | pup "li.find-title-result" | sed "s/xmlns/src/g" | sed "s/svg/img/g" | pup "img attr{src}" | awk -F '._' '{print $1}')

#movie or series title and also i replaced " " with "_" for the program
titles=$(echo "$imdb_html_content" | pup "li.find-title-result a text{}" | sed "s/ /_/g")

# results store like this: id1 image_url1 title1\n id2 image_url2 title2\n
results=$(paste -d " " <(echo "$ids") <(echo "$image_urls") <(echo "$titles"))

# i added image preview which we get from results and intensity 10 with chafa really gave me good results
name=$(echo "$results" | fzf --with-nth=3.. --prompt "What do you want to watch? " --preview "echo {} | cut -d' ' -f2 | xargs -I {} curl -s {} | chafa -c full --dither-intensity 10")
imdb_id=$(echo "$name" | cut -d' ' -f1)

# the whole block below checks if it is a movie or a series and if it is a series, it fetches season and episodes
# going to https://www.imdb.com/title/imdb_id/episodes gives episode list if it's a series and tells "we don't have episode list" if it is a movie
check_if=$(curl -Ls "https://www.imdb.com/title/$imdb_id/episodes" -A "uwu")
if echo "$check_if" | pup "p[data-testid] text{}" |grep -q "episode"; then
    data_id=$(curl -s "https://vidsrc.to/embed/movie/${imdb_id}" | sed -nE "s@.*data-id=\"([^\"]*)\".*@\1@p")
    [ -z "$data_id" ] && exit 1
else
    season_number=$(echo "$check_if" | pup 'ul.ipc-tabs.ipc-tabs--base.ipc-tabs--align-left li.ipc-tab.ipc-tab--on-base.ipc-tab--active[data-testid="tab-season-entry"] text{}' | fzf --prompt "Select the season: ")
    episode_number=$(curl -Ls "https://www.imdb.com/title/$imdb_id/episodes?season=$season_number" -A "uwu" | pup "h4.sc-1318654d-7.fACRye text{}" | fzf --prompt "Select the episode: " | sed -n 's/.*E\([0-9]\+\).*/\1/p')
    data_id=$(curl -s "https://vidsrc.to/embed/tv/${imdb_id}/$season_number/$episode_number" | sed -nE "s@.*data-id=\"([^\"]*)\".*@\1@p")
    [ -z "$data_id" ] && exit 1
fi


vidplay_id=$(curl -s "https://vidsrc.to/ajax/embed/episode/${data_id}/sources" | tr '{}' '\n' | sed -nE "s@.*\"id\":\"([^\"]*)\".*\"Vidplay.*@\1@p")
[ -z "$vidplay_id" ] && exit 1

encrypted_provider_url=$(curl -s "https://vidsrc.to/ajax/embed/source/${vidplay_id}" | sed -nE "s@.*\"url\":\"([^\"]*)\".*@\1@p")
[ -z "$encrypted_provider_url" ] && exit 1
printf "Getting id...\n"
provider_embed=$(curl -s "$base_helper_url/fmovies-decrypt?query=${encrypted_provider_url}&apikey=jerry" | sed -nE "s@.*\"url\":\"([^\"]*)\".*@\1@p")
[ -z "$provider_embed" ] && exit 1
tmp=$(printf "%s" "$provider_embed" | sed -nE "s@.*/e/([^\?]*)(\?.*)@\1\t\2@p")
provider_query=$(printf "%s" "$tmp" | cut -f1)
params=$(printf "%s" "$tmp" | cut -f2)
printf "A few seconds...\n"
futoken=$(curl -s "vidstream.pro/futoken")
raw_url=$(curl -s "$base_helper_url/rawvizcloud?query=${provider_query}&apikey=jerry" -d "query=${provider_query}&futoken=${futoken}" | sed -nE "s@.*\"rawURL\":\"([^\"]*)\".*@\1@p")
video_link=$(curl -s "$raw_url${params}" -e "$provider_embed" | sed "s/\\\//g" | sed -nE "s@.*file\":\"([^\"]*)\".*@\1@p")
[ -z "$video_link" ] && exit 1
cd_link=$(curl -s "$raw_url${params}" -e "$provider_embed" | sed "s/\\\//g")

# Get the url of the first file which contains raw url of the content
first_file_url="${cd_link#*\"file\":\"}"
first_file_url="${first_file_url%%\"*}"

mpv --force-media-title="$title" "$first_file_url"
