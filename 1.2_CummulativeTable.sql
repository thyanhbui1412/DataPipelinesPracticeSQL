do
$$
    begin
        --the starting years is always empty. implement the loop to get cumulative table for all years
        for i in ((select min(year) from actor_films) - 1)..(select max(year) from actor_films)
            loop
                WITH yesterday AS
                         (SELECT *
                          FROM actors
                          WHERE current_year = i),
                     today AS
                         (SELECT actor,
                                 actorid,
                                 year,
                                 array_agg(row (film, votes, rating, filmid)::films
                                           order by filmid desc)        as films,
                                 ROUND(CAST(AVG(rating) AS numeric), 2) AS avg_rating
                          FROM actor_films
                          WHERE year = i + 1
                          group by actor,
                                   actorid,
                                   year),
                     combined as
                         (SELECT COALESCE(t.actorid, y.actorid)       AS actorid,
                                 COALESCE(t.actor, y.actor)           AS actor,
--Concat actors table of previous years to today years, there are 3 cases:
                                 -- when starting year is empty. use data of the following year,
                                 -- when the starting year and following year isnt empty, concat them,
                                 -- when the starting year isnt empty and the following year is empty, use data of yesterday
                                 CASE
                                     WHEN y.films IS NULL THEN t.films
                                     WHEN t.year IS NOT NULL THEN t.films || y.films
                                     ELSE y.films
                                     END                              AS films,
                                 CASE
                                     WHEN t.avg_rating IS NULL THEN y.quality_class
                                     WHEN t.avg_rating > 8.0 THEN 'star'
                                     WHEN t.avg_rating > 7.0 THEN 'good'
                                     WHEN t.avg_rating > 6.0 THEN 'average'
                                     else 'bad'
                                     END                              as quality_class,
                                 t.year is not null                   as is_active, --actor is_active when year is not null
                                 coalesce(t.year, y.current_year + 1) as current_year
                          FROM today t
                                   FULL OUTER JOIN yesterday y ON t.actorid = y.actorid)
                INSERT
                INTO actors
                select *
                from combined;
            end loop;
    end;

$$

