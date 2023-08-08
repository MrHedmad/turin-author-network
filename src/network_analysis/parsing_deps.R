library(tidyverse)
library(ggraph)
requireNamespace("igraph")

edgelist <- read_csv("~/Downloads/weighted_network.txt", col_names = c("from", "to", "weight"), col_types = "cc") |> as.matrix()
turin_authors <- read_delim("~/Downloads/authors_turin.tsv", delim = "\t", col_names = c("id", "name", "org"), col_types = "ccc")
turin_authors <- turin_authors |> na.omit()
turin_authors[turin_authors$org == "",] <- NA
turin_authors <- turin_authors |> na.omit()

## Clean the authors
greps <- list(
  "N/A" = "via torino", # non c'e' una via torino a torino
  "Politecnico di Torino" = 'pol[iy]t[ée]ch?(?:nico)?',
  "Dipartimento di Matematica" = 'd[ei]p(arti?mento?)?(.*?)mat',
  "Citta della Salute" = 'cit(?:t)[aá](.*?)salute',
  "Dipartimento di Veterinaria"= 'd[ei]p(arti?mento?)?(.*?)vet',
  "Dipartimento di Neuroscienze"= 'd[ei]p(arti?mento?)?(.*?)neuroscien[cz]e',
  "Dipartimento di Chimica"= 'd[ei]p(arti?mento?)?(.*?)ch[ie]mi',
  "Dipartimento di Scienze Chirurgiche"= 'd[ei]p(arti?mento?)?(.*?)(?:surgery)|(?:chirur)',
  "Dipartimento di Fisica"= 'd[ei]p(arti?mento?)?(.*?)[pf]h?[iy]sic[sa]',
  "Dipartimento di Onocologia"= 'd[ei]p(arti?mento?)?(.*?)oncolog[iy]a?',
  "Dipartimento di Biologia"= 'd[ei]p(arti?mento?)?(.*?)biolog[iy]a?',
  "Molecular Biotechnology Center"= '(?:nizza)|biotech',
  "Dipartimento di Informatica"= '(?:comput)|(?:inf(?:ormatica)?)', # this is prolly to broad but whatever
  "Dipartimento di Psicologia"= 'd[ei]p(arti?mento?)?(.*?)ps[iy]c',
  "Dipartimento di Economia"= 'd[ei]p(arti?mento?)?(.*?)econom[iy]',
  "Other UNITO"= "uni(?:versit)"
)

for (i in seq_along(greps)) {
  val <- names(greps)[i]
  exprs <- greps[[i]]
  
  print(val)
  print(length(unique(turin_authors$org)))
  
  turin_authors[grepl(exprs, str_to_lower(turin_authors$org), perl = TRUE), "org"] <- val
}

turin_authors <- turin_authors |> na.omit()
turin_authors[turin_authors$org == "N/A",] <- NA
turin_authors <- turin_authors |> na.omit()
turin_authors[! turin_authors$org %in% names(greps), "org"] <- "other"

unique(turin_authors$org)

table(turin_authors$org)

turin_authors$name[turin_authors$org == "Dipartimento di Biologia"]
turin_authors$name[turin_authors$org == "Dipartimento di Informatica"]

useful_turin_authors <- turin_authors[! turin_authors$org %in% c("Citta della Salute", "Politecnico di Torino", "other", "Other UNITO"), ]

# We need to make the graph smaller

trimmed_edges <- edgelist[edgelist[,"from"] %in% useful_turin_authors$id | edgelist[,"to"] %in% useful_turin_authors$id, ]

trimmed_edges <- as.data.frame(trimmed_edges)
trimmed_edges$weight <- as.numeric(str_trim(trimmed_edges$weight))
wgraph <- igraph::graph.data.frame(trimmed_edges, directed = FALSE)
wgraph <- igraph::simplify(wgraph)

# we need the degree distribution for plotting later
graph_degree <- igraph::degree(wgraph)

# Add to the graph the information about the affiliation of the authors
# and their name
wgraph <- igraph::set_vertex_attr(
  wgraph,
  "affiliation",
  value = unlist(map(
    igraph::vertex_attr(wgraph, "name"),
    \(x) {
      if (x %in% turin_authors$id) {
        return(turin_authors$org[which(turin_authors$id == x)])
      } else {
        return("other")
      }
    }
  ))
)

wgraph <- igraph::set_vertex_attr(
  wgraph,
  "real_name",
  value = unlist(map(
    igraph::vertex_attr(wgraph, "name"),
    \(x) {
      if (x %in% turin_authors$id && graph_degree[[x]] > 15) {
        return(turin_authors$name[which(turin_authors$id == x)])
      } else {
        return(NA)
      }
    }
  ))
)

# We now have the graph, we can delete everything else
rm(list = c("edgelist", "greps", "trimmed_edges", "exprs", "i", "val", "affils"))


graph_degree_dist <- igraph::degree.distribution(wgraph)

graph_colours <- c(
  "Dipartimento di Biologia" = "#5afc03",
  "Dipartimento di Chimica" = "#ff9100",
  "Dipartimento di Economia" = "#99c9ff",
  "Dipartimento di Fisica" = "#0378ff",
  "Dipartimento di Informatica" = "#ff0378",
  "Dipartimento di Matematica" = "#ff0303",
  "Dipartimento di Neuroscienze" = "#03fff2",
  "Dipartimento di Onocologia" = "#7403ff", 
  "Dipartimento di Psicologia" = "#fc81c3",
  "Dipartimento di Scienze Chirurgiche" = "#454099", 
  "Dipartimento di Veterinaria" = "#adeb7f",
  "Molecular Biotechnology Center" = "#318c00",
  "other" = "#d9d9d9"
)

pdf(file = "/home/hedmad/Desktop/test_clades.pdf", width = 15, height = 15)
ggraph(wgraph, layout = "stress") +
  geom_edge_link(alpha = 0.2, show.legend = FALSE) + 
  geom_node_point(
    aes(size = graph_degree / (max(graph_degree) / 0.75), color = affiliation), alpha = 0.5
  ) +
  geom_node_label(
    aes(label = real_name), repel = TRUE, size = 2,
    min.segment.length = 0, max.overlaps = 250
  ) +
  scale_color_manual(values = graph_colours) +
  theme(legend.position = "bottom")
dev.off()

igraph::assortativity_degree(wgraph)
# This is negative, so high-degree nodes tend to connect to low-degree nodes.
# This might be distorted due to the cropping.

# Under which transformations do graphs continue to keep their properties?
# i.e. assortativity, degree distribution...

# There are disconnected components in the graph
wcomp <- igraph::components(wgraph)
wcomp

# Let's keep only the principal component, the largest
lgraph <- igraph::subgraph(wgraph, names(wcomp$membership[wcomp$membership == 1]))

lgraph_degree <- igraph::degree(lgraph)

pdf(file = "/home/hedmad/Desktop/test.pdf", width = 20, height = 20)
ggraph(lgraph, layout = "stress") +
  geom_edge_link(alpha = 0.2, show.legend = FALSE) + 
  geom_node_point(
    aes(size = lgraph_degree / (max(lgraph_degree) / 0.75), color = affiliation), alpha = 0.5
  ) +
  geom_node_label(
    aes(label = real_name), repel = TRUE, size = 2,
    min.segment.length = 0, max.overlaps = 250
  ) +
  
  theme(legend.position = "bottom")
dev.off()
