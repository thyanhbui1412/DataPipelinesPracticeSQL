DROP TABLE user_devices_cumulated;
CREATE TABLE user_devices_cumulated
(
    user_id      TEXT,                                         --previously used BIGINT but got out of range error
    device_activity_datelist DATE[],
    --device_id    BIGINT,
    today_date   DATE,
    browser_type TEXT,
    PRIMARY KEY (user_id, today_date, browser_type)
);

DO
$$
    DECLARE
        i DATE;
    BEGIN
        FOR i IN (SELECT GENERATE_SERIES((SELECT CAST(MIN(CAST(event_time AS DATE)) AS DATE) - INTERVAL '1 day'
                                          FROM events
                                                   LEFT JOIN devices USING (device_id)),
                                         (SELECT CAST(MAX(CAST(event_time AS DATE)) AS DATE)
                                          FROM events
                                                   LEFT JOIN devices USING (device_id)),
                                         INTERVAL '1 day') AS i)

            LOOP
                INSERT INTO user_devices_cumulated

                WITH yesterday AS (SELECT *
                                   FROM user_devices_cumulated
                                   WHERE today_date = date(i)),
                     today AS (SELECT CAST(user_id AS TEXT)               AS user_id,
                                      date(CAST(event_time AS TIMESTAMP)) AS today_date,
                                      --device_id,
                                      devices.browser_type                AS browser_type,
                                      row_number() OVER (PARTITION BY CAST(user_id AS TEXT), date(CAST(event_time AS TIMESTAMP)), --device_id,
                                        browser_type) as row_num

                               FROM events
                                        LEFT JOIN devices USING (device_id)
                               WHERE date(CAST(event_time AS TIMESTAMP)) = date(date(i) + INTERVAL '1 day')
                                 AND user_id IS NOT NULL
                                 --AND device_id IS NOT NULL
                                 AND devices.browser_type IS NOT NULL

                               GROUP BY CAST(user_id AS TEXT), date(CAST(event_time AS TIMESTAMP)), --device_id,
                                        browser_type
                               order by row_num)
                SELECT COALESCE(y.user_id, t.user_id)  AS user_id,

                       CASE
                           WHEN y.device_activity_datelist IS NULL THEN ARRAY [t.TODAY_DATE]
                           WHEN t.today_date IS NOT NULL THEN ARRAY [t.today_date] || y.device_activity_datelist
                           ELSE y.device_activity_datelist
                           END                                                 AS dates_active,
                       COALESCE(t.today_date, y.today_date + INTERVAL '1 day') AS today_date,
                       COALESCE(y.browser_type, t.browser_type)                AS browser_type
                FROM yesterday y
                         FULL OUTER JOIN today t ON y.user_id = t.user_id AND y.browser_type = t.browser_type;


            END LOOP;
    END ;
$$

