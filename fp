#!/usr/bin/env bash

shopt -s nocasematch
shopt -s nocaseglob
shopt -s extglob

function get_key {
  local chrDec chrOct chr
  local -i ret
  read_mod='' read_key=''
  read -rsn1 -d $'\0' -t 0.1
  (( ret=$?, ret == 142 )) && return 0
  (( ret )) && return $(( ret ))
  case "$REPLY" in
    [[:print:]]) read_key="$REPLY" ;;
    $'\x08') read_key=bs ;; # backspace
    $'\x7f') read_key=bs ;; # c-h
    $'\x1b')
      read -rsn1 -t 0.01
      case "$REPLY" in
        '') read_key=esc ;;
        [) read -rsn1 -t 0.01
        case "$REPLY" in  # translate arrowkeys ( multibyte keys starting with escpae )
            A) read_mod=m read_key=k ;;
            B) read_mod=m read_key=j ;;
            C) read_mod=m read_key=l ;;
            D) read_mod=m read_key=h ;;
          esac
          ;;
        [[:print:]]) read_mod=a read_key="$REPLY"  ;;
      esac
      ;;
  esac
  if [[ -z $read_key ]]; then  # resolve ctrl-mask
    printf -v chrDec %d \'"$REPLY"
    ((chrDec >= 27)) && return
    read_mod=c
    ((chrDec += 64 + 32)) # 64 = ctrl mask, 32 = shift mask
    printf -v chrOct '\\%03o' "$chrDec"
    printf -v chr '%b' "$chrOct"
    read_key="$chr"
    unset chr chrDec chrOct
  fi
}

