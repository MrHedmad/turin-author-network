import ijson
import json
from itertools import combinations
from pathlib import Path
from tqdm import tqdm
from multiprocessing import Pool

in_real = "/home/hedmad/Downloads/dblp.v12.json"
in_test = "./test_data.json"
file_in = in_real
out_nw = "/home/hedmad/Downloads/network.txt"
out_authors = "/home/hedmad/Downloads/authors{n}.json"

stream = Path(file_in).open("rb")
data = ijson.items(stream, "item")

authors_n = 1
authors = {}

with Path(out_nw).open("w+") as nwstream:
    for entry in tqdm(data):
        ids = []
        these_authors = entry.get("authors")
        if not these_authors:
            continue
        for author in these_authors:
            authors[author["id"]] = {"name": author["name"], "org": author.get("org")}
            ids.append(author["id"])
        for combo in combinations(ids, 2):
            nwstream.write(f"{combo[0]}, {combo[1]}\n")

        if len(authors) > 100_000:
            with Path(out_authors.format(n=authors_n)).open("w+") as auth_stream:
                json.dump(authors, auth_stream, indent=4)
            authors = {}
            authors_n += 1

with Path(out_authors).open("w+") as auth_stream:
    json.dump(authors, auth_stream, indent=4)
