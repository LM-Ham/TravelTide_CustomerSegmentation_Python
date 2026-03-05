/*
01_cohort_qc_03_cancellation_share.sql
Zweck: Prüfung der Cancellation-Lastigkeit in der Cohort
Output: Anteil Cancellation-Sessions und Anteil User mit mindestens einer Cancellation-Session
*/

WITH sessions_scoped AS (                                        -- Einschränkung auf Cohort-Zeitfenster
  SELECT
    user_id,                                                     -- User-ID
    cancellation                                                 -- Flag: Session diente der Stornierung
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
cohort_sessions AS (                                             -- Sessions innerhalb der Cohort
  SELECT
    s.user_id,                                                   -- User-ID
    s.cancellation                                               -- Cancellation-Flag
  FROM sessions_scoped s                                         -- Nutzung der gefilterten Sessions
  JOIN cohort c ON c.user_id = s.user_id                          -- Einschränkung auf Cohort-User
),
user_cancellation_flags AS (                                     -- Ableitung pro User: hat Cancellation-Session?
  SELECT
    user_id,                                                     -- User-ID
    MAX(CASE WHEN cancellation IS TRUE THEN 1 ELSE 0 END) 
      AS has_cancellation                                        -- Indikator: mind. eine Cancellation-Session
  FROM cohort_sessions                                           -- Nutzung der Cohort-Sessions
  GROUP BY
    user_id                                                      -- Aggregation auf User-Level
)
SELECT
  COUNT(*) AS cohort_sessions,                                   -- Anzahl Sessions in der Cohort
  SUM(CASE WHEN cancellation IS TRUE THEN 1 ELSE 0 END) 
    AS cancellation_sessions,                                    -- Anzahl Cancellation-Sessions
  ROUND(
    100.0 * SUM(CASE WHEN cancellation IS TRUE THEN 1 ELSE 0 END) 
    / NULLIF(COUNT(*), 0),
    2
  ) AS pct_cancellation_sessions,                                -- Anteil (%) Cancellation-Sessions
  (SELECT COUNT(*) FROM user_cancellation_flags) 
    AS cohort_users,                                             -- Anzahl User in der Cohort
  (SELECT SUM(has_cancellation) FROM user_cancellation_flags) 
    AS users_with_any_cancellation,                              -- Anzahl User mit mind. einer Cancellation-Session
  ROUND(
    100.0 * (SELECT SUM(has_cancellation) FROM user_cancellation_flags) 
    / NULLIF((SELECT COUNT(*) FROM user_cancellation_flags), 0),
    2
  ) AS pct_users_with_any_cancellation                           -- Anteil (%) User mit mind. einer Cancellation-Session
FROM cohort_sessions;                                            -- Datenquelle: Cohort-Sessions