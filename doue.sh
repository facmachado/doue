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
  echo 'User not in the input group (or not root)' >&2
  exit 1
fi

#
# Declare some consts
#
EVEMU=$(command -v evemu-event)

#
# Check some dependencies
#
if [ ! "$EVEMU" ]; then
  echo 'Error: evemu-tools not installed' >&2
  exit 1
fi
if [ ! -e "/tmp/doued.lock" ]; then
  echo 'Error: doued not running' >&2
  exit 1
fi

#
# Declare more consts
#
declare -a fnls
declare -ri REL_0=-2147483648
EVENT=$(awk '/doued/,/event/ {a=$5} END {print a}' </proc/bus/input/devices)
INPUT_DEVICE="/dev/input/$EVENT"

# -----------------------------------------------------------------------------

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
  esac
}

#
# Holds the specified key(s) (up to 9 keys)
# @param {string} key_1
# ...
# @param {string} key_n
#
function keydown() {
  local k
  if (($# < 10)); then
    for k in "$@"; do
      "$EVEMU" "$INPUT_DEVICE" --type EV_KEY --code "$k" --value 1 --sync
    done
  fi
}

#
# Presses and releases the specified key
# @param {string} key
#
function keypress() {
  local k
  if (($# < 10)); then
    for k in "$@"; do
      keydown "$k"
      keyup   "$k"
    done
  fi
}

#
# Releases the specified key(s) (up to 9 keys)
# @param {string} key_1
# ...
# @param {string} key_n
#
function keyup() {
  local k
  if (($# < 10)); then
    for k in "$@"; do
      "$EVEMU" "$INPUT_DEVICE" --type EV_KEY --code "$k" --value 0 --sync
    done
  fi
}

#
# Clicks with the specified mouse button
# @param {string} button (2 = right; 3 = middle)
# @param {number} times (2 = double click)
#
function mouseclick() {
  for ((i=0; i<${2:-1}; i++)); do
    mousedown "$1"
    mouseup "$1"
  done
}

#
# Holds the specified mouse button
# @param {string} button (2 = right; 3 = middle)
#
function mousedown() {
  local b
  case "$1" in
    1) b=BTN_LEFT   ;;
    2) b=BTN_RIGHT  ;;
    3) b=BTN_MIDDLE ;;
    *) return 0     ;;
  esac
  "$EVEMU" "$INPUT_DEVICE" --type EV_KEY --code "$b" --value 1 --sync
}

#
# Moves the mouse pointer to an absolute position on screen.
# Cannot be negative
# @param {number} x
# @param {number} y
#
function mousemove() {
  mousezero
  "$EVEMU" "$INPUT_DEVICE" --type EV_REL --code REL_X --value $(($1 / 2))
  "$EVEMU" "$INPUT_DEVICE" --type EV_REL --code REL_Y --value $(($2 / 2)) --sync
}

#
# Scrolls the mouse wheel (1 step = 3 lines; negative = down)
# @param {number} steps
#
function mousescroll() {
  "$EVEMU" "$INPUT_DEVICE" --type EV_REL --code REL_WHEEL --value "$1" --sync
}

#
# Releases the specified mouse button
# @param {string} button (2 = right; 3 = middle)
#
function mouseup() {
  local b
  case "$1" in
    1) b=BTN_LEFT   ;;
    2) b=BTN_RIGHT  ;;
    3) b=BTN_MIDDLE ;;
    *) return 0     ;;
  esac
  "$EVEMU" "$INPUT_DEVICE" --type EV_KEY --code "$b" --value 0 --sync
}

#
# Moves the mouse pointer to coord (0, 0)
#
function mousezero() {
  "$EVEMU" "$INPUT_DEVICE" --type EV_REL --code REL_X --value $REL_0
  "$EVEMU" "$INPUT_DEVICE" --type EV_REL --code REL_Y --value $REL_0 --sync
}

# -----------------------------------------------------------------------------

#
# Listing functions for parsing
# shellcheck disable=SC2207
#
fnls=('#' 'sleep' $(declare -F | cut -d' ' -f3))

#
# Try to get file input, otherwise prompt
#
file=$(realpath "${1:-/dev/stdin}")

#
# Main loop
#
while read -r -p '% ' -a line; do
  if grep "${line[0]}" <<<"${fnls[@]}" >/dev/null; then
    eval "${line[@]}"
  else
    echo "error: invalid command '${line[0]}'"
  fi
  sleep 0.01
done <"$file" && echo
