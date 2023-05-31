OpenSearch Index for the [The Movie Database](https://www.themoviedb.org/).

This repository is part of the _Think Like a Relevancy Engineer_ training provided by [OpenSource Connections](https://opensourceconnections.com/events/training/).

## Steps to get up and running:
- Download this repo
- Install the software (using either Docker or installing manually)
- Index the TMDB movie data
- Confirm OpenSearch has the data
- Install Postman (optional)

# Download this repo

Download the zip from https://github.com/o19s/os-tmdb/archive/master.zip, and you will get the file os-tmdb-master.zip. Unzip this file, resulting in the directory os-tmdb-master.

After you have this download, change into the newly created directory.

# Install OpenSearch w/ Dependencies

Make sure you have at least 4GB of memory available for Docker. See Docker's Preferences >>> Resources-tab, to adjust.

Linux/Windows/Mac:

```
docker-compose up
```

Give it a minute to fully boot up then use a browser to go to http://localhost:9200 and http://localhost:5601 to confirm OpenSearch and OpenSearch Dashboards are running.

# Index TMDB movies

Once OpenSearch and OpenSearch Dashboards are ready go, we need to create our example search index.

Linux/Mac:

```
./index.sh
```

Windows:

```
powershell index.ps1
```

If you don't have admin permissions to run PowerShell scripts, then open up the PowerShell ISE application as an administrator.  Then switch to the downloaded code directory and cut and paste the contents of `index.ps1` into the console to work around this issue.

# Confirm OpenSearch has TMDB movies

Run a [wildcard search](http://localhost:9200/tmdb/_search?q=*) and confirm you get results.

# Postman

[Postman](https://www.postman.com/) helps manage API requests. The examples from the TLRE slides exist here too as a Postman Collection (`os-postman-collection.json`). We like using Postman because it makes tinkering with query parameters nicer.

We will mainly Kibana's DevTools for tinkering, but if you already familiar with Postman you can use that and get similar milage.

If you want to use Postman during the TLRE class:

1. Download [Postman](https://www.postman.com/downloads/) for your OS
2. Open Postman and Import (top-menu >> File) `os-postman-collection.json`
3. Define a global variable (grey eye icon in the upper-right) `os_host` to point to your running OpenSearch instance (default is `localhost:9200`)
4. Tinker with the base URL, Params or JSON Body (optional)
5. Press 'Send' (blue rectangle button right of URL bar) to Search!
