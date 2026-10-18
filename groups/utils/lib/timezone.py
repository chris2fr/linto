#!/usr/bin/env python3
"""Convert an ISO date/time from a source time zone to a destination time zone."""

import argparse
import re
import sys
from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

ISO_INPUT = re.compile(
    r"^(?P<date>\d{4}-\d{2}-\d{2})"
    r"(?:[T ](?P<time>\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?))?"
    r"(?P<offset>Z|[+-]\d{2}:?\d{2})?$"
)


def parse_datetime(value: str, source_timezone: str) -> tuple[datetime, int]:
    """Parse ISO input, applying the source zone if no offset is supplied."""
    match = ISO_INPUT.fullmatch(value)
    if not match:
        raise ValueError(
            "expected YYYY-MM-DD[THH:MM[:SS[.fraction]]][Z|+/-HH:MM]"
        )

    date_part = match.group("date")
    time_part = match.group("time")
    offset_part = match.group("offset")
    if time_part is None:
        precision = 0
    elif "." in time_part:
        precision = 4
    elif time_part.count(":") == 2:
        precision = 3
    else:
        precision = 2

    normalized = date_part
    if time_part is not None:
        normalized += "T" + time_part
    if offset_part:
        normalized += "+00:00" if offset_part == "Z" else offset_part
        if offset_part != "Z" and len(offset_part) == 5:
            normalized = normalized[:-5] + offset_part[:3] + ":" + offset_part[3:]

    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise ValueError(f"invalid ISO date/time: {value}") from exc

    if parsed.tzinfo is None:
        try:
            source = ZoneInfo(source_timezone)
        except ZoneInfoNotFoundError as exc:
            raise ValueError(f"unknown source time zone: {source_timezone}") from exc
        parsed = parsed.replace(tzinfo=source)

    return parsed, precision


def format_offset(value: datetime) -> str:
    offset = value.strftime("%z")
    return f"{offset[:3]}:{offset[3:]}"


def generate_biblatex_date(
    value: str,
    destination_timezone: str = "Europe/Paris",
    source_timezone: str | None = None,
) -> str:
    """Convert to the destination zone while preserving date/time precision."""
    source_timezone = source_timezone or destination_timezone
    parsed, precision = parse_datetime(value, source_timezone)
    try:
        destination = ZoneInfo(destination_timezone)
    except ZoneInfoNotFoundError as exc:
        raise ValueError(
            f"unknown destination time zone: {destination_timezone}"
        ) from exc

    converted = parsed.astimezone(destination)
    offset_suffix = "Z" if destination_timezone == "UTC" else format_offset(converted)
    date_part = converted.strftime("%Y-%m-%d")
    if precision == 0:
        return f"{date_part}{offset_suffix}"

    result = date_part + converted.strftime("T%H:%M")
    if precision >= 3:
        result += converted.strftime(":%S")
    if precision == 4:
        fraction = f"{converted.microsecond:06d}".rstrip("0")
        if fraction:
            result += f".{fraction}"
    return result + offset_suffix


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Convert an ISO date/time between IANA time zones."
    )
    parser.add_argument(
        "datetime",
        help="ISO date/time, e.g. 2027-12-28T14:30 or 2027-12-28T14:30-02:00",
    )
    parser.add_argument(
        "-s", "--source-timezone",
        help="source IANA time zone; defaults to the destination zone",
    )
    parser.add_argument(
        "-d", "--destination-timezone",
        default="Europe/Paris",
        help="destination IANA time zone (default: Europe/Paris)",
    )
    args = parser.parse_args()

    try:
        result = generate_biblatex_date(
            args.datetime,
            destination_timezone=args.destination_timezone,
            source_timezone=args.source_timezone,
        )
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    print(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
