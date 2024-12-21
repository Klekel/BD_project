--
-- PostgreSQL database dump
--

-- Dumped from database version 16.6 (Ubuntu 16.6-1.pgdg24.04+1)
-- Dumped by pg_dump version 16.6 (Ubuntu 16.6-1.pgdg24.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: schedule_table; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.schedule_table AS (
	train_number character varying(20),
	type character varying(20),
	departure_time interval,
	station_name character varying(100),
	route_id integer,
	summa numeric
);


ALTER TYPE public.schedule_table OWNER TO postgres;

--
-- Name: schedule_table_new; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.schedule_table_new AS (
	train_number character varying(20),
	type character varying(20),
	departure_time interval,
	arrival_time interval,
	station_name character varying(100),
	route_id integer,
	summa numeric
);


ALTER TYPE public.schedule_table_new OWNER TO postgres;

--
-- Name: add_route(integer, integer, interval, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_route(IN p_start_station_id integer, IN p_end_station_id integer, IN p_estimated_time interval, IN p_description text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO Routes (start_station_id, end_station_id, estimated_time, description)
    VALUES (p_start_station_id, p_end_station_id, p_estimated_time, p_description);
END;
$$;


ALTER PROCEDURE public.add_route(IN p_start_station_id integer, IN p_end_station_id integer, IN p_estimated_time interval, IN p_description text) OWNER TO postgres;

--
-- Name: add_ticket(integer, integer, integer, integer, character varying, date); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_ticket(IN p_user_id integer, IN p_route_id integer, IN p_from_station_id integer, IN p_to_station_id integer, IN p_train_type character varying, IN p_date date)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO Tickets (user_id, route_id, from_station_id, to_station_id,train_type, date)
    VALUES (p_user_id, p_route_id, p_from_station_id, p_to_station_id, p_train_type, p_date);
END;
$$;


ALTER PROCEDURE public.add_ticket(IN p_user_id integer, IN p_route_id integer, IN p_from_station_id integer, IN p_to_station_id integer, IN p_train_type character varying, IN p_date date) OWNER TO postgres;

--
-- Name: add_user(character varying, character varying, character varying, character varying, numeric, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_user(IN p_first_name character varying, IN p_last_name character varying, IN p_mail character varying, IN p_phone_number character varying, IN p_money numeric, IN p_user_password character varying, IN p_transport_concession character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO Users (first_name, last_name, mail, phone_number,money, user_password, transport_concession)
    VALUES (p_first_name, p_last_name, p_mail, p_phone_number, p_money, p_user_password, p_transport_concession);
END;
$$;


ALTER PROCEDURE public.add_user(IN p_first_name character varying, IN p_last_name character varying, IN p_mail character varying, IN p_phone_number character varying, IN p_money numeric, IN p_user_password character varying, IN p_transport_concession character varying) OWNER TO postgres;

--
-- Name: add_users_money(integer, numeric); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_users_money(IN p_user_id integer, IN p_money numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE Users
    SET money = money + p_money
  WHERE user_id = p_user_id;
END;
$$;


ALTER PROCEDURE public.add_users_money(IN p_user_id integer, IN p_money numeric) OWNER TO postgres;

--
-- Name: calculate_ticket_price(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calculate_ticket_price() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    calculated_price DECIMAL;
    concession_factor DECIMAL := 1.0;
BEGIN
    -- Вычисляем базовую стоимость билета
    SELECT
        SUM(rs.price_to_next_station)
    INTO
        calculated_price
    FROM
        RouteStations rs
    WHERE
        rs.route_id = NEW.route_id
        AND rs.station_order >= (
            SELECT station_order
            FROM RouteStations
            WHERE station_id = NEW.from_station_id
            AND route_id = NEW.route_id
        )
        AND rs.station_order < (
            SELECT station_order
            FROM RouteStations
            WHERE station_id = NEW.to_station_id
            AND route_id = NEW.route_id
        );

    -- Устанавливаем цену билета
    NEW.price := calculated_price;

    -- Определяем коэффициент льгот для пользователя
    SELECT
        CASE
            WHEN u.transport_concession = 'пол цены' THEN 0.5
            WHEN u.transport_concession = 'бесплатно' THEN 0.0
            ELSE 1.0
        END
    INTO
        concession_factor
    FROM
        Users u
    WHERE
        u.user_id = NEW.user_id;

    -- Рассчитываем total_price с учетом типа электрички и льгот
    IF NEW.train_type = 'Ласточка' THEN
        NEW.total_price := concession_factor * NEW.price * 2;
    ELSE
        NEW.total_price := concession_factor * NEW.price;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.calculate_ticket_price() OWNER TO postgres;

--
-- Name: change_users_money(integer, numeric); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.change_users_money(IN p_user_id integer, IN p_money numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE Users
    SET money = p_money
	WHERE user_id = p_user_id;

	IF NOT FOUND THEN
        RAISE NOTICE 'Пользователь с user_id = % не найден.', p_user_id;
    ELSE
        RAISE NOTICE 'Счёт пользователя с user_id = % умпешно изменён.', p_user_id;
    END IF;
END;
$$;


ALTER PROCEDURE public.change_users_money(IN p_user_id integer, IN p_money numeric) OWNER TO postgres;

--
-- Name: check_user(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_user(p_mail character varying, p_user_password character varying) RETURNS TABLE(user_id integer)
    LANGUAGE sql
    AS $$
	SELECT user_id FROM Users WHERE mail = p_mail AND user_password = p_user_password
$$;


ALTER FUNCTION public.check_user(p_mail character varying, p_user_password character varying) OWNER TO postgres;

--
-- Name: decrise_money(integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.decrise_money(IN p_user_id integer, IN p_cost integer)
    LANGUAGE sql
    AS $$
	UPDATE Users SET money = money - p_cost WHERE user_id = p_user_id
$$;


ALTER PROCEDURE public.decrise_money(IN p_user_id integer, IN p_cost integer) OWNER TO postgres;

--
-- Name: delete_route(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.delete_route(IN p_route_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM Routes
    WHERE route_id = p_route_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'Маршрут с route_id = % не найден.', p_route_id;
    ELSE
        RAISE NOTICE 'Маршрут с route_id = % успешно удален.', p_route_id;
    END IF;
END;
$$;


ALTER PROCEDURE public.delete_route(IN p_route_id integer) OWNER TO postgres;

--
-- Name: delete_tickets(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.delete_tickets(IN p_user_id integer)
    LANGUAGE sql
    AS $$
	DELETE FROM Tickets WHERE user_id = p_user_id
$$;


ALTER PROCEDURE public.delete_tickets(IN p_user_id integer) OWNER TO postgres;

--
-- Name: delete_user(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.delete_user(IN p_user_id integer)
    LANGUAGE sql
    AS $$
	DELETE FROM Users WHERE user_id = p_user_id
$$;


ALTER PROCEDURE public.delete_user(IN p_user_id integer) OWNER TO postgres;

--
-- Name: get_money_amount(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_money_amount(p_user_id integer) RETURNS TABLE(money numeric)
    LANGUAGE sql
    AS $$
	SELECT money FROM Users WHERE user_id = p_user_id
$$;


ALTER FUNCTION public.get_money_amount(p_user_id integer) OWNER TO postgres;

--
-- Name: get_tickets(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_tickets(p_user_id integer) RETURNS TABLE(ticket_id integer, user_id integer, route_id integer, from_station_id integer, to_station_id integer, date date, price numeric, total_price numeric, train_type character varying)
    LANGUAGE sql
    AS $$
    SELECT *
    FROM Tickets 
    WHERE user_id = p_user_id;
$$;


ALTER FUNCTION public.get_tickets(p_user_id integer) OWNER TO postgres;

--
-- Name: get_train_schedule_with_price(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_train_schedule_with_price(from_station_id integer, to_station_id integer, user_id integer) RETURNS TABLE(train_number character varying, train_type character varying, departure_time interval, arrival_time interval, station_name character varying, route_id integer, total_price numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
    base_price DECIMAL(10, 2);
    concession_type VARCHAR(20);
    train_type VARCHAR(20);
    rec RECORD;
BEGIN
    -- Получаем тип льготы пользователя
    SELECT transport_concession INTO concession_type
    FROM Users
    WHERE Users.user_id = get_train_schedule_with_price.user_id;

    -- Выборка данных о поездах
    FOR rec IN
        SELECT 
            tr.train_number,
            tr.type AS train_type,
            sc.departure_time,
            (
                SELECT sc2.arrival_time
                FROM Schedule sc2
                WHERE sc2.station_id = get_train_schedule_with_price.to_station_id
                  AND sc2.train_id = sc.train_id
            ) AS arrival_time,
            st.station_name,
            sc.route_id,
            (
                SELECT SUM(rs.price_to_next_station)
                FROM RouteStations rs
                WHERE rs.route_id = sc.route_id
                  AND rs.station_order >= (
                      SELECT rs1.station_order
                      FROM RouteStations rs1
                      WHERE rs1.station_id = get_train_schedule_with_price.from_station_id
                        AND rs1.route_id = sc.route_id
                  )
                  AND rs.station_order < (
                      SELECT rs2.station_order
                      FROM RouteStations rs2
                      WHERE rs2.station_id = get_train_schedule_with_price.to_station_id
                        AND rs2.route_id = sc.route_id
                  )
            ) AS base_price
        FROM Schedule sc
        -- Соединяем с таблицей Trains для получения train_number и train_type
        LEFT JOIN Trains tr ON tr.train_id = sc.train_id
        -- Соединяем с таблицей Stations для получения station_name
        LEFT JOIN Stations st ON st.station_id = sc.station_id
        WHERE sc.route_id IN (
                SELECT DISTINCT rs1.route_id
                FROM RouteStations rs1
                JOIN RouteStations rs2 ON rs1.route_id = rs2.route_id
                WHERE rs1.station_id = get_train_schedule_with_price.from_station_id
                  AND rs2.station_id = get_train_schedule_with_price.to_station_id
            )
            AND sc.station_id = get_train_schedule_with_price.from_station_id
            AND sc.departure_time IS NOT NULL
            AND (
                SELECT SUM(rs.price_to_next_station)
                FROM RouteStations rs
                WHERE rs.route_id = sc.route_id
                  AND rs.station_order >= (
                      SELECT rs1.station_order
                      FROM RouteStations rs1
                      WHERE rs1.station_id = get_train_schedule_with_price.from_station_id
                        AND rs1.route_id = sc.route_id
                  )
                  AND rs.station_order < (
                      SELECT rs2.station_order
                      FROM RouteStations rs2
                      WHERE rs2.station_id = get_train_schedule_with_price.to_station_id
                        AND rs2.route_id = sc.route_id
                  )
            ) IS NOT NULL
    LOOP
        -- Применяем льготы
        base_price := rec.base_price;
        train_type := rec.train_type;

        IF concession_type = 'бесплатно' THEN
            base_price := 0;
        ELSIF concession_type = 'пол цены' THEN
            base_price := base_price / 2;
        END IF;

        -- Применяем коэффициент для типа электрички
        IF train_type = 'Ласточка' THEN
            base_price := base_price * 2;
        END IF;

        -- Возвращаем результат с учетом льгот и типа электрички
        train_number := rec.train_number;
        train_type := rec.train_type;
        departure_time := rec.departure_time;
        arrival_time := rec.arrival_time;
        station_name := rec.station_name;
        route_id := rec.route_id;
        total_price := base_price;

        RETURN NEXT;
    END LOOP;
END;
$$;


ALTER FUNCTION public.get_train_schedule_with_price(from_station_id integer, to_station_id integer, user_id integer) OWNER TO postgres;

--
-- Name: get_train_schedule_with_price_1(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_train_schedule_with_price_1(p_from_station_id integer, p_to_station_id integer, p_user_id integer) RETURNS TABLE(train_number character varying, train_type character varying, departure_time interval, arrival_time interval, station_name character varying, route_id integer, total_price numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
    base_price DECIMAL(10, 2);
    concession_type VARCHAR(20);
    train_type VARCHAR(20);
    rec RECORD;
BEGIN
    -- Получаем тип льготы пользователя
    SELECT transport_concession INTO concession_type
    FROM Users
    WHERE user_id = p_user_id;

    -- Выборка данных о поездах
    FOR rec IN
        SELECT 
            tr.train_number,
            tr.type AS train_type,
            sc.departure_time,
            (
                SELECT sc2.arrival_time
                FROM Schedule sc2
                WHERE sc2.station_id = p_to_station_id
                  AND sc2.train_id = sc.train_id
            ) AS arrival_time,
            st.station_name,
            sc.route_id,
            (
                SELECT SUM(rs.price_to_next_station)
                FROM RouteStations rs
                WHERE rs.route_id = sc.route_id
                  AND rs.station_order >= (
                      SELECT rs1.station_order
                      FROM RouteStations rs1
                      WHERE rs1.station_id = p_from_station_id
                        AND rs1.route_id = sc.route_id
                  )
                  AND rs.station_order < (
                      SELECT rs2.station_order
                      FROM RouteStations rs2
                      WHERE rs2.station_id = p_to_station_id
                        AND rs2.route_id = sc.route_id
                  )
            ) AS base_price
        FROM Schedule sc
        LEFT JOIN Trains tr ON tr.train_id = sc.train_id
        LEFT JOIN Stations st ON st.station_id = sc.station_id
        WHERE sc.route_id IN (
                SELECT DISTINCT rs1.route_id
                FROM RouteStations rs1
                JOIN RouteStations rs2 ON rs1.route_id = rs2.route_id
                WHERE rs1.station_id = p_from_station_id
                  AND rs2.station_id = p_to_station_id
            )
            AND sc.station_id = p_from_station_id
            AND sc.departure_time IS NOT NULL
            AND (
                SELECT SUM(rs.price_to_next_station)
                FROM RouteStations rs
                WHERE rs.route_id = sc.route_id
                  AND rs.station_order >= (
                      SELECT rs1.station_order
                      FROM RouteStations rs1
                      WHERE rs1.station_id = p_from_station_id
                        AND rs1.route_id = sc.route_id
                  )
                  AND rs.station_order < (
                      SELECT rs2.station_order
                      FROM RouteStations rs2
                      WHERE rs2.station_id = p_to_station_id
                        AND rs2.route_id = sc.route_id
                  )
            ) IS NOT NULL
    LOOP
        -- Применяем льготы
        base_price := rec.base_price;
        train_type := rec.train_type;

        IF concession_type = 'бесплатно' THEN
            base_price := 0;
        ELSIF concession_type = 'пол цены' THEN
            base_price := base_price / 2;
        END IF;

        -- Применяем коэффициент для типа электрички
        IF train_type = 'Ласточка' THEN
            base_price := base_price * 2;
        END IF;

        -- Возвращаем результат с учетом льгот и типа электрички
        train_number := rec.train_number;
        departure_time := rec.departure_time;
        arrival_time := rec.arrival_time;
        station_name := rec.station_name;
        route_id := rec.route_id;
        total_price := base_price;

        RETURN NEXT;
    END LOOP;
END;
$$;


ALTER FUNCTION public.get_train_schedule_with_price_1(p_from_station_id integer, p_to_station_id integer, p_user_id integer) OWNER TO postgres;

--
-- Name: get_train_schedule_with_price_2(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_train_schedule_with_price_2(p_from_station_id integer, p_to_station_id integer, p_user_id integer) RETURNS TABLE(train_number character varying, train_type character varying, departure_time interval, arrival_time interval, station_name character varying, route_id integer, total_price numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
    concession_type VARCHAR(20);
BEGIN
    -- Получаем тип льготы пользователя
    SELECT transport_concession INTO concession_type
    FROM Users
    WHERE user_id = p_user_id;

    -- Возвращаем данные о поездах с учетом льгот и типа электрички
    RETURN QUERY
    SELECT 
        tr.train_number,
        tr.type AS train_type,
        sc.departure_time,
        sc2.arrival_time,
        st.station_name,
        sc.route_id,
        (CASE 
            WHEN concession_type = 'бесплатно' THEN 0
            WHEN concession_type = 'пол цены' THEN (SUM(rs.price_to_next_station) / 2)
            ELSE SUM(rs.price_to_next_station)
        END * CASE 
            WHEN tr.type = 'Ласточка' THEN 2
            ELSE 1
        END) AS total_price
    FROM Schedule sc
    LEFT JOIN Trains tr ON tr.train_id = sc.train_id
    LEFT JOIN Stations st ON st.station_id = sc.station_id
    LEFT JOIN Schedule sc2 ON sc2.train_id = sc.train_id AND sc2.station_id = p_to_station_id
    LEFT JOIN RouteStations rs ON rs.route_id = sc.route_id
    WHERE sc.route_id IN (
            SELECT rs1.route_id
            FROM RouteStations rs1
            JOIN RouteStations rs2 ON rs1.route_id = rs2.route_id
            WHERE rs1.station_id = p_from_station_id
              AND rs2.station_id = p_to_station_id
        )
        AND sc.station_id = p_from_station_id
        AND sc.departure_time IS NOT NULL
        AND rs.station_order >= (
            SELECT rs1.station_order
            FROM RouteStations rs1
            WHERE rs1.station_id = p_from_station_id
              AND rs1.route_id = sc.route_id
        )
        AND rs.station_order < (
            SELECT rs2.station_order
            FROM RouteStations rs2
            WHERE rs2.station_id = p_to_station_id
              AND rs2.route_id = sc.route_id
        )
    GROUP BY 
        tr.train_number, tr.type, sc.departure_time, sc2.arrival_time, st.station_name, sc.route_id;
END;
$$;


ALTER FUNCTION public.get_train_schedule_with_price_2(p_from_station_id integer, p_to_station_id integer, p_user_id integer) OWNER TO postgres;

--
-- Name: get_user_id(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_user_id(p_mail character varying) RETURNS TABLE(user_id integer)
    LANGUAGE sql
    AS $$
	SELECT user_id FROM Users WHERE mail = p_mail
$$;


ALTER FUNCTION public.get_user_id(p_mail character varying) OWNER TO postgres;

--
-- Name: get_user_name(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_user_name(p_user_id integer) RETURNS TABLE(first_name character varying, last_name character varying, money numeric)
    LANGUAGE sql
    AS $$
    SELECT first_name, last_name, money
    FROM Users 
    WHERE user_id = p_user_id;
$$;


ALTER FUNCTION public.get_user_name(p_user_id integer) OWNER TO postgres;

--
-- Name: name_to_id(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.name_to_id(station_name_in character varying) RETURNS integer
    LANGUAGE sql
    AS $$
Select station_id FROM stations where station_name = station_name_in
$$;


ALTER FUNCTION public.name_to_id(station_name_in character varying) OWNER TO postgres;

--
-- Name: table_for_schedule(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.table_for_schedule(from_station_id integer, to_station_id integer) RETURNS SETOF public.schedule_table
    LANGUAGE sql
    AS $$
SELECT tr.train_number, tr.type, sc.departure_time, st.station_name, sc.route_id, (SELECT SUM(rs.price_to_next_station)
        																			 FROM RouteStations rs
        																			 WHERE rs.route_id = sc.route_id
          																			 AND rs.station_order >= (
              																			 SELECT station_order
              																			 FROM RouteStations
              																			 WHERE station_id = from_station_id
                																			 AND route_id = sc.route_id
          																			 )
          																			 AND rs.station_order < (
              																			 SELECT station_order
              																			 FROM RouteStations
              																			 WHERE station_id = to_station_id
                																			 AND route_id = sc.route_id
          																			 )) AS total_price
FROM Schedule sc
LEFT JOIN Trains tr ON tr.train_id = sc.train_id 
LEFT JOIN Stations st ON st.station_id = sc.station_id
WHERE sc.route_id IN (
        SELECT DISTINCT rs1.route_id
        FROM RouteStations rs1
        JOIN RouteStations rs2 ON rs1.route_id = rs2.route_id
        WHERE rs1.station_id = from_station_id AND rs2.station_id = to_station_id
    ) AND sc.station_id = from_station_id AND sc.departure_time IS NOT NULL 
    AND (SELECT SUM(rs.price_to_next_station)
        FROM RouteStations rs
        WHERE rs.route_id = sc.route_id
          AND rs.station_order >= (
              SELECT station_order
              FROM RouteStations
              WHERE station_id = from_station_id
                AND route_id = sc.route_id
          )
          AND rs.station_order < (
              SELECT station_order
              FROM RouteStations
              WHERE station_id = to_station_id
                AND route_id = sc.route_id)
    ) IS NOT NULL;
$$;


ALTER FUNCTION public.table_for_schedule(from_station_id integer, to_station_id integer) OWNER TO postgres;

--
-- Name: table_for_schedule2(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.table_for_schedule2(from_station_id integer, to_station_id integer) RETURNS SETOF public.schedule_table_new
    LANGUAGE sql
    AS $$
SELECT tr.train_number, tr.type, sc.departure_time, (Select arrival_time from schedule  where station_id = to_station_id and train_id = tr.train_id ), st.station_name, sc.route_id, (SELECT SUM(rs.price_to_next_station)
        																			 FROM RouteStations rs
        																			 WHERE rs.route_id = sc.route_id
          																			 AND rs.station_order >= (
              																			 SELECT station_order
              																			 FROM RouteStations
              																			 WHERE station_id = from_station_id
                																			 AND route_id = sc.route_id
          																			 )
          																			 AND rs.station_order < (
              																			 SELECT station_order
              																			 FROM RouteStations
              																			 WHERE station_id = to_station_id
                																			 AND route_id = sc.route_id
          																			 )) AS total_price
FROM Schedule sc
LEFT JOIN Trains tr ON tr.train_id = sc.train_id 
LEFT JOIN Stations st ON st.station_id = sc.station_id
WHERE sc.route_id IN (
        SELECT DISTINCT rs1.route_id
        FROM RouteStations rs1
        JOIN RouteStations rs2 ON rs1.route_id = rs2.route_id
        WHERE rs1.station_id = from_station_id AND rs2.station_id = to_station_id
    ) AND sc.station_id = from_station_id AND sc.departure_time IS NOT NULL 
    AND (SELECT SUM(rs.price_to_next_station)
        FROM RouteStations rs
        WHERE rs.route_id = sc.route_id
          AND rs.station_order >= (
              SELECT station_order
              FROM RouteStations
              WHERE station_id = from_station_id
                AND route_id = sc.route_id
          )
          AND rs.station_order < (
              SELECT station_order
              FROM RouteStations
              WHERE station_id = to_station_id
                AND route_id = sc.route_id)
    ) IS NOT NULL;
$$;


ALTER FUNCTION public.table_for_schedule2(from_station_id integer, to_station_id integer) OWNER TO postgres;

--
-- Name: table_for_schedule2(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.table_for_schedule2(from_station_id integer, to_station_id integer, user_id integer) RETURNS TABLE(train_number character varying, type character varying, departure_time interval, arrival_time interval, station_name character varying, route_id integer, total_price numeric)
    LANGUAGE sql
    AS $_$
WITH user_concession AS (
    SELECT transport_concession
    FROM Users
    WHERE user_id = $3
),
train_type_multiplier AS (
    SELECT 
        CASE 
            WHEN tr.type = 'Ласточка' THEN 2.0
            ELSE 1.0
        END AS multiplier
    FROM Trains tr
    WHERE tr.train_id = (
        SELECT train_id 
        FROM Schedule 
        WHERE route_id IN (
            SELECT DISTINCT rs1.route_id
            FROM RouteStations rs1
            JOIN RouteStations rs2 ON rs1.route_id = rs2.route_id
            WHERE rs1.station_id = $1 AND rs2.station_id = $2
        ) AND station_id = $1
        LIMIT 1
    )
),
base_price AS (
    SELECT SUM(rs.price_to_next_station) AS base_price
    FROM RouteStations rs
    WHERE rs.route_id = (
        SELECT route_id 
        FROM Schedule 
        WHERE route_id IN (
            SELECT DISTINCT rs1.route_id
            FROM RouteStations rs1
            JOIN RouteStations rs2 ON rs1.route_id = rs2.route_id
            WHERE rs1.station_id = $1 AND rs2.station_id = $2
        ) AND station_id = $1
        LIMIT 1
    )
    AND rs.station_order >= (
        SELECT station_order
        FROM RouteStations
        WHERE station_id = $1
          AND route_id = (
              SELECT route_id 
              FROM Schedule 
              WHERE route_id IN (
                  SELECT DISTINCT rs1.route_id
                  FROM RouteStations rs1
                  JOIN RouteStations rs2 ON rs1.route_id = rs2.route_id
                  WHERE rs1.station_id = $1 AND rs2.station_id = $2
              ) AND station_id = $1
              LIMIT 1
          )
    )
    AND rs.station_order < (
        SELECT station_order
        FROM RouteStations
        WHERE station_id = $2
          AND route_id = (
              SELECT route_id 
              FROM Schedule 
              WHERE route_id IN (
                  SELECT DISTINCT rs1.route_id
                  FROM RouteStations rs1
                  JOIN RouteStations rs2 ON rs1.route_id = rs2.route_id
                  WHERE rs1.station_id = $1 AND rs2.station_id = $2
              ) AND station_id = $1
              LIMIT 1
          )
    )
)
SELECT 
    tr.train_number, 
    tr.type, 
    sc.departure_time, 
    (SELECT arrival_time 
     FROM schedule  
     WHERE station_id = $2 
       AND train_id = tr.train_id
    ), 
    st.station_name, 
    sc.route_id, 
    (SELECT 
        CASE 
            WHEN uc.transport_concession = 'бесплатно' THEN 0
            WHEN uc.transport_concession = 'пол цены' THEN (bp.base_price * ttm.multiplier) / 2
            ELSE bp.base_price * ttm.multiplier
        END
     FROM user_concession uc, base_price bp, train_type_multiplier ttm
    ) AS total_price
FROM Schedule sc
LEFT JOIN Trains tr ON tr.train_id = sc.train_id 
LEFT JOIN Stations st ON st.station_id = sc.station_id
WHERE sc.route_id IN (
        SELECT DISTINCT rs1.route_id
        FROM RouteStations rs1
        JOIN RouteStations rs2 ON rs1.route_id = rs2.route_id
        WHERE rs1.station_id = $1 AND rs2.station_id = $2
    ) 
    AND sc.station_id = $1 
    AND sc.departure_time IS NOT NULL 
    AND (SELECT base_price FROM base_price) IS NOT NULL;
$_$;


ALTER FUNCTION public.table_for_schedule2(from_station_id integer, to_station_id integer, user_id integer) OWNER TO postgres;

--
-- Name: table_for_schedule3(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.table_for_schedule3(from_station_id integer, to_station_id integer) RETURNS TABLE(train_number character varying, train_type character varying, departure_time interval, arrival_time interval, station_name character varying, route_id integer, total_price numeric)
    LANGUAGE sql
    AS $$
SELECT 
    tr.train_number,
    tr.type AS train_type,
    sc.departure_time,
    (
        SELECT sc2.arrival_time
        FROM Schedule sc2
        WHERE sc2.station_id = to_station_id
          AND sc2.train_id = sc.train_id
    ) AS arrival_time,
    st.station_name,
    sc.route_id,
    (
        SELECT SUM(rs.price_to_next_station)
        FROM RouteStations rs
        WHERE rs.route_id = sc.route_id
          AND rs.station_order >= (
              SELECT rs1.station_order
              FROM RouteStations rs1
              WHERE rs1.station_id = from_station_id
                AND rs1.route_id = sc.route_id
          )
          AND rs.station_order < (
              SELECT rs2.station_order
              FROM RouteStations rs2
              WHERE rs2.station_id = to_station_id
                AND rs2.route_id = sc.route_id
          )
    ) AS total_price
FROM Schedule sc
LEFT JOIN Trains tr ON tr.train_id = sc.train_id
LEFT JOIN Stations st ON st.station_id = sc.station_id
WHERE sc.route_id IN (
        SELECT DISTINCT rs1.route_id
        FROM RouteStations rs1
        JOIN RouteStations rs2 ON rs1.route_id = rs2.route_id
        WHERE rs1.station_id = from_station_id
          AND rs2.station_id = to_station_id
    )
    AND sc.station_id = from_station_id
    AND sc.departure_time IS NOT NULL
    AND (
        SELECT SUM(rs.price_to_next_station)
        FROM RouteStations rs
        WHERE rs.route_id = sc.route_id
          AND rs.station_order >= (
              SELECT rs1.station_order
              FROM RouteStations rs1
              WHERE rs1.station_id = from_station_id
                AND rs1.route_id = sc.route_id
          )
          AND rs.station_order < (
              SELECT rs2.station_order
              FROM RouteStations rs2
              WHERE rs2.station_id = to_station_id
                AND rs2.route_id = sc.route_id
          )
    ) IS NOT NULL;
$$;


ALTER FUNCTION public.table_for_schedule3(from_station_id integer, to_station_id integer) OWNER TO postgres;

--
-- Name: table_for_schedule_new(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.table_for_schedule_new(from_station_id integer, to_station_id integer, p_user_id integer) RETURNS SETOF public.schedule_table
    LANGUAGE plpgsql
    AS $$
DECLARE
    base_price DECIMAL(10, 2);
    train_type VARCHAR(20);
    transport_concession VARCHAR(20);
BEGIN
    -- Получаем тип электрички и льготу пользователя
    SELECT tr.type, u.transport_concession
    INTO train_type, transport_concession
    FROM Schedule sc
    LEFT JOIN Trains tr ON tr.train_id = sc.train_id
    LEFT JOIN Users u ON u.user_id = p_user_id
    WHERE sc.route_id IN (
            SELECT DISTINCT rs1.route_id
            FROM RouteStations rs1
            JOIN RouteStations rs2 ON rs1.route_id = rs2.route_id
            WHERE rs1.station_id = from_station_id AND rs2.station_id = to_station_id
        )
    LIMIT 1;

    -- Рассчитываем базовую цену
    SELECT SUM(rs.price_to_next_station)
    INTO base_price
    FROM RouteStations rs
    WHERE rs.route_id = sc.route_id
      AND rs.station_order >= (
          SELECT station_order
          FROM RouteStations
          WHERE station_id = from_station_id
            AND route_id = sc.route_id
      )
      AND rs.station_order < (
          SELECT station_order
          FROM RouteStations
          WHERE station_id = to_station_id
            AND route_id = sc.route_id
      );

    -- Изменяем цену в зависимости от типа электрички
    IF train_type = 'Ласточка' THEN
        base_price := base_price * 2;
    END IF;

    -- Изменяем цену в зависимости от льготы пользователя
    IF transport_concession = 'пол цены' THEN
        base_price := base_price / 2;
    ELSIF transport_concession = 'бесплатно' THEN
        base_price := 0;
    END IF;

    -- Возвращаем результат
    RETURN QUERY
    SELECT tr.train_number, tr.type, sc.departure_time, st.station_name, sc.route_id, base_price
    FROM Schedule sc
    LEFT JOIN Trains tr ON tr.train_id = sc.train_id 
    LEFT JOIN Stations st ON st.station_id = sc.station_id
    WHERE sc.route_id IN (
            SELECT DISTINCT rs1.route_id
            FROM RouteStations rs1
            JOIN RouteStations rs2 ON rs1.route_id = rs2.route_id
            WHERE rs1.station_id = from_station_id AND rs2.station_id = to_station_id
        ) AND sc.station_id = from_station_id AND sc.departure_time IS NOT NULL 
        AND base_price IS NOT NULL;
END;
$$;


ALTER FUNCTION public.table_for_schedule_new(from_station_id integer, to_station_id integer, p_user_id integer) OWNER TO postgres;

--
-- Name: update_user_money(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_user_money() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE Users
    SET money = money - NEW.total_price 
    WHERE user_id = NEW.user_id;

    IF (SELECT money FROM Users WHERE user_id = NEW.user_id) < 0 THEN
        RAISE EXCEPTION 'Недостаточно средств на счете пользователя с ID %', NEW.user_id;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_user_money() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: routes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.routes (
    route_id integer NOT NULL,
    start_station_id integer NOT NULL,
    end_station_id integer NOT NULL,
    estimated_time interval NOT NULL,
    description text NOT NULL,
    CONSTRAINT chk_start_end_station CHECK ((start_station_id <> end_station_id))
);


ALTER TABLE public.routes OWNER TO postgres;

--
-- Name: routes_route_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.routes_route_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.routes_route_id_seq OWNER TO postgres;

--
-- Name: routes_route_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.routes_route_id_seq OWNED BY public.routes.route_id;


--
-- Name: routestations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.routestations (
    routestation_id integer NOT NULL,
    route_id integer NOT NULL,
    station_id integer NOT NULL,
    station_order integer NOT NULL,
    price_to_next_station numeric(10,2) NOT NULL,
    CONSTRAINT routestations_price_to_next_station_check CHECK ((price_to_next_station >= (0)::numeric))
);


ALTER TABLE public.routestations OWNER TO postgres;

--
-- Name: routestations_routestation_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.routestations_routestation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.routestations_routestation_id_seq OWNER TO postgres;

--
-- Name: routestations_routestation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.routestations_routestation_id_seq OWNED BY public.routestations.routestation_id;


--
-- Name: schedule; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schedule (
    schedule_id integer NOT NULL,
    train_id integer NOT NULL,
    route_id integer NOT NULL,
    departure_time interval,
    arrival_time interval,
    station_id integer NOT NULL
);


ALTER TABLE public.schedule OWNER TO postgres;

--
-- Name: schedule_schedule_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.schedule_schedule_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.schedule_schedule_id_seq OWNER TO postgres;

--
-- Name: schedule_schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.schedule_schedule_id_seq OWNED BY public.schedule.schedule_id;


--
-- Name: stations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stations (
    station_id integer NOT NULL,
    station_name character varying(100) NOT NULL,
    train_platform_amount integer NOT NULL,
    self_checkout boolean NOT NULL,
    CONSTRAINT stations_train_platform_amount_check CHECK ((train_platform_amount <= 10))
);


ALTER TABLE public.stations OWNER TO postgres;

--
-- Name: stations_station_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stations_station_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stations_station_id_seq OWNER TO postgres;

--
-- Name: stations_station_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stations_station_id_seq OWNED BY public.stations.station_id;


--
-- Name: tickets; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tickets (
    ticket_id integer NOT NULL,
    user_id integer NOT NULL,
    route_id integer NOT NULL,
    from_station_id integer NOT NULL,
    to_station_id integer NOT NULL,
    date date NOT NULL,
    price numeric(10,2) DEFAULT 0 NOT NULL,
    total_price numeric(10,2) DEFAULT 0 NOT NULL,
    train_type character varying(20) NOT NULL,
    CONSTRAINT chk_from_to_station CHECK ((from_station_id <> to_station_id)),
    CONSTRAINT tickets_price_check CHECK ((price >= (0)::numeric)),
    CONSTRAINT tickets_total_price_check CHECK ((total_price >= (0)::numeric)),
    CONSTRAINT tickets_train_type_check CHECK (((train_type)::text = ANY ((ARRAY['Ласточка'::character varying, 'Комфорт'::character varying, 'Обычная'::character varying])::text[])))
);


ALTER TABLE public.tickets OWNER TO postgres;

--
-- Name: tickets_ticket_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tickets_ticket_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tickets_ticket_id_seq OWNER TO postgres;

--
-- Name: tickets_ticket_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tickets_ticket_id_seq OWNED BY public.tickets.ticket_id;


--
-- Name: trains; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trains (
    train_id integer NOT NULL,
    train_number character varying(20) NOT NULL,
    type character varying(20) NOT NULL,
    carriage_amount integer NOT NULL,
    CONSTRAINT trains_carriage_amount_check CHECK (((carriage_amount > 5) AND (carriage_amount <= 12))),
    CONSTRAINT trains_type_check CHECK (((type)::text = ANY ((ARRAY['Ласточка'::character varying, 'Комфорт'::character varying, 'Обычная'::character varying])::text[])))
);


ALTER TABLE public.trains OWNER TO postgres;

--
-- Name: trains_train_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.trains_train_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.trains_train_id_seq OWNER TO postgres;

--
-- Name: trains_train_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.trains_train_id_seq OWNED BY public.trains.train_id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    user_id integer NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    mail character varying(100) NOT NULL,
    phone_number character varying(15) NOT NULL,
    date_of_reg date DEFAULT CURRENT_DATE NOT NULL,
    money numeric(15,2) NOT NULL,
    transport_concession character varying(20) NOT NULL,
    user_password character varying(255) DEFAULT 0 NOT NULL,
    CONSTRAINT chk_valid_mail CHECK (((mail)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text)),
    CONSTRAINT users_money_check CHECK ((money >= (0)::numeric)),
    CONSTRAINT users_phone_number_check CHECK (((phone_number)::text ~* '^\d-\d{3}-\d{3}-\d{2}-\d{2}$'::text)),
    CONSTRAINT users_transport_concession_check CHECK (((transport_concession)::text = ANY ((ARRAY['без льгот'::character varying, 'пол цены'::character varying, 'бесплатно'::character varying])::text[])))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_user_id_seq OWNER TO postgres;

--
-- Name: users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_user_id_seq OWNED BY public.users.user_id;


--
-- Name: routes route_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.routes ALTER COLUMN route_id SET DEFAULT nextval('public.routes_route_id_seq'::regclass);


--
-- Name: routestations routestation_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.routestations ALTER COLUMN routestation_id SET DEFAULT nextval('public.routestations_routestation_id_seq'::regclass);


--
-- Name: schedule schedule_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule ALTER COLUMN schedule_id SET DEFAULT nextval('public.schedule_schedule_id_seq'::regclass);


--
-- Name: stations station_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stations ALTER COLUMN station_id SET DEFAULT nextval('public.stations_station_id_seq'::regclass);


--
-- Name: tickets ticket_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tickets ALTER COLUMN ticket_id SET DEFAULT nextval('public.tickets_ticket_id_seq'::regclass);


--
-- Name: trains train_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trains ALTER COLUMN train_id SET DEFAULT nextval('public.trains_train_id_seq'::regclass);


--
-- Name: users user_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN user_id SET DEFAULT nextval('public.users_user_id_seq'::regclass);


--
-- Data for Name: routes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.routes (route_id, start_station_id, end_station_id, estimated_time, description) FROM stdin;
2	12	38	00:51:00	Клин, пл.Фроловское, пл.Покровка, пл.Головково, пл.Сенеж, Подсолненчная, пл.Березки-Дачные, Поворово-1, пл.Поваровка, пл.Радищево, Зеленоград-Крюково, пл.Фирсановская, Сходня, пл.Подрезково, пл.Новоподрезково, пл.Молжаниново, Химки, пл.Левобережная, Москва Ленинградская
3	1	38	00:35:00	Зеленоград, Сходня, Химки, Москва Ленинградская
5	12	38	01:07:00	Все остановки кроме: пл.Радищево, пл.Малино, пл.Рижская
7	12	38	00:34:00	Клин, Подсолнечная, Поварово-1, Зеленоград-Крюково, Сходня, Химки, Москва Ленинградская
8	38	1	00:28:00	Москва Ленинградская, Химки, Сходня,Зеленоград-Крюково, Подсолнечная, Клин, Решетниково, Завидово, Редкино, пл.Чуприяновка, Тверь
9	38	12	00:36:00	Москва Ленинградская, Химки, Сходня, Зеленоград-Крюково, пл.Алабушево, пл.Поваровка, Поварово-1, пл.Березки-Дачные, Подсолнечная, пл.Сенеж, пл.Головково, пл.Покровка, пл.Фроловское, пл.Стреглово, Клин
10	38	1	00:58:00	Все остановки кроме: пл.Рижская, пл.Малино
6	38	17	00:58:00	Все остановки кроме: пл.Рижская и пл.Малино
4	2	38	01:03:00	Все остановки кроме: пл.Алабушево, пл.Малино, пл.Рижская
1	1	38	01:03:00	Зеленоград-Крюково, пл.Фирсановская, Сходня, пл.Подрезково, пл.Новоподрезково, пл.Молжаниново, Химки, пл.Левобережная, пл.Ховрино, Грачевская, пл.Моссельмаш, пл.Лихоборы, пл.Петровско-Разумовская,пл.Останкино, Москва Ленинградская
\.


--
-- Data for Name: routestations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.routestations (routestation_id, route_id, station_id, station_order, price_to_next_station) FROM stdin;
220	1	1	1	20.00
221	1	24	2	15.00
222	1	25	3	16.00
224	1	27	5	20.00
225	1	28	6	15.00
226	1	29	7	15.00
227	1	30	8	14.00
229	1	32	10	15.00
233	1	36	14	20.00
234	1	38	15	0.00
235	2	12	1	20.00
237	2	14	3	15.00
238	2	15	4	25.00
239	2	16	5	20.00
240	2	17	6	20.00
241	2	18	7	15.00
242	2	19	8	25.00
243	2	20	9	30.00
244	2	21	10	25.00
250	2	28	16	20.00
253	2	38	19	0.00
257	3	38	4	0.00
258	4	2	1	20.00
260	4	4	3	20.00
261	4	5	4	20.00
262	4	6	5	20.00
269	4	13	12	15.00
271	4	14	14	20.00
272	4	15	15	20.00
274	4	17	17	20.00
275	4	18	18	25.00
276	4	19	19	30.00
277	4	20	20	20.00
279	4	1	22	20.00
280	4	24	23	20.00
281	4	25	24	10.00
282	4	26	25	20.00
284	4	28	27	20.00
291	4	35	34	15.00
292	4	36	35	20.00
293	4	38	36	0.00
304	5	1	11	15.00
305	5	24	12	15.00
308	5	27	15	15.00
309	5	28	16	15.00
311	5	30	18	20.00
314	5	32	21	20.00
315	5	33	22	15.00
316	5	34	23	20.00
317	5	35	24	20.00
318	5	36	25	15.00
319	5	38	26	20.00
320	6	38	1	25.00
321	6	36	2	20.00
322	6	35	3	25.00
323	6	34	4	25.00
324	6	33	5	20.00
325	6	32	6	25.00
326	6	31	7	20.00
327	6	30	8	20.00
328	6	29	9	15.00
329	6	28	10	20.00
330	6	27	11	20.00
331	6	26	12	20.00
332	6	25	13	15.00
333	6	24	14	15.00
334	6	1	15	25.00
335	6	22	16	25.00
336	6	21	17	15.00
337	6	20	18	25.00
338	6	19	19	20.00
339	6	18	20	40.00
340	6	17	21	0.00
347	7	38	7	0.00
348	8	38	1	40.00
349	8	29	2	35.00
350	8	25	3	40.00
351	8	1	4	45.00
352	8	17	5	35.00
353	8	12	6	50.00
354	8	10	7	45.00
355	8	8	8	40.00
356	8	6	9	50.00
357	8	3	10	35.00
358	8	2	11	0.00
359	9	38	1	25.00
360	9	29	2	25.00
361	9	25	3	30.00
362	9	1	4	25.00
363	9	22	5	30.00
364	9	20	6	25.00
365	9	19	7	20.00
366	9	18	8	25.00
367	9	17	9	35.00
368	9	16	10	15.00
369	9	15	11	35.00
370	9	14	12	25.00
371	9	39	13	20.00
372	9	13	14	25.00
373	9	12	15	0.00
374	10	38	1	25.00
375	10	36	2	25.00
376	10	35	3	20.00
223	1	26	4	15.00
245	2	1	11	30.00
259	4	3	2	20.00
228	1	31	9	15.00
231	1	34	12	15.00
236	2	39	2	15.00
263	4	7	6	15.00
248	2	26	14	20.00
249	2	27	15	30.00
251	2	29	17	25.00
252	2	30	18	35.00
246	2	24	12	30.00
247	2	25	13	30.00
264	4	8	7	16.00
254	3	1	1	90.00
255	3	25	2	80.00
256	3	29	3	50.00
265	4	9	8	15.00
268	4	12	11	15.00
266	4	10	9	14.00
306	5	25	13	10.00
286	4	30	29	15.00
287	4	31	30	10.00
288	4	32	31	10.00
289	4	33	32	10.00
290	4	34	33	10.00
283	4	27	26	30.00
298	5	15	5	10.00
296	5	39	3	15.00
299	5	16	6	10.00
297	5	14	4	10.00
294	5	12	1	10.00
303	5	20	10	10.00
302	5	19	9	10.00
310	5	29	17	10.00
313	5	32	20	10.00
377	10	34	4	25.00
378	10	33	5	30.00
379	10	32	6	30.00
380	10	31	7	15.00
381	10	30	8	30.00
382	10	29	9	20.00
383	10	28	10	15.00
384	10	27	11	25.00
385	10	26	12	15.00
386	10	25	13	25.00
387	10	24	14	15.00
388	10	1	15	0.00
230	1	33	11	15.00
232	1	35	13	10.00
267	4	11	10	10.00
270	4	39	13	10.00
273	4	16	16	10.00
278	4	21	21	10.00
285	4	29	28	10.00
295	5	13	2	10.00
300	5	17	7	10.00
301	5	18	8	10.00
307	5	26	14	10.00
312	5	31	19	10.00
341	7	12	1	45.00
342	7	17	2	45.00
344	7	1	4	55.00
343	7	19	3	85.00
345	7	25	5	80.00
346	7	29	6	85.00
\.


--
-- Data for Name: schedule; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schedule (schedule_id, train_id, route_id, departure_time, arrival_time, station_id) FROM stdin;
170	1	1	04:47:00	\N	1
171	1	1	04:56:00	04:55:00	24
172	1	1	05:00:00	04:59:00	25
173	1	1	05:03:00	05:02:00	26
174	1	1	05:05:00	05:04:00	27
175	1	1	05:08:00	05:07:00	28
176	1	1	05:14:00	05:14:00	29
177	1	1	05:17:00	05:17:00	30
178	1	1	05:19:00	05:18:00	31
179	1	1	05:22:00	05:22:00	32
180	1	1	05:25:00	05:24:00	33
181	1	1	05:28:00	05:27:00	34
182	1	1	05:32:00	05:32:00	35
183	1	1	05:37:00	05:36:00	36
184	1	1	\N	05:50:00	38
185	2	2	03:30:00	\N	12
186	2	2	03:39:00	03:38:00	39
187	2	2	03:44:00	03:43:00	14
188	2	2	03:48:00	03:47:00	15
189	2	2	03:52:00	03:51:00	16
190	2	2	03:55:00	03:54:00	17
191	2	2	04:02:00	04:01:00	18
192	2	2	04:06:00	04:05:00	19
193	2	2	04:08:00	04:07:00	20
194	2	2	04:12:00	04:11:00	21
195	2	2	04:20:00	04:19:00	1
196	2	2	04:29:00	04:28:00	24
197	2	2	04:33:00	04:32:00	25
198	2	2	04:36:00	04:35:00	26
199	2	2	04:39:00	04:38:00	27
200	2	2	04:41:00	04:40:00	28
201	2	2	04:46:00	04:45:00	29
202	2	2	04:49:00	04:48:00	30
203	2	2	\N	05:11:00	38
204	3	3	04:12:00	\N	1
205	3	3	04:21:00	04:20:00	25
206	3	3	04:30:00	04:29:00	29
207	3	3	\N	04:47:00	38
208	4	4	04:14:00	\N	2
209	4	4	04:24:00	04:23:00	3
210	4	4	04:30:00	04:29:00	4
211	4	4	04:35:00	04:34:00	5
212	4	4	04:41:00	04:40:00	6
213	4	4	04:45:00	04:44:00	7
214	4	4	04:52:00	04:51:00	8
215	4	4	04:58:00	04:57:00	9
216	4	4	05:03:00	05:02:00	10
217	4	4	05:09:00	05:08:00	11
218	4	4	05:16:00	05:15:00	12
219	4	4	05:20:00	05:19:00	13
220	4	4	05:24:00	05:23:00	39
221	4	4	05:29:00	05:28:00	14
222	4	4	05:33:00	05:32:00	15
223	4	4	05:37:00	05:36:00	16
224	4	4	05:41:00	05:40:00	17
225	4	4	05:48:00	05:47:00	18
226	4	4	05:52:00	05:51:00	19
227	4	4	05:55:00	05:54:00	20
228	4	4	05:59:00	05:58:00	21
229	4	4	06:07:00	06:06:00	1
230	4	4	06:16:00	06:15:00	24
231	4	4	06:20:00	06:19:00	25
232	4	4	06:23:00	06:22:00	26
233	4	4	06:25:00	06:24:00	27
234	4	4	06:28:00	06:27:00	28
235	4	4	06:34:00	06:33:00	29
236	4	4	06:37:00	06:36:00	30
237	4	4	06:39:00	06:38:00	31
238	4	4	06:42:00	06:41:00	32
239	4	4	06:45:00	06:44:00	33
240	4	4	06:48:00	06:47:00	34
241	4	4	06:52:00	06:51:00	35
242	4	4	06:57:00	06:56:00	36
243	4	4	\N	07:10:00	38
244	5	5	04:34:00	\N	12
245	5	5	04:41:00	04:40:00	13
246	5	5	04:45:00	04:44:00	39
247	5	5	04:50:00	04:49:00	14
248	5	5	04:54:00	04:53:00	15
249	5	5	04:58:00	04:57:00	16
250	5	5	05:01:00	05:00:00	17
251	5	5	05:09:00	05:08:00	18
252	5	5	05:13:00	05:12:00	19
253	5	5	05:16:00	05:15:00	20
254	5	5	05:27:00	05:26:00	1
255	5	5	05:36:00	05:35:00	24
256	5	5	05:40:00	05:39:00	25
257	5	5	05:43:00	05:42:00	26
258	5	5	05:45:00	05:44:00	27
259	5	5	05:48:00	05:47:00	28
260	5	5	05:54:00	05:53:00	29
261	5	5	05:57:00	05:56:00	30
262	5	5	05:59:00	05:58:00	31
263	5	5	06:02:00	06:01:00	32
264	5	5	06:05:00	06:04:00	32
265	5	5	06:08:00	06:07:00	33
266	5	5	06:12:00	06:11:00	34
267	5	5	06:17:00	06:16:00	35
268	5	5	06:19:00	06:18:00	36
269	5	5	\N	06:34:00	38
270	6	6	06:57:00	\N	38
271	6	6	07:07:00	07:06:00	36
272	6	6	07:10:00	07:09:00	35
273	6	6	07:13:00	07:12:00	34
274	6	6	07:16:00	07:15:00	33
275	6	6	07:19:00	07:18:00	32
276	6	6	07:22:00	07:21:00	31
277	6	6	07:24:00	07:23:00	30
278	6	6	07:27:00	07:26:00	29
279	6	6	07:33:00	07:32:00	28
280	6	6	07:36:00	07:35:00	27
281	6	6	07:39:00	07:38:00	26
282	6	6	07:42:00	07:41:00	25
283	6	6	07:46:00	07:45:00	24
284	6	6	07:56:00	07:55:00	1
285	6	6	08:00:00	07:59:00	22
286	6	6	08:04:00	08:03:00	21
287	6	6	08:08:00	08:07:00	20
288	6	6	08:11:00	08:10:00	19
289	6	6	08:15:00	08:14:00	18
290	6	6	\N	07:17:00	17
291	7	7	06:27:00	\N	12
292	7	7	06:40:00	06:39:00	17
293	7	7	06:48:00	06:47:00	19
294	7	7	06:56:00	06:55:00	1
295	7	7	07:04:00	07:03:00	25
296	7	7	07:13:00	07:12:00	29
297	7	7	\N	07:30:00	38
298	8	8	05:04:00	05:03:00	38
299	8	8	05:19:00	05:18:00	29
300	8	8	05:27:00	05:26:00	25
301	8	8	05:33:00	05:32:00	1
302	8	8	05:46:00	05:45:00	17
303	8	8	06:01:00	06:00:00	12
304	8	8	06:10:00	06:09:00	10
305	8	8	06:19:00	06:18:00	8
306	8	8	06:27:00	06:26:00	6
307	8	8	06:38:00	06:37:00	3
308	8	8	\N	06:47:00	2
309	9	9	04:27:00	\N	38
310	9	9	04:46:00	04:45:00	29
311	9	9	04:55:00	04:54:00	25
312	9	9	05:04:00	05:03:00	1
313	9	9	05:08:00	05:07:00	22
314	9	9	05:14:00	05:13:00	20
315	9	9	05:17:00	05:16:00	19
316	9	9	05:21:00	05:20:00	18
317	9	9	05:28:00	05:27:00	17
318	9	9	05:31:00	05:30:00	16
319	9	9	05:35:00	05:34:00	15
320	9	9	05:39:00	05:38:00	14
321	9	9	05:45:00	05:44:00	39
322	9	9	05:49:00	05:48:00	13
323	9	9	\N	05:56:00	12
324	10	10	00:17:00	\N	38
325	10	10	00:27:00	00:26:00	36
326	10	10	00:30:00	00:29:00	35
327	10	10	00:33:00	00:32:00	34
328	10	10	00:36:00	00:35:00	33
329	10	10	00:39:00	00:38:00	32
330	10	10	00:42:00	00:41:00	31
331	10	10	00:44:00	00:43:00	30
332	10	10	00:47:00	00:48:00	29
333	10	10	00:53:00	00:52:00	28
334	10	10	00:56:00	00:55:00	27
335	10	10	00:59:00	00:58:00	26
336	10	10	01:02:00	01:01:00	25
337	10	10	01:06:00	01:05:00	24
338	10	10	\N	01:15:00	1
\.


--
-- Data for Name: stations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stations (station_id, station_name, train_platform_amount, self_checkout) FROM stdin;
1	Зеленоград-Крюково	4	t
2	Тверь	4	t
3	Пл. Чуприняновка	2	t
4	Пл. Кузьминка	2	t
5	Пл. Межево	2	f
6	Редкино	2	t
7	Пл. Московское море	2	f
8	Завидово	2	t
9	Пл. Черничная	2	f
10	Решетниково	2	t
11	Пл. Ямуга	2	f
12	Клин	2	t
13	пл. Стреглово	2	f
14	пл. Покровка	2	f
15	пл. Головково	2	f
16	пл. Сенеж	2	f
17	Подсолнечная	2	t
18	пл. Березки-Дачные	2	f
19	Поварово-1	2	t
20	пл. Поваровка	2	f
21	пл. Радищево	2	f
22	пл. Алабушево	2	f
23	пл. Малино	2	f
24	пл. Фирсановская	2	f
25	Сходня	2	t
26	пл. Подрезково	2	f
27	пл. Новоподрезково	2	f
28	пл. Молжаниново	2	f
29	Химки	3	t
30	пл. Левобережная	2	f
31	пл. Ховрино	2	f
32	Грачёвская	2	f
33	пл. Моссельмаш	2	f
34	пл. Лихоборы	2	f
35	пл. Петровско-Разумовская	2	f
36	пл. Останкино	2	f
37	пл. Рижская	2	f
38	Москва Ленинградская	9	t
39	пл.Фроловское	2	f
\.


--
-- Data for Name: tickets; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tickets (ticket_id, user_id, route_id, from_station_id, to_station_id, date, price, total_price, train_type) FROM stdin;
1	1	8	38	12	2023-12-14	145.00	0.00	Ласточка
6	1	8	38	1	2023-11-14	90.00	0.00	Ласточка
7	2	8	38	1	2023-11-14	90.00	90.00	Ласточка
8	2	8	38	1	2023-11-14	90.00	45.00	Обычная
9	3	8	38	1	2023-11-14	90.00	180.00	Ласточка
11	8	3	1	38	2024-12-15	95.00	95.00	Комфорт
12	8	4	1	38	2024-12-15	345.00	345.00	Обычная
13	8	5	1	38	2024-12-15	300.00	300.00	Комфорт
14	8	1	1	38	2024-12-15	590.00	590.00	Комфорт
15	8	1	1	38	2024-12-15	590.00	590.00	Комфорт
16	8	1	1	38	2024-12-15	590.00	590.00	Комфорт
17	8	1	1	38	2024-12-15	590.00	590.00	Комфорт
18	8	1	1	38	2024-12-15	590.00	590.00	Комфорт
19	8	1	1	38	2024-12-15	590.00	590.00	Комфорт
20	8	1	1	38	2024-12-15	590.00	590.00	Комфорт
21	8	1	1	38	2024-12-15	590.00	590.00	Комфорт
22	8	2	1	38	2024-12-15	370.00	370.00	Комфорт
23	8	1	1	38	2024-12-15	590.00	590.00	Комфорт
24	8	2	1	38	2024-12-15	370.00	370.00	Комфорт
25	8	1	1	38	2024-12-15	590.00	590.00	Комфорт
26	8	4	2	38	2024-12-15	995.00	995.00	Обычная
27	8	4	2	38	2024-12-15	995.00	995.00	Обычная
28	8	4	2	38	2024-12-15	995.00	995.00	Обычная
29	8	4	2	38	2024-12-15	995.00	995.00	Обычная
30	8	4	2	38	2024-12-15	995.00	995.00	Обычная
33	8	4	2	3	2024-12-15	20.00	20.00	Обычная
34	8	4	2	3	2024-12-15	20.00	20.00	Обычная
35	8	3	1	38	2024-12-15	95.00	95.00	Комфорт
36	8	7	1	38	2024-12-15	80.00	160.00	Ласточка
37	8	4	1	38	2024-12-15	345.00	345.00	Обычная
38	8	3	1	38	2024-12-15	95.00	95.00	Комфорт
39	8	4	1	38	2024-12-15	345.00	345.00	Обычная
40	8	4	2	8	2024-12-16	220.00	220.00	Обычная
41	8	2	12	1	2024-12-17	600.00	600.00	Комфорт
42	8	2	12	1	2024-12-17	600.00	600.00	Комфорт
43	8	5	12	1	2024-12-17	200.00	200.00	Комфорт
44	8	2	12	38	2024-12-17	970.00	970.00	Комфорт
45	8	1	1	38	2024-12-17	590.00	590.00	Комфорт
46	8	4	2	5	2024-12-17	90.00	90.00	Обычная
47	8	4	2	5	2024-12-17	90.00	90.00	Обычная
48	8	7	1	38	2024-12-17	80.00	160.00	Ласточка
49	8	9	1	12	2024-12-17	370.00	370.00	Комфорт
50	8	4	2	4	2024-12-17	50.00	50.00	Обычная
51	8	7	1	38	2024-12-17	80.00	160.00	Ласточка
52	11	8	1	2	2024-12-18	240.00	240.00	Ласточка
53	12	4	2	30	2024-12-18	800.00	400.00	Обычная
54	12	4	2	30	2024-12-18	800.00	400.00	Обычная
55	12	4	1	38	2024-12-18	345.00	172.50	Обычная
59	16	4	2	38	2024-12-18	995.00	497.50	Обычная
73	8	7	1	38	2024-12-18	80.00	160.00	Ласточка
78	8	3	1	38	2024-12-18	75.00	75.00	Комфорт
79	8	7	1	38	2024-12-18	155.00	310.00	Ласточка
80	8	7	1	38	2024-12-18	155.00	310.00	Ласточка
81	8	7	1	38	2024-12-20	155.00	310.00	Ласточка
82	8	4	2	38	2024-12-20	700.00	700.00	Обычная
83	8	7	1	38	2024-12-20	155.00	310.00	Ласточка
84	8	7	1	38	2024-12-20	155.00	310.00	Ласточка
88	33	5	1	38	2024-12-20	250.00	0.00	Комфорт
89	8	5	1	38	2024-12-20	250.00	250.00	Комфорт
90	8	7	1	38	2024-12-20	155.00	310.00	Ласточка
92	8	4	2	38	2024-12-20	700.00	700.00	Обычная
94	8	1	1	38	2024-12-20	235.00	235.00	Комфорт
95	8	7	1	38	2024-12-21	155.00	310.00	Ласточка
96	8	1	1	38	2024-12-21	225.00	225.00	Комфорт
97	8	2	1	38	2024-12-21	220.00	220.00	Комфорт
98	8	7	1	38	2024-12-21	220.00	440.00	Ласточка
99	8	4	1	38	2024-12-21	220.00	220.00	Обычная
\.


--
-- Data for Name: trains; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.trains (train_id, train_number, type, carriage_amount) FROM stdin;
1	6503	Комфорт	10
2	6501	Комфорт	10
3	6301	Комфорт	10
5	6505	Комфорт	10
6	6402	Комфорт	10
7	7901	Ласточка	10
8	7922	Ласточка	10
9	6502	Комфорт	10
10	6802	Комфорт	10
4	6701	Обычная	8
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (user_id, first_name, last_name, mail, phone_number, date_of_reg, money, transport_concession, user_password) FROM stdin;
23	sadfg	adfsgh	dsfgh@dsffg.dsfg	8-999-999-00-00	2024-12-18	219.00	без льгот	1234567890
2	Артемон	Высоцкикус	abobusasus@mail.ru	8-915-305-32-30	2024-12-15	12312.00	пол цены	3282e90d7367d4b473024eca40072cd1
3	Артемон	Бубрерушкав	abobdfssd@mail.ru	8-915-676-45-33	2024-12-15	12312.00	без льгот	993c15fb02b6e242919009c6da68d84b
34	asadas	asds	ads@adsad.sads	7-888-888-88-88	2024-12-20	718.00	пол цены	123
6	Афелий	прерправ	abobdfssd@gmail.com	8-915-696-45-33	2024-12-15	12312.00	без льгот	6e4ab49df504ef55a73832b957cc6604
12	asdfgh	asdfgh	asdfgh@asdfgh.asdfg	8-999-996-96-96	2024-12-18	494.50	пол цены	1234567890
15	werstd	qswfrdg	qerwt@dfsg.wefrg	8-343-333-21-11	2024-12-18	421.00	пол цены	123
16	фывап	фваыпварп	asdfg@asdff.dfg	8-333-333-33-33	2024-12-18	412.50	пол цены	12345
17	sdfghjk	szdfgchvknlm	sdxfcgvhj@sdfghjk.dxfcgvhjlk	8-444-444-44-44	2024-12-18	719.00	без льгот	1234567
19	dfxgchlk	frezrftgyiok	szdxfgchj@fcgv.dfghjlk	8-888-888-88-88	2024-12-18	1234568762.00	без льгот	waerstdguoij
25	aqsdfrthj	afsdr	adf@FGHJK.DFGHJK	8-999-999-34-34	2024-12-20	378.00	бесплатно	1234567
28	QSSDFG	SFDG	SDFDG@ASGD.DFG	8-999-999-92-22	2024-12-20	894.00	пол цены	WSDGNB
31	ваыпр	выапр	asdf@afdsgd.dsfg	8-777-777-77-77	2024-12-20	109.00	пол цены	123
32	ввуап	ывапро	asdfg@afsgdthjgh.srdtfg	3-333-333-33-33	2024-12-20	177.00	бесплатно	123
1	Андрэээээээээ	Буланов	bulashvili@mail.ru	8-999-999-99-99	2024-12-12	1020.00	бесплатно	84e21234847f23762e63bad77d5d4571
11	asdfg	asdfg	asdf@mail.ru	8-912-122-11-11	2024-12-18	535.00	пол цены	1456
38	sdgdfgd	dfgdfg	ad@asdsa.gdg	3-333-222-22-22	2024-12-21	320.00	бесплатно	123
8	Андрей	Колыванов	123@mail.ru	8-915-696-45-36	2024-12-15	8267.00	без льгот	123
33	фвавыа	ываы	sadas@mail.ru	1-111-111-11-11	2024-12-20	970.00	бесплатно	123
\.


--
-- Name: routes_route_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.routes_route_id_seq', 21, true);


--
-- Name: routestations_routestation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.routestations_routestation_id_seq', 388, true);


--
-- Name: schedule_schedule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.schedule_schedule_id_seq', 338, true);


--
-- Name: stations_station_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stations_station_id_seq', 38, true);


--
-- Name: tickets_ticket_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tickets_ticket_id_seq', 99, true);


--
-- Name: trains_train_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.trains_train_id_seq', 18, true);


--
-- Name: users_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_user_id_seq', 38, true);


--
-- Name: routes routes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.routes
    ADD CONSTRAINT routes_pkey PRIMARY KEY (route_id);


--
-- Name: routestations routestations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.routestations
    ADD CONSTRAINT routestations_pkey PRIMARY KEY (routestation_id);


--
-- Name: schedule schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT schedule_pkey PRIMARY KEY (schedule_id);


--
-- Name: stations stations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stations
    ADD CONSTRAINT stations_pkey PRIMARY KEY (station_id);


--
-- Name: stations stations_station_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stations
    ADD CONSTRAINT stations_station_name_key UNIQUE (station_name);


--
-- Name: tickets tickets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_pkey PRIMARY KEY (ticket_id);


--
-- Name: trains trains_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trains
    ADD CONSTRAINT trains_pkey PRIMARY KEY (train_id);


--
-- Name: users users_mail_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_mail_key UNIQUE (mail);


--
-- Name: users users_phone_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_number_key UNIQUE (phone_number);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: idx_routestations_route_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_routestations_route_id ON public.routestations USING btree (route_id);


--
-- Name: idx_routestations_station_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_routestations_station_id ON public.routestations USING btree (station_id);


--
-- Name: tickets ticket_purchase_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ticket_purchase_trigger AFTER INSERT ON public.tickets FOR EACH ROW EXECUTE FUNCTION public.update_user_money();


--
-- Name: tickets trigger_calculate_ticket_price; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_calculate_ticket_price BEFORE INSERT OR UPDATE ON public.tickets FOR EACH ROW EXECUTE FUNCTION public.calculate_ticket_price();


--
-- Name: routes fk_end_station; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.routes
    ADD CONSTRAINT fk_end_station FOREIGN KEY (end_station_id) REFERENCES public.stations(station_id);


--
-- Name: tickets fk_from_station; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT fk_from_station FOREIGN KEY (from_station_id) REFERENCES public.stations(station_id);


--
-- Name: routestations fk_route; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.routestations
    ADD CONSTRAINT fk_route FOREIGN KEY (route_id) REFERENCES public.routes(route_id);


--
-- Name: tickets fk_route; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT fk_route FOREIGN KEY (route_id) REFERENCES public.routes(route_id);


--
-- Name: schedule fk_route_schedule; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT fk_route_schedule FOREIGN KEY (route_id) REFERENCES public.routes(route_id);


--
-- Name: routes fk_start_station; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.routes
    ADD CONSTRAINT fk_start_station FOREIGN KEY (start_station_id) REFERENCES public.stations(station_id);


--
-- Name: routestations fk_station; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.routestations
    ADD CONSTRAINT fk_station FOREIGN KEY (station_id) REFERENCES public.stations(station_id);


--
-- Name: schedule fk_station; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT fk_station FOREIGN KEY (station_id) REFERENCES public.stations(station_id);


--
-- Name: tickets fk_to_station; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT fk_to_station FOREIGN KEY (to_station_id) REFERENCES public.stations(station_id);


--
-- Name: schedule fk_train; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT fk_train FOREIGN KEY (train_id) REFERENCES public.trains(train_id);


--
-- Name: tickets fk_user; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES public.users(user_id);


--
-- PostgreSQL database dump complete
--

