
# Compile and run the docker container
all-docker: build-docker run-docker

# Run the docker container, and run chown on the output
run-docker:
    docker run -v ./data/:/app/data \
    --rm \
    turinauthors:bleeding 
    sudo chown ${UID} ./data/*

# Build the docker container
build-docker:
    docker build . -t turinauthors:bleeding

# For debugging: Enter the container interactively
enter-docker: 
    docker run -v ./data/:/app/data \
    --rm -it \
    turinauthors:bleeding \
    bash

# Export data for uploading to Zenodo
export-data:
    ./src/data_preparsing/iris_to_json.py ./data/in/papers/*.csv -v | \
    ./src/anonimize_CRIS.py > \
    ./data/out/unito_author_collab_data.json


