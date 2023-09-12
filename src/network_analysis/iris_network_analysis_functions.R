#' These are the functions for the iris network analysis stuff.

library(tidyverse)
library(ggraph)
requireNamespace("igraph")
requireNamespace("oaqc")

## DATA LOADING FUNCTIONS ----
graph_from_edgelist <- function(edgelist, author_list, standardise_weigths = FALSE) {
  #' Load a graph from the edgelist and author list, setting vertex attributes
  #' accordingly.
  #' 
  #' Authors with no department (i.e. department = NA) will be marked to be
  #' of an "unknown" department. This is to allow for easier subsetting and
  #' plotting later on.
  #' 
  #' @param edgelist A data.frame with two source/sink node columns and a 
  #'   column named "weight" with edge weights.
  #' @param author_list A data.frame with an id column with the node IDs and 
  #'   at least the name, surname, affiliation and department columns to label
  #'   the nodes with.
  #' @param standardise_weights Bool. Should weights be standardized to be
  #'   between 0 and 1?
  #'   
  #' @returns An igraph::graph with edge and vertex attributes.
  
  # Change NAs to be "unknown", so we can subset for them later on.
  author_list$department[is.na(author_list$department)] <- "unknown"

  # Create the full author name, for labeling later
  author_list$full_name <- paste(author_list$name, author_list$surname)
  author_list$full_name <- str_squish(author_list$full_name) |> str_to_title()
  
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
      \(x) {author_list$full_name[which(author_list$id == x)]}
    ))
  )
  
  graph <- igraph::set_vertex_attr(
    graph,
    "department",
    value = unlist(map(
      igraph::vertex_attr(graph, "name"), # same as before
      \(x) {author_list$department[which(author_list$id == x)]}
    ))
  )
  
  if (! igraph::is_simple(graph)) {
    # From the python code, the graph should be simple.
    # But it turns out it's not. Why?
    # TODO: Find out why.
    warning("Graph is not simple. Will simplify.")
    
    graph <- igraph::simplify(
      # Sum the weights of the parallel edges, ignore other attributes
      # This works ehhh if the weights are standardized, but alas.
      graph, list(weight="sum", "ignore")
    )
  }
  
  graph
}


filter_graph <- function(graph, selected_deps, keep_only_major = TRUE) {
  #' Filter the graph to make it more manageable.
  #' 
  #' @param graph The graph to filter.
  #' @param selected_deps A list of names = c(new_name, color), whose names
  #'  will be extracted to be used for selecting vertices. Colors are actually
  #'  optional but included so we can reuse the same input for graphing later.
  #' @param keep_only_major Keep only the major component? Default TRUE.
  #' 
  #' @returns An igraph::graph properly subsetted.
  
  sgraph <- igraph::subgraph(
    graph,
    # Why does this work? No idea.
    igraph::V(graph)[ department %in% names(selected_deps)]
  )
  
  # Get rid of small components
  if (keep_only_major) {
    # This finds components. The first one is the major one.
    comps <- igraph::components(sgraph)
    largest <- which(comps$csize == max(comps$csize))
    sgraph <- igraph::subgraph(
      sgraph,
      names(comps$membership[comps$membership == largest])
    )
  }
  
  sgraph
}

find_communities <- function(graph, number_override = NA, walk = FALSE) {
  #' Find communities in a graph.
  #' 
  #' We use the igraph::cluster_spinglass function, and find a number of 
  #' communities equal to the number of departments in the graph. This is to
  #' give a chance for each department to cluster together in one community.
  #' 
  #' @param graph The graph to find communities on. Made by graph_from_edgelist.
  #' 
  #' @returns A igraph::graph with community annotations as vertex attributes.

  expected_comms <- if (is.na(number_override)) {
    length(levels(as.factor(
    igraph::vertex_attr(graph, "department")
  )))
  } else {
    number_override
  }

  if (expected_comms == 1) {
    # If there is just one department, it makes no sense to find one community.
    expected_comms <- 2
  }
  print(paste0("Finding ", expected_comms, " communities..."))
  communities <-  if (! walk) {
    igraph::cluster_spinglass(
      graph, spins = expected_comms
    )
  } else {
    membership <- igraph::cluster_walktrap(
      graph, weights = NULL, steps = 8
    ) |> igraph::cut_at(no = expected_comms)
    
    data.frame(
      names = igraph::vertex_attr(graph, "name"),
      membership = membership
    )
  }
  
  
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

get_community_purity <- function(graph) {
  #' Calculate community-wise purity values, i.e. how many authors of a
  #' certain department fall in a certain community.
  #'
  #' @param graph An igraph::graph (annotated with community information).
  #' 
  #' @returns A data.frame with columns 'community' (1, 2, 3, ...), 'department'
  #'   ("biology", ...), and 'n' (with the counts).
  data <- as.data.frame(cbind(
    community = igraph::vertex_attr(graph, "community"),
    department = igraph::vertex_attr(graph, "department")
  ))
  
  counts <- data |> group_by(community, department) |>
    count()
  
  counts
}


### PLOTTING ---
plot_graph <- function(
    graph,
    selected_departments,
    layout,
    
    title = NA,
    
    show_legend = TRUE,
    
    include_labels = TRUE,
    label_degree_treshold = 15,
    
    include_communities = TRUE
    
) {
  #' Plot an (annotated) igraph::graph.
  #' 
  #' Graph will be colored based on the 'department' attribute.
  #' 
  #' @param graph The graph object to plot.
  #' @param selected_departments A list of names = c(new_name, color), whose names
  #'  will be extracted to be used for selecting vertices.
  #' @param layout A pre-computed igraph layout to use for this plot.
  #' @param title The title of the graph.
  #' @param show_legend Should the color code legend be included?
  #' @param include_labels Should name labels be included?
  #' @param label_degree_treshold If labels are included, annotate nodes with a
  #'   degree larger than this value. To avoid overcrowding the plots.
  #' @param incude_communities Include community annotations? These are plotted
  #'   with the ggforce::geom_mark_hull function, which draws smooth areas
  #'   around points.
  #'   This might need external dependencies to run, like the bulky V8 engine.
  #'   It makes a mess anyway. Keep this off.
  #'
  #' @returns A ggplot plot object.
  
  # Relevel the departments according to the new names (if any)
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
  
  # Generate a named color vector suitable for geom_color_manual()
  graph_colors <- map(selected_departments, \(x) {x[2]})
  new_names <- map(selected_departments, \(x) {x[1]})
  names(graph_colors) <- ifelse(
    is.na(new_names),
    names(selected_departments),
    new_names
  )
  
  # We need this for later - labeling and point size
  graph_degree <- igraph::degree(graph)
  
  # Make the graph
  p <- ggraph(graph, layout = layout)
  # I want the layer with the communities to be BELOW the actual network
  # This is why we must add it (if requested) before anything else.
  if (include_communities) {
    p <- p + ggforce::geom_mark_hull(
      aes(x, y, fill = as.factor(community)),
      alpha = 0.1,
      show.legend = FALSE
    )
  }
  p <- p + geom_edge_link(aes(alpha = (weight / 100)), show.legend = FALSE) + 
    geom_node_point(
      aes(
        size = graph_degree / (max(graph_degree) / 0.75),
        color = department
      ), alpha = 0.5,
    ) +
    guides(size = "none") + # Remove the legend for point size
    scale_color_manual(values = graph_colors) +
    theme_void() +
    theme(legend.position = ifelse(show_legend, "bottom", "none"))
  
  # But I want the labels on top of everything else, so I add them last.
  if (include_labels) {
    # We need to get rid of the names that we do not want
    p <- p + geom_node_label(
      aes(filter = graph_degree > label_degree_treshold, label = display_name),
      repel = TRUE, size = 2,
      min.segment.length = 0,
      max.overlaps = 50
    )
  }
  
  if (!is.na(title)) {
    p <- p + ggtitle(title)
  }
  
  p
}


plot_purity <- function(
    purity, selected_departments,
    plot_percentage = TRUE,
    title = NA
  ) {
  #' Plot the result of get_community_purity() as a barchart, where each
  #' bar is a community and the colors are the departments.
  #' 
  #' Adds the size of the communities at the bottom if the percentage bar chart
  #' is generated.
  #' 
  #' @param purity A purity dataframe made by get_community_purity()
  #' @param selected_departments A list of names = c(new_name, color), used
  #'   for the color codes.
  #' @param plot_percentage Should the bars be standardized to height = 1? I.e.
  #'   plot % of total community composition instead of absolute values.
  #'   
  #' @returns A ggplot plot object.
  
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
  
  sums <- purity |> group_by(community) |> summarize(total = sum(n))
  
  p <- ggplot(data = purity, aes(x = community, y = n, fill = department)) +
    geom_bar(position = ifelse(plot_percentage, "fill", "stack"), stat = "identity") +
    scale_fill_manual(values = graph_colors) +
    ylab("Number of nodes in community") +
    xlab("Community Number") +
    theme_minimal() +
    labs(fill = "Department")
  
  if (plot_percentage) {
    p <- p + scale_y_continuous(labels = scales::percent) +
      ylab("Percentage of community in department") +
      geom_text(
        data = sums,
        aes(label = total, x = community, y = 0),
        inherit.aes = FALSE,
        vjust = 1.8
      )
  }
  
  if (! is.na(title)) {
    p <- p + ggtitle(title)
  }
  
  p
}


plot_purity_dots <- function(purity, selected_departments) {
  #' EXPERIMENTAL --
  #' Plot the purity dots
  #' 
  #' @param purity A purity dataframe made by get_community_purity()
  #' @param selected_departments A list of names = c(new_name, color), used
  #'   for the color codes.
  #'  
  #' @returns A ggplot plot object

  # Relevel the departments + make graph colors (just like before)
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
  
  # TODO: This is the focal point - how to calculate the "groupdness" of the
  # departments?
  # Here I do a weird variance thing, but it seems that just var() works about
  # as well to separate the dots.
  # However - I want just the large numbers to weight on the stat, not the small
  # ones (like calculating variance does). This does not do that.
  var_calc <- function(n) {
    new <- c()
    for (i in seq_along(n)) {
      new <- c(new, var(n) - var(n[-i]))
    }
    
    max(new)
  }
  
  purity |> filter(department != "unknown") |>
    group_by(department) |> summarise(
      variance = var_calc(n),
      numerosity = sum(n)
    ) -> purity
  
  p <- ggplot(data = purity, aes(x = numerosity, y = variance)) +
    geom_point(aes(color = department, size = 2)) +
    scale_color_manual(values = graph_colors) +
    theme_minimal() +
    theme(legend.position = "bottom")
  
  p
}


plot_degree_distribution <- function(
    graph,
    
    loglog = TRUE,
    
    title = NA,
    
    add_smooth = TRUE,
    add_abline = FALSE
) {
  graph_degree <- igraph::degree_distribution(graph)[-1]
  graph_degree <- as.data.frame(cbind(
    graph_degree,
    seq(length.out = length(graph_degree)))
  )
  
  graph_degree |> filter(
    graph_degree > 0 & V2 > 0
  ) -> graph_degree
  
  graph_degree <- log10(graph_degree) 
  
  power_fit <- lm(graph_degree ~ V2, graph_degree)
  print(summary(power_fit))
  
  p <- ggplot(data = graph_degree, aes(x = V2, y = graph_degree)) +
    geom_point() +
    theme_minimal() +
    xlab("Degree - (k)") + ylab("Probabily of k - p(k)")
    
  if (add_abline) {
    p <- p + geom_abline(intercept = log10(0.1), slope = -2.5)
  }
  
  if (add_smooth) {
    p <- p + geom_smooth(method = "lm", se = FALSE, formula = y ~ x)
  }
  
  if (loglog) {
    # Using a pseudo-log as there are zeroes. Using a tiny sigma, so the un-log 
    # is very close to 0
    p <- p + scale_y_continuous(trans = scales::pseudo_log_trans(base = 10, sigma = 1e-4)) +
      scale_x_log10()
  }
  
  if (! is.na(title)) {
    p <- p + ggtitle(title)
  }
  
  p
  
}


inspect_one <- function(
  graph,
  department_name,
  short_name = NA,
  color = "red",
  label_degree_treshold = 5,
  walk = FALSE,
  override_communities = NA
) {
  selected_departments_just_one <- list(
    c(short_name, color)
  )
  names(selected_departments_just_one) <- department_name
  one_graph <- filter_graph(graph, selected_departments_just_one)
  one_graph <- find_communities(
    one_graph, 
    ifelse(
      is.na(override_communities),
      round(sqrt(length(igraph::V(one_graph)))),
      override_communities
    ),
    walk = walk
  )
  
  print("Computing layout...")
  
  # If 'weights' is NULL uses the weights in the graph
  layout_one <- if (length(igraph::V(one_graph)) > 500) {
    graphlayouts::layout_with_sparse_stress(
      one_graph, weights = NULL, pivots = 25
    )
  } else {
    graphlayouts::layout_with_stress(one_graph)
  }
  
  plot_graph(
    one_graph, selected_departments_just_one, layout = layout_one,
    include_labels = TRUE,
    label_degree_treshold = label_degree_treshold,
    include_communities = TRUE,
    title = paste0("One network - ", short_name)
  )
}
