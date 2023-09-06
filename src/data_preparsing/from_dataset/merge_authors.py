import json
from pathlib import Path
import os
from tqdm import tqdm

in_dir = "/home/hedmad/Downloads/"

files = os.listdir(Path(in_dir))
files = [
    os.path.join(in_dir, x)
    for x in files
    if os.path.isfile(os.path.join(in_dir, x)) and x.startswith("authors")
]

authors = {}
for file in tqdm(files):
    with Path(file).open("r") as stream:
        authors.update(json.load(stream))

with (Path(in_dir) / "all_authors.json").open("w+") as out:
    json.dump(authors, out, indent=4)
