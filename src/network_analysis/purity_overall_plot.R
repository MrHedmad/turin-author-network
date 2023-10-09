library(tidyverse)
requireNamespace("ggbump")


purity_files <- unique(list.files(
  "./data/out/figures/",
  pattern = "(.+?)_(hard|biological)_purity\\.csv$",
  recursive = TRUE, include.dirs = FALSE
))

for (i in list.files("./data/out/figures/", recursive = TRUE, include.dirs = FALSE)) {
  cat(i)
  cat("\n")
}

bio_purity <- grep("biological", purity_files, value = TRUE)
hard_purity <- grep("hard", purity_files, value = TRUE)

bio_purity_years <- str_sub(bio_purity, 1, 9)
hard_purity_years <- str_sub(hard_purity, 1, 9)

bio_purity_files <- map(
  file.path("./data/out/figures", bio_purity),
  read_csv
)

hard_purity_files <- map(
  file.path("./data/out/figures", hard_purity),
  read_csv
)

calc_var_purity <- function(x) {
  new <- c()
  for (i in seq_along(x)) {
    new <- c(new, var(x) - var(x[-i]))
  }
  
  if (any(is.na(new))) {
    print(new)
    print(x)
  }
  
  max(new)
}

calc_comp_purity <- function(x) {
  tot = 0
  for (item in x) {
    percentage = item / sum(x) * 100
    value = percentage**2
    tot = sum(tot, value)
  }
  #tot = (tot - 1000) / 9000
  tot
}

fuse_purities <- function(data, years, metric_fun) {
  resulting <- list()
  for (i in seq_along(years)) {
    year <- years[i]
    data[[i]] |> filter(department != "unknown") |>
      group_by(department) |> summarise(
        value = metric_fun(n),
        numerosity = sum(n)
      ) -> purity
    purity$year <- year
    purity$rank <- order(purity$value, decreasing = TRUE)
    purity$start_year <- as.numeric(str_split_i(purity$year, "-", 1))
    resulting[[i]] <- purity
  }
  
  reduce(resulting, rbind)
}

hard_fused_var <- fuse_purities(hard_purity_files, hard_purity_years, calc_var_purity)
bio_fused_var <- fuse_purities(bio_purity_files, hard_purity_years, calc_var_purity)
hard_fused_comp <- fuse_purities(hard_purity_files, hard_purity_years, calc_comp_purity)
bio_fused_comp <- fuse_purities(bio_purity_files, hard_purity_years, calc_comp_purity)

selected_departments <- list(
  "biotecnologie molecolari e scienze per la salute" = c("biotech. mol.", "darkgreen"),
  # NOTE: This department seems like an error - there's just one person in it
  #"centro interdipartimentale di ricerca per le biotecnologie molecolari - mbc" = c("MBC", "limegreen"), 
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

plot_fused_ranks <- function(data, selected_departments, title = "") {
  # Relevel the departments + make graph colors (just like before)
  data <- na.omit(data)
  data$department <- unlist(map(
    data$department,
    \(x) {
      new_name <- selected_departments[[x]][1]
      return(ifelse(is.na(new_name), x, new_name))
    }
  ))
  graph_colors <- unlist(map(selected_departments, \(x) {x[2]}))
  new_names <- map(selected_departments, \(x) {x[1]})
  names(graph_colors) <- ifelse(
    is.na(new_names),
    names(selected_departments),
    new_names
  )

  ggplot(data, aes(x = start_year, y = rank, color = department)) +
    ggbump::geom_bump(linewidth = 0.5) +
    geom_point(size = 6) +
    scale_color_manual(values = graph_colors) +
    scale_x_continuous(
      breaks = data$start_year,
      labels = data$year
    ) +
    ggtitle(title) +
    theme_minimal() +
    xlab("Year period") + ylab("Rank") +
    scale_y_continuous(labels = NULL) +
    theme(legend.position = "bottom")
}

plots <- list()

tee <- function(plot, name) {
  png(file.path("./data/out/figures/", paste0(name, ".png")), width = 10, height = 6, unit = "in", res = 450)
  print(plot)
  dev.off()
  
  plot
}


plot_fused_ranks(hard_fused_var, selected_departments, "Variability - Hard sciences") |>
  tee("Variability - Hard sciences")
plot_fused_ranks(bio_fused_var, selected_departments_biology, "Variability - Biological sciences") |>
  tee("Variability - Biological sciences")
plot_fused_ranks(hard_fused_comp, selected_departments, "Compactdness - Hard sciences") |>
  tee("Compactdness - Hard sciences")
plot_fused_ranks(bio_fused_comp, selected_departments_biology, "Compactdness - Biological sciences") |>
  tee("Compactdness - Biological sciences")

plot_fused_stat <- function(data, selected_departments, title = "", log = FALSE) {
  # Relevel the departments + make graph colors (just like before)
  data <- na.omit(data)
  data$department <- unlist(map(
    data$department,
    \(x) {
      new_name <- selected_departments[[x]][1]
      return(ifelse(is.na(new_name), x, new_name))
    }
  ))
  graph_colors <- unlist(map(selected_departments, \(x) {x[2]}))
  new_names <- map(selected_departments, \(x) {x[1]})
  names(graph_colors) <- ifelse(
    is.na(new_names),
    names(selected_departments),
    new_names
  )
  
  p <- ggplot(data, aes(x = year, y = value / max(value), color = department)) +
    geom_line(aes(group = department)) +
    geom_point(size = 2) +
    scale_color_manual(values = graph_colors) +
    ggtitle(title) +
    theme_minimal() +
    xlab("Year period") + ylab("Value") +
    theme(legend.position = "bottom")
  
  if (log) {
    p <- p + scale_y_log10()
  }
  
  p
}

plot_fused_stat(hard_fused_comp, selected_departments, log = FALSE, title = "Compactedness in time - Hard Sciences") |>
  tee("compact_time_hard")
plot_fused_stat(bio_fused_comp, selected_departments_biology, log = FALSE, title = "Compactedness in time - Biological Sciences") |>
  tee("compact_time_bio")
plot_fused_stat(hard_fused_var, selected_departments, log = TRUE, title = "Variability in time - Hard Sciences") |>
  tee("var_time_hard")
plot_fused_stat(bio_fused_var, selected_departments_biology, log = TRUE, title = "Variability in time - Biological Sciences") |>
  tee("var_time_bio")
