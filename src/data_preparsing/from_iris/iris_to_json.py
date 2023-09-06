from __future__ import annotations

import pandas as pd
from pathlib import Path
from dataclasses import dataclass
from typing import Optional
from uuid import uuid4
from jellyfish import jaro_winkler_similarity as jws
from io import StringIO, IOBase
from tqdm import tqdm
import csv
import logging
import json
import numpy as np
import sys

logging.basicConfig(level=logging.INFO)

log = logging.getLogger(__name__)


class Author:
    def __init__(
        self,
        name: str,
        surname: str,
        affiliation: str,
        department: Optional[str] = None,
        id: Optional[str] = None,
    ) -> None:
        log.debug(f"Creating author {name} {surname} {affiliation} {department} {id}")
        # TODO: perhaps we could remove weird unicode characters? To make the matching easier?
        # The guarding IFs are to get around NAs
        self.name = name.lower().strip() if name and pd.notna(name) else None
        self.surname = (
            surname.lower().strip() if surname and pd.notna(surname) else None
        )
        self.affiliation = (
            affiliation.lower().strip()
            if affiliation and pd.notna(affiliation)
            else None
        )
        self.department = (
            department.lower().strip() if department and pd.notna(department) else None
        )
        self.id = id or str(uuid4())

        assert self.id is not None, "ID should not be None"

    def is_superset_of(self, other: Author) -> bool:
        """Return if this author is a better version than the other"""
        if other.id != self.id:
            return False

        # If any any of our fields are filled, we are better.
        return (
            (self.name is not None and other.name is None)
            or (self.surname is not None and other.surname is None)
            or (self.affiliation is not None and other.affiliation is None)
            or (self.department is not None and other.department is None)
        )

    def distance(self, other: Author) -> float:
        """Return the distance between this author and the other, ignoring the ID"""
        # This is a weighted average, were we give more importance to the name and surname
        # The rationale is that the affiliation and department are more likely to change
        # between roles
        return (
            jws(self.name or "", other.name or "")
            + jws(self.surname or "", other.surname or "")
            + jws(self.affiliation or "", other.affiliation or "") * 0.5
            + jws(self.department or "", other.department or "") * 0.5
        ) / 3


class AuthorGlobber:
    def __init__(self) -> None:
        self.authors = dict()

    def add(self, author: Author) -> None:
        self.authors[author.id] = author

    def add_or_glob(self, author: Author) -> str:
        if hit := self.find(author):
            return hit.id
        else:
            self.add(author)
            return author.id

    def find(self, author: Author) -> Optional[Author]:
        if author.id in self.authors:
            # TODO: We return the saved one, but which is better?
            return self.authors[author.id]

        for saved_author in self.authors.values():
            # If we have a similar author, return it
            if saved_author.distance(author) < 0.25:
                # TODO: make the distance a parameter
                # TODO: Which author is better?
                return saved_author

        return None


@dataclass
class Paper:
    id: str
    title: int
    year: int
    authors: list[str]


def parse_file_simple(gobbler: AuthorGlobber, data: pd.DataFrame) -> list[Paper]:
    # Here, we do not do any fancy matching, we just add the authors if they
    # are "recognized"
    # The resulting network will only have known authors. Not sure if this is ok
    # but it's a start.

    papers = []

    for paper_id, paper in tqdm(data.groupby("handle")):
        # Extract the authors and add them to the gobbler
        authors = []
        for _, row in paper.iterrows():
            author = Author(
                name=row["author_name"],
                surname=row["author_surname"],
                affiliation="University of Turin (maybe)",
                department=row["author_department"],
                id=row["author_cris_id"],
            )
            result = gobbler.add_or_glob(author)
            authors.append(result)

        paper_obj = Paper(
            id=paper_id,
            title=paper["title"].iloc[0],  # The titles should all be the same
            # TODO: We should probably check that the titles are the same
            year=paper["year"].iloc[0],  # The years should all be the same
            # TODO: We should probably check that the years are the same,
            authors=authors,
        )
        papers.append(paper_obj)

    log.info(f"Found {len(papers)} papers")
    log.debug(papers[0])

    return papers


