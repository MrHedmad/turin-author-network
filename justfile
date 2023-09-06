
# Run iris preparsing
prep-iris OUT:
    python src/data_preparsing/from_iris/iris_to_json.py \
        /home/hedmad/Files/data/CollabNetwork/papers -v

# Test iris preprocessing with small files
test-iris:
    python src/data_preparsing/from_iris/iris_to_json.py \
        /home/hedmad/Files/data/CollabNetwork/test_papers -v