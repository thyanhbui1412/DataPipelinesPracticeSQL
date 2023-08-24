drop type scd_type;
create type scd_type as
(
    quality_class quality_class,
    is_active     BOOLEAN,
    start_date    INTEGER,
    end_date      INTEGER
);
-- We have 3 group to concat: new data, potentially need to update, "fixated" data.
with historical_scd as (select actorid,
                               actor,
                               quality_class,
                               is_active,
                               start_date,
                               end_date
                        from actors_history_scd
                        where end_date < 2021),
     last_year_scd as (select *
                       from actors_history_scd
                       where end_date = 2021),
     this_year_scd as (select *
                       from actors
                       where current_year = 2022),
    -- Potentially, there might be changes between current year and last year, so we are putting unchanged records and changed records into groups.
     unchanged_records as (select ty.actorid,
                                  ty.actor,
                                  ty.quality_class,
                                  ty.is_active,
                                  ly.start_date,
                                  ty.current_year as end_year
                           from this_year_scd ty
                                    LEFT JOIN last_year_scd ly USING (actorid)
                           where ty.quality_class = ly.quality_class
                             and ty.is_active = ly.is_active),

     changed_records as (select ty.actorid,
                                ty.actor,

                                unnest(array [row (ly.quality_class,
                                    ly.is_active,
                                    ly.start_date,
                                    ly.end_date)::scd_type,
                                    row (ty.quality_class,
                                        ty.is_active,
                                        ty.current_year,
                                        ty.current_year)::scd_type]) as records
                         from this_year_scd ty
                                  LEFT JOIN last_year_scd ly USING (actorid)
                         where (ty.quality_class <> ly.quality_class
                             or ty.is_active = ly.is_active)
                            or ly.actor is null),
    -- with changed records, we need to explode the struct for scd table to capture the change.
     unnested_changed_records as (select actorid,
                                         actor,
                                         (records::scd_type).quality_class,
                                         (records::scd_type).is_active,
                                         (records::scd_type).start_date,
                                         (records::scd_type).end_date
                                  from changed_records),
    -- new records are any records where actorid is empty.
     new_records as (select ty.actorid,
                            ty.actor,
                            ty.quality_class,
                            ty.is_active,
                            ty.current_year as start_date,
                            ty.current_year as end_date
                     from this_year_scd ty
                              left join last_year_scd ly using (actorid)
                     where ly.actorid is null)

select *
from historical_scd
union all
select *
from unnested_changed_records
union all
select *
from new_records

order by start_date, actorid;