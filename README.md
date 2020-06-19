# Test MATLAB&reg; code against databases running in Docker&reg;

## Introduction

The code in this project allows you to test MATLAB code that requires a database by using a local instance of the database server running in Docker.

The following databases are currently supported:
* Microsoft SQL Server® 2017 & 2019 (latest published)
* PostgreSQL® (latest published)
* SQLite (does not require Docker).

By creating tests that inherit from the relevant test class, the Docker container will automatically be spun up and a connection created. The test class also provides methods to create database checkpoints, restore the database to that checkpoint, delete the checkpoint, and import backup files (e.g. from your production database).

## Requirements

1.  [MATLAB](https://www.mathworks.com/products/matlab.html)
2.  [Database Toolbox](https://www.mathworks.com/help/database/)&trade;
3.  [Docker Desktop](https://www.docker.com/products/docker-desktop)
4.  Database drivers.  

## Installation & Documentation

Install by double-clicking the `mltbx` file. Documentation is provided in the [getting started guide](code/doc/gettingStartedGuide.mlx).

## Licence

Please see [LICENCE.txt](LICENCE.txt).

## Enhancement requests

Please submit issues to GitHub.