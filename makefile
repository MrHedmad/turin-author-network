
# make a phony env target if you just want to remake the env. 
PHONY += env
env: env/touchfile

# The dot operator is the same as source, but it is the POSIX standard
env/touchfile: requirements.txt
	python -m venv env
	. env/bin/activate; pip install -Ur requirements.txt
	touch env/touchfile

./data/iris_data.json: env/touchfile
	. env/bin/activate; python src/data_preparsing/from_iris/iris_to_json.py \
		./data/in/papers > $@

ALL += ./data/edgelist.csv
./data/edgelist.csv: env/touchfile ./data/iris_data.json
	. env/bin/activate; \
	python src/data_preparsing/filter_json.py --input_file ./data/iris_data.json | \
		python src/data_preparsing/json_to_network.py $@ ./data/authors.csv \
		--weight_strategy paper_size_moderated

PHONY += all
all: $(ALL)

.PHONY = $(PHONY)

.DEFAULT_GOAL = all
