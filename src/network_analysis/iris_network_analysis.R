#' This is the code for the network analysis of the Turin author network
#' For this to work, you must set the working directory to be in the root
#' of the repository (i.e. ./turin-author-network/). The calls to source()
#' and the data loading are relative to that position.
library(tidyverse)
library(ggraph)
requireNamespace("igraph")
requireNamespace("oaqc")
# TODO: Some deps for igraph (especially the layout functions) might be
# missing.
# NOTE: To install `concaveman`, to plot the communities, use:
# Sys.setenv(DOWNLOAD_STATIC_LIBV8 = 1)
# install.packages("concaveman")
# this only works if you are using linux.
source("./src/network_analysis/iris_network_analysis_functions.R")

### ---

# Params - before I make it executable
edgelist_path <- "./data/edgelist.csv"
authors_path <- "./data/authors.csv"

# Data loading
edgelist <- read_csv(edgelist_path)
authors <- read_csv(authors_path, na = c("Null", "null", "na", "NA", "None", "none"))

graph <- graph_from_edgelist(edgelist, authors)

## Inspect what departments are available:
#igraph::vertex_attr(graph, "department") |> as.factor() |> levels() |> paste(collapse = "\n") |> cat()

# Select what departments should be included, and what color they should have.
# Optionally (NA ignores), select a new name (e.g. abbreviation) for the
# department, to be shown in the legend.
# The structure is list(old_name = c(new_name, color))
# Note some (like "giurisprudenza") are missing. See above for the full list.
# TODO: Export this to a config file (maybe)?

## A list of "hard science" departments, to use a derogatory term.
# I leave some commented if we want to include them later.
selected_departments <- list(
  "biotecnologie molecolari e scienze per la salute" = c("biotech. mol.", "darkgreen"),
  "centro interdipartimentale di ricerca per le biotecnologie molecolari - mbc" = c("MBC", "limegreen"), 
  "chimica" = c(NA, "orange"),
  #"dental school centro di eccellenza per la ricerca, la didattica e l'assistenza in campo odontostomatologico" = c("dental school", "purple"), 
  "fisica" = c(NA, "blue"),
  "informatica" = c(NA, "lightblue"),
  "matematica giuseppe peano" = c("matematica", "purple"),
  "neuroscienze rita levi montalcini" = c("neuroscienze", "pink"), 
  "oncologia" = c(NA, "brown"),
  "psicologia" = c(NA, "magenta"),
  "scienza e tecnologia del farmaco" = c("farmacologia", "darkorange2"), 
  #"scienze agrarie, forestali e alimentari" = c("agraria", "darkseagreen"),
  #"scienze chirurgiche" = c("chirurgia", "cyan"), 
  "scienze cliniche e biologiche" = c("clinica", "yellow"),
  #"scienze della sanita' pubblica e pediatriche" = c("sanita' pubblica", "cyan4"), 
  #"scienze della terra" = c(NA, "darkseagreen"),
  "scienze della vita e biologia dei sistemi" = c("DBioS", "red"), 
  #"scienze economico-sociali e matematico-statistiche" = c("economia e statistica", "deepskyblue"),
  "scienze mediche" = c("medicina", "darkturquoise")
  #"scienze veterinarie" = c("veterinaria", "darkolivegreen1"),
  #"unknown" = c(NA, "darkgray")
)

# Same as above, but limited to the biological/biomedical areas
selected_departments_biology <- list(
  "biotecnologie molecolari e scienze per la salute" = c("biotech. mol.", "blue"),
  "centro interdipartimentale di ricerca per le biotecnologie molecolari - mbc" = c("MBC", "limegreen"), 
  "neuroscienze rita levi montalcini" = c("neuroscienze", "pink"), 
  "oncologia" = c(NA, "yellow"),
  "psicologia" = c(NA, "magenta"),
  "scienze agrarie, forestali e alimentari" = c("agraria", "purple4"),
  "scienze cliniche e biologiche" = c("clinica", "brown"),
  "scienze della terra" = c(NA, "darkseagreen"),
  "scienze della vita e biologia dei sistemi" = c("DBioS", "red"),
  "scienze veterinarie" = c("veterinaria", "orange")
  #"unknown" = c(NA, "darkgray")
)

# Generate the subgraphs, and add information about communities.
hard_graph <- filter_graph(graph, selected_departments)
hard_graph <- find_communities(hard_graph)

bio_graph <- filter_graph(graph, selected_departments_biology)
bio_graph <- find_communities(bio_graph)


## PLOTTING GRAPHS
# If 'weights' is NULL the function uses weights in the graph
hard_layout <- graphlayouts::layout_with_sparse_stress(
  hard_graph, weights = NULL, pivots = 25
)
plot_graph(
  hard_graph, selected_departments, hard_layout,
  include_labels = FALSE,
  label_degree_treshold = 40,
  include_communities = FALSE,
  title = "Sample network"
)

# Using igraph::layout_with_dh() is prettier, but takes a very, very long time
layout <- graphlayouts::layout_with_sparse_stress(
  bio_graph, weights = NULL, pivots = 25
)
plot_graph(
  bio_graph, selected_departments_biology, layout = layout,
  include_labels = TRUE,
  label_degree_treshold = 40,
  include_communities = FALSE,
  title = "Sample network - biological area"
)


# Inspect single departments
inspect_one(
  graph,
  "scienze della vita e biologia dei sistemi",
  "DBios",
  walk = TRUE,
  label_degree_treshold = 0
) 
inspect_one(graph, "psicologia", NA, "blue")
inspect_one(graph, "fisica", NA, "orange", label_degree_treshold = 2)
inspect_one(graph, "oncologia", NA, "purple", label_degree_treshold = 2)
inspect_one(graph, "studi umanistici", NA, "yellow", label_degree_treshold = 2)
inspect_one(
  graph, "scienze mediche", NA, "yellow", label_degree_treshold = 2,
  override_communities = 2
)

## --- Community purity
bio_purity <- get_community_purity(bio_graph)
plot_purity(bio_purity, selected_departments_biology)

plot_purity_dots(bio_purity, selected_departments_biology)

hard_purity <- get_community_purity(hard_graph)
plot_purity(hard_purity, selected_departments)
plot_purity_dots(hard_purity, selected_departments)


## Network Degree
plot_degree_distribution(graph, loglog = FALSE)
plot_degree_distribution(hard_graph, loglog = TRUE)
plot_degree_distribution(bio_graph, loglog = FALSE)
