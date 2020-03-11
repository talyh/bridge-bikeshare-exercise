# Introduction
We're working with a largeish dataset. It's comprised of all the Toronto bike share trips from 2017 and 2018, from [here](https://open.toronto.ca/dataset/bike-share-toronto-ridership-data/). This repo contains the data dump itself, some scripts that load it into a postgres database (using Docker Compose), and a set of exercises around it.

# Getting Started

## Prerequisites
You will need Docker / Docker Compose for this to work

- For MacOS, you can install [Docker Desktop for Mac](https://hub.docker.com/editions/community/docker-ce-desktop-mac) or do `brew cask install docker` if you use [Homebrew](https://brew.sh/)
- For Windows, you can install [Docker Desktop for Windows](https://hub.docker.com/editions/community/docker-ce-desktop-windows/)
- For Linux, you can install via your package manager


## Initializing the Database
The first thing you're going to want to do is iniitalize the database

```bash
./bin/init
```

This takes about **10 minutes** to run, so do it first!


## Accessing the database

We can access the database in one of two ways, we can either use [http://sosedoff.github.io/pgweb/] or access it via a console.

For pgweb try

``` bash
./bin/pgweb
```

Note if that doesn't work you can just run

``` bash
docker-compose up -d
```

and open http://localhost:8081 in your browser!

---

For console try

``` bash
./bin/psql
```

# Tips

1) Take good notes on the queries you're running and what you're seeing!
2) Don't forget to add `LIMIT 10` to your exploratory queries so you don't overload the database. Take it off when you're ready to go!
2) If you want to make a backup, try

``` sql
CREATE TABLE trips_backup AS 
TABLE trips;
```

## Starting Over

If you want to start over at any point you can run the `./bin/init` script at any point (remember that it will take a while).

If you really mess up and want to completely get rid of **everything** and start over, you can

``` bash
docker-compose down
docker-compose rm
docker volume rm toronto-bikeshare-data_db-data
```