def read_iris_data(path: Path) -> pd.DataFrame:
    """Read the iris data from the given path"""
    log.info(f"Reading {path} to an IRIS dataset")
    # Edit the header
    data = StringIO()
    with path.open("r") as stream:
        reader = csv.reader(stream)
        header = next(reader)
        header = [standardize_header(head.strip('"')) for head in header]

        data.write(",".join(header) + "\n")

        for line in stream:
            data.write(line)

    data.seek(0)

    data = pd.read_csv(
        data,
        encoding="utf-8",
        true_values=["si", "Sì", "SI", "sì", "yes", "Yes", "YES"],
        false_values=["no", "No", "NO"],
        na_values=[
            "n.d.",
            "n.d",
            "nd",
            "N.D.",
            "N.D",
            "ND",
            "n.a.",
            "n.a",
            "na",
            "N.A.",
            "N.A",
            "NA",
            "",
        ],
        skip_blank_lines=True,
    )

    return data


def standardize_header(head: str) -> str:
    """Standardize a header string"""
    head = head.strip().replace("\n", " ")
    matches = {
        "Handle": "handle",
        "Titolo": "title",
        "Anno di pubblicazione": "year",
        "Tipologia IRIS": "iris_type",
        "Tutti gli autori/Curatori": "authors",
        "Nr autori/Curatori (numero)": "num_authors",
        "contributors: Autori/curatori riconosciuti (elenco)": "recognized_authors",
        "contributors: Autori/curatori riconosciuti (conteggio)": "num_recognized_authors",
        "contributors: Autori/curatori attualmente afferenti (elenco)": "currently_affiliated_authors",
        "contributors: Autori/curatori attualmente afferenti (Nr)": "num_currently_affiliated_authors",
        "Lingua (denominazione)": "language",
        "Nome rivista": "journal_name",
        "Rivista/Serie: ISSN": "journal_issn",
        "Rivista: codice ANCE": "journal_ance_code",
        "rivista: DOAJ (si/no)": "journal_is_doaj",
        "rivista: policy sherpa/romeo per pre-print": "journal_sherpa_romeo_preprint_policy",
        "rivista: policy sherpa/romeo per versione editoriale": "journal_sherpa_romeo_policy",
        "rivista: policy sherpa/romeo per post-print": "journal_sherpa_romeo_postprint_policy",
        "rivista: editore": "journal_publisher",
        "autore: Cognome": "author_surname",
        "autore: Nome": "author_name",
        "autore: ORCID": "author_orcid",
        "autore: ID persona (CRIS)": "author_cris_id",
        "autore: Ruolo al 01/07/2023": "author_role",
        "autore: Unità organizzativa interna al 01/07/2023": "author_department",
        "scopus: Identificativo": "scopus_id",
        "scopus: affiliazioni": "scopus_affiliations",
        "scopus: nazioni": "scopus_countries",
        "scopus: presenza coautore straniero": "scopus_has_foreign_coauthor",
    }

    if head in matches:
        return matches[head]

    raise ValueError(f"Unknown header: {head}")


class NpEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, np.integer):
            return int(obj)
        if isinstance(obj, np.floating):
            return float(obj)
        if isinstance(obj, np.ndarray):
            return obj.tolist()
        return super(NpEncoder, self).default(obj)


def main(folder: Path, output_steam: IOBase):
    files = list(folder.glob("*.csv"))
    log.info(f"Found {len(files)} files. Reading them in...")
    datasets = [read_iris_data(path) for path in files]

    author_gobbler = AuthorGlobber()
    papers = []
    for dataset in datasets:
        papers.extend(parse_file_simple(author_gobbler, dataset))

    log.info(f"Found {len(author_gobbler.authors)} authors")
    log.info(f"Found {len(papers)} papers")

    json.dump(
        {
            "authors": [x.__dict__ for x in author_gobbler.authors.values()],
            "papers": [x.__dict__ for x in papers],
        },
        output_steam,
        cls=NpEncoder,
    )

    return None


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()

    parser.add_argument("folder", help="Folder containing the iris data", type=Path)
    parser.add_argument("--output_file", help="Output file", type=Path, default=None)
    parser.add_argument(
        "-v", "--verbose", action="count", default=0, help="Increase verbosity"
    )

    args = parser.parse_args()

    verbosity_levels = {
        0: logging.WARNING,
        1: logging.INFO,
        2: logging.DEBUG,
    }

    for i, level in verbosity_levels.items():
        if args.verbose >= i:
            log.setLevel(level)

    output_stream = args.output_file.open("w+") if args.output_file else sys.stdout
    main(args.folder, output_stream)
