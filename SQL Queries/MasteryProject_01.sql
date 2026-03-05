/*
01_cohort_qc_01_size_and_sessions.sql
Zweck: Prüfung der Cohort-Größe und Session-Count-Verteilung
Output: Anzahl Cohort-User und Kenngrößen der Session-Anzahl pro User
*/

WITH sessions_scoped AS (                                        -- Einschränkung auf Cohort-Zeitfenster
  SELECT
    user_id                                                      -- Auswahl der user_id zur Aggregation
  FROM sessions                                                  -- Datenquelle: sessions
  WHERE session_start >= TIMESTAMP '2023-01-04 00:00:00'          -- Filter auf Sessions ab 2023-01-04
),
user_session_counts AS (                                         -- Zählung der Sessions pro User im Zeitfenster
  SELECT
    user_id,                                                     -- Gruppierungs-Schlüssel
    COUNT(*) AS session_count                                    -- Berechnung der Session-Anzahl pro User
  FROM sessions_scoped                                           -- Nutzung der gefilterten Sessions
  GROUP BY
    user_id                                                      -- Aggregation auf User-Level
),
cohort AS (                                                       -- Auswahl der Cohort gemäß >7 Sessions
  SELECT
    user_id,                                                     -- Ausgabe der user_id
    session_count                                                -- Ausgabe der Session-Anzahl
  FROM user_session_counts                                       -- Nutzung der User-Session-Zählung
  WHERE session_count > 7                                        -- Filter auf aktive User
)
SELECT
  COUNT(*) AS cohort_users,                                      -- Anzahl User in der Cohort
  MIN(session_count) AS min_sessions,                            -- minimale Session-Anzahl in der Cohort
  PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY session_count) 
    AS median_sessions,                                          -- Median der Session-Anzahl in der Cohort
  PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY session_count) 
    AS p75_sessions,                                             -- 75. Perzentil der Session-Anzahl
  MAX(session_count) AS max_sessions                             -- maximale Session-Anzahl in der Cohort
FROM cohort;                                                     -- Datenquelle: Cohort