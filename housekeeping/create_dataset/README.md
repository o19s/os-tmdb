# Generating the TMDB dataset

Periodically we update the TMDB dataset as new movies come out, or new data sources are added.

1. Get the latest TMDB dump using the https://github.com/o19s/tmdb_dump project.

2. Set up a virtual environment:

```
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

3. Create the OpenSearch schema formatted JSON file:

Pass in the TMDB extract file and the name of the resulting OpenSearch JSON file.

```
python3 createOpenSearchTmdbDataset.py tmdb_dump_2020-08-13.json tmdb_os.json
```

4. Zip and store the file in the root directory

```
zip tmdb_es.json.zip tmdb_es.json
cp tmdb_es.json.zip ../../
```

4. Don't forget to check the new zip file in!


https://raw.githubusercontent.com/o19s/tmdb_dump/master/tmdb_dataflows.png


# Understanding Data Structure

You can use `jq` to parse the JSON.   Just unzip a chunk and then do:

> cat tmdb_os_2020-08-12.json | jq .

Or, to look at a specific movie dataset, look it up by id:

> jq '.[] | select(._id=="87381")' tmdb_os_2020-08-12.json