function decide_and_sort {
  local -a key_words=()
  local -i i tmp tick
  local basic_pattern
  local -a clutter=( \\ \| / - )
  trap 'redraw_statusline; return 0' int
  trap 'set +f' return

  # set -f
  # key_words=( ${cmdline//\*/\\*} )  # BAH
  # set +f
  read -ra key_words <<< "${cmdline//\*/\\*}"

  [[ "${lcmdline_arr[*]}" == "${key_words[*]}" ]] && return ||
    lcmdline_arr=( "${key_words[@]}" )
  if (( ! ${#key_words[@]} )); then
    sorted=( "${!haystack[@]}" )
    lcmdline_arr=( "${key_words[@]}" )
    return
  fi

  # keys=( ${!haystack[@]} )
  # keys=( ${!sorted[@]} )


  # -a haystack: list of strings
  # -A matches:  assoc where keys are indexes to haystack && values are how well a string matched.
  # -a sorted:   list of indexes in haystack,  undergoes sorting as to not move strings around.

  eval local -a bucket_{4..500}=\(\)

  # there exists a problem with globbing here.
  set -f ; printf -v basic_pattern '%s|' "${key_words[@]}" ; set +f
  basic_pattern="+(${basic_pattern%|})"

  for ((Fnr=0,margin=${#sorted[@]}/10; Fnr<${#sorted[@]}; Fnr++,weight=0)); do
    # (( Fnr % margin == 0 )) && {
    #   progress_str="${clutter[$((tick++%4))]}"
    #   redraw_statusline
    # }
    [[ x${haystack[${sorted[$Fnr]}]}x == x*${basic_pattern}*x ]] || continue
    for k in "${key_words[@]}"; do
      [[ ${haystack[${sorted[$Fnr]}]} == *${k}*             ]] && (( weight+=4 )) || continue
      [[ ${haystack[${sorted[$Fnr]}]} == *[^[:alnum:]]${k}* ]] && (( weight+=1 ))
    done ; eval "bucket_$weight+=( ${sorted[$Fnr]} )"
  done
  sorted=()
  local -n keys
  for keys in bucket_{500..4}; do
    (( ${#keys[@]} )) || continue
    sorted+=( "${keys[@]}" )
    progress_str="${#sorted[@]}/${#haystack[@]}"
    redraw_statusline
  done
}

function line_add_hilight {
  lhl="$1"
  for (( i=0; i<${#lcmdline_arr[@]}; i++ )); do
    lhl="${lhl//${lcmdline_arr[$i]}/$'\e[4m'${lcmdline_arr[$i]}$'\e[24m'}"
  done
}

# Redraws the current and previous lines.
function redraw_quick {
  local ll lhl line
  (( lOffset == offset )) || { redraw; return; }
  (( cursorLine+offset == lCursorLine+offset )) && { return; }
  line="${haystack[${sorted[$cursorLine]}]:0:$lwidth}"
  line_add_hilight "$line"
  printf -v ll '%*s\e[32;7m%s\e[m' "$pad" '' "$lhl${spacer:0:$((lwidth-${#line}))}"
  printf "\e[%d;%dH\e[K%s" $((lines+offset-cursorLine-1)) 1 "$ll"

  line_add_hilight "${haystack[${sorted[$lCursorLine]}]:0:$lwidth}"
  if (( ${marks[$lCursorLine]} )); then
    printf -v ll '%*s\e[32;3m%-*s\e[m' "$pad" '' "$lwidth" "$lhl"
  else
    printf -v ll '%*s%-*s\e[m' "$pad" '' "$lwidth" "$lhl"
  fi
  printf "\e[%d;%dH\e[K%s" $((lines+offset-lCursorLine-1)) 1 "$ll"
}

function redraw {
  local l=0 ll lhl
  local -a o
  for ((m = lines-1>${#sorted[@]} ? ${#sorted[@]} : lines-1; l<m ; l++)); do
    line_add_hilight "${haystack[${sorted[$((offset+l))]}]:0:$lwidth}"
    if (( offset+l == cursorLine )); then
      : "${haystack[${sorted[$((offset+l))]}]:0:$lwidth}"
      printf -v ll '%*s\e[32;7m%-*s\e[m' "$pad" '' "$lwidth" "${lhl}${spacer:0:$((lwidth-${#_}))}"
    elif (( ${marks[${sorted[$((offset+l))]}]} )); then
      printf -v ll '%*s\e[32;3m%-*s\e[m' "$pad" '' "$lwidth" "${lhl}${spacer:0:$((lwidth-${#_}))}"
    else
      printf -v ll '%*s%-*s\e[m' "$pad" '' "$lwidth" "$lhl${spacer:0:$((lwidth-${#_}))}"
    fi
    printf -v o[$l] "\e[%d;%dH\e[K%s" $((lines-l-1)) 1 "$ll"
  done

  for (( ; l<lines-1; l++ )); do
    printf -v o[$l] "\e[%d;%dH\e[K%s" $((lines-l-1)) 1 ''
  done
  printf "\e7"
  printf %s "${o[@]}"
  printf "\e8"
}

function redraw_statusline {
  local right tmp
  eval printf -v timeout %.0s. "{0..$(( delay_to_sort > 0 ? delay_to_sort : 0 ))}"
  local timeout=${progress_str:-$timeout}
  : ${#haystack[@]}
  printf -v right "%0*d/%d " "${#_}" "${#sorted[@]}" "${#haystack[@]}"
  printf -v tmp "[%2s:%-2s]"  "${read_key}" "$read_mod"
  printf "%b%*s\r %s [%s]%s\e[%dD\e[1D\e[m" "$statusline_bar" "$cols" "$right" "$tmp" "$cmdline" "$timeout" "${#timeout}"
}

function handle_winch {
  (:)
  (( lines=LINES, cols=COLUMNS, lwidth=cols-4, pad=2 ))
  printf '\e[2j'
  printf -v statusline_bar "\e[%d;1H\e[7m%*s\r" "$lines" "$cols" ""
  eval printf -v spacer '"%.0s "' "{1..$cols}"
  redraw
}

function scroll_up {
  (( lCursorLine=cursorLine, lOffset=offset,
      offset += offset <= ${#sorted[@]}-lines,
  cursorLine += offset > cursorLine,
  1)) ; redraw
}

function scroll_dn {
  (( lCursorLine=cursorLine, lOffset=offset,
      offset -= offset > 0,
  cursorLine -= cursorLine > offset+lines-2,
  1)) ; redraw
}

function cursor_up {
  (( lCursorLine=cursorLine, lOffset=offset,
  cursorLine += cursorLine < ${#sorted[@]}-1,
      offset += cursorLine > offset+lines-2,
  1)) ; redraw_quick
}

function cursor_dn {
  (( lCursorLine=cursorLine, lOffset=offset,
  cursorLine -= cursorLine > 0,
      offset -= cursorLine < offset,
  1)) ; redraw_quick
}

function line_clear {
  cmdline=''
  refresh_when "${FUNCNAME[0]}"
}

function line_clear_word {
  local lcmdline="$cmdline"
  cmdline=${cmdline% *}
  [[ "$lcmdline" == "$cmdline" ]] && cmdline=''
  refresh_when "${FUNCNAME[0]}"
}

function line_clear_one {
  cmdline=${cmdline:0:$(( -(${#cmdline}-1>0) ))}
  refresh_when "${FUNCNAME[0]}"
}

function line_add_char {
  cmdline+="$read_key"
  (( ! $# )) && refresh_when "${FUNCNAME[0]}"
}

function mark_toggle {
  if (( ${#marks[${sorted[$cursorLine]}]} )); then
    unset marks["${sorted[$cursorLine]}"]
  else
    marks[${sorted[$cursorLine]}]=1
  fi

  if (( lCursorLine < cursorLine )); then
    cursor_up
  else
    cursor_dn
  fi
}

function mark_get_files {
  local curKey=${sorted[$cursorLine]}
  marked_files=()
  if (( ${#marks[@]} )); then
    for key in "${!marks[@]}"; do
      (( key == curKey ))
      marked_files+=( "${haystack[$key]}" )
    done
  else
    marked_files+=( "${haystack[$curKey]}" )
  fi
}

function return_selected {
  printf "\e[?1049l" >/dev/tty

  mark_get_files
  printf "%s\n" "${marked_files[@]}"
} >&10

function exec_line {
  local prompt todo
  trap 'return 0' int
  printf -v prompt "\e[${lines}:1H\e[K%s: " "Enter a command"
  read -i 'nvim' -erp "$prompt" todo || return 0
  mark_get_files
  exec "$todo" "${marked_files[@]}"
}


function refresh_when {
  (( delay_to_sort = sort_delays[$1] >= 0 ? sort_delays[$1] : 0 ))
}

function set_delays {
  (( adjust_delays )) || return 0
  if (( ${#haystack[@]} < 1000 )); then
    sort_delays=( [line_add_char]=-1 [line_clear_one]=-1
                  [line_clear_word]=-1 [line_clear]=-1 )
  elif (( ${#haystack[@]} < 5000 )); then
    sort_delays=( [line_add_char]=2 [line_clear_one]=2
                  [line_clear_word]=2 [line_clear]=2 )
  fi
}

function wrap_sort {
  decide_and_sort
  (( lOffset = offset, lCursorLine = cursorLine,
  offset = 0, cursorLine = 0, 1 ))
  redraw
}

function mapfile_callback {
  if (( times == 0 )); then
    times=1
    sorted=( "${!haystack[@]}" )
  fi
  redraw
  redraw_statusline
}

function main {
  local -i times=0
  local -i lines cols lwidth pad
  local -i cursorLine=0 offset=0 lCursorLine lOffset
  local -a sorted haystack
  local read_key read_mod
  local cmdline lcmdline lcmdline_arr mode=insert

  local    adjust_delays=1
  local -A sort_delays=( [line_add_char]=3   [line_clear_one]=4
                         [line_clear_word]=5 [line_clear]=1 )
  local -i delay_to_sort=-1
  local progress_str
  local spacer
  local -A marks
  local -a marked_files

  exec 10>/dev/stdout 1>/dev/tty || exit 1

  printf "\e[?1049h"  # smcup
  trap handle_winch winch
  handle_winch
  redraw

  if [[ -p /dev/stdin ]]; then
    # If stdin is a pipe, read it then begin taking input from the tty.
    mapfile -t -C mapfile_callback -c 1000 haystack
    exec 0</dev/tty || exit 1
  else
    # If stdin isn't a pipe, find files in the current directory.
    # mapfile -t -C mapfile_callback -c 1000 haystack < <(
    #   stdbuf -o0 find . -mindepth 1 -maxdepth 2
    # )
    haystack=( */* * )
  fi

  sorted=( "${!haystack[@]}" )
  redraw
  set_delays

  while get_key; do
    progress_str=''
    trap 'printf "\e[?1049l"; exit' int
    case "${mode:-insert}:${read_mod:-x}:${read_key}" in
    insert:*:esc)         mode=normal ;;
    insert:a:x)           exec_line || redraw ;;
    insert:c:v)           mark_toggle ;;
    insert:c:j)           return_selected && return 0 ;;
    insert:x:[[:space:]]) line_add_char nop || : ;;
    insert:x:[[:print:]]) line_add_char   || wrap_sort ;;
    insert:x:bs)          line_clear_one  || wrap_sort ;;
    insert:c:w)           line_clear_word || wrap_sort ;;
    insert:c:u)           line_clear      || wrap_sort ;;
    insert:+([ma]:k|c:p)) cursor_up ;;
    insert:+([ma]:j|c:n)) cursor_dn ;;
    insert:+([ma]:h|c:y)) scroll_up ;;
    insert:+([ma]:l|c:e)) scroll_dn ;;
    insert:x:)            (( delay_to_sort -= delay_to_sort > -1, delay_to_sort == 0 )) && wrap_sort ;;
    # -------------
    normal:x:[iIaA])      mode=insert ;;
    normal:x:[[:space:]]) mark_toggle ;;
    normal:c:j)           return_selected && return 0 ;;
    normal:[mx]:k)        cursor_up ;;
    normal:[mx]:j)        cursor_dn ;;
    normal:+(m:h|x:[hu])) scroll_up ;;
    normal:+(m:l|x:[ld])) scroll_dn ;;
    esac
    redraw_statusline
  done
}

main
