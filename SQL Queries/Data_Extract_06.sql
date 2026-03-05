WITH sessions_scoped AS (                                         -- Einschränkung der Sessions auf das Cohort-Zeitfenster
  SELECT
    *
  FROM sessions                                                   -- Datenquelle: sessions
  WHERE session_start >= TIMESTAMP '2023-01-04 00:00:00'          -- Filter auf Sessions ab 2023-01-04
),
user_session_counts AS (                                          -- Zählung der Sessions pro User im Zeitfenster
  SELECT
    user_id,                                                      -- Gruppierungs-Schlüssel
    COUNT(*) AS session_count                                     -- Berechnung der Session-Anzahl pro User
  FROM sessions_scoped                                            -- Nutzung der gefilterten Sessions
  GROUP BY
    user_id                                                       -- Aggregation auf User-Level
),
cohort AS (                                                        -- Baseline-Cohort nach Elena: mehr als 7 Sessions
  SELECT
    user_id                                                       -- Ausgabe der Cohort-User
  FROM user_session_counts                                        -- Nutzung der Session-Counts
  WHERE session_count > 7                                         -- Filter auf aktive User
),
sessions_cohort AS (                                              -- Einschränkung der Sessions auf Cohort-User
  SELECT
    s.*                                                           -- Auswahl aller Session-Spalten
  FROM sessions_scoped s                                          -- Nutzung der gefilterten Sessions
  JOIN cohort c ON c.user_id = s.user_id                           -- Join: nur Cohort-User behalten
)
SELECT
  s.session_id,                                                   -- Session-ID
  s.user_id,                                                      -- User-ID
  s.trip_id,                                                      -- Trip-ID (Join-Schlüssel zu flights/hotels)
  s.session_start,                                                -- Session-Startzeit
  s.session_end,                                                  -- Session-Endzeit
  EXTRACT(EPOCH FROM (s.session_end - s.session_start)) 
    AS session_duration_sec,                                      -- Session-Dauer in Sekunden
  s.page_clicks,                                                  -- Klickanzahl in der Session
  s.flight_discount,                                              -- Flug-Discount angeboten
  s.hotel_discount,                                               -- Hotel-Discount angeboten
  s.flight_discount_amount,                                       -- Flug-Discount-Höhe (Prozent)
  s.hotel_discount_amount,                                        -- Hotel-Discount-Höhe (Prozent)
  s.flight_booked,                                                -- Flug gebucht
  s.hotel_booked,                                                 -- Hotel gebucht
  s.cancellation,                                                 -- Session-Zweck: Storno

  u.birthdate,                                                    -- Geburtsdatum
  u.gender,                                                       -- Geschlecht
  u.married,                                                      -- verheiratet (Flag)
  u.has_children,                                                 -- Kinder (Flag)
  u.home_country,                                                 -- Heimatland
  u.home_city,                                                    -- Heimatstadt
  u.home_airport,                                                 -- Heimatflughafen
  u.home_airport_lat,                                             -- Heimatflughafen Latitude
  u.home_airport_lon,                                             -- Heimatflughafen Longitude
  u.sign_up_date,                                                 -- Registrierungsdatum

  f.destination              AS flight_destination,               -- Flugziel (Stadt)
  f.destination_airport       AS flight_destination_airport,      -- Zielflughafen
  f.seats                     AS flight_seats,                    -- gebuchte Sitzplätze
  f.return_flight_booked      AS flight_return_flight_booked,     -- Rückflug gebucht (Flag)
  f.departure_time            AS flight_departure_time,           -- Abflugzeit
  f.return_time               AS flight_return_time,              -- Rückflugzeit
  f.checked_bags              AS flight_checked_bags,             -- aufgegebene Gepäckstücke
  f.trip_airline              AS flight_airline,                  -- Airline
  f.destination_airport_lat   AS flight_destination_airport_lat,  -- Zielflughafen Latitude
  f.destination_airport_lon   AS flight_destination_airport_lon,  -- Zielflughafen Longitude
  f.base_fare_usd             AS flight_base_fare_usd,            -- Basispreis Flug (pre-discount)

  h.hotel_name                AS hotel_name,                      -- Hotelname (inkl. Zusatzinfos laut Kurs)
  h.nights                    AS hotel_nights,                    -- Nächte (raw, kann anomale Werte enthalten)
  h.rooms                     AS hotel_rooms,                     -- Zimmeranzahl
  h.check_in_time             AS hotel_check_in_time,             -- Check-in
  h.check_out_time            AS hotel_check_out_time,            -- Check-out
  h.hotel_per_room_usd        AS hotel_per_room_usd               -- Preis pro Zimmer pro Nacht (pre-discount)
FROM sessions_cohort s                                             -- Datenquelle: Sessions der Cohort
JOIN users u ON u.user_id = s.user_id                               -- Join: User-Daten anreichern (Pflicht)
LEFT JOIN flights f ON f.trip_id = s.trip_id                         -- Left Join: Flugdaten, falls trip_id vorhanden
LEFT JOIN hotels h ON h.trip_id = s.trip_id;                         -- Left Join: Hoteldaten, falls trip_id vorhanden