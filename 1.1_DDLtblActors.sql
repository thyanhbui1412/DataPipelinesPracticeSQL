drop type films;
create type films as
(
    film   text,
    votes  integer,
    rating real,
    filmid text
);

drop type quality_class;
create type quality_class as ENUM ('star','good','average','bad');

drop table actors;
create table actors
(
    actorid       text,
    actor         text,
    films         films[],
    quality_class quality_class,
    is_active     boolean,
    current_year  int,
    primary key (actorid, current_year)
);
