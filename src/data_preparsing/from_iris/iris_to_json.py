from __future__ import annotations

import pandas as pd
from pathlib import Path
from dataclasses import dataclass
from typing import Optional
from uuid import uuid4
from jellyfish import jaro_winkler_similarity as jws
from io import StringIO


class Author:
    def __init__(self, name: str, surname: str, affiliation: str, department: Optional[str] = None, id: Optional[str] = None) -> None:
        # TODO: perhaps we could remove weird unicode characters? To make the matching easier?
        self.name = name.lower().strip()
        self.surname = surname.lower().strip()
        self.affiliation = affiliation.lower().strip()
        self.department = department.lower().strip() if department is not None else None
        self.id = id or str(uuid4())

        assert self.id is not None, "ID should not be None"

    def is_superset_of(self, other: Author) -> bool:
        """Return if this author is a better version than the other"""
        if other.id != self.id:
            return False
        
        # If any any of our fields are filled, we are better.
        return (self.name is not None and other.name is None ) or \
            (self.surname is not None and other.surname is None) or \
            (self.affiliation is not None and other.affiliation is None) or \
            (self.department is not None and other.department is None)

    def distance(self, other: Author) -> float:
        """Return the distance between this author and the other, ignoring the ID"""
        # This is a weighted average, were we give more importance to the name and surname
        # The rationale is that the affiliation and department are more likely to change
        # between roles
        return (jws(self.name, other.name) + \
            jws(self.surname, other.surname) + \
            jws(self.affiliation, other.affiliation) * 0.5 + \
            jws(self.department, other.department) * 0.5 ) / 3


class AuthorGlobber:
    def __init__(self) -> None:
        self.authors = dict()
    
    def add(self, author: Author) -> None:
        self.authors[author.id] = author
    
    def add_or_glob(self, author: Author) -> str:
        if (hit := self.find(author)):
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
    id: int
    title: int
    year: int
    authors: list[str]


def parse_file(gobbler: AuthorGlobber, data: pd.DataFrame) -> list[Paper]:
    # For every paper, we create a list of authors, then check if we have seen them before
    # If we have, we use the same ID, otherwise we create a new author, and add it to the gobbler

    papers = []

    for paper_id, paper in data.groupby("paper_id"):
        pass


def read_iris_data(path: Path) -> pd.DataFrame:
    """Read the iris data from the given path"""
    # Edit the header
    data = StringIO()
    with path.open("r") as stream:
        header = stream.readline().split(",")
        header = [standardize_header(head.strip('"')) for head in header]

        data.write(",".join(header) + "\n")

        for line in stream:
            data.write(line)

    data = pd.read_csv(
        data,
        encoding="utf-8",
        true_values=["si", "Sì", "SI", "sì", "yes", "Yes", "YES"],
        false_values=["no", "No", "NO"],
        na_values=["n.d.", "n.d", "nd", "N.D.", "N.D", "ND", "n.a.", "n.a", "na", "N.A.", "N.A", "NA", ""],
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
    

def main(folder: Path):
    files = folder.glob("*.csv")



if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()

    parser.add_argument("folder", help="Folder containing the iris data", type=Path)

    args = parser.parse_args()

    main(args.folder)
