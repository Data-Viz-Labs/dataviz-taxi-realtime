Aquí lo tienes listo para **copiar y pegar directamente en un `.md`**:

---

# 🚕 Taxi Trips Simulation – Data Dictionary

## 1️⃣ Trips Fact Table (`df_trips`)

This table contains one record per taxi trip. Each row represents a single completed journey.

---

### Core Identifiers & Raw Fields

| Column           | Type                | Description                                                                                |
| ---------------- | ------------------- | ------------------------------------------------------------------------------------------ |
| **TRIP_ID**      | String              | Unique identifier for each trip.                                                           |
| **CALL_TYPE**    | Categorical (A/B/C) | Service request type: A = dispatched via call center/app; B = taxi stand; C = street hail. |
| **ORIGIN_CALL**  | Integer (nullable)  | Identifier of the phone call when CALL_TYPE = A. Null otherwise.                           |
| **ORIGIN_STAND** | Integer (nullable)  | Taxi stand identifier when CALL_TYPE = B. Null otherwise.                                  |
| **TAXI_ID**      | Integer             | Unique taxi (and driver) identifier. Foreign key to Drivers table.                         |
| **TIMESTAMP**    | Integer             | Unix timestamp (seconds) indicating trip start time (UTC).                                 |
| **DAY_TYPE**     | Categorical (A/B/C) | Day classification: A = normal day; B = holiday/special day; C = day before holiday.       |
| **MISSING_DATA** | Boolean             | Indicates if GPS data is incomplete.                                                       |
| **POLYLINE**     | String (JSON list)  | Ordered list of GPS coordinates `[longitude, latitude]` recorded every 15 seconds.         |
| **datetime**     | Datetime            | Parsed timestamp derived from TIMESTAMP.                                                   |
| **time_2h**      | Datetime            | Timestamp floored to 2-hour interval for aggregation.                                      |
| **hour**         | Integer (0–23)      | Hour of day extracted from datetime.                                                       |
| **month**        | Integer (1–12)      | Month extracted from datetime.                                                             |

---

### Derived Operational Metrics

| Column           | Type         | Description                                                  |
| ---------------- | ------------ | ------------------------------------------------------------ |
| **n_points**     | Integer      | Number of GPS points in POLYLINE.                            |
| **duration_sec** | Float        | Trip duration in seconds (n_points × 15).                    |
| **duration_min** | Float        | Trip duration in minutes.                                    |
| **distance_km**  | Float        | Estimated trip distance (Haversine formula).                 |
| **speed_kmh**    | Float        | Average trip speed (distance / duration).                    |
| **fare**         | Float        | Estimated base fare (distance + duration pricing model).     |
| **tip**          | Binary (0/1) | Indicates whether a tip was given.                           |
| **tip_amount**   | Float        | Tip amount (percentage of fare).                             |
| **total_fare**   | Float        | Total amount paid (fare + tip).                              |
| **payment**      | Categorical  | Payment method: card or cash.                                |
| **channel**      | Categorical  | Booking channel derived from CALL_TYPE (app, stand, street). |

---

### Passenger & Contextual Features

| Column           | Type          | Description                                          |
| ---------------- | ------------- | ---------------------------------------------------- |
| **passengers**   | Integer (1–3) | Number of passengers in the trip.                    |
| **nationality**  | Categorical   | Passenger type: local or tourist.                    |
| **purpose**      | Categorical   | Trip purpose: work or leisure (probabilistic model). |
| **radio**        | Categorical   | Radio station playing during trip.                   |
| **ac_requested** | Boolean       | Whether air conditioning was requested.              |

---

### Environmental Simulation

| Column           | Type  | Description                                        |
| ---------------- | ----- | -------------------------------------------------- |
| **temp_outside** | Float | Simulated outdoor temperature (summer model).      |
| **humidity**     | Float | Simulated relative humidity (%).                   |
| **temp_inside**  | Float | Simulated cabin temperature (depends on AC usage). |
| **temperature**  | Float | Monthly average temperature proxy.                 |

---

### Satisfaction & Ratings

| Column                 | Type        | Description                                                                    |
| ---------------------- | ----------- | ------------------------------------------------------------------------------ |
| **passenger_feedback** | Float (1–5) | Passenger rating influenced by comfort, trip length, channel, and temperature. |
| **driver_feedback**    | Float (1–5) | Driver rating influenced by distance, passenger count, and payment method.     |
| **avg_feedback**       | Float (1–5) | Mean of passenger_feedback and driver_feedback.                                |

---

## 2️⃣ Drivers Dimension Table (`df_drivers`)

This table contains static attributes of each taxi/driver. One row per TAXI_ID.

| Column            | Type        | Description                                                 |
| ----------------- | ----------- | ----------------------------------------------------------- |
| **TAXI_ID**       | Integer     | Unique taxi and driver identifier.                          |
| **fuel_type**     | Categorical | Vehicle fuel type: diesel, hybrid, electric, LPG, gasoline. |
| **vehicle_year**  | Integer     | Vehicle production year.                                    |
| **comfort_base**  | Float       | Base comfort score (driver/vehicle characteristic).         |
| **driver_rating** | Float (1–5) | Average rating across all trips performed by the driver.    |

---

## 📊 Data Model Structure

* `df_trips` → Fact table (transactional events)
* `df_drivers` → Dimension table (static taxi attributes)
* Relationship → `TAXI_ID` (1-to-many)

---

## 🧠 Simulation Notes

* Spatial trajectories correspond to real Porto GPS data.
* Environmental and behavioral variables are probabilistically generated but follow realistic constraints.
* Fuel type is constant per taxi.
* Ratings evolve per trip; `driver_rating` is an aggregate metric.
* AC usage depends on external temperature and passenger characteristics.

---

Si quieres, puedo generarte ahora:

* Un diagrama estrella (Star Schema) en markdown
* O una versión “Executive Summary” más corta para README principal
