#!/bin/bash

#
#  doue.sh - UInput device tiny server (doue client)
#
#  Copyright (c) 2022 Flavio Augusto (@facmachado)
#
#  This software may be modified and distributed under the terms
#  of the MIT license. See the LICENSE file for details.
#
#  Usage: doue [file]
#

#
# Checks user's permissions
#
if ! (id -Gn "$USER" | grep input) >/dev/null 2>&1 && ((UID != 0)); then
  echo 'error: user not in the input group (or not root)' >&2
  exit 1
fi

#
# Check if evemu is installed and doued is running
#
EVEMU=$(command -v evemu-event)
if [ ! "$EVEMU" ]; then
  echo 'error: evemu or evemu-tools not installed' >&2
  exit 1
fi
if [ ! -e "/tmp/doued.lock" ]; then
  echo 'error: doued not running' >&2
  exit 1
fi

#
# Declare some consts
#
declare INPUT
declare DEVICE
declare -a CMDS
declare -i REL_0
REL_0=-2147483648
DEVICE="/dev/input/$(
  awk '/doued/,/event/ {a=$5} END {print a}' </proc/bus/input/devices
)"

#
# Makes keys combinations (up to 9 keys).
# The last key is the trigger
# @param {string} key_1
# ...
# @param {string} key_keypress
#
function keycombo() {
  case "$#" in
    2)
      keydown  "$1"
      keypress "$2"
      keyup    "$1"
    ;;
    3)
      keydown  "$1" "$2"
      keypress "$3"
      keyup    "$2" "$1"
    ;;
    4)
      keydown  "$1" "$2" "$3"
      keypress "$4"
      keyup    "$3" "$2" "$1"
    ;;
    5)
      keydown  "$1" "$2" "$3" "$4"
      keypress "$5"
      keyup    "$4" "$3" "$2" "$1"
    ;;
    6)
      keydown  "$1" "$2" "$3" "$4" "$5"
      keypress "$6"
      keyup    "$5" "$4" "$3" "$2" "$1"
    ;;
    7)
      keydown  "$1" "$2" "$3" "$4" "$5" "$6"
      keypress "$7"
      keyup    "$6" "$5" "$4" "$3" "$2" "$1"
    ;;
    8)
      keydown  "$1" "$2" "$3" "$4" "$5" "$6" "$7"
      keypress "$8"
      keyup    "$7" "$6" "$5" "$4" "$3" "$2" "$1"
    ;;
    9)
      keydown  "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8"
      keypress "$9"
      keyup    "$8" "$7" "$6" "$5" "$4" "$3" "$2" "$1"
    ;;
    *)
      echo "syntax: keycombo <key_1> <key_2> [key_3] ... [key_9]" >&2
      return 1
    ;;
  esac
}

#
# Holds the specified key(s) (up to 9 keys)
# @param {string} key_1
# ...
# @param {string} key_9
#
function keydown() {
  if (($# < 1)); then
    echo "syntax: keydown <key_1> [key_2] [key_3] ... [key_9]" >&2
    return 1
  fi
  local k
  if (($# < 10)); then
    for k in "$@"; do
      "$EVEMU" "$DEVICE" --type EV_KEY --code "$k" --value 1 --sync
    done
  fi
}

#
# Presses and releases the specified key(s)
# @param {string} key_1
# ...
#
function keypress() {
  if (($# < 1)); then
    echo "syntax: keypress <key_1> [key_2] [key_3] ..." >&2
    return 1
  fi
  local k
  for k in "$@"; do
    keydown "$k"
    keyup   "$k"
  done
}

#
# Releases the specified key(s) (up to 9 keys)
# @param {string} key_1
# ...
# @param {string} key_9
#
function keyup() {
  if (($# < 1)); then
    echo "syntax: keyup <key_1> [key_2] [key_3] ... [key_9]" >&2
    return 1
  fi
  local k
  if (($# < 10)); then
    for k in "$@"; do
      "$EVEMU" "$DEVICE" --type EV_KEY --code "$k" --value 0 --sync
    done
  fi
}

#
# Clicks with the specified mouse button
# @param {string} button
# @param {number} clicks
#
function mouseclick() {
  if (($# != 2)); then
    echo -e 'syntax: mouseclick <button> <clicks>\n' \
    '       button: (1 = left; 2 = right; 3 = middle)\n' \
    '       clicks: (1 = single; 2 = double)' >&2
    return 1
  fi
  for ((i=0; i<$2; i++)); do
    mousedown "$1"
    mouseup "$1"
  done
}

#
# Holds the specified mouse button
# @param {string} button
#
function mousedown() {
  if (($# != 1)); then
    echo "syntax: mousedown <button> (1 = left; 2 = right; 3 = middle)" >&2
    return 1
  fi
  local b
  case "$1" in
    1) b=BTN_LEFT   ;;
    2) b=BTN_RIGHT  ;;
    3) b=BTN_MIDDLE ;;
    *) return 0     ;;
  esac
  "$EVEMU" "$DEVICE" --type EV_KEY --code "$b" --value 1 --sync
}

#
# Moves the mouse pointer to an absolute position on screen.
# Cannot be negative
# @param {number} x
# @param {number} y
#
function mousemove() {
  if (($# != 2)); then
    echo "syntax: mousemove <x> <y>" >&2
    return 1
  fi
  mousezero
  "$EVEMU" "$DEVICE" --type EV_REL --code REL_X --value $(($1 / 2))
  "$EVEMU" "$DEVICE" --type EV_REL --code REL_Y --value $(($2 / 2)) --sync
}

#
# Scrolls the mouse wheel
# @param {number} steps
#
function mousescroll() {
  if (($# != 1)); then
    echo "syntax: mousescroll <steps> (1 step = 3 lines; negative = down)" >&2
    return 1
  fi
  "$EVEMU" "$DEVICE" --type EV_REL --code REL_WHEEL --value "$1" --sync
}

#
# Releases the specified mouse button
# @param {string} button
#
function mouseup() {
  if (($# != 1)); then
    echo "syntax: mouseup <button> (1 = left; 2 = right; 3 = middle)" >&2
    return 1
  fi
  local b
  case "$1" in
    1) b=BTN_LEFT   ;;
    2) b=BTN_RIGHT  ;;
    3) b=BTN_MIDDLE ;;
    *) return 0     ;;
  esac
  "$EVEMU" "$DEVICE" --type EV_KEY --code "$b" --value 0 --sync
}

#
# Moves mouse pointer to coord (0, 0)
#
function mousezero() {
  "$EVEMU" "$DEVICE" --type EV_REL --code REL_X --value $REL_0
  "$EVEMU" "$DEVICE" --type EV_REL --code REL_Y --value $REL_0 --sync
}

#
# Listing commands
# shellcheck disable=SC2207
#
CMDS=('#' 'echo' 'exit' 'sleep' $(declare -F | cut -d' ' -f3))

#
# Prompt if file not given. If given, try to find it
#
if [ "$1" ] && [ ! -f "$(realpath "$1")" ]; then
  echo "error: $1 not found" >&2
  exit 1
fi
INPUT=$(realpath "${1:-/dev/stdin}")

#
# Our interpreter's main loop
#
while read -r -e -p '% ' -a line; do
  if ! grep -q "${line[0]}" <<<"${CMDS[@]}"; then
    echo "error: invalid command '${line[0]}'" >&2
    continue
  fi
  eval "${line[@]}"
done <"$INPUT"
