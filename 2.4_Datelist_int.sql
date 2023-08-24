-- A datelist_int generation query. Convert the device_activity_datelist column into a datelist_int column
-- CREATE TABLE device_datelist_int (
--     user_id BIGINT,
--     datelist_int BIT(32),
--     date DATE,
--     PRIMARY KEY (user_id, date)
-- );
-- This query is looking at user active on 2023-01-10
WITH user_devices AS (SELECT *
                      FROM user_devices_cumulated
                      WHERE today_date = DATE('2023-01-10')),

     series AS (SELECT *
                FROM GENERATE_SERIES((SELECT CAST(MIN(CAST(event_time AS DATE)) AS DATE) - INTERVAL '1 day'
                                      FROM events
                                               LEFT JOIN devices USING (device_id)),
                                     (SELECT CAST(MAX(CAST(event_time AS DATE)) AS DATE)
                                      FROM events
                                               LEFT JOIN devices USING (device_id)),
                                     INTERVAL '1 day') AS series_date),
     place_holder_ints AS (SELECT
                               --today_date - DATE(S),
                               CASE
                                   WHEN
                                       device_activity_datelist @> ARRAY [DATE(series_date)]
                                       THEN CAST(POW(2, 32 - (today_date - DATE(series_date))) AS BIGINT)
                                   ELSE 0 END AS placeholder_int_value,
                               *
                           FROM user_devices
                                    CROSS JOIN series
         --WHERE user_id = '16665089995802500000'
     )

SELECT user_id,
       browser_type,
       today_date,
       device_activity_datelist,
       CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))            AS datelist_int_binary,
       BIT_COUNT(CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))) AS cnt_active_dates,
       CAST(SUM(placeholder_int_value) AS BIGINT)                             AS datelist_int
FROM place_holder_ints
GROUP BY user_id, browser_type, today_date, device_activity_datelist