library(tidyverse)
library(ggraph)
requireNamespace("igraph")
requireNamespace("oaqc")

graph_from_edgelist <- function(edgelist, author_list, standardise_weigths = FALSE) {
  # Create the full author name, for labeling later
  authors$full_name <- paste(authors$name, authors$surname)
  authors$full_name <- str_squish(authors$full_name) |> str_to_title()
  
  if (standardise_weigths) {
    edgelist$weight <- scale(edgelist$weight, center = FALSE)
  }
  
  graph <- igraph::graph_from_data_frame(edgelist, directed = FALSE)
  
  # Add vertex information, like author names and department of origin
  graph <- igraph::set_vertex_attr(
    graph,
    "display_name",
    value = unlist(map(
      igraph::vertex_attr(graph, "name"), # This gets the IDs of the nodes
      \(x) {authors$full_name[which(authors$id == x)]}
    ))
  )
  
  graph <- igraph::set_vertex_attr(
    graph,
    "department",
    value = unlist(map(
      igraph::vertex_attr(graph, "name"), # same as before
      \(x) {authors$department[which(authors$id == x)]}
    ))
  )
  
  if (! igraph::is_simple(graph)) {
    warning("Graph is not simple. Will simplify.")
    
    graph <- igraph::simplify(
      # Sum the weights of the parallel edges, ignore other attributes
      graph, list(weight="sum", "ignore")
    )
  }
  
  graph
}


filter_graph <- function(graph, selected_deps, keep_only_major = TRUE) {
  #' Filter the graph to make it more manageable
  #' 
  #' @param graph The graph to filter.
  #' @param selected_deps A list of names = c(new_name, color), whose names
  #'  will be extracted to be used for selecting vertices.
  #' @param keep_only_major Keep only the major component? Default TRUE.
  
  sgraph <- igraph::subgraph(
    graph,
    # Why does this work? No idea.
    igraph::V(graph)[ department %in% names(selected_deps) ]
  )
  
  # Get rid of small components
  if (keep_only_major) {
    comps <- igraph::components(sgraph)
    sgraph <- igraph::subgraph(
      sgraph,
      names(comps$membership[comps$membership == 1])
    )
  }
  
  sgraph
}

find_communities <- function(graph) {
  expected_comms <- length(levels(as.factor(
    igraph::vertex_attr(graph, "department")
  )))
  print(paste0("Finding ", expected_comms, " communities..."))
  #' Add community info to the graph.
  communities <- igraph::cluster_spinglass(
    graph, spins = expected_comms
  )
  
  graph <- igraph::set_vertex_attr(
    graph,
    "community",
    value = unlist(map(
      igraph::vertex_attr(graph, "name"),
      \(x) {communities$membership[which(communities$names == x)]}
    ))
  )
  
  graph
}

plot_graph <- function(
  graph,
  selected_departments,
  layout,
  
  title = NA,
  
  show_legend = TRUE,
  
  include_labels = TRUE,
  label_size_treshold = 15,
  
  include_communities = TRUE
  
) {
  graph_degree <- igraph::degree(graph)
  
  # Relevel the departments
  graph <- igraph::set_vertex_attr(
    graph,
    "department",
    value = unlist(map(
      igraph::vertex_attr(graph, "department"),
      \(x) {
        new_name <- selected_departments[[x]][1]
        return(ifelse(is.na(new_name), x, new_name))
      }
    ))
  )
  
  graph_colors <- map(selected_departments, \(x) {x[2]})
  new_names <- map(selected_departments, \(x) {x[1]})
  names(graph_colors) <- ifelse(
    is.na(new_names),
    names(selected_departments),
    new_names
  )
  
  p <- ggraph(graph, layout = layout)
  
  if (include_communities) {
    p <- p + ggforce::geom_mark_hull(
      aes(x, y, fill = as.factor(community)),
      alpha = 0.1,
      show.legend = FALSE
    )
  }
  
  # I want the layer with the communities to be BELOW the actual network
  # This is why this is done like this.
  p <- p + geom_edge_link(aes(alpha = (weight / 100)), show.legend = FALSE) + 
    geom_node_point(
      aes(
        size = graph_degree / (max(graph_degree) / 0.75),
        color = department
      ), alpha = 0.5,
    ) +
    guides(size = "none") +
    scale_color_manual(values = graph_colors) +
    theme_void() +
    theme(legend.position = ifelse(show_legend, "bottom", "none"))
  
  # But I want the labels on top of everything
  if (include_labels) {
    # We need to get rid of the names that we do not want
    p <- p + geom_node_label(
      aes(filter = graph_degree > label_size_treshold, label = display_name),
      repel = TRUE, size = 2,
      min.segment.length = 0, max.overlaps = 50
    )
  }
  
  if (!is.na(title)) {
    p <- p + ggtitle(title)
  }
  
  p
}

### ---

