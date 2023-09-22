FROM rocker/verse:4.3

RUN apt update && \
    apt install -y \
        parallel ripgrep python3.11 python3.11-venv && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

RUN Rscript -e 'install.packages(c("igraph", "oaqc", "ggraph"))' && \
    Rscript -e 'Sys.setenv(DOWNLOAD_STATIC_LIBV8 = 1); install.packages("concaveman")'

# Copy the code - we will need to download the data at runtime
COPY . ./app
WORKDIR /app
CMD make

