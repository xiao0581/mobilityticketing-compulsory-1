# MobilityTicketing: Lecture 1

This repository contains the completed Lecture 1 implementation for the MobilityTicketing project.

The implementation focuses on a small PostgreSQL relational model for route maintenance and timetable queries.

It includes:

- operators, routes, stops, route stops, and trips
- primary-key and foreign-key relationships
- repeatable seed data
- three workload queries
- an ER diagram and modelling notes

## Start the database

Requirements:

- Docker Desktop with Compose

Start PostgreSQL:

```bash
docker compose up -d
```

For modelling decisions, ER diagram, functional dependency, and implementation evidence, see:

`docs/lab.md`