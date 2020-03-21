## Task

1. Write a query that fills out this table. Try your best to pick the correct station name for each ID. You may have to make some manual choices or editing based on the inconsistencies we've found. Do try to pick the correct name for each station ID based on how popular it is in the trip data.

   ### Steps

   1. Create an index on `from_station_id` and `to_station_id` on `trips` table to help query on those

      ```
      CREATE INDEX idx_from_station ON trips USING btree (from_station_id);
      ```

      ```
      CREATE INDEX idx_to_station ON trips USING btree (to_station_id);
      ```

   2. Get the first name for stations, assuming that as the correct one where there's more than one, combining the `from` and `to` column results

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

   3. Insert into the `stations` table the result of our query

      ```
      INSERT INTO stations ( SELECT from_station_id, (ARRAY_AGG(DISTINCT from_station_name))[1]
      FROM trips
      WHERE from_station_id IS NOT NULL
      GROUP BY from_station_id
      UNION
      SELECT from_station_id, (ARRAY_AGG(DISTINCT from_station_name))[1]
      FROM trips
      WHERE from_station_id IS NOT NULL
      GROUP BY from_station_id);
      ```
