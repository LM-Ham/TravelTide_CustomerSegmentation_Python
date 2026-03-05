/*
01_cohort_qc_threshold_sweep.sql
Zweck: Vergleich verschiedener Session-Schwellenwerte im gleichen Zeitfenster
Output: Cohort-Größe und Buchungsquote je Schwellenwert
*/

WITH sessions_scoped AS (
  SELECT
    user_id,
    flight_booked,
    hotel_booked
  FROM sessions
  WHERE session_start >= TIMESTAMP '2023-01-04 00:00:00'
),
user_stats AS (
  SELECT
    user_id,
    COUNT(*) AS session_count,
    MAX(CASE WHEN (flight_booked IS TRUE OR hotel_booked IS TRUE) THEN 1 ELSE 0 END) AS has_any_booking
  FROM sessions_scoped
  GROUP BY user_id
),
thresholds AS (
  SELECT 3 AS min_sessions UNION ALL
  SELECT 5 UNION ALL
  SELECT 7 UNION ALL
  SELECT 10
)
SELECT
  t.min_sessions,
  COUNT(*) AS cohort_users,
  SUM(CASE WHEN u.has_any_booking = 1 THEN 1 ELSE 0 END) AS users_with_any_booking,
  ROUND(100.0 * SUM(CASE WHEN u.has_any_booking = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS pct_with_any_booking
FROM thresholds t
JOIN user_stats u ON u.session_count > t.min_sessions
GROUP BY t.min_sessions
ORDER BY t.min_sessions;