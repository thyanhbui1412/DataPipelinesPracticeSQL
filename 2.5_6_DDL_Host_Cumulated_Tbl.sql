DROP TABLE hosts_cumulated;
CREATE TABLE hosts_cumulated
(
    host                   TEXT,
    host_activity_datelist DATE[],
    today_date             DATE,
    PRIMARY KEY (host, today_date)
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
                INSERT INTO hosts_cumulated
                WITH yesterday AS (SELECT * FROM hosts_cumulated WHERE today_date = date(i)),
                     today AS (SELECT host,
                                      CAST(CAST(event_time AS TIMESTAMP) AS DATE) AS today_date
                               FROM events
                               WHERE CAST(CAST(event_time AS TIMESTAMP) AS DATE) = date(i + 1)
                                 AND host IS NOT NULL
                               GROUP BY 1, 2)
                SELECT COALESCE(y.host, t.host)                                AS host,
                       CASE
                           WHEN Y.host_activity_datelist IS NULL THEN ARRAY [T.today_date]
                           WHEN T.today_date IS NOT NULL THEN ARRAY [T.today_date] || y.host_activity_datelist
                           ELSE y.host_activity_datelist END                   AS host_activity_datelist,
                       COALESCE(t.today_date, y.today_date + INTERVAL '1 day') AS today_date
                FROM yesterday y
                         FULL OUTER JOIN today t USING (host);


            END LOOP;
    END ;
$$
