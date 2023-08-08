from pathlib import Path
from tqdm import tqdm
from collections import Counter


file_in = "/home/hedmad/Downloads/network.txt"
out = "/home/hedmad/Downloads/weighted_network.txt"

links = Path(file_in).open("r").readlines()

links = list(tqdm([x.strip() for x in links]))

counts = Counter(links)

with Path(out).open("w+") as stream:
    for link in tqdm(counts):
        stream.write(f"{link}, {counts[link]}\n")

