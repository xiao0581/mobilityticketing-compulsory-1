-- Query 1: upcoming trips
select
    t.id,
    t.scheduled_departure_utc,
    t.status
from trips t
where t.route_id = :route_id
  and t.scheduled_departure_utc >= :after_utc
order by t.scheduled_departure_utc
limit 20;

-- Query 2: ordered route stops
select
    rs.stop_sequence,
    s.id,
    s.name
from route_stops rs
join stops s
    on s.id = rs.stop_id
where rs.route_id = :route_id
order by rs.stop_sequence;


-- Query 3: routes and trip count, including routes with zero trips
select
    r.id,
    r.short_name,
    count(t.id) as scheduled_trip_count
from routes r
left join trips t
    on t.route_id = r.id
    and t.service_date = :service_date
    and t.status = 'scheduled'
group by
    r.id,
    r.short_name
order by
    r.short_name;

    --4. Show the next 20 scheduled trips for a route after a supplied timestamp.
select
    t.id,
    t.scheduled_departure_utc,
    t.status
from trips t
where t.route_id = :route_id
  and t.status = 'scheduled'
  and t.scheduled_departure_utc >= :after_utc
order by t.scheduled_departure_utc
limit 20;

-- 5. Show the ordered stops belonging to a route.
select
    rs.stop_sequence,
    s.id,
    s.name
from route_stops rs
join stops s
    on s.id = rs.stop_id
where rs.route_id = :route_id
order by rs.stop_sequence;

-- 6. Show all routes and the number of scheduled trips
-- on a supplied service date, including routes with no trips.
select
    r.id,
    r.short_name,
    count(t.id) as scheduled_trip_count
from routes r
left join trips t
    on t.route_id = r.id
    and t.service_date = :service_date
    and t.status = 'scheduled'
group by
    r.id,
    r.short_name
order by
    r.short_name;