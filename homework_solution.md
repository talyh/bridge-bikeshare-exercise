# Part 1: Missing Station Data

1. _**Write a query that fills out this table. Try your best to pick the correct station name for each ID. You may have to make some manual choices or editing based on the inconsistencies we've found. Do try to pick the correct name for each station ID based on how popular it is in the trip data.**_

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
         FROM trips
         WHERE
            from_station_id IS NULL
         AND
            from_station_name NOT IN (SELECT name from stations)
         GROUP BY from_station_name
      );
      INSERT INTO stations(
         SELECT nextval(pg_get_serial_sequence('stations', 'id')), to_station_name
         FROM trips
         WHERE
            to_station_id IS NULL
         AND
            to_station_name NOT IN (SELECT name from stations)
         GROUP BY to_station_name
      );
      ```

2. _**Should we add any indexes to the stations table, why or why not?**_

   Not right now. We already have an index on `id`, because it's the table's pkey. For our current usage, that should suffice.

3. _**Fill in the missing data in the `trips` table based on the work you did above**_

   ### Steps

   1. We _could_ update the names in `trips`, like so:

      ```
      UPDATE trips t
      SET
         from_station_name = (SELECT name FROM stations s WHERE t.from_station_id = s.id),
         to_station_name = (SELECT name FROM stations s WHERE t.from_station_id = s.id)
      ```

   2. However, it's best to just delete the station names column, so the `stations` table becomes the single source of truth for that (but we won't do that just yet!!)

      ```
      ALTER TABLE trips_backup
      DROP COLUMN from_station_name,
      DROP COLUMN to_station_name;
      ```

   3. Before dropping the columns, we have to populate the station ids columns where they're null

      ```
      UPDATE trips t
      SET from_station_id = (SELECT id FROM stations s WHERE t.from_station_name = s.name),
      to_station_id  = (SELECT id FROM stations s WHERE t.to_station_name = s.name)
      WHERE from_station_id IS NULL OR to_station_id IS NULL
      ```

Now all of our `trips` should have stations ids that can be joined on the `stations` table when we need to get more information.

# Part 2: Missing Date Data

1.  _**What's the inconsistency in date formats? You can assume that each quarter's trips are numbered sequentially, starting with the first day of the first month of that quarter.**_

    There are many. We can examine them by running (this uses the fairly safe assumption of consistency within each of the original csv, so looking at the first record for a given file provides insight into the whole file, and looking into the start date format gives insight into the end date format).

    ```
    SELECT original_filename, (ARRAY_AGG(DISTINCT start_time_str))[1]
    FROM trips
    GROUP BY original_filename;
    ```

    It gets us the result

    ```
    original_filename             |     array_agg
    ------------------------------------------+-------------------
    Bikeshare Ridership (2017 Q1).csv        | 10/1/2017 0:03
    Bikeshare Ridership (2017 Q2).csv        | 10/4/2017 0:00
    Bikeshare Ridership (2017 Q3).csv        | 7/10/2017 0:00
    Bikeshare Ridership (2017 Q4).csv        | 10/01/17 00:00:01
    Bike Share Toronto Ridership_Q1 2018.csv | 1/10/2018 0:01
    Bike Share Toronto Ridership_Q2 2018.csv | 4/10/2018 0:01
    Bike Share Toronto Ridership_Q3 2018.csv | 7/10/2018 0:00
    Bike Share Toronto Ridership_Q4 2018.csv | 10/10/2018 0:01
    ```

    We can see there that:

    - Throughout 2017 there's no consistency in using `dd/mm` and `mm/dd`. The first 2 quarters use `dd/m`, while the last 2 use `m/dd`.
    - Further, throughout 2017 there's no consistency in using `yy` and `yyyy`. The first 3 quarters use the full year, while the last one uses short year.
    - Time format is also inconsistent throughout 2017, with the first 3 quarters using `h:mm`, while the last one uses `hh:mm:ss`
    - 2018 was a beautiful year for date formating in the bike share organization

2.  _**Take a look at Postgres's [date functions](https://www.postgresql.org/docs/12/functions-datetime.html), and fill in the missing date data using proper timestamps. You may have to write several queries to do this.**_

    Our final goal is to get all dates to be in the format used throughout 2018 files, which is `mm/dd/yyyy h:mm`.

    Because each quarter may have a different format, and because there's no consistency in the original_filenames, we'll run separate queries for each quarter, using `to_timestamp` with the format we saw for each file.

    ## Steps

    1. Check if there are cases where start time is present without end time or vice-versa. That'll determine whether we can combine updates for both columns or need to run them separately.

       ```
       SELECT COUNT(*)
       FROM trips
       WHERE
          (start_time_str IS NULL AND end_time_str IS NOT NULL)
       OR
          (start_time_str IS NOT NULL AND end_time_str IS NULL);
       ```

       The result is `0`, so we can rely on checking for nulls on either column and trust that it accounts for both.

    2. Update `2017 Q1` and `2017 Q2` records, since they share the same format

       ```
       UPDATE trips
       SET
          start_time = (SELECT TO_TIMESTAMP(start_time_str, 'DD/MM/YYYY HH24:MI')),
          end_time = (SELECT TO_TIMESTAMP(end_time_str, 'DD/MM/YYYY HH24:MI'))
       WHERE original_filename SIMILAR TO '%(2017 Q1|2017 Q2)%'
       AND start_time_str IS NOT NULL;
       ```

    3. Update `2017 Q3` records

       ```
       UPDATE trips
       SET
          start_time = (SELECT TO_TIMESTAMP(start_time_str, 'MM/DD/YYYY HH24:MI')),
          end_time = (SELECT TO_TIMESTAMP(end_time_str, 'MM/DD/YYYY HH24:MI'))
       WHERE original_filename LIKE '%2017 Q3%'
       AND start_time_str IS NOT NULL;
       ```

    4. Update `2017 Q4` records

       ```
       UPDATE trips
       SET
          start_time = (SELECT TO_TIMESTAMP(start_time_str, 'MM/DD/YY HH24:MI')),
          end_time = (SELECT TO_TIMESTAMP(end_time_str, 'MM/DD/YY HH24:MI'))
       WHERE original_filename LIKE '%2017 Q4%'
       AND start_time_str IS NOT NULL
       AND id <> 2302635;
       ```

       (While dealing with this, we found that record `2302635` has `end_time_str` of `NULLNULL`, so we'll treat it separately)

       ```
       UPDATE trips
       SET
          start_time = (SELECT TO_TIMESTAMP(start_time_str, 'MM/DD/YY HH24:MI')),
          end_time_str = NULL
       WHERE id = 2302635;
       ```

    5. Update `2018` records
       ```
       UPDATE trips
       SET
          start_time = (SELECT TO_TIMESTAMP(start_time_str, 'MM/DD/YYYY HH24:MI')),
          end_time = (SELECT TO_TIMESTAMP(end_time_str, 'MM/DD/YYYY HH24:MI'))
       WHERE original_filename LIKE '%2018%'
       AND start_time_str IS NOT NULL;
       ```

3.  _**Other than the index in class, would we benefit from any other indexes on this table? Why or why not?**_

Yes. An index on `original_filename` goes a long way here.
It can be perceived by the observing the different `cost` before and after the index:

```

