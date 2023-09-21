#!/usr/bin/env python

"""Utility to group input files by year"""

from pathlib import Path
import json
from typing import TextIO, Generator, Iterable, Union
from more_itertools import batched, windowed
from sys import stdout


def find_year(metadata:dict, year: int) -> dict:
    """Find and return a single file object for one year.

    Finds the first item for that year. If none are found, raises
    a `FileNotFoundError`.
    """
    for item in list(metadata["files"]):
        if item["year"] == year:
            return item

    raise FileNotFoundError(f"No file for year {year} exists in the metadata")


def window(medatada: dict, width: int, sliding: bool = False) -> Generator[str, None, None]:
    """Sort files by year, and return a (sliding) window over them"""
    files = [x["path"] for x in metadata["files"]]
    years = [x["year"] for x in metadata["files"]]

    files = [x for x, _ in sorted(zip(files, years), key = lambda x: x[1])]
    
    if sliding:
        return windowed(files, width)
    return batched(files, width) 

def slice(metadata: dict, start: int, end: int) -> Generator[str, None, None]:
    """Return all years between two fenceposts, both inclusive""" 
    for year in range(start, end + 1):
        yield find_year(metadata, year)["path"]

def single(metadata: dict) -> Generator[str, None, None]:
    """Sort files by year, and return a (sliding) window over them"""
    files = [x["path"] for x in metadata["files"]]
    years = [x["year"] for x in metadata["files"]]

    files = [x for x, _ in sorted(zip(files, years), key = lambda x: x[1])]

    for file in files:
        yield file

def write_output(generator: Iterable, outstream: TextIO = stdout) -> None:
    for item in generator:
        if isinstance(item, str):
            outstream.write(f'"{item}"\n')
            continue

        outstream.write(' '.join([f'"{x}"' for x in item]))
        outstream.write("\n")
        

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()

    parser.add_argument("metadata", help = "Path to the metadata file", type = argparse.FileType("r"))
    parser.add_argument("--root", help = "Path to root fs. Defaults to using the metadata dir",
                        default=None)

    subparsers = parser.add_subparsers(help = "parsing methods", required=True, dest="method")

    parser_window = subparsers.add_parser("window", help = "Return a series of windows of a certain size")
    parser_window.add_argument("size", type = int, help = "size of window")
    parser_window.add_argument("--sliding", action="store_true", help="If specified, makes the window a sliding window")

    parser_single = subparsers.add_parser("single", help = "Outputs one year at a time")

    parser_bulk = subparsers.add_parser("bulk", help = "Return all or a slice of all years")
    parser_bulk.add_argument("--slice", help = "Years to slice, e.g. 2012-2015. Use - as a separator.")

    args = parser.parse_args()
    
    metadata = json.load(args.metadata)
    match args.method:
        case "window":
            write_output(window(metadata, width=args.size, sliding=args.sliding))
        case "single":
            write_output(single(metadata))
        case "bulk":
            if args.slice:
                years = [int(x) for x in args.slice.split("-")]
                # Hard to see, but this is a one-length tuple, with the list
                # in position zero (since it's what write_output wants)
                write_output(
                    (slice(metadata, start = min(years), end = max(years)), )
                )
            else:
                # Same as above, is a tuple
                write_output(([x["path"] for x in metadata["files"]], ))


