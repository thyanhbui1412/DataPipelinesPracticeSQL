DROP TABLE IF EXISTS player_points_team_wins;
CREATE TABLE player_points_team_wins
(
    player_id           TEXT,
    player_name         TEXT,
    team_id             TEXT,
    team_city           TEXT,
    season              TEXT,
    total_pts_by_player INTEGER,
    total_wins_by_team  INTEGER,
    aggregation_level   TEXT
);
INSERT INTO player_points_team_wins
WITH game_augmented AS (SELECT gd.player_id        AS player_id,
                               gd.player_name      AS player_name,
                               gd.team_id          AS team_id,
                               gd.team_city        AS team_city,
                               g.season            AS season,
                               gd.game_id          AS game_id,
                               COALESCE(gd.pts, 0) AS player_pts,
                               CASE
                                   WHEN (gd.team_id = g.home_team_id AND home_team_wins = 1)
                                       OR (gd.team_id <> g.home_team_id AND home_team_wins = 0) THEN 1
                                   ELSE 0
                                   END             AS win
                        FROM game_details gd
                                 LEFT JOIN games g USING (game_id)),
     agg AS (SELECT COALESCE(CAST(player_id AS TEXT), '(Overall)')       AS player_id,
                    COALESCE(CAST(player_name AS TEXT), '(Overall)')     AS player_name,
                    COALESCE(CAST(team_id AS TEXT), '(Overall)')         AS team_id,
                    COALESCE(CAST(team_city AS TEXT), '(Overall)')       AS team_city,
                    COALESCE(CAST(season AS TEXT), '(Overall)')          AS season,

                    SUM(player_pts)                                      AS total_pts_by_player,
                    COUNT(DISTINCT (CASE WHEN win = 1 THEN game_id END)) AS total_wins_by_team,
                    CASE
                        WHEN GROUPING(player_id, player_name, team_id, team_city) = 0
                            THEN 'player_pts_by_team'
                        WHEN GROUPING(player_id, player_name, season) = 0
                            THEN 'player_pts_by_season'
                        WHEN GROUPING(team_id, team_city) = 0
                            THEN 'team' END                              AS aggregation_level
             FROM game_augmented ga
             GROUP BY GROUPING SETS ((player_id, player_name, team_id, team_city),
                                     (player_id, player_name, season),
                                     (team_id, team_city)
                 ))
SELECT *
FROM agg;
--Golden Gate wins the most game, 445 games from 2003 to 2022
SELECT team_city, total_wins_by_team
FROM player_points_team_wins
WHERE aggregation_level = 'team'
ORDER BY total_wins_by_team DESC;
--Giannis Antetokounmpo scores the most for team Milwaukee from 2003 to 2022
SELECT player_name, total_pts_by_player, team_city
FROM player_points_team_wins
WHERE aggregation_level = 'player_pts_by_team'
ORDER BY total_pts_by_player DESC;
--James Harden got the highest points of 3247 in season 2018 for the timeframe from 2003 to 2022
SELECT player_name, total_pts_by_player, season
FROM player_points_team_wins
WHERE aggregation_level = 'player_pts_by_season'
ORDER BY total_pts_by_player DESC
