#!/bin/sh

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

encrypted_source=$(curl -s "https://vidsrc.to/ajax/embed/source/${vidplay_id}" | sed -nE "s@.*\"url\":\"([^\"]*)\".*@\1@p")
[ -z "$encrypted_source" ] && exit 1

futoken=$(curl -s "https://vidplay.online/futoken" | sed -nE "s@.*k='([^']*)'.*@\1@p")

vidsrc() {
  encrypted_source=$(printf "%s" "$1" | sed -e 's/_/\//g' -e 's/-/+/g')
  node -e "
  const source = '$encrypted_source';
  const key = '$vidsrc_key';
 	const parse=r=>{if((r=(r=(r=\"\".concat(r)).replace(/[\t\n\f\r]/g,\"\")).length%4==0?r.replace(/==?$/,\"\"):r).length%4==1||/[^+/0-9A-Za-z]/.test(r))return null;for(var e,n=\"\",o=0,t=0,a=0;a<r.length;a++)o=(o<<=6)|(e=r[a],(e=\"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/\".indexOf(e))<0?void 0:e),24===(t+=6)&&(n=(n=(n+=String.fromCharCode((16711680&o)>>16))+String.fromCharCode((65280&o)>>8))+String.fromCharCode(255&o),o=t=0);return 12===t?(o>>=4,n+=String.fromCharCode(o)):18===t&&(o>>=2,n=(n+=String.fromCharCode((65280&o)>>8))+String.fromCharCode(255&o)),n}
 	const decrypt=_=>{for(var t,e=[],n=0,a=\"\",f=0;f<256;f++)e[f]=f;for(f=0;f<256;f++)n=(n+e[f]+key.charCodeAt(f%key.length))%256,t=e[f],e[f]=e[n],e[n]=t;for(var f=0,n=0,h=0;h<parse(source).length;h++)t=e[f=(f+1)%256],e[f]=e[n=(n+e[f])%256],e[n]=t,a+=String.fromCharCode(parse(source).charCodeAt(h)^e[(e[f]+e[n])%256]);return a}
  console.log(decodeURIComponent(decrypt(parse(source))));
  "
}
vidplay() {
  node -e "
  const source = '$source_id';
  const key_1 = '$vidplay_key_1';
  const key_2 = '$vidplay_key_2';
  const futoken = '$futoken';
  const parse=r=>{for(r=''.concat(r),t=0;t<r.length;t++)if(255<r.charCodeAt(t))return null;for(var o='',t=0;t<r.length;t+=3){var e=[void 0,void 0,void 0,void 0];e[0]=r.charCodeAt(t)>>2,e[1]=(3&r.charCodeAt(t))<<4,r.length>t+1&&(e[1]|=r.charCodeAt(t+1)>>4,e[2]=(15&r.charCodeAt(t+1))<<2),r.length>t+2&&(e[2]|=r.charCodeAt(t+2)>>6,e[3]=63&r.charCodeAt(t+2));for(var n=0;n<e.length;n++)o+=void 0===e[n]?'=':function(r){if(0<=r&&r<64)return'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'[r]}(e[n])}return o}
  const enc=(r,o)=>{for(var e,t=[],f=0,n='',a=0;a<256;a++)t[a]=a;for(a=0;a<256;a++)f=(f+t[a]+r.charCodeAt(a%r.length))%256,e=t[a],t[a]=t[f],t[f]=e;for(var a=0,f=0,h=0;h<o.length;h++)e=t[a=(a+1)%256],t[a]=t[f=(f+t[a])%256],t[f]=e,n+=String.fromCharCode(o.charCodeAt(h)^t[(t[a]+t[f])%256]);return n}
  let hash = parse(enc(key_2, enc(key_1, source))).replace(/\//g, '_'), a = [futoken];
  for (var i = 0; i < hash.length; i++)
    a.push(futoken.charCodeAt(i % futoken.length) + hash.charCodeAt(i));
  console.log('mediainfo/' + a.join(','));

  "
}


resp=$(curl -s "https://keys4.fun")
vidsrc_key="$(printf "%s" "$resp"| tr -d '\n ' | sed -nE "s@.*vidsrc_to\":\{\"keys\":\[\"[^\"]*\",\"([^\"]*)\".*@\1@p")"
futoken="$(curl -s "https://vidplay.online/futoken" | sed -nE "s@.*k='([^']*)'.*@\1@p")"
vidplay_key_1="$(printf "%s" "$resp" | tr -d '\n ' | sed -nE "s@.*vidplay\":\{\"keys\":\[\"([^\"]*)\",\"[^\"]*\".*@\1@p")"
vidplay_key_2="$(printf "%s" "$resp" | tr -d '\n ' | sed -nE "s@.*vidplay\":\{\"keys\":\[\"[^\"]*\",\"([^\"]*)\".*@\1@p")"

vidsrc=$(vidsrc "$encrypted_source")
source_id=$(printf "%s" "$vidsrc" | sed -nE "s@.*/e/([^?]*)?.*@\1@p")
vidplay=$(vidplay)

request=$(printf "%s\n" "$vidsrc" | sed "s@/e/${source_id}@/${vidplay}@")
video_link=$(curl -s "$request" | sed -nE "s@.*\"file\":\"([^\"]*)\".*@\1@p" | tr -d '\\')

[ -z "$video_link" ] && exit 1
mpv --force-media-title="$title" "$video_link"
