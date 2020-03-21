# Part 1: Missing Station Data

1. Write a query that fills out this table. Try your best to pick the correct station name for each ID. You may have to make some manual choices or editing based on the inconsistencies we've found. Do try to pick the correct name for each station ID based on how popular it is in the trip data.

   ### Steps

   1. Create an index on `from_station_id` and `to_station_id` on `trips` table to help query on those

      ```
      CREATE INDEX idx_from_station ON trips USING btree (from_station_id);
      ```

      ```
      CREATE INDEX idx_to_station ON trips USING btree (to_station_id);
      ```

   2. Delete the exist `stations` table and recreate it with serial ids, so we can rely on auto-increment. (We could try and alter the table, but that seems to be an involved process, and our table being currently empty, it's easier to just recreate it)

   ```
   DROP TABLE stations;
   ```

   ```
   CREATE TABLE stations
   (
      id SERIAL,
      name VARCHAR(100)
   );
   ```

   The effect of this can be perceived by running `SELECT nextval(pg_get_serial_sequence('stations', 'id'));`.
   On the old table, that sequence, though present, wouldn't return a value. Now it does.

   3. Get the first name for stations, assuming that as the correct one where there's more than one, combining the `from` and `to` column results

      ```
      SELECT from_station_id, (ARRAY_AGG(DISTINCT from_station_name))[1]
      FROM trips
      WHERE from_station_id IS NOT NULL
      GROUP BY from_station_id
      UNION
      SELECT from_station_id, (ARRAY_AGG(DISTINCT from_station_name))[1]
      FROM trips
      WHERE from_station_id IS NOT NULL
      GROUP BY from_station_id;
      ```

   4. Insert into the `stations` table the result of our query

      ```
      INSERT INTO stations (
         SELECT from_station_id, (ARRAY_AGG(DISTINCT from_station_name))[1]
         FROM trips
         WHERE from_station_id IS NOT NULL
         GROUP BY from_station_id
         UNION
         SELECT from_station_id, (ARRAY_AGG(DISTINCT from_station_name))[1]
         FROM trips
         WHERE from_station_id IS NOT NULL
         GROUP BY from_station_id
      );
      ```

   5. Adjust the `id` sequence to be the highest `id` from our `INSERT` above

      ```
      SELECT setval(pg_get_serial_sequence('stations', 'id'), (SELECT MAX(id) FROM stations));
      ```

   6. Finally, add entries for records where a name exists, but the id is null, relying on the seqquence to generate an id. This has to be done in 2 steps, so we can exclude the records from the first insertions when we run the second one, avoiding duplicates.

      ```
      INSERT INTO stations (
         SELECT nextval(pg_get_serial_sequence('stations', 'id')), from_station_name
         FROM trips t
         WHERE
            from_station_id IS NULL
         AND
            from_station_name NOT IN (SELECT name from stations)
         GROUP BY from_station_name
      );
      INSERT INTO stations(
         SELECT nextval(pg_get_serial_sequence('stations', 'id')), to_station_name
         FROM trips t
         WHERE
            to_station_id IS NULL
         AND
            to_station_name NOT IN (SELECT name from stations)
         GROUP BY to_station_name
      );
      ```

2) Should we add any indexes to the stations table, why or why not?

   Not right now. We already have an index on `id`, because it's the table's pkey. For our current usage, that should suffice.

3) Fill in the missing data in the `trips` table based on the work you did above

   ### Steps

   1. We _could_ update the names in `trips`, like so:

   ```
   UPDATE trips t
   SET from_station_name = (SELECT name FROM stations s WHERE t.from_station_id = s.id),
      to_station_name = (SELECT name FROM stations s WHERE t.from_station_id = s.id)
   ```

   2. However, it's best to just delete the station names column, so the `stations` table becomes the single source of truth for that

   ```
   ALTER TABLE trips_backup
   DROP COLUMN from_station_name,
   DROP COLUMN to_station_name;
   ```

   3. Before doing that, we have to populate the station ids columns where they're null

   ```
   UPDATE trips t
   SET from_station_id = (SELECT id FROM stations s WHERE t.from_station_name = s.name),
    to_station_id  = (SELECT id FROM stations s WHERE t.to_station_name = s.name)
   WHERE from_station_id IS NULL OR to_station_id IS NULL
   ```

Now all of our `trips` should have stations ids that can be joined on the `stations` table when we need to get more information.

# Part 2: Missing Date Data

1. What's the inconsistency in date formats? You can assume that each quarter's trips are numbered sequentially, starting with the first day of the first month of that quarter.

2. Take a look at Postgres's [date functions](https://www.postgresql.org/docs/12/functions-datetime.html), and fill in the missing date data using proper timestamps. You may have to write several queries to do this.

3. Other than the index in class, would we benefit from any other indexes on this table? Why or why not?

# Part 3: Data-driven insights

1. Build a mini-report that does a breakdown of number of trips by month
2. Build a mini-report that does a breakdown of number trips by time of day of their start and end times
3. What are the most popular stations to bike to in the summer?
4. What are the most popular stations to bike from in the winter?
5. Come up with a question that's interesting to you about this data that hasn't been asked and answer it.
