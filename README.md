FP - fuzzy picker
=================

written purely in bash, for bash. fp is Currently a standalone proof of
concept, it is not meant to do heavy lifting but provide fuzzy selection
capabilities with no overhead for other bash scripts.

![screenshot](/media/screenshot.jpg)

## Features

- vim-based modes
- multiple-selection
- run command on selection
- arrow keys

## Keymap

    # normal mode

      i | I | a | A      insert mode

      left  | h | u      scroll up
      down  | l | d      scroll down
      up    | k          selection cursor up
      down  | j          selection cursor down

      space              mark
      enter | c-j        select

    # insert mode

      escape             normal mode

      left  | m-h | c-y  scroll up
      right | m-l | c-e  scroll down
      up    | m-k | c-p  move selection cursor up
      down  | m-j | c-n  move selection cursor down

      M-x                run command
      C-v                mark
      enter | c-j        select
      backspace          delete one char
      C-w                delete last word
      C-u                clear line

## Planned

- Refactor into a set of functions to be sourced
- Restrict window to a given size
- Terminal position awareness (for usage from readline binds, etc)
- Switch from xterm esc sequences to tput
- Improve sorting

## Maybe

- interactive preview of glob/extglob/regex patterns
