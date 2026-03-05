TravelTide Rewards-Personalisierung via Segmentierung und Perk-Zuweisung

Kontext und Ziel
TravelTide möchte die Kundenbindung durch ein personalisiertes Rewards-Programm
verbessern. Zentraler Hebel ist eine Einladungskommunikation, die pro Nutzer das
wahrscheinlich attraktivste Reward-Element hervorhebt (z. B. kostenlose Stornierung,
Discounts, Hotel-Perk). Ziel des Projekts war daher zweigeteilt: (1) in den Daten
nachweisbare Verhaltensmuster identifizieren, die mit unterschiedlichen Perk-Präferenzen
vereinbar sind, und (2) für jeden Nutzer eine favorisierte Perk-Zuweisung ableiten, die sich
nachvollziehbar begründen lässt.

SQL: Kohortendefinition und Extraktion
Warum eine Kohorte und warum “> 7 Sessions”?
Für verhaltensbasierte Personalisierung gilt: zu wenig Daten pro Nutzer ? Personalisierung
wird Zufall. Ein einzelnes Session-Verhalten ist stark situationsabhängig (z. B. spontanes
Stöbern vs. konkrete Buchungsabsicht) und liefert kaum stabile Signale. Daher wurde eine
Kohorte gewählt, die genügend Interaktionen pro Nutzer enthält, um robuste Kennzahlen
(Median/Anteile über Sessions/Trips) zu berechnen.
Die Vorgabe „mehr als 7 Sessions“ (also ? 8 Sessions) erfüllt genau diesen Zweck: Sie stellt
sicher, dass pro Nutzer ausreichend Sessions vorliegen, um z. B. einen stabilen Median der
Sessiondauer oder einen verlässlichen Anteil an Cancellation-Sessions zu berechnen. Im
Datensatz ergab dies eine Kohorte von 5.998 Nutzern und 49.211 Sessions, wobei die
Sessionanzahl pro Nutzer in dieser Kohorte eng begrenzt ist (Median 8, Maximum 12). Das
reduziert außerdem die Verzerrung durch extrem aktive Power-User, die einzelne Segmente
dominieren könnten.

Warum Startdatum 2023-01-04?
Das Datum folgt dem Stakeholder-Vorschlag, eine zeitlich konsistente Beobachtungsperiode
zu nutzen. Ohne Zeitfenster würden Nutzer mit sehr langer Plattformhistorie mit neuen
Nutzern vermischt; Verhalten ändert sich aber systematisch mit der “Tenure” (Erfahrung mit
der Plattform, veränderte Reisegewohnheiten, Saisonalität). Ein fixes Startdatum schafft
Vergleichbarkeit und reduziert zeitbedingte Biases.

Ergebnis der SQL-Phase
Die SQL-Extraktion erzeugte eine Session-Level-Datei (CSV), die Sessions, Buchungsflags,
Discounts, sowie Flight- und Hotel-bezogene Attribute über trip_id zusammenführt. Diese
Session-Basis ist die notwendige Grundlage für alle folgenden Bereinigungs-, Aggregations-
und Feature-Schritte.

Python: Pipeline, Bereinigung und Feature Engineering
Arbeitsweise und eingesetzte Tools
Die Python-Arbeit erfolgte in Colab (reproduzierbar, gut teilbar, CSVs im Drive). Zentrale
Werkzeuge:
* pandas / numpy für Datenhandling, Aggregationen und Feature Engineering
* matplotlib für Visualisierungen
* scikit-learn für Skalierung (StandardScaler) und Clustering (KMeans) sowie Metriken
* Speicherung von Zwischenergebnissen als CSV (processed folder), um die Pipeline
auch nach Runtime-Reset stabil fortsetzen zu können

Datenbereinigung (GIGO-Prinzip)
Mehrere QC-Schritte wurden durchgeführt, um ein “sauberes Datenpaket” zu erzeugen:
1. Hotel-Nights-Anomalien (? 0)
Nights-Werte von 0 oder negativ sind als Aufenthaltsdauer nicht plausibel. Statt diese
Zeilen pauschal zu löschen (Datenverlust) wurden Nights aus Check-in/Check-out
abgeleitet (“inferred nights”).
* Falls eine positive Differenz berechenbar war, wurde hotel_nights_clean
* korrigiert.
* Falls keine sinnvolle Ableitung möglich war, wurde der Wert auf „Missing“ gesetzt.

2. Outlier-Behandlung (Winsorizing)
Statt harte Filter (die viele Nutzer vollständig entfernen könnten) wurde eine
winsorisierte Variante erstellt: numerische Extremwerte wurden auf das 1%- bzw.
99%-Quantil begrenzt. Diese Entscheidung wurde gegen IQR-Logik geprüft (Boxplot-
Idee) und bewusst gewählt, weil sie (a) robust gegenüber Heavy Tails ist und (b)
Datenpunkte nicht entfernt, sondern nur extreme Skalenwirkung reduziert – wichtig
für Distanzverfahren wie KMeans.

