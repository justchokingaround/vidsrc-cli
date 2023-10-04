#!/bin/sh

base_helper_url="https://9anime.eltik.net"

[ -z "$*" ] && printf '\033[1;35m=> ' && read -r user_query || user_query=$*
query=$(printf "%s" "$user_query" | tr " " "+")

# TODO: implement series

imdb_info=$(curl -s "https://www.imdb.com/find/?q=${query}" -A "uwu" | sed "s/div/\n/g" |
    sed -nE "s@.*href=\"/title/([a-z0-9]*)/[^\"]*\">([^<]*)<.*@\1\t\2@p" | fzf --with-nth=2..)
imdb_id=$(printf "%s" "$imdb_info" | cut -f1)
title=$(printf "%s" "$imdb_info" | cut -f2)
[ -z "$imdb_id" ] && exit 1

data_id=$(curl -s "https://vidsrc.to/embed/movie/${imdb_id}" | sed -nE "s@.*data-id=\"([^\"]*)\".*@\1@p")
[ -z "$data_id" ] && exit 1
vidplay_id=$(curl -s "https://vidsrc.to/ajax/embed/episode/${data_id}/sources" | tr '{}' '\n' | sed -nE "s@.*\"id\":\"([^\"]*)\".*\"Vidplay.*@\1@p")
[ -z "$vidplay_id" ] && exit 1

encrypted_provider_url=$(curl -s "https://vidsrc.to/ajax/embed/source/${vidplay_id}" | sed -nE "s@.*\"url\":\"([^\"]*)\".*@\1@p")
[ -z "$encrypted_provider_url" ] && exit 1

provider_embed=$(curl -s "$base_helper_url/fmovies-decrypt?query=${encrypted_provider_url}&apikey=jerry" | sed -nE "s@.*\"url\":\"([^\"]*)\".*@\1@p")
[ -z "$provider_embed" ] && exit 1
tmp=$(printf "%s" "$provider_embed" | sed -nE "s@.*/e/([^\?]*)(\?.*)@\1\t\2@p")
provider_query=$(printf "%s" "$tmp" | cut -f1)
params=$(printf "%s" "$tmp" | cut -f2)

futoken=$(curl -s "vidstream.pro/futoken")
raw_url=$(curl -s "$base_helper_url/rawvizcloud?query=${provider_query}&apikey=jerry" -d "query=${provider_query}&futoken=${futoken}" | sed -nE "s@.*\"rawURL\":\"([^\"]*)\".*@\1@p")
video_link=$(curl -s "$raw_url${params}" -e "$provider_embed" | sed "s/\\\//g" | sed -nE "s@.*file\":\"([^\"]*)\".*@\1@p")
[ -z "$video_link" ] && exit 1
mpv --force-media-title="$title" "$video_link"
