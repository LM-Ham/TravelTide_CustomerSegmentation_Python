/*
01_cohort_qc_04_compare_baseline_vs_booking.sql
Zweck: Vergleich der Cohort-Größe zwischen Baseline und zusätzlichem Buchungsfilter
Output: User-Anzahl je Cohort-Variante
*/

WITH sessions_scoped AS (                                        -- Einschränkung auf Cohort-Zeitfenster
  SELECT
    user_id,                                                     -- User-ID
    flight_booked,                                               -- Flugbuchung-Flag
    hotel_booked                                                 -- Hotelbuchung-Flag
  FROM sessions                                                  -- Datenquelle: sessions
  WHERE session_start >= TIMESTAMP '2023-01-04 00:00:00'          -- Filter auf Sessions ab 2023-01-04
),
user_counts AS (                                                 -- Zählung der Sessions pro User
  SELECT
    user_id,                                                     -- Gruppierungs-Schlüssel
    COUNT(*) AS session_count                                    -- Session-Anzahl pro User
  FROM sessions_scoped                                           -- Nutzung der gefilterten Sessions
  GROUP BY
    user_id                                                      -- Aggregation auf User-Level
),
baseline_cohort AS (                                             -- Baseline-Cohort nach Elena
  SELECT
    user_id                                                      -- User-ID
  FROM user_counts                                               -- Nutzung der Session-Counts
  WHERE session_count > 7                                        -- Filter auf aktive User
),
booking_flags AS (                                               -- Ableitung: mind. eine Buchung pro User?
  SELECT
    s.user_id,                                                   -- User-ID
    MAX(CASE WHEN (s.flight_booked IS TRUE OR s.hotel_booked IS TRUE) THEN 1 ELSE 0 END)
      AS has_any_booking                                         -- Indikator: mind. eine Buchung
  FROM sessions_scoped s                                         -- Nutzung der gefilterten Sessions
  JOIN baseline_cohort b ON b.user_id = s.user_id                 -- Einschränkung auf Baseline-Cohort
  GROUP BY
    s.user_id                                                    -- Aggregation auf User-Level
),
booking_cohort AS (                                              -- Alternative Cohort: Baseline + mind. eine Buchung
  SELECT
    user_id                                                      -- User-ID
  FROM booking_flags                                             -- Nutzung der Booking-Flags
  WHERE has_any_booking = 1                                      -- Filter auf User mit mind. einer Buchung
)
SELECT
  (SELECT COUNT(*) FROM baseline_cohort) AS baseline_users,       -- Größe der Baseline-Cohort
  (SELECT COUNT(*) FROM booking_cohort) AS booking_users;         -- Größe der Alternative (Baseline + Buchung)