#!/usr/bin/env python3
"""
FastAPI application for Porto Taxi Real-Time Simulation

Loads parquet files from local data/ directory or S3 bucket.
"""

import os
import logging
import json
from pathlib import Path
from contextlib import asynccontextmanager
from datetime import datetime, timezone

import pandas as pd
import boto3
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("porto-taxi-api")

# Global data storage
trips_df = None
drivers_df = None

# Authentication configuration
API_KEY = os.getenv("API_KEY", "dev-key-12345")
VALID_GROUPS = os.getenv("VALID_GROUPS", "dev-group,test-group").split(",")

# Simulation configuration
# Reference time: 2013-11-26 08:00:00 (most active 2-hour window)
SIMULATION_START = datetime(2013, 11, 26, 8, 0, 0, tzinfo=timezone.utc)
SIMULATION_DURATION_SECONDS = 2 * 60 * 60  # 2 hours
SIMULATION_CYCLE_STARTS = [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23]  # Odd hours


class AuthMiddleware(BaseHTTPMiddleware):
    """Middleware to validate API key and group name headers."""
    
    async def dispatch(self, request: Request, call_next):
        # Skip auth for health endpoint
        if request.url.path == "/health":
            return await call_next(request)
        
        # Extract headers
        api_key = request.headers.get("x-api-key")
        group_name = request.headers.get("x-group-name")
        
        # Log request attempt
        logger.info(
            f"AUTH_ATTEMPT | path={request.url.path} | "
            f"method={request.method} | "
            f"has_api_key={api_key is not None} | "
            f"has_group={group_name is not None} | "
            f"group={group_name or 'MISSING'}"
        )
        
        # Check x-api-key header
        if not api_key:
            logger.warning(
                f"AUTH_FAILED | reason=missing_api_key | "
                f"path={request.url.path} | "
                f"group={group_name or 'MISSING'}"
            )
            return JSONResponse(
                status_code=401,
                content={"error": "Missing x-api-key header"}
            )
        
        if api_key != API_KEY:
            logger.warning(
                f"AUTH_FAILED | reason=invalid_api_key | "
                f"path={request.url.path} | "
                f"group={group_name or 'MISSING'}"
            )
            return JSONResponse(
                status_code=401,
                content={"error": "Invalid API key"}
            )
        
        # Check x-group-name header
        if not group_name:
            logger.warning(
                f"AUTH_FAILED | reason=missing_group | "
                f"path={request.url.path}"
            )
            return JSONResponse(
                status_code=401,
                content={"error": "Missing x-group-name header"}
            )
        
        if group_name not in VALID_GROUPS:
            logger.warning(
                f"AUTH_FAILED | reason=invalid_group | "
                f"path={request.url.path} | "
                f"group={group_name} | "
                f"valid_groups={','.join(VALID_GROUPS)}"
            )
            return JSONResponse(
                status_code=403,
                content={"error": f"Invalid group name. Valid groups: {', '.join(VALID_GROUPS)}"}
            )
        
        # Add group to request state for logging/metrics
        request.state.group = group_name
        
        # Log successful auth
        logger.info(
            f"AUTH_SUCCESS | path={request.url.path} | "
            f"method={request.method} | "
            f"group={group_name}"
        )
        
        # Process request
        response = await call_next(request)
        
        # Log response
        logger.info(
            f"REQUEST_COMPLETE | path={request.url.path} | "
            f"method={request.method} | "
            f"group={group_name} | "
            f"status={response.status_code}"
        )
        
        return response


def load_from_local() -> tuple[pd.DataFrame, pd.DataFrame]:
    """Load parquet files from local data directory."""
    trips_path = Path("data/trips_memory.parquet")
    drivers_path = Path("data/drivers_memory.parquet")
    
    if trips_path.exists() and drivers_path.exists():
        logger.info("Loading data from local directory...")
        trips = pd.read_parquet(trips_path)
        drivers = pd.read_parquet(drivers_path)
        return trips, drivers
    
    return None, None


def download_from_s3(s3_path: str) -> None:
    """Download parquet files from S3 to local data directory."""
    logger.info(f"Downloading data from S3: {s3_path}")
    
    # Parse bucket and prefix from s3_path
    # Supports: "bucket/prefix" or "bucket"
    parts = s3_path.split("/", 1)
    bucket_name = parts[0]
    prefix = parts[1] + "/" if len(parts) > 1 else ""
    
    logger.info(f"Bucket: {bucket_name}, Prefix: {prefix}")
    
    s3 = boto3.client("s3")
    local_dir = Path("data")
    local_dir.mkdir(exist_ok=True)
    
    files = ["trips_memory.parquet", "drivers_memory.parquet"]
    
    for file in files:
        local_path = local_dir / file
        s3_key = f"{prefix}{file}"
        logger.info(f"Downloading s3://{bucket_name}/{s3_key}...")
        s3.download_file(bucket_name, s3_key, str(local_path))
        logger.info(f"Downloaded {file} to {local_path}")


def load_data() -> tuple[pd.DataFrame, pd.DataFrame]:
    """Load data from local or S3."""
    # Try local first
    trips, drivers = load_from_local()
    
    if trips is not None and drivers is not None:
        logger.info(f"Loaded {len(trips)} trips and {len(drivers)} drivers from local")
        return trips, drivers
    
    # Try S3 if local fails
    bucket = os.getenv("S3_BUCKET")
    if bucket:
        try:
            download_from_s3(bucket)
            trips, drivers = load_from_local()
            if trips is not None and drivers is not None:
                logger.info(f"Loaded {len(trips)} trips and {len(drivers)} drivers from S3")
                return trips, drivers
        except Exception as e:
            logger.error(f"Failed to load from S3: {e}")
    
    raise RuntimeError("Could not load data from local or S3")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load data on startup."""
    global trips_df, drivers_df
    
    logger.info("Starting application...")
    trips_df, drivers_df = load_data()
    logger.info("Data loaded successfully")
    
    yield
    
    logger.info("Shutting down...")


app = FastAPI(
    title="Porto Taxi API",
    description="Real-time taxi trip simulation API",
    version="1.0.0",
    lifespan=lifespan
)

# Add authentication middleware
app.add_middleware(AuthMiddleware)


@app.get("/health")
async def health_check():
    """Health check endpoint for ECS."""
    data_loaded = trips_df is not None and drivers_df is not None
    
    return JSONResponse(
        status_code=200 if data_loaded else 503,
        content={
            "status": "healthy" if data_loaded else "unhealthy",
            "data_loaded": data_loaded
        }
    )


@app.get("/drivers")
async def list_drivers(limit: int = 100, offset: int = 0):
    """List all taxi drivers."""
    if drivers_df is None:
        return JSONResponse(
            status_code=503,
            content={"error": "Data not loaded"}
        )
    
    total = len(drivers_df)
    drivers = drivers_df.iloc[offset:offset + limit].to_dict(orient="records")
    
    return {
        "total": total,
        "limit": limit,
        "offset": offset,
        "count": len(drivers),
        "drivers": drivers
    }


@app.get("/trips")
async def list_trips(
    limit: int = 100,
    offset: int = 0,
    driver_id: int = None,
    date: int = None
):
    """
    List trips with optional filters.
    
    Args:
        limit: Maximum number of trips to return
        offset: Number of trips to skip
        driver_id: Filter by TAXI_ID
        date: Filter by timestamp (Unix epoch seconds)
    """
    if trips_df is None:
        return JSONResponse(
            status_code=503,
            content={"error": "Data not loaded"}
        )
    
    # Validate date range if provided
    if date is not None:
        # Dataset range: 2013-07-01 00:00:53 to 2014-06-30 23:59:56
        min_timestamp = 1372636853  # 2013-07-01 00:00:53
        max_timestamp = 1404172796  # 2014-06-30 23:59:56
        
        if date < min_timestamp or date > max_timestamp:
            return JSONResponse(
                status_code=400,
                content={
                    "error": "Date out of range",
                    "message": f"Date must be between 2013-07-01 and 2014-06-30",
                    "provided_timestamp": date,
                    "valid_range": {
                        "min": min_timestamp,
                        "max": max_timestamp,
                        "min_date": "2013-07-01 00:00:53",
                        "max_date": "2014-06-30 23:59:56"
                    }
                }
            )
    
    # Apply filters
    filtered_df = trips_df.copy()
    
    if driver_id is not None:
        filtered_df = filtered_df[filtered_df["TAXI_ID"] == driver_id]
    
    if date is not None:
        # Filter by date (same day as provided timestamp)
        filtered_df["date_only"] = pd.to_datetime(filtered_df["TIMESTAMP"], unit="s").dt.date
        target_date = pd.to_datetime(date, unit="s").date()
        filtered_df = filtered_df[filtered_df["date_only"] == target_date]
        filtered_df = filtered_df.drop(columns=["date_only"])
    
    total = len(filtered_df)
    
    # Return 404 if no trips found
    if total == 0:
        return JSONResponse(
            status_code=404,
            content={"error": "No trips found with the specified filters"}
        )
    
    # Apply pagination and convert to dict
    trips_subset = filtered_df.iloc[offset:offset + limit]
    
    # Replace NaN/inf values with None for JSON compatibility
    trips_subset = trips_subset.replace({float('nan'): None, float('inf'): None, float('-inf'): None})
    trips = trips_subset.to_dict(orient="records")
    
    return {
        "total": total,
        "limit": limit,
        "offset": offset,
        "count": len(trips),
        "filters": {
            "driver_id": driver_id,
            "date": date
        },
        "trips": trips
    }


def get_simulation_time():
    """
    Calculate current simulation time based on real time.
    
    Simulation repeats every 2 hours starting at odd hours (01:00, 03:00, ..., 23:00).
    Maps current time to the 2-hour window starting at 2013-11-26 08:00:00.
    
    Returns:
        tuple: (simulation_timestamp, seconds_into_cycle)
    """
    now = datetime.now(timezone.utc)
    
    # Find current cycle start (most recent odd hour)
    current_hour = now.hour
    if current_hour % 2 == 0:
        # Even hour: go back to previous odd hour
        cycle_start_hour = (current_hour - 1) % 24
    else:
        # Odd hour: use current hour
        cycle_start_hour = current_hour
    
    cycle_start = now.replace(hour=cycle_start_hour, minute=0, second=0, microsecond=0)
    
    # If we went back in time (e.g., from 00:xx to 23:00), adjust the date
    if cycle_start > now:
        cycle_start = cycle_start.replace(day=cycle_start.day - 1)
    
    # Calculate seconds into current 2-hour cycle
    seconds_into_cycle = int((now - cycle_start).total_seconds())
    
    # Map to simulation time
    simulation_timestamp = int(SIMULATION_START.timestamp()) + seconds_into_cycle
    
    return simulation_timestamp, seconds_into_cycle


def parse_polyline(polyline_str):
    """Parse polyline JSON string to list of coordinates."""
    try:
        return json.loads(polyline_str)
    except:
        return []


@app.get("/live")
async def live_all(driver_id: int = None):
    """
    Get all active trips at current simulation time.
    
    Args:
        driver_id: Optional filter by TAXI_ID
    
    Returns:
        List of active trips with current GPS position and trip details
    """
    if trips_df is None:
        return JSONResponse(
            status_code=503,
            content={"error": "Data not loaded"}
        )
    
    sim_timestamp, seconds_into_cycle = get_simulation_time()
    
    # Filter trips that are active at simulation time
    # A trip is active if: start_time <= sim_time < end_time
    active_trips = trips_df[
        (trips_df["TIMESTAMP"] <= sim_timestamp) &
        (trips_df["TIMESTAMP"] + trips_df["duration_sec"] > sim_timestamp)
    ].copy()
    
    if driver_id is not None:
        active_trips = active_trips[active_trips["TAXI_ID"] == driver_id]
    
    if len(active_trips) == 0:
        return JSONResponse(
            status_code=404,
            content={"error": "No active trips at current simulation time"}
        )
    
    # Build response with GPS history
    result = []
    for _, trip in active_trips.iterrows():
        elapsed = sim_timestamp - trip["TIMESTAMP"]
        polyline = parse_polyline(trip["POLYLINE"])
        
        # Calculate how many GPS points to show (one every 15 seconds)
        points_to_show = min(int(elapsed / 15) + 1, len(polyline))
        
        trip_data = {
            "driver_id": int(trip["TAXI_ID"]),
            "trip_id": int(trip["TRIP_ID"]),
            "elapsed_seconds": int(elapsed),
            "total_duration": int(trip["duration_sec"]),
            "progress_pct": round((elapsed / trip["duration_sec"]) * 100, 2),
            "trip_details": {
                "call_type": trip["CALL_TYPE"],
                "passengers": int(trip["passengers"]) if pd.notna(trip["passengers"]) else None,
                "fare": float(trip["fare"]) if pd.notna(trip["fare"]) else None,
                "payment": trip["payment"] if pd.notna(trip["payment"]) else None,
                "purpose": trip["purpose"] if pd.notna(trip["purpose"]) else None,
                "fuel_type": trip["fuel_type"] if pd.notna(trip["fuel_type"]) else None,
            },
            "gps_history": polyline[:points_to_show],
            "current_position": polyline[points_to_show - 1] if points_to_show > 0 else None
        }
        result.append(trip_data)
    
    return {
        "simulation_time": sim_timestamp,
        "real_time": datetime.now(timezone.utc).isoformat(),
        "seconds_into_cycle": seconds_into_cycle,
        "active_trips": len(result),
        "trips": result
    }


@app.get("/live/{driver_id}")
async def live_driver(driver_id: int):
    """
    Get active trips for specific driver at current simulation time.
    
    Args:
        driver_id: TAXI_ID to filter
    
    Returns:
        Active trips for the driver with GPS history
    """
    return await live_all(driver_id=driver_id)


@app.get("/live/{driver_id}/latest")
async def live_driver_latest(driver_id: int):
    """
    Get latest GPS position for driver's active trip (no history).
    
    Args:
        driver_id: TAXI_ID to filter
    
    Returns:
        Current position and trip details only
    """
    if trips_df is None:
        return JSONResponse(
            status_code=503,
            content={"error": "Data not loaded"}
        )
    
    sim_timestamp, seconds_into_cycle = get_simulation_time()
    
    # Find active trip for driver
    active_trip = trips_df[
        (trips_df["TAXI_ID"] == driver_id) &
        (trips_df["TIMESTAMP"] <= sim_timestamp) &
        (trips_df["TIMESTAMP"] + trips_df["duration_sec"] > sim_timestamp)
    ]
    
    if len(active_trip) == 0:
        return JSONResponse(
            status_code=404,
            content={"error": f"Driver {driver_id} has no active trip"}
        )
    
    trip = active_trip.iloc[0]
    elapsed = sim_timestamp - trip["TIMESTAMP"]
    polyline = parse_polyline(trip["POLYLINE"])
    
    # Get current position only
    points_to_show = min(int(elapsed / 15) + 1, len(polyline))
    current_pos = polyline[points_to_show - 1] if points_to_show > 0 else None
    
    return {
        "simulation_time": sim_timestamp,
        "real_time": datetime.now(timezone.utc).isoformat(),
        "driver_id": int(trip["TAXI_ID"]),
        "trip_id": int(trip["TRIP_ID"]),
        "elapsed_seconds": int(elapsed),
        "total_duration": int(trip["duration_sec"]),
        "progress_pct": round((elapsed / trip["duration_sec"]) * 100, 2),
        "current_position": current_pos,
        "trip_details": {
            "call_type": trip["CALL_TYPE"],
            "passengers": int(trip["passengers"]) if pd.notna(trip["passengers"]) else None,
            "fare": float(trip["fare"]) if pd.notna(trip["fare"]) else None,
            "payment": trip["payment"] if pd.notna(trip["payment"]) else None,
            "purpose": trip["purpose"] if pd.notna(trip["purpose"]) else None,
        }
    }


@app.get("/live/{driver_id}/trip/{trip_id}")
async def live_driver_trip(driver_id: int, trip_id: int):
    """
    Get specific trip details with GPS history.
    
    Args:
        driver_id: TAXI_ID
        trip_id: TRIP_ID
    
    Returns:
        Trip details with GPS history up to current simulation time
    """
    if trips_df is None:
        return JSONResponse(
            status_code=503,
            content={"error": "Data not loaded"}
        )
    
    sim_timestamp, seconds_into_cycle = get_simulation_time()
    
    # Find specific trip
    trip_match = trips_df[
        (trips_df["TAXI_ID"] == driver_id) &
        (trips_df["TRIP_ID"] == trip_id)
    ]
    
    if len(trip_match) == 0:
        return JSONResponse(
            status_code=404,
            content={"error": f"Trip {trip_id} not found for driver {driver_id}"}
        )
    
    trip = trip_match.iloc[0]
    
    # Check if trip is active
    is_active = (trip["TIMESTAMP"] <= sim_timestamp < trip["TIMESTAMP"] + trip["duration_sec"])
    
    if not is_active:
        return JSONResponse(
            status_code=404,
            content={"error": f"Trip {trip_id} is not active at current simulation time"}
        )
    
    elapsed = sim_timestamp - trip["TIMESTAMP"]
    polyline = parse_polyline(trip["POLYLINE"])
    points_to_show = min(int(elapsed / 15) + 1, len(polyline))
    
    # Replace NaN/inf with None
    trip_dict = trip.replace({float('nan'): None, float('inf'): None, float('-inf'): None}).to_dict()
    
    return {
        "simulation_time": sim_timestamp,
        "real_time": datetime.now(timezone.utc).isoformat(),
        "driver_id": int(trip["TAXI_ID"]),
        "trip_id": int(trip["TRIP_ID"]),
        "elapsed_seconds": int(elapsed),
        "total_duration": int(trip["duration_sec"]),
        "progress_pct": round((elapsed / trip["duration_sec"]) * 100, 2),
        "gps_history": polyline[:points_to_show],
        "current_position": polyline[points_to_show - 1] if points_to_show > 0 else None,
        "trip_data": trip_dict
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
