#import "@preview/acrostiche:0.3.0": *

#init-acronyms((
  "IRIS": ("Institutional Research Information System",),
))

#align(center, text(17pt)[
  *Turin Author Collaborations* \
  A Network Analysis Project
])
#grid(
  columns: (1fr),
  align(center)[
    Luca Visentin \
    University of Turin \
    #link("mailto:luca.visentin@unito.it")
  ],
)


#set heading(numbering: "1.")

= Introduction
The university of Turin is a public university in Turin, Italy.
The university produces many research articles each year.
We set out to study the collaboration patterns inside the university.
In particular, we posed the following questions:
- Can we detect tightly-knit groups of researchers (i.e. research groups)?
- Do departments collaborate more within themselves or with other departments?
- Are some departments more fragmented than others? I.e. are they split into many small groups, or are they more cohesive?

= Data Source
We sourced the data by contacting directly the #acr("IRIS") office of the university.
They provided us with a series of Excel files, one for each publication year, containing the list of all the publications of the university.

We define "publication" as category `03 - "ARTICOLO IN RIVISTA"` of the #acr("IRIS") database, meaning any contributions, be them original research or reviews, published in scientific journals.

Source data included all departments of the university, and was provided for the year period of 2012-2023.
Data was extracted on the first of September 2023 (or later) so the data for 2023 is incomplete.
We were also provided with a list of authors, with their department and role (professor, researcher, etc.), taken from the university's HR database, as of the first of July, 2023.

The data is provided in Excel format. Each Excel file contains the publications of a single year.
See @inputformat for a description of the data format, and an explaination of the meaning of the various fields.

= Data cleaning
It is clear that the data requires cleaning. To generate the collaboration network, we ultimately require two lists:
- A list of articles, where each article has information on:
    - The list of IDs of the authors.
    - The year of publication.
    - The publication journal.
- A list of authors, with information on:
    - The ID of the author.
    - The university of the author.
    - The department of the author (if working in UNITO).
    - The role of the author (if working in UNITO).

From these lists a collaboration network can be generated, by representing authors as node and connecting those that appear in the same article with links.
The weight of each link may be the number of articles in which the two authors appear together, or other metrics, as detailed below.

For the list of articles, we can make the following observations:
- The `Handle` field is unique for each article, and is the same for all rows of the same article. We will use this as the ID of the article.
- The `Tutti gli autori/curatori` field is malformed, but we can extract the list of authors from it. This is the only field with ALL authors.
- The `contributors: Autori/curatori riconosciuti (elenco)` field is not malformed, but it is incomplete.
    - For these authors, we have a permanent ID (the `autore: ID persona (CRIS)` field), and we have the department and role (in many cases). We will use this field preferentially to create author profiles.
    - We could assign arbitrary IDs to other authors in the `Tutti gli autori/curatori` field, and attempt to heuristically match then between articles, but we will not do this for now, as it might degrade the quality of the data.

For the list of authors, we can make the following observations:
- The `autore: ID persona (CRIS)` field is unique for each author, and is the same for all rows of the same author. We will use this as the ID of the author.
    - If we were to use heuristics for other authors, we would have to assign them arbitrary IDs, just as before.
- Recognized authors are affiliated with UNITO. They *may* have a department and role.
    - We could use the `scopus: affiliazioni` field to double check this assumption, again with heuristics since the data is not homogeneous.
    - We could use the same field to find the university external authors are affiliated with, and potentially to aid the heuristics.

Given these considerations, the simplest thing to do is to look only at recognized authors, and use their clean data to generate the collaboration network. We might relax this limitation in the future.
For this reason, the list of authors might not be complete.

The preprocessing is carried out in Python, using the `pandas` library. The code is `data_preparsing/from_iris/iris_to_json.py`.
A simple command to conver the excel files to a simpler `.csv` format is:
```bash
# In the same folder as the data
libreoffice --headless --convert-to csv *.xlsx
```
The python script accepts a list of `.csv` files as input, and outputs a single JSON file with author and paper information.
The output is piped to `STDOUT` by default.

The script may be run as follows:
```bash
python iris_to_json.py <path_to_input_dir> <path_to_output_file>
```

Note that, for usage simplicity, the columns are renamed at the beginning of the script to a more manageable format.
We filter the resulting JSON file to remove single author articles, since they are not informative.

= Generating the network
The parsed JSON file may be easily converted into both an edgelist and an author list with author metadata.
The author list is - in essence - the same data as the JSON file but in `.csv` format.
The edgelist is the most common format for network data, and is a list of edges, each with a source and a target.
In out case, it is saved as a `.csv` file, since we also compute a weight statistic for each edge.

The weight statistic is proportional to the number of articles in which the two authors appear together.
It may be calculated in two ways:
- The number of articles in which the two authors appear together.
- The number of articles in which the two authors appear together, weighted by the number of authors in each article.
    - This is a measure of how much the two authors collaborate *relative* to the number of authors in the article.
    - This is useful to avoid biasing the results towards articles with many authors. This sort of bias often occurs in fields where research is carried out by large teams, such as experimental physics.

As a first pass, the weight statistic is calculated using the second method.
This should result in a network that should give less emphasis to large teams, or very large collaborations, and more emphasis on smaller but frequent collaborations.

= Network analysis
The network is analyzed using the `igraph` library in R.
We leverage R for its powerful plotting capabilities, and for an easier time exp=loring the data interactively.

The scripts will still be ultimately packaged and run by the command line.

#align(center)[
    #box(
        fill: yellow,
        radius: 2pt,
        outset: (y: 3pt),
        inset: (x: 3pt, y: 0pt)
    )[*Ongoing work starts here*]
]
#counter(heading).update(0)
// There is currently no clean way to show "Appendix A" since A is treated a s a special char
// See issue https://github.com/typst/typst/issues/1177
#set heading(numbering: "A -", supplement: [Appendix])
= Input data format <inputformat>

Each raw Excel file contains the following columns:
- `Handle`: The unique identifier of the publication.
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