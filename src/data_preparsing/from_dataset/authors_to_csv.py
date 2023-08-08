from pathlib import Path
import json
from tqdm import tqdm

in_file = "/home/hedmad/Downloads/all_authors.json"
out_file = "/home/hedmad/Downloads/all_authors.tsv"

data = json.load(Path(in_file).open())

with Path(out_file).open("w+") as stream:
    stream.write("id\tname\torg\n")
    for key, values in tqdm(data.items()):
        stream.write(f"{key}\t{values['name']}\t{values['org']}\n")