# Params - before I make it executable
edgelist_path <- "/tmp/test_edgelist.csv"
authors_path <- "/tmp/test_authors.csv"

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
# TODO: Export this to a config file
selected_departments <- list(
  "biotecnologie molecolari e scienze per la salute" = c("biotech. mol.", "darkgreen"),
  "centro interdipartimentale di ricerca per le biotecnologie molecolari - mbc" = c("MBC", "limegreen"), 
  "chimica" = c(NA, "orange"),
  #"dental school centro di eccellenza per la ricerca, la didattica e l'assistenza in campo odontostomatologico" = c("dental school", "purple"), 
  "fisica" = c(NA, "blue"),
  "informatica" = c(NA, "lightblue"),
  "matematica giuseppe peano" = c("matematica", "purple"),
  "neuroscienze rita levi montalcini" = c("neuroscienze", "pink"), 
  "oncologia" = c(NA, "gray"),
  "psicologia" = c(NA, "magenta"),
  "scienza e tecnologia del farmaco" = c("farmacologia", "darkorange4"), 
  #"scienze agrarie, forestali e alimentari" = c("agraria", "darkseagreen"),
  #"scienze chirurgiche" = c("chirurgia", "cyan"), 
  "scienze cliniche e biologiche" = c("clinica", "yellow"),
  #"scienze della sanita' pubblica e pediatriche" = c("sanita' pubblica", "cyan4"), 
  #"scienze della terra" = c(NA, "darkseagreen"),
  "scienze della vita e biologia dei sistemi" = c("DBioS", "red"), 
  #"scienze economico-sociali e matematico-statistiche" = c("economia e statistica", "deepskyblue"),
  "scienze mediche" = c("medicina", "darkturquoise")
  #"scienze veterinarie" = c("veterinaria", "darkolivegreen1")
)

selected_departments_biology <- list(
  "biotecnologie molecolari e scienze per la salute" = c("biotech. mol.", "blue"),
  "centro interdipartimentale di ricerca per le biotecnologie molecolari - mbc" = c("MBC", "limegreen"), 
  "neuroscienze rita levi montalcini" = c("neuroscienze", "pink"), 
  "oncologia" = c(NA, "yellow"),
  "psicologia" = c(NA, "magenta"),
  "scienze agrarie, forestali e alimentari" = c("agraria", "purple4"),
  #"scienze cliniche e biologiche" = c("clinica", "yellow"),
  "scienze della terra" = c(NA, "darkseagreen"),
  "scienze della vita e biologia dei sistemi" = c("DBioS", "red"),
  "scienze veterinarie" = c("veterinaria", "orange")
)

hard_graph <- filter_graph(graph, selected_departments)
hard_graph <- find_communities(hard_graph)

# If 'weights' is NULL uses the weights in the graph
layout <- graphlayouts::layout_with_sparse_stress(
  hard_graph, weights = NULL, pivots = 50
)
plot_graph(
  hard_graph, selected_departments, layout = layout,
  include_labels = TRUE,
  label_size_treshold = 40,
  include_communities = FALSE,
  title = "Sample network - years 2012/13/14"
)

bio_graph <- filter_graph(graph, selected_departments_biology)
bio_graph <- find_communities(bio_graph)

# If 'weights' is NULL uses the weights in the graph
layout <- igraph::layout_with_dh(
  bio_graph
)
plot_graph(
  bio_graph, selected_departments_biology, layout = layout,
  include_labels = TRUE,
  label_size_treshold = 40,
  include_communities = FALSE,
  title = "Sample network - biological area - years 2012/13/14"
)


## --- Community purity
get_community_purity <- function(graph) {
  data <- as.data.frame(cbind(
    community = igraph::vertex_attr(graph, "community"),
    department = igraph::vertex_attr(graph, "department")
  ))
  
  counts <- data |> group_by(community, department) |>
    count()
  
  counts
}

plot_purity <- function(purity, selected_departments) {
  
  # Relevel the departments
  purity$department <- unlist(map(
    purity$department,
    \(x) {
      new_name <- selected_departments[[x]][1]
      return(ifelse(is.na(new_name), x, new_name))
    }
  ))
  graph_colors <- map(selected_departments, \(x) {x[2]})
  new_names <- map(selected_departments, \(x) {x[1]})
  names(graph_colors) <- ifelse(
    is.na(new_names),
    names(selected_departments),
    new_names
  )

  p <- ggplot(data = purity, aes(x = community, y = n, fill = department)) +
    geom_bar(position = "fill", stat = "identity") +
    scale_fill_manual(values = graph_colors)
  p
}

bio_purity <- get_community_purity(bio_graph)
plot_purity(bio_purity, selected_departments_biology)

plot_purity_dots <- function(purity, selected_departments) {
  # Relevel the departments
  purity$department <- unlist(map(
    purity$department,
    \(x) {
      new_name <- selected_departments[[x]][1]
      return(ifelse(is.na(new_name), x, new_name))
    }
  ))
  graph_colors <- map(selected_departments, \(x) {x[2]})
  new_names <- map(selected_departments, \(x) {x[1]})
  names(graph_colors) <- ifelse(
    is.na(new_names),
    names(selected_departments),
    new_names
  )
  
  var_calc <- function(n) {
    n <- scale(n, center = FALSE)
    new <- c()
    for (i in seq_along(n)) {
      new <- c(new, var(n) - var(n[-i]))
    }
    new
  }
  purity |> group_by(department) |> mutate(variance = var_calc(n)) -> purity
  
  p <- ggplot(data = purity, aes(x = n, y = variance)) +
    geom_point(aes(color = department, size = n)) +
    scale_color_manual(values = graph_colors) +
    theme_minimal() +
    theme(legend.position = "bottom")
  
  p
}

plot_purity_dots(bio_purity, selected_departments_biology)
