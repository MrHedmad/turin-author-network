
# make a phony env target if you just want to remake the env. 
PHONY += env
env: env/touchfile

# The dot operator is the same as source, but it is the POSIX standard
env/touchfile: requirements.txt
	python3.11 -m venv env
	. env/bin/activate; pip install -Ur requirements.txt
	touch env/touchfile

TO_CLEAN += ./data/networks/all.flag
ALL += ./data/networks/all.flag
./data/networks/all.flag: env/touchfile ./data/years/all_years.flag \
		src/data_preparsing/json_to_network.py \
		src/data_preparsing/filter_json.py
	mkdir -p ${@D}
	
	. env/bin/activate; \
	find ./data/years/ | rg .json | parallel \
	'python src/data_preparsing/filter_json.py --input_file {} |' \
	python src/data_preparsing/json_to_network.py \
		${@D}/edgelist_{minyear}-{maxyear}.csv ${@D}/authors_{minyear}-{maxyear}.csv \
		--weight_strategy paper_size_moderated

TO_CLEAN += ./data/years/all_years.flag
./data/years/all_years.flag: env/touchfile src/data_preparsing/group_files.py \
		data/in/metadata.json src/data_preparsing/iris_to_json.py
	mkdir -p ${@D}
	. env/bin/activate; \
	./src/data_preparsing/group_files.py ./data/in/metadata.json window 3 --sliding | \
		parallel --linebuffer -j 4 "./src/data_preparsing/iris_to_json.py {=uq=} -v > ${@D}/file_{%}.json" \	

	touch $@

PHONY += all
all: $(ALL)

PHONY += clean
clean:
	rm -rf $(TO_CLEAN)
	rm -rf ./data/years
	rm -rf ./data/networks

.PHONY = $(PHONY)

.DEFAULT_GOAL = all

