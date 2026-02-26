#!/usr/bin/env python3
"""
FastAPI application for Porto Taxi Real-Time Simulation

Loads parquet files from local data/ directory or S3 bucket.
"""

import os
from pathlib import Path
from contextlib import asynccontextmanager

import pandas as pd
import boto3
from fastapi import FastAPI
from fastapi.responses import JSONResponse


# Global data storage
trips_df = None
drivers_df = None


def load_from_local() -> tuple[pd.DataFrame, pd.DataFrame]:
    """Load parquet files from local data directory."""
    trips_path = Path("data/trips_memory.parquet")
    drivers_path = Path("data/drivers_memory.parquet")
    
    if trips_path.exists() and drivers_path.exists():
        print("Loading data from local directory...")
        trips = pd.read_parquet(trips_path)
        drivers = pd.read_parquet(drivers_path)
        return trips, drivers
    
    return None, None


def download_from_s3(s3_path: str) -> None:
    """Download parquet files from S3 to local data directory."""
    print(f"Downloading data from S3: {s3_path}")
    
    # Parse bucket and prefix from s3_path
    # Supports: "bucket/prefix" or "bucket"
    parts = s3_path.split("/", 1)
    bucket_name = parts[0]
    prefix = parts[1] + "/" if len(parts) > 1 else ""
    
    print(f"Bucket: {bucket_name}, Prefix: {prefix}")
    
    s3 = boto3.client("s3")
    local_dir = Path("data")
    local_dir.mkdir(exist_ok=True)
    
    files = ["trips_memory.parquet", "drivers_memory.parquet"]
    
    for file in files:
        local_path = local_dir / file
        s3_key = f"{prefix}{file}"
        print(f"Downloading s3://{bucket_name}/{s3_key}...")
        s3.download_file(bucket_name, s3_key, str(local_path))
        print(f"Downloaded {file} to {local_path}")


def load_data() -> tuple[pd.DataFrame, pd.DataFrame]:
    """Load data from local or S3."""
    # Try local first
    trips, drivers = load_from_local()
    
    if trips is not None and drivers is not None:
        print(f"Loaded {len(trips)} trips and {len(drivers)} drivers from local")
        return trips, drivers
    
    # Try S3 if local fails
    bucket = os.getenv("S3_BUCKET")
    if bucket:
        try:
            download_from_s3(bucket)
            trips, drivers = load_from_local()
            if trips is not None and drivers is not None:
                print(f"Loaded {len(trips)} trips and {len(drivers)} drivers from S3")
                return trips, drivers
        except Exception as e:
            print(f"Failed to load from S3: {e}")
    
    raise RuntimeError("Could not load data from local or S3")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load data on startup."""
    global trips_df, drivers_df
    
    print("Starting application...")
    trips_df, drivers_df = load_data()
    print("Data loaded successfully")
    
    yield
    
    print("Shutting down...")


app = FastAPI(
    title="Porto Taxi API",
    description="Real-time taxi trip simulation API",
    version="1.0.0",
    lifespan=lifespan
)


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


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
