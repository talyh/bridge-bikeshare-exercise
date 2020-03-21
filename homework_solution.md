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

   2. Identify which stations have a 1:1 relationship between id and name

      ```
      SELECT from_station_id, COUNT(DISTINCT from_station_name) as station_name_count
      FROM stations_transform
      GROUP BY from_station_id
      HAVING COUNT(DISTINCT from_station_name) = 1;
      ```

      ```
      SELECT from_station_id, COUNT(DISTINCT from_station_name) as station_name_count
      FROM stations_transform
      GROUP BY from_station_id
      HAVING COUNT(DISTINCT from_station_name) = 1;
      ```

   3. Get the ids and names for the stations that have that 1:1 relationship

      ```
      SELECT DISTINCT from_station_id, from_station_name
      FROM trips t1
      WHERE t1.from_station_id IN (
         SELECT from_station_id
         FROM trips t2
         GROUP BY t2.from_station_id
         HAVING COUNT (DISTINCT t2.from_station_name) = 1
      );
      ```

      ```
      SELECT DISTINCT to_station_id, to_station_name
      FROM trips t1
      WHERE t1.to_station_id IN (
         SELECT to_station_id
         FROM trips t2
         GROUP BY t2.to_station_id
         HAVING COUNT (DISTINCT t2.to_station_name) = 1
      );
      ```

   4. Insert the safe entries found in the `from_station` query into the `stations` table

      ```
      INSERT INTO stations (
         SELECT DISTINCT from_station_id, from_station_name
         FROM trips t1
         WHERE t1.from_station_id IN (
            SELECT DISTINCT from_station_id
            FROM trips t2
            GROUP BY t2.from_station_id
            HAVING COUNT (DISTINCT t2.from_station_name) = 1
         )
      );
      ```

   5. Insert the safe entries found in `to_station` query into the `stations` table, skipping the ones that may have been added on step #4

      ```
      INSERT INTO stations (
         SELECT DISTINCT to_station_id, to_station_name
         FROM trips t1
         WHERE t1.to_station_id IN (
            SELECT DISTINCT to_station_id
            FROM trips t2
            GROUP BY t2.to_station_id
            HAVING COUNT (DISTINCT t2.to_station_name) = 1
            )
         AND t1.to_station_id NOT IN (
            SELECT id FROM stations
         )
      );
      ```

   6. Identify which stations have a n:1 relationship between id and name

      ```
      SELECT from_station_name, COUNT (DISTINCT from_station_id)
      FROM trips
      GROUP BY from_station_name
      HAVING (COUNT DISTINCT from_station_id);
      ```

      ```
      SELECT to_station_name, COUNT (DISTINCT to_station_id)
      FROM trips
      GROUP BY to_station_name
      HAVING COUNT (DISTINCT to_station_id) > 1;
      ```

      These queries yielded no results, so we don't need to take any further action on this path

   7. Identify which stations have a 1:n relationship between id and name

      ```
      SELECT from_station_id, COUNT (DISTINCT from_station_name)
      FROM trips
      GROUP BY from_station_id
      HAVING COUNT (DISTINCT from_station_name) > 1;
      ```

      ```
      SELECT to_station_id, COUNT (DISTINCT to_station_name)
      FROM trips
      GROUP BY to_station_id
      HAVING COUNT (DISTINCT to_station_name) > 1;
      ```

   8. Get the first name where a 1:n relationship exists, and assume that's the correct name for the station

      ```
      SELECT from_station_id, (ARRAY_AGG(DISTINCT from_station_name))[1]
      FROM trips
      WHERE from_station_id IS NOT NULL
      GROUP BY from_station_id
      HAVING COUNT(DISTINCT from_station_name) > 1;
      ```

      ```
      SELECT from_station_id, (ARRAY_AGG(DISTINCT from_station_name))[1]
      FROM trips
      WHERE from_station_id IS NOT NULL
      GROUP BY from_station_id
      HAVING COUNT(DISTINCT from_station_name) > 1;
      ```