3. Typkonvertierung und Normalisierung
Booleans wurden konsistent normalisiert, Datumsfelder als Datetime interpretiert,
numerische Spalten coercion-sicher konvertiert.


4. Missingness-Strategie (Imputation mit Logik)
Missing Values wurden nicht “blind” ersetzt, sondern kontextabhängig:
* Nutzer ohne Flight-Trips: flight-basierte Metriken wurden auf 0 gesetzt (keine
* Flüge ? keine Discounts/Distance/Savings).
* Nutzer ohne Hotel-Trips: hotel-basierte Metriken wurden auf 0 gesetzt (keine
* Hotels ? keine Nights/Rate).
Ziel: Clustering und Scoring sollen mit vollständigen Matrizen arbeiten
können, ohne dass Missingness selbst zum dominanten Signal wird.

Clustering: Vorgehen und Begründung
Feature Set und Skalierung
Das Clustering wurde auf einem Feature Set durchgeführt, das perk-nahe
Verhaltensdimensionen enthält (Discount-/Deal-Signale, Hotel-Intensität, Gepäck/Seats,
Cancellation/Engagement). Da KMeans distanzbasiert ist, wurden die Features mittels
StandardScaler skaliert (Mean ~0, Std ~1).
Wahl von k und Stabilität
Die Clusterzahl wurde nicht willkürlich gewählt. Es wurden mehrere k-Werte evaluiert:
* Inertia/Elbow als Komplexitäts-Tradeoff
* Silhouette Score als Trennschärfe-Indikator
Zusätzlich wurde die Robustheit über verschiedene Seeds geprüft (Adjusted Rand
Index), mit hoher durchschnittlicher Übereinstimmung (~0,87). Daraus wurde k = 4 als
gute Balance aus Interpretierbarkeit und Stabilität übernommen.

Rolle von PCA
PCA wurde unterstützend genutzt, um Cluster in 2D zu visualisieren und grobe Trennbarkeit
zu prüfen (ohne PCA als zwingenden Modellschritt zu behandeln). Die ersten zwei
Komponenten erklärten zusammen rund die Hälfte der Varianz (~0,51), was als plausibel für
eine Verdichtung vieler Verhaltensdimensionen gilt.

Durchschnitts-Personas je Cluster (Steckbrief, Medianwerte)
Die folgenden Kennzahlen sind Medianwerte je Cluster (komprimierter Steckbrief).
cluster_pct beschreibt den Anteil der Nutzer in der Kohorte.
Cluster 0 (8,55% | n=513) – Discount-orientiert
* Sessions: 8 | Sessiondauer: 89s | Klicks: 12 | Cancellation: 0%
* Flights: 2 | Discount-Frequenz: 0,50 | Avg Discount: 0,18 | Bargain Index: 0,01
* Seats: 2 | Checked Bags: 1
* Hotels: 2 | Nights: 2,5 | Rate: 160 | Hotel-Kosten (est.): 1.110
Cluster 1 (45,88% | n=2.752) – Value-orientiert (moderat)
* Sessions: 8 | Sessiondauer: 72,5s | Klicks: 10 | Cancellation: 0%
* Flights: 1 | Discount-Frequenz: 0,00 | Avg Discount: 0,00
* Seats: 1 | Bags: 0
* Hotels: 1 | Nights: 2,5 | Rate: 129 | Hotel-Kosten (est.): 658
Cluster 2 (9,34% | n=560) – Flex/Indecision gemischt
* Sessions: 8 | Sessiondauer: 131,25s | Klicks: 17,25 | Cancellation: 12,5%
* Flights: 3 | Discount-Frequenz: 0,50 | Avg Discount: 0,00
* Seats: 3 | Bags: 2
* Hotels: 2 | Nights: 3,0 | Rate: 146 | Hotel-Kosten (est.): 1.594
Cluster 3 (36,23% | n=2.173) – Hotel-/Trip-intensiv, Value-getrieben
* Sessions: 8 | Sessiondauer: 129s | Klicks: 17,5 | Cancellation: 0%
* Flights: 4 | Discount-Frequenz: 0,00 | Avg Discount: 0,00
* Seats: 4 | Bags: 2
* Hotels: 4 | Nights: 2,5 | Rate: 154 | Hotel-Kosten (est.): 2.113

Perk-Zuweisung: Scoring-Logik und Begründung
Warum Scoring statt “Cluster = Perk”?
Cluster dienen als Archetypen zur Interpretation. Die tatsächliche Rewards-Personalisierung
soll jedoch auf Nutzer-Ebene erfolgen, weil innerhalb eines Clusters relevante Untergruppen
existieren (z. B. Cluster 1 enthält neben “Free night”-Affinen auch Bag- und Cancellation-
affine Nutzer). Scoring ermöglicht eine feinere Zuordnung, ohne die Segment-Story zu
verlieren.

