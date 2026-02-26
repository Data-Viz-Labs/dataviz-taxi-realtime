#!/usr/bin/env python3
"""
FastAPI application for Porto Taxi Real-Time Simulation

Minimal API with health endpoint for ECS health checks.
"""

from fastapi import FastAPI
from fastapi.responses import JSONResponse

app = FastAPI(
    title="Porto Taxi API",
    description="Real-time taxi trip simulation API",
    version="1.0.0"
)


@app.get("/health")
async def health_check():
    """Health check endpoint for ECS."""
    return JSONResponse(
        status_code=200,
        content={"status": "healthy"}
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
