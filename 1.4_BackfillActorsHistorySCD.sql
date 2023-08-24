/*I want to backfill for actor scd that tracks changes of quality_class and is_active.
  Therefore, first, I need a CTE that shows quality_class and is_active of all years and those of the year before*/
insert into actors_history_scd
with with_previous as
         (SELECT actorid,
                 actor,
                 current_year,
                 quality_class,
                 is_active,
                 LAG(quality_class, 1) OVER (PARTITION BY actor --LAG brings another column of previous values
                     ORDER BY current_year) as previous_rating_class,
                 LAG(is_active, 1) OVER (PARTITION BY actor
                     ORDER BY current_year) as previous_is_active
          FROM actors
          where current_year <=
                (select max(year)
                 from actor_films)),
-- Second, on top of the previous CTE, I need to a change_indicator column to track either any changes in quality_class or is_active,
    -- take 1 if there are changes in either of the two columns during the current and previous year.
     with_indicators as
         (select *,
                 case
                     when quality_class <> previous_rating_class then 1
                     when is_active <> previous_is_active then 1
                     else 0
                     end as change_indicator
          from with_previous),
-- Third, on top of the previous CTE, I need a streak_identifier column that counts the change time.
     with_streaks as
         (select *,
                 sum(change_indicator) over (partition by actor
                     order by current_year) as streak_identifier
          from with_indicators)
-- Now that I have the final CTE ready, I can do a simple select statement. We will need to update current_year each time.
-- Depend on the situation, I could make it dynamic by (SELECT EXTRACT(YEAR FROM CURRENT_DATE) AS current_year) or (SELECT MAX(YEAR) FROM actors) AS current_year;
select actorid,
       actor,
       quality_class,
       is_active,
       min(current_year) as start_year,
       max(current_year) as end_year,
       2021              as current_year
from with_streaks
group by actorid,
         actor,
         streak_identifier,
         is_active,
         quality_class
order by actorid,
         actor,
         streak_identifier

