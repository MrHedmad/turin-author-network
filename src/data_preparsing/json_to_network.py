#!/usr/bin/env python

import json
from pathlib import Path
from io import IOBase
import sys
from enum import Enum
from itertools import combinations
from dataclasses import dataclass

HELP = """Convert JSON digests of IRIS files to an edgelist and authorlist

Will convert some special characters in the output file names to network
characteristics:
    - {minyear}: The lowest paper publication year;
    - {maxyear}: The highest paper publication year;
    - {numnodes}: The number of authors (nodes);
    - {numedges}: The number of edges in the network;

E.g. edgelist_{minyear}-{maxyear}.csv is converted to edgelist_2012-2015.csv
"""


# The json structure is the one in the other file,
# i'm not copying the classes here, I'm not sure they are super necessary
# And in any case, they would be just for typing...
class WeightStrategy(Enum):
    UNWEIGTHED = "unweigthed"
    LINEAR = "linear"
    PAPER_SIZE_MODERATED = "paper_size_moderated"


@dataclass
class JsonStats:
    minyear: int
    maxyear: int
    numnodes: int
    numedges: int


def make_edgelist(papers: list[dict], strategy: WeightStrategy) -> list[str]:
    # TODO: This is very slow - please make me faster.
    # But it seems I'm fast enough for most networks.
    edges = {}

    for paper in papers:
        # We sort this as `combinations` will produce ordered tuples
        # if the input is sorted, and we want unique indexes for each
        # pair of author (edge). Having the sorted indexes be their new ID
        # should ensure this is the case
        authors = sorted(paper["authors"])
        for combo in combinations(authors, 2):
            # I use this ID format so its easy to pass it to .csv
            id = f'"{combo[0]}","{combo[1]}"'
            old_value = edges.get(id, 0)

            if strategy == WeightStrategy.UNWEIGTHED:
                edges[id] = 1
            elif strategy == WeightStrategy.LINEAR:
                edges[id] = old_value + 1
            elif strategy == WeightStrategy.PAPER_SIZE_MODERATED:
                edges[id] = old_value + (1 / len(authors))
    edgelist = []
    for key, value in edges.items():
        edgelist.append(f"{key},{value}")

    return edgelist


def make_authorlist(authors: list[dict]) -> list[str]:
    authors_list = []
    for a in authors:
        authors_list.append(
            f'"{a["name"]}","{a["surname"]}","{a["affiliation"]}","{a["department"]}","{a["id"]}"'
        )
    return authors_list


def main(
    input_path: Path,
    output_edgelist_path: Path,
    output_authors_path: Path,
    weigth_strategy: WeightStrategy,
) -> None:
    data = json.load(input_stream)

    edgelist = make_edgelist(data["papers"], weigth_strategy)
    authors_list = make_authorlist(data["authors"])

    all_years = [x["year"] for x in data["papers"]]
    stats = JsonStats(
        minyear=int(min(all_years)),
        maxyear=int(max(all_years)),
        numedges=len(edgelist),
        numnodes=len(authors_list),
    )

    print(stats.__dict__)

    output_authors_path = Path(str(output_authors_path).format_map(stats.__dict__))
    output_edgelist_path = Path(str(output_edgelist_path).format_map(stats.__dict__))

    output_edgelist_stream = output_edgelist_path.open("w+")
    output_authors_stream = output_authors_path.open("w+")

    output_edgelist_stream.writelines("node_1,node_2,weight\n")
    output_edgelist_stream.writelines([f"{x}\n" for x in edgelist])

    output_authors_stream.writelines("name,surname,affiliation,department,id\n")
    output_authors_stream.writelines([f"{x}\n" for x in authors_list])

    return None


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()

    parser.add_argument("output_edgelist", help="Output network edgelist", type=Path)
    parser.add_argument("output_authors", help="Output file to process", type=Path)
    parser.add_argument(
        "--weight_strategy",
        help="How should weights be calculated?",
        choices=["unweighted", "linear", "paper_size_moderated"],
        default="unweighted",
    )
    parser.add_argument(
        "--input_file", help="Input file to process", type=Path, default=None
    )

    args = parser.parse_args()

    input_stream = args.input_file.open("r") if args.input_file else sys.stdin

    main(
        input_stream,
        output_edgelist_path=args.output_edgelist,
        output_authors_path=args.output_authors,
        weigth_strategy=WeightStrategy(args.weight_strategy),
    )
