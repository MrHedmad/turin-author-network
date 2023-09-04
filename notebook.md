# Data source

We sourced the data by contacting directly the IRIS office of the university.
They provided us with a series of Excel files, one for each publication year, containing the list of all the publications of the university.

We define "publication" as category `03 - "ARTICOLO IN RIVISTA"` of the IRIS database. 
This category includes all the publications in scientific journals.

We included all departments of the university. Data was provided for the year period of 2012-2023.
Data was extracted on the first of September, 2023.

We were also provided with a list of authors, with their department and role (professor, researcher, etc.), taken from the university's HR database, as of the first of July, 2023.

Each Excel file contains the following columns:
- `Handle`: the unique identifier of the publication.
- `Titolo`: The full title of the publication.
- `Anno di pubblicazione`: The year of publication.
- `Tipologia IRIS`: The type of publication. We only consider publications of type `03 - "ARTICOLO IN RIVISTA"`, but this category has two sub-categories, `03A` for research articles, and `03B` for reviews. We consider both.
- `Tutti gli autori/curatori`: The list of authors.
    - This field is malformed. The author list is sometimes with full names, sometimes with abbreviations, sometimes comma-separated and sometimes semicolon-separated.
- `Nr autori/Curatori (numero)`: The number of authors.
- `contributors: Autori/curatori riconosciuti (elenco)`: The list of curated authors, broadly meaning the authors with a position in UNITO. The list is a subset of the previous one, but not malformed. The data is all uppercase, and the names are separated by semicolons.
- `contributors: Autori/curatori riconosciuti (conteggio)`: The number of curated authors.
- `contributors: Autori/curatori attualmente afferenti (elenco)`: Same as the `contributors: Autori/curatori riconosciuti (elenco)` field, but only for authors *currently* affiliated with UNITO. The data is in the same format as before.
- `contributors: Autori/curatori attualmente afferenti (Nr)`: The number of authors currently affiliated with UNITO.
- `Lingua (denominazione)`: The language of the publication, in Italian (e.g. "Inglese").
- `Nome Rivista`: The name of the journal.
- `Rivista/Serie: ISSN`: The International Standard Series Number (ISSN) of the journal.
- `Rivista: codice ANCE`: The ANCE code of the journal. ANCHE is a ministerial database for scientific journals.
- `rivista: DOAJ (si/no)`: Whether the journal is in the Directory of Open Access Journals (DOAJ), either Si or No.
- `rivista: policy sherpa/romeo per pre-print`: The policy of the journal regarding pre-prints, either "can archive pre-print" (can), "cannot archive pre-print" (cannot), or with some restrictions (restricted). May be unknown (unknown).
- `rivista: policy sherpa/romeo per versione editoriale`: Same as before, but for the final version of the article.
- `rivista: policy sherpa/romeo per post-print`: Same as before, but for the post-print version of the article.
- `rivista: editore`: The publisher of the journal.
- `scopus: affiliazioni`: The affiliations of the authors, as reported by Scopus. This is a semicolon-separated list of affiliations, one for each author in the `Tutti gli autori/curatori` field.
    - The field is not malformed, but the manually-added data is not homogeneous. For example, some affiliations are in English, some in Italian, some are the full name of the department, some are the acronym, and some are the full name of the university. For just the University of Turin, the terms "Universita' di Torino", "Universita' degli studi di Torino", and "University of Torino" are used, to name a few.
- `scopus: nazioni`: The nations of the affiliations, as reported by Scopus. This is a semicolon-separated list of nations, one for each author in the `Tutti gli autori/curatori` field.
    - This seems to be from a drop-down menu, as the data is homogeneous.
- `scopus: presenza coautore straniero`: Whether there is a foreign co-author, either Si or NO.

The remaining columns require some explanation. Each article (with the same `Handle`) may have multiple rows. Each row corresponds to a different *curated* author. The columns are:
- `autore: Cognome`: The surname of the author.
- `autore: Nome`: The name of the author.
- `autore: ORCID`: The ORCID of the author, if inserted.
    - A cursory inspection discovers that some ORCIDs are plainly wrong, referring to other authors.
- `autore: ID persona (CRIS)`: The ID of the author in the HR database.
- `autore: Ruolo al 01/07/2023`: The role of the author in the HR database, as of the first of July, 2023.
- `autore: Unità organizzativa interna al 01/07/2023`: The department of the author in the HR database, as of the first of July, 2023.
- `scopus: Identificativo`: The Scopus ID of.. something. It's not clear what this field is.

# Data cleaning
It is clear that the data requires cleaning. We require two lists:
- A list of articles, with information on:
    - A list of IDs of the authors.
    - The year of publication.
    - The publication journal.
- A list of authors, with information on:
    - The ID of the author.
    - The university of the author.
    - The department of the author (if working in UNITO).
    - The role of the author (if working in UNITO).

For the list of articles, we can make the following observations:
- The `Handle` field is unique for each article, and is the same for all rows of the same article. We will use this as the ID of the article.
- The `Tutti gli autori/curatori` field is malformed, but we can extract the list of authors from it. This is the only field with ALL authors.
- The `contributors: Autori/curatori riconosciuti (elenco)` field is not malformed, but it is incomplete.
    - For these authors, we have a permanent ID (the `autore: ID persona (CRIS)` field), and we have the department and role (in many cases). We will use this field preferentially to create author profiles.
    - We can assign arbitrary IDs to other authors in the `Tutti gli autori/curatori` field, and attempt to heuristically match then between articles. This approach is flawed, but it is the best we can do.

For the list of authors, we can make the following observations:
- The `autore: ID persona (CRIS)` field is unique for each author, and is the same for all rows of the same author. We will use this as the ID of the author.
    - If the author is not in the `contributors: Autori/curatori riconosciuti (elenco)` field, we will assign an arbitrary ID, as per before.
- Recognized authors are affiliated with UNITO. They may have a department and role.
    - We can use the `scopus: affiliazioni` field to double check this assumption, again with heuristics since the data is not homogeneous.
    - We can use the same field to find the university external authors are affiliated with, and potentially to aid the heuristics.

Given these considerations, the first step is to produce these two lists. We will save them in json format.
Since we would like to collapse authors, we will have to digest all years at the same time, producing a single digested file.

The preprocessing is carried out in Python, using the `pandas` library. The code is `data_preparsing/from_iris/iris_to_json.py`.

Note that, for usage simplicity, the columns are renamed at the beginning of the script.