#!/usr/bin/env python

import json
from pathlib import Path
from uuid import uuid4
from copy import deepcopy
from tqdm import tqdm
import sys

def main(input_stream):
    data = json.load(input_stream)

    new_ids = {}
    new_authors = []

    for author in tqdm(data["authors"], desc="Making new authors..."):
        if not new_ids.get(author["id"]):
            new_ids[author["id"]] = str(uuid4())
        new_author = deepcopy(author)
        new_author["id"] = new_ids[author["id"]]
        new_authors.append(new_author)

    assert len(list(new_ids.values())) == len(set(new_ids.values()))

    new_papers = []
    for paper in tqdm(data["papers"], desc="Replacing paper IDs..."):
        new_paper = deepcopy(paper)
        new_paper["authors"] = [new_ids[id] for id in paper["authors"]]
        new_papers.append(new_paper)

    return {"authors": new_authors, "papers": new_papers}

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()

    parser.add_argument("--input_path", type=Path, default=None, help="JSON data to anonimize")
    parser.add_argument("--output_path", type=Path, default=None, help="Output path to write")

    args = parser.parse_args()
    
    result = main(args.input_path.open("r") if args.input_path else sys.stdin)

    stream = args.output_path.open("w+") if args.output_path else sys.stdout

    json.dump(result, stream)

