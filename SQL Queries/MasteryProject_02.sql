/*
01_cohort_qc_02_booking_rates.sql
Zweck: Prüfung, wie viele Cohort-User tatsächlich Buchungen haben
Output: Anzahl und Anteil von Usern mit mind. einer Flug- oder Hotelbuchung
*/

WITH sessions_scoped AS (                                        -- Einschränkung auf Cohort-Zeitfenster
  SELECT
    user_id,                                                     -- Auswahl der user_id
    flight_booked,                                               -- Flag für Flugbuchung
    hotel_booked                                                 -- Flag für Hotelbuchung
  FROM sessions                                                  -- Datenquelle: sessions
  WHERE session_start >= TIMESTAMP '2023-01-04 00:00:00'          -- Filter auf Sessions ab 2023-01-04
),
user_session_counts AS (                                         -- Zählung der Sessions pro User
  SELECT
    user_id,                                                     -- Gruppierungs-Schlüssel
    COUNT(*) AS session_count                                    -- Session-Anzahl pro User
  FROM sessions_scoped                                           -- Nutzung der gefilterten Sessions
  GROUP BY
    user_id                                                      -- Aggregation auf User-Level
),
cohort AS (                                                       -- Cohort nach Elena: >7 Sessions
  SELECT
    user_id                                                      -- Ausgabe der user_id
  FROM user_session_counts                                       -- Nutzung der Session-Counts
  WHERE session_count > 7                                        -- Filter auf aktive User
),
user_booking_flags AS (                                          -- Ableitung, ob pro User jemals gebucht wurde
  SELECT
    s.user_id,                                                   -- User-ID
    MAX(CASE WHEN s.flight_booked IS TRUE THEN 1 ELSE 0 END) 
      AS has_flight_booking,                                     -- Indikator: mind. ein Flug gebucht
    MAX(CASE WHEN s.hotel_booked IS TRUE THEN 1 ELSE 0 END) 
      AS has_hotel_booking                                       -- Indikator: mind. ein Hotel gebucht
  FROM sessions_scoped s                                         -- Nutzung der gefilterten Sessions
  JOIN cohort c ON c.user_id = s.user_id                          -- Einschränkung auf Cohort-User
  GROUP BY
    s.user_id                                                    -- Aggregation auf User-Level
)
SELECT
  COUNT(*) AS cohort_users,                                      -- Anzahl User in der Cohort
  SUM(CASE WHEN (has_flight_booking = 1 OR has_hotel_booking = 1) THEN 1 ELSE 0 END)
    AS users_with_any_booking,                                   -- Anzahl User mit mind. einer Buchung
  ROUND(
    100.0 * SUM(CASE WHEN (has_flight_booking = 1 OR has_hotel_booking = 1) THEN 1 ELSE 0 END) 
    / NULLIF(COUNT(*), 0),
    2
  ) AS pct_users_with_any_booking,                               -- Anteil (%) User mit mind. einer Buchung
  SUM(CASE WHEN has_flight_booking = 1 THEN 1 ELSE 0 END)
    AS users_with_flight_booking,                                -- Anzahl User mit mind. einer Flugbuchung
  SUM(CASE WHEN has_hotel_booking = 1 THEN 1 ELSE 0 END)
    AS users_with_hotel_booking                                  -- Anzahl User mit mind. einer Hotelbuchung
FROM user_booking_flags;                                         -- Datenquelle: User-Booking-Flags