Wie funktionieren die Scores?
Für jeden Nutzer wurden pro Perk Score-Komponenten berechnet und auf 0–1 normalisiert
(MinMax). Beispiele:
* Exclusive Discounts: Kombination aus Discount-Häufigkeit, durchschnittlicher Discount-Höhe, Dollars-saved-per-km (skaliert), Bargain Index.
* No Cancellation Fees: hoher Cancellation-Anteil + lange Sessions + viele Klicks (Indecision-/Flexibilitätssignal).
* Free Checked Bag: Bags pro Seat + Seats (Gruppensignal) + Kinderindikator (Familiennähe).
* Free Hotel Meal: Hotel-Intensität (Trips), längere Aufenthalte (Nights), höheres Preisniveau (Rate).
* 1 Night Free Hotel with Flight: Hotel-Intensität + Stay-Länge + “Value”-Signal über niedrigere Hotelrate + Deal-Orientierung.
Der Perk mit dem höchsten Score wird zugewiesen.

Warum Eligibility/Gating?
Ein wichtiger Qualitäts-Schritt war, Perks nur dann “gewinnbar” zu machen, wenn
entsprechende Verhaltensdaten existieren:
* Hotel-Perks nur bei hotel_trips_count > 0
* Discounts/Bag nur bei flight_trips_count > 0, Bag zusätzlich nur bei seats_sum > 0
* Cancellation-Perk nur bei pct_cancellation_sessions > 0
Damit wird verhindert, dass ein Perk durch Imputation (z. B. Hotelrate = 0 bei Nicht-Hotel-
Nutzern) künstlich Vorteile erhält. Nach Gating ergibt sich eine plausiblere Gesamtverteilung
(u. a. steigt “no_cancellation_fees” deutlich).

Ergebnis: Perk-Verteilung je Cluster (Top-Perk-Anteile)
* Cluster 0: exclusive_discounts (49,9%)
* Cluster 1: one_night_free_hotel_with_flight (56,5%)
* Cluster 2: one_night_free… (33,9%) knapp vor no_cancellation_fees (32,3%) ? idealer A/B-Test-Kandidat
* Cluster 3: one_night_free… (73,8%)

Fazit und Empfehlung
Fazit
Das Projekt liefert eine reproduzierbare Pipeline von SQL-Extraktion über Bereinigung,
Feature Engineering, stabile Segmentierung (k=4) und nachvollziehbare Perk-Zuweisung pro
Nutzer. Die Segmente sind interpretierbar (Discount-, Value-, Flex-/Indecision-, Intensiv-
Reisende), und die Perks sind datenbasiert abgeleitet statt rein intuitiv vergeben.
Live-Test: KPIs und Experimentdesign
Um den Erfolg nach Launch zu prüfen, sollten Metriken entlang einer klaren Wirkungskette
gemessen werden:
E-Mail / Rewards Signup (kurzfristig)
* Open Rate, CTR (Call-to-Action)
* Signup-Rate Rewards-Programm (Overall + je Perk + je Cluster)
Verhalten (mittel-/langfristig)
* Booking Conversion nach Email (z. B. 7/14/30 Tage)
* Wiederbuchung / Retention (30/60/90 Tage)
* Stornoquote nach Einführung (insbesondere für Cancellation-Perk)
* Durchschnittlicher Deckungsbeitrag pro Buchung (Profitabilität, nicht nur Umsatz)
Experimentempfehlung
* A/B-Test im Cluster 2: No cancellation fees vs. One night free (Top-2 nahezu gleich stark)
* Kontrollgruppe: generische Email ohne Perk-Personalisierung, um uplift zu messen

Skalierung / Ausbau
Das aktuelle Setup ist bewusst auf eine “datenstarke” Kohorte fokussiert. Ein realistischer
Ausbau wäre:
1. Schrittweise Kohortenerweiterung
* Test mit ?5 Sessions (größer, aber noisiger) und Vergleich der Stabilität
* Einführung eines “cold start”-Pfads: Nutzer mit wenigen Sessions erhalten zunächst eine konservative Default-Strategie (z. B. clusterbasierte Wahrscheinlichkeiten oder einfache Regeln), bis genug Daten vorliegen
2. Score-Weiterentwicklung
* Gewichte datengetrieben nachjustieren (z. B. anhand der KPI-Uplifts pro Perk)
* Ergänzende Features: Saisonalität, Reisedistanz-Profile, Return-Flight-Verhalten, Hotel-Comfort vs Budget
3. Kosten-/ROI-Modell
* Perk-Kosten gegenüber Retention-Uplift abbilden (z. B. free night ist teuer ? gezielte Anwendung bei hoher erwarteter Wirkung)
