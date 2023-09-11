# Collaboration network of the University of Turin

The university of Turin is a public university in Turin, Italy.
We posed the question of whether there are collaboration patterns in the university, if some departments behave differently from others, and if there are fragmented departments.

## Reproducing the analysis
> IMPORTANT: The analysis is still largely incomplete. The makefile will not cover all the analysis steps, and the manuscript is still incomplete.
> The network analysis in R is missing from the makefile. Please run it manually.

You'll need Python, R and [Typst](https://github.com/typst/typst) installed.
The makefile will attempt to install dependencies automatically, but you may need to install some manually, if the installation process fails (looking at you, R).
```bash
# Clone the repository
git clone git@github.com:MrHedmad/turin-author-network.git
cd turin-author-network

# Link the data folder
./link "path_to_data_folder"

# Run the analysis
make .
```

The output manuscript will be in `./paper/manuscript.pdf`.
The analysis does not require particularly powerful hardware.
