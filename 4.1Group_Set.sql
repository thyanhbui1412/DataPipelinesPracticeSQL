/*# Week 4 Applying Analytical Patterns
The homework this week will be using the `players`, `players_scd`, and `player_seasons` tables from week 1

- A query that does state change tracking for `players`
  - A player entering the league should be `New`
  - A player leaving the league should be `Retired`
  - A player staying in the league should be `Continued Playing`
  - A player that comes out of retirement should be `Returned from Retirement`
  - A player that stays out of the league should be `Stayed Retired`*/

--Create enum type to ensure quality
CREATE TYPE season_state AS ENUM ('New', 'Retired','Continued Playing','Returned from Retirement','Stayed Retired');
DROP TABLE IF EXISTS player_state_change;
CREATE TABLE IF NOT EXISTS player_state_change
(
    player_name         TEXT,
    first_active_season INTEGER,
    last_active_season  INTEGER,
    season_state        season_state,
    current_season      INTEGER,
    PRIMARY KEY (player_name, current_season)

);
-- I can create a state change table with table player_season or table player. Let's solve with the former one.
-- Solution 1: with table player_season
DO
$$
    BEGIN
        --the starting years is always empty. implement the loop to get cumulative table for all years
        FOR i IN ((SELECT MIN(season) FROM player_seasons) - 1)..(SELECT MAX(season) FROM player_seasons)
            LOOP
                WITH yesterday AS (SELECT player_name,
                                          first_active_season,
                                          last_active_season,
                                          current_season
                                   FROM player_state_change
                                   WHERE current_season = i),
                     today AS (SELECT player_name,
                                      season
                               FROM player_seasons
                               WHERE season = i + 1
                                 AND player_name IS NOT NULL),
                     combined AS (SELECT COALESCE(y.player_name, t.player_name)      AS player_name,
                                         COALESCE(y.first_active_season, t.season)   AS first_active_season,
                                         COALESCE(t.season, y.last_active_season)    AS last_active_season,


                                         CASE
                                             WHEN y.player_name IS NULL THEN 'New'
                                             WHEN y.last_active_season = t.Season - 1 THEN 'Continued Playing'
                                             WHEN y.last_active_season < t.season - 1 THEN 'Returned from Retirement'
                                             WHEN t.season IS NULL AND y.last_active_season = y.current_season
                                                 THEN 'Retired'
                                             ELSE 'Stayed Retired'::season_state END AS season_state,
                                         COALESCE(t.season, y.current_season + 1)    AS current_season
                                  FROM today t
                                           FULL OUTER JOIN yesterday y ON t.player_name = y.player_name)
                INSERT
                INTO player_state_change
                SELECT *
                FROM combined;
            END LOOP;
    END;

$$
;
--Check pipelines
SELECT *
FROM player_state_change;
-- Solution 2: with table players
-- Tbl Players is a cumulative table already so we don't need to create new table.
WITH state_tracking AS (SELECT players.*,
                               LAG(current_season, 1)
                               OVER (PARTITION BY player_name ORDER BY current_season)                   AS y_season,
                               LAG(is_active, 1) OVER (PARTITION BY player_name ORDER BY current_season) AS y_is_active
                        FROM players),
     state_change AS (SELECT player_name,
                             height,
                             college,
                             country,
                             draft_year,
                             draft_round,
                             draft_number,
                             seasons,
                             scoring_class,
                             is_active                                   AS t_is_active,
                             current_season,
                             y_is_active,
                             CASE
                                 WHEN y_is_active IS NULL AND is_active = TRUE THEN 'New'
                                 WHEN is_active = TRUE AND y_is_active = TRUE THEN 'Continued Playing'
                                 WHEN is_active = TRUE AND y_is_active = FALSE THEN 'Returned from Retirement'
                                 WHEN is_active = FALSE AND y_is_active = TRUE THEN 'Retired'
                                 ELSE 'Stayed Retired'::season_state END AS state_change
                      FROM state_tracking),
     state_change_1 AS (SELECT player_name, season_state, current_season FROM player_state_change),
     state_change_2 AS (SELECT player_name, state_change AS season_state, current_season FROM state_change)
--Testing outputs from two solutions, it gives 0 rows. All match.
SELECT *
FROM state_change_2
EXCEPT
SELECT *
FROM state_change_1


