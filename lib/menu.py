"""Pick one item from a list with the arrow keys.

Usage: menu.py [--prefix TEXT] TITLE ITEM...

The menu is drawn on standard output, which must be a terminal. The chosen
item is written to standard error, so callers can capture it with
`2>&1 >/dev/tty`. Nothing is written when the menu is cancelled.
"""

import argparse
import curses
import os
import sys

os.environ.setdefault("ESCDELAY", "25")

ENTER_KEYS = {curses.KEY_ENTER, 10, 13}
UP_KEYS = {curses.KEY_UP, ord("k")}
DOWN_KEYS = {curses.KEY_DOWN, ord("j")}
QUIT_KEYS = {27, ord("q")}


def choose(screen, title, items, prefix):
    curses.curs_set(0)
    screen.keypad(True)
    selected = 0
    top = 0
    while True:
        height, width = screen.getmaxyx()
        visible = max(1, height - 3)
        if selected < top:
            top = selected
        elif selected >= top + visible:
            top = selected - visible + 1

        screen.erase()
        screen.addnstr(0, 0, title, width - 1, curses.A_BOLD)
        for row, item in enumerate(items[top:top + visible]):
            attributes = curses.A_REVERSE if top + row == selected else curses.A_NORMAL
            screen.addnstr(row + 2, 2, prefix + item, width - 3, attributes)
        screen.refresh()

        key = screen.getch()
        if key in ENTER_KEYS:
            return items[selected]
        if key in QUIT_KEYS:
            return None
        if key in UP_KEYS:
            selected = (selected - 1) % len(items)
        elif key in DOWN_KEYS:
            selected = (selected + 1) % len(items)
        elif key == curses.KEY_HOME:
            selected = 0
        elif key == curses.KEY_END:
            selected = len(items) - 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--prefix", default="")
    parser.add_argument("title")
    parser.add_argument("items", nargs="+")
    args = parser.parse_args()
    choice = curses.wrapper(choose, args.title, args.items, args.prefix)
    if choice is not None:
        print(choice, file=sys.stderr)


if __name__ == "__main__":
    main()
