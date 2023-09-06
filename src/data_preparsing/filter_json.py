#!/usr/bin/env python

"""This file filters the json file for various parameters."""
import sys
import sys
from pathlib import Path
from io import IOBase
import json
import logging

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)


def remove_single_author_papers(data: list[dict]) -> dict:
    """Remove papers that have only one author"""
    log.info("Removing single author papers...")
    return [value for value in data if len(value["authors"]) > 1]


FILTERS = {
    "papers": [
        remove_single_author_papers,
    ],
    "authors": [],
    "both": [],
}


def apply_filters(data: dict, filters: list) -> dict:
    for filter in filters["papers"]:
        data["papers"] = filter(data["papers"])
    for filter in filters["authors"]:
        data["authors"] = filter(data["authors"])
    for filter in filters["both"]:
        data = filter(data)

    return data


def main(input_stream: IOBase, output_stream: IOBase) -> None:
    data = json.load(input_stream)
    # TODO: Add a way to select which filters to apply
    data = apply_filters(data, FILTERS)

    json.dump(data, output_stream)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--input_file", help="Input file to process", type=Path, default=None
    )
    parser.add_argument(
        "--output_file", help="Output file to process", type=Path, default=None
    )

    args = parser.parse_args()

    input_stream = args.input_file.open("r") if args.input_file else sys.stdin
    output_stream = args.output_file.open("w+") if args.output_file else sys.stdout

    main(input_stream, output_stream)
