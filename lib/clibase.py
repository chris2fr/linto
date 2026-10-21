"""Command-line scaffolding shared by the Python commands of every group.

Gives them the same look as the shell commands: a "Usage: linto GROUP NAME ..."
line, "-h/--help", and errors reported as "NAME: message" (exit status 2 for a
usage error, 1 for a runtime error).
"""

import argparse
import sys

from i18n import _  # noqa: F401  (re-exported for the commands)


class _Formatter(argparse.HelpFormatter):
    def add_usage(self, usage, actions, groups, prefix=None):
        super().add_usage(usage, actions, groups, prefix or "Usage: ")


class _RawFormatter(_Formatter, argparse.RawDescriptionHelpFormatter):
    pass


class Parser(argparse.ArgumentParser):
    def __init__(self, group, name, description=None, epilog=None, raw=False):
        super().__init__(
            prog=f"linto {group} {name}",
            description=description,
            epilog=epilog,
            add_help=False,
            formatter_class=_RawFormatter if raw else _Formatter,
        )
        self.name = name
        self._positionals.title = "Arguments"
        self._optionals.title = "Options"
        self.add_argument("-h", "--help", action="help", help=_("Show this help and exit."))

    def parse_args(self, args=None, namespace=None):
        args, extras = self.parse_known_args(args, namespace)
        if extras:
            self.error(_("unrecognized arguments: {}").format(" ".join(extras)))
        return args

    def error(self, message):
        print(f"{self.name}: {message}", file=sys.stderr)
        self.print_usage(sys.stderr)
        sys.exit(2)


def stdin_requested(parser, inputs, what):
    """True when the input is stdin: no file given, or a lone "-".

    Fails with a usage error when stdin is a terminal or "-" is mixed with files.
    """
    if inputs and "-" in inputs and len(inputs) > 1:
        parser.error(_("- (stdin) cannot be combined with other files"))
    if inputs and inputs != ["-"]:
        return False
    if sys.stdin.isatty():
        parser.error(_("no {}: give a file or provide stdin").format(what))
    return True


def fail(name, message):
    """Report a runtime error as "NAME: message" on stderr and return status 1."""
    print(f"{name}: {message}", file=sys.stderr)
    return 1
