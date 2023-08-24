-- screening dedups, PK = (game_id, team_id, player_id)
SELECT game_id, team_id, player_id, COUNT(*) AS count_dups
FROM game_details
GROUP BY game_id, team_id, player_id
HAVING COUNT(1) > 1;
-- yes, there are dups.
WITH dedupped AS (SELECT *, ROW_NUMBER() OVER (PARTITION BY game_id,team_id,player_id) AS row_num
                  FROM game_details)
SELECT *
FROM dedupped
WHERE row_num = 1 --choose the first row to remove other dups.