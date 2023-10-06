# Loop to perform network analysis (src/network_analysis/iris_network_analysis_markdown.Rmd, same as iris_network_analysis.R) 
#on all subsets of data (found in data/networks/) and produce a markdown report for each. 
#Functions used in network analysis are in src/iris_network_analysis_functions.R
#Data is subset based on years ranges 
years = unique(gsub("^.+?_(.+?)\\.csv$", "\\1", list.files("./data/networks/")))

# NOTE: If you are not in Docker, this can be skipped.
setwd("/app/")

for (i in years) {
  cat(paste0("Processing year(s): ", i, "\n"))
  rmarkdown::render(
    input = "./src/network_analysis/iris_network_analysis_markdown.Rmd",  # 1. Search for your base report
    output_format = "html_document",         # 2. Establish the format
    output_file = paste0(i ,"_report.html"), # 3. Define the output file name
    output_dir = "./data/out/",              # 4. Define an output folder/directory
    params = list(
      # path relative to .Rmd file # 5. Integrate your parameters
      edgelist_path = paste0("../../data/networks/edgelist_", i ,".csv"),
      authors_path = paste0("../../data/networks/authors_", i ,".csv"),
      functions_path = "./iris_network_analysis_functions.R",
      figure_output_path = "../../data/out/figures/"
      )
    )
}
