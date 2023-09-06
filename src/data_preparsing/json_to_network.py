import json
from pathlib import Path
from io import IOBase
import sys


def main(input_stream: IOBase, output_stream: IOBase) -> None:
    data = json.load(input_stream)
    # TODO: Add a way to select which filters to apply

    json.dump(data, output_stream)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()

    parser.add_argument("output_edgelist", help="Output network edgelist", type=Path)
    parser.add_argument("output_authors_csv", help="Output file to process", type=Path)
    parser.add_argument(
        "--weight_strategy",
        help="How should weights be calculated?",
        choices=["unweighted", "linear", "paper_size_weight"],
        default="unweighted",
    )
    parser.add_argument(
        "--input_file", help="Input file to process", type=Path, default=None
    )

    args = parser.parse_args()

    input_stream = args.input_file.open("r") if args.input_file else sys.stdin
    output_stream = args.output_file.open("w+")

    main(input_stream, output_stream)