postgres=# EXPLAIN SELECT original_filename, (ARRAY_AGG(DISTINCT start_time_str))[1]
FROM trips
GROUP BY original_filename;
QUERY PLAN

---

GroupAggregate (cost=719052.22..744667.25 rows=8 width=69)
Group Key: original_filename
-> Sort (cost=719052.22..727590.53 rows=3415324 width=52)
Sort Key: original_filename
-> Seq Scan on trips (cost=0.00..114957.24 rows=3415324 width=52)
JIT:
Functions: 7
Options: Inlining true, Optimization true, Expressions true, Deforming true
(8 rows)

```

```

postgres=# CREATE INDEX idx_original_filename ON trips USING btree (original_filename);
CREATE INDEX

```

```

postgres=# EXPLAIN SELECT original_filename, (ARRAY_AGG(DISTINCT start_time_str))[1]
FROM trips
GROUP BY original_filename;
QUERY PLAN

---

GroupAggregate (cost=0.56..343851.30 rows=8 width=69)
Group Key: original_filename
-> Index Scan using idx_original_filename on trips (cost=0.56..326774.58 rows=3415324 width=52)
JIT:
Functions: 5
Options: Inlining false, Optimization false, Expressions true, Deforming true
(6 rows)

```

# Part 3: Data-driven insights

1. _**Build a mini-report that does a breakdown of number of trips by month**_

   ```
   SELECT
      CASE  EXTRACT (MONTH FROM start_time)
         WHEN 1 THEN '01 - JAN'
         WHEN 2 THEN '02 - FEB'
         WHEN 3 THEN '03 - MAR'
         WHEN 4 THEN '04 - APR'
         WHEN 5 THEN '05 - MAY'
         WHEN 6 THEN '06 - JUN'
         WHEN 7 THEN '07 - JUL'
         WHEN 8 THEN '08 - AUG'
         WHEN 9 THEN '09 - SEP'
         WHEN 10 THEN '10 - OCT'
         WHEN 11 THEN '11 - NOV'
         WHEN 12 THEN '12 - DEC'
      END
      AS Month,
      COUNT(id) as Trips
   FROM trips
   GROUP BY Month
   ORDER BY 1;
   ```

   This yields:

   ```
   month   | trips
   ----------+--------
   01 - JAN | 748661
   02 - FEB |  91357
   03 - MAR | 134152
   04 - APR | 173809
   05 - MAY | 317475
   06 - JUN | 400439
   07 - JUL | 286316
   08 - AUG | 281219
   09 - SEP | 255001
   10 - OCT | 361455
   11 - NOV | 223000
   12 - DEC | 142440
   ```

2. _**Build a mini-report that does a breakdown of number trips by time of day of their start and end times**_

   ```
   SELECT EXTRACT (HOUR FROM start_time) as Hour, COUNT(id) Trips
   FROM trips
   GROUP BY Hour
   ORDER BY 1;
   ```

   This yields:

   ```
   hour | trips
   ------+--------
      0 |  51963
      1 |  34881
      2 |  25890
      3 |  14971
      4 |  10050
      5 |  14605
      6 |  35964
      7 | 102293
      8 | 262611
      9 | 182866
      10 | 116588
      11 | 143002
      12 | 195771
      13 | 196422
      14 | 178743
      15 | 196403
      16 | 270860
      17 | 362711
      18 | 279013
      19 | 207960
      20 | 173010
      21 | 155357
      22 | 119962
      23 |  83428
   ```

3. _**What are the most popular stations to bike to in the summer?**_

   ```
   SELECT s.name AS Station, COUNT(t.id) AS Trips
   FROM stations s JOIN trips t
      ON s.id = t.from_station_id
   WHERE EXTRACT (MONTH FROM start_time) BETWEEN 7 AND 9
   GROUP BY Station
   ORDER BY Trips DESC
   LIMIT 10;
   ```

   This yields:

   ```

                     station                    | trips
   -----------------------------------------------+-------
   York St / Queens Quay W                       | 12130
   Bay St / Queens Quay W (Ferry Terminal)       | 11447
   Bathurst St/Queens Quay(Billy Bishop Airport) |  8837
   Lakeshore Blvd W / Ontario Dr                 |  8105
   Front St W / Blue Jays Way                    |  7191
   Queens Quay W / Lower Simcoe St               |  7041
   Dockside Dr / Queens Quay E (Sugar Beach)     |  7041
   Bay St / Wellesley St W                       |  7012
   Union Station                                 |  7001
   Queen St W / Portland St                      |  6955
   ```

4. _**What are the most popular stations to bike from in the winter?**_

   ```
   SELECT s.name AS Station, COUNT(t.id) AS Trips
   FROM stations s JOIN trips t
      ON s.id = t.from_station_id
   WHERE EXTRACT (MONTH FROM start_time) IN (12, 1, 2)
   GROUP BY Station
   ORDER BY Trips DESC
   LIMIT 10;
   ```

   This yields:

   ```
                  station                 | trips
   -----------------------------------------+-------
   Union Station                           | 13764
   York St / Queens Quay W                 | 12530
   Dundas St W / Yonge St                  | 12379
   Bay St / Wellesley St W                 | 11381
   Bay St / College St (East Side)         | 11007
   Queen St W / Portland St                | 10617
   King St W / Spadina Ave                 | 10510
   Front St W / Blue Jays Way              | 10403
   Bay St / Queens Quay W (Ferry Terminal) | 10142
   Ontario Place Blvd / Remembrance Dr     |  9751
   ```

5. _**Come up with a question that's interesting to you about this data that hasn't been asked and answer it.**_

   We'll take a look at popular stations to start a journey from, along Yonge St.

   ```
   SELECT s.name AS Station, COUNT(t.id) AS Trips
   FROM stations s JOIN trips_backup t
      ON s.id = t.from_station_id
   WHERE s.name LIKE '%Yonge%'
   GROUP BY Station
   ORDER BY Trips DESC
   LIMIT 15;
   ```

   This yields:

   ```
                     station                   | trips
   ---------------------------------------------+-------
   Dundas St W / Yonge St                      | 36607
   Queens Quay / Yonge St                      | 23030
   Edward St / Yonge St                        | 18280
   Wellesley St E / Yonge St (Green P)         | 18076
   Front St W / Yonge St (Hockey Hall of Fame) | 17610
   Yonge St / Wood St                          | 15248
   Yonge St / Harbour St                       | 14003
   Gould St / Yonge St (Ryerson University)    | 13980
   Toronto Eaton Centre (Yonge St)             | 13263
   Yonge St / Yorkville Ave                    | 12595
   Yonge St / Dundonald St - SMART             |  6715
   Yonge St / Alexander St - SMART             |  6584
   Marlborough Ave / Yonge St                  |  3872
   Yonge St / Aylmer Ave                       |  3739
   Yonge St / Bloor St                         |  1230
   ```

   It's no surpise that the highest concentration is closer downtown (as can be seen on the query results plotted at https://drive.google.com/open?id=1du9Tz8PVe0Xl2FEpIi2ehkaDre4NV1ML&usp=sharing).

   However, it's worthy of attention that there isn't more activity between Union and Queen St.
   It's also interesting to see that Bloor/Yonge, being such a significant crossing and combining the 2 TTC lines, sits at 15th place.
