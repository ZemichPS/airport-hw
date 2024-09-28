-- 1. Вывести к каждому самолету класс обслуживания и количество мест этого класса
SELECT aircrafts_data.aircraft_code,
       model,
       range,
       fare_conditions,
       count(seat_no) AS count_seat
FROM aircrafts_data
         INNER JOIN seats USING (aircraft_code)
group by aircrafts_data.aircraft_code, model, range, fare_conditions;


-- 2. Найти 3 самых вместительных самолета (модель + кол-во мест)
SELECT model,
       count(seats.seat_no) count_seats
FROM aircrafts_data
         INNER JOIN seats USING (aircraft_code)
GROUP BY model
ORDER BY count_seats DESC
limit 3;


-- 3. Вывести код, модель самолета и места не эконом класса для самолета 'Аэробус A321-200' с сортировкой по местам
SELECT aircrafts_data.aircraft_code,
       model,
       seat_no
FROM aircrafts_data
         INNER JOIN seats USING (aircraft_code)
WHERE fare_conditions not LIKE 'Economy'
  AND model::text LIKE '%Аэробус A321-200%';


-- 4. Вывести города в которых больше 1 аэропорта (код аэропорта, аэропорт, город)
SELECT airport_code,
       airport_name,
       city
FROM airports_data
where city ->> 'ru' IN (SELECT city ->> 'ru' as airport_city
                        FROM airports_data
                        GROUP BY city ->> 'ru'
                        HAVING COUNT(city) > 1);


-- 5. Найти ближайший вылетающий рейс из Екатеринбурга в Москву, на который еще не завершилась регистрация
SELECT *
FROM flights
         INNER JOIN airports_data AS departure_airport ON flights.departure_airport = departure_airport.airport_code
         INNER JOIN airports_data AS arrival_airport ON flights.arrival_airport = arrival_airport.airport_code
WHERE departure_airport.city ->> 'ru'::text LIKE '%Екатеринбург%'
  AND arrival_airport.city ->> 'ru'::text LIKE '%Москва%'
  AND status IN ('On Time', 'Delayed')
  AND flights.scheduled_departure > NOW()
ORDER BY scheduled_departure ASC
LIMIT 1;


-- 6. Вывести самый дешевый и дорогой билет и стоимость (в одном результирующем ответе)
WITH amount_ticket_cost AS (SELECT ticket_flights.ticket_no,
                                   SUM(ticket_flights.amount) AS sum_amount
                            FROM ticket_flights
                            GROUP BY ticket_flights.ticket_no),
     min_max_cost AS (SELECT min(sum_amount) AS min_cost,
                             max(sum_amount) AS max_cost
                      FROM amount_ticket_cost)
SELECT tickets.*,
       sum_amount
FROM min_max_cost mmc,
     tickets
         INNER JOIN amount_ticket_cost as atc USING (ticket_no)
WHERE atc.sum_amount = mmc.max_cost
   OR atc.sum_amount = mmc.min_cost
ORDER BY sum_amount DESC;


-- 7. Вывести информацию о вылете с наибольшей суммарной стоимостью билетов
WITH sum_cost_flight AS (SELECT SUM(ticket_flights.amount) AS sum_fligth_cost,
                                flight_id
                         FROM ticket_flights
                         GROUP BY flight_id
),
max_flight_cost AS (
SELECT MAX(sum_fligth_cost) AS max_cost
FROM sum_cost_flight
)
SELECT flights.*,
       sum_fligth_cost
FROM max_flight_cost,
     flights
         INNER JOIN sum_cost_flight USING (flight_id)
WHERE sum_fligth_cost = max_flight_cost.max_cost;


-- 8. Найти модель самолета, принесшую наибольшую прибыль (наибольшая суммарная стоимость билетов). Вывести код модели, информацию о модели и общую стоимость
WITH model_sum_profit AS (SELECT aircrafts_data.aircraft_code,
                                 aircrafts_data.model,
                                 aircrafts_data.range,
                                 SUM(ticket_flights.amount) AS total_profit
                          FROM aircrafts_data
                                   INNER JOIN flights USING (aircraft_code)
                                   INNER JOIN ticket_flights USING (flight_id)
                          GROUP BY aircrafts_data.aircraft_code, aircrafts_data.model, aircrafts_data.range)
SELECT aircraft_code,
       model,
       range,
       total_profit
FROM model_sum_profit
WHERE total_profit = (SELECT MAX(total_profit) from model_sum_profit)
GROUP BY aircraft_code, model, range, total_profit;


-- 9. Найти самый частый аэропорт назначения для каждой модели самолета. Вывести количество вылетов, информацию о модели самолета, аэропорт назначения, город
SELECT aircrafts_data.aircraft_code,
       aircrafts_data.model,
       flights.arrival_airport,
       airports_data.airport_name ->> 'ru' AS airport_name,
       airports_data.city ->> 'ru'         AS city,
       COUNT(flights.flight_id)      AS flight_count
FROM flights
         INNER JOIN aircrafts_data  USING(aircraft_code)
         INNER JOIN airports_data  ON flights.arrival_airport = airports_data.airport_code
GROUP BY aircrafts_data.aircraft_code, aircrafts_data.model, flights.arrival_airport, airports_data.airport_name, airports_data.city
HAVING COUNT(flights.flight_id) = (SELECT MAX(count_flights)
                             FROM (SELECT COUNT(*) AS count_flights
                                   FROM flights f_inner
                                            INNER JOIN aircrafts_data ad_inner
                                                       ON f_inner.aircraft_code = ad_inner.aircraft_code
                                            INNER JOIN airports_data a_inner ON f_inner.arrival_airport = a_inner.airport_code
                                   WHERE ad_inner.aircraft_code = aircrafts_data.aircraft_code
                                   GROUP BY f_inner.arrival_airport) flight_counts);

