# Porto Taxi Trips - Real-Time Simulation API

A lightweight solution for simulating real-time taxi trip data from Porto, Portugal. Built for a data visualisation hackathon, this project provides a REST API that serves GPS coordinates and trip details as if they were happening right now.

## Overview

This project takes historical taxi trip data from Kaggle (Porto taxi trips with GPS positions every 15 seconds) and transforms it into a real-time simulation API. The system is designed to be scalable, cacheable, and perfect for teaching API consumption and data visualisation.

## Features

- **Real-time simulation**: Historical data replayed as current events
- **Scalable architecture**: ECS/Fargate containers with API Gateway caching
- **Pre-computed data**: Pickle files for consistent responses across containers
- **API key authentication**: Simple header-based validation (api-key + group)
- **Live monitoring**: CloudWatch dashboard showing real-time metrics
- **Load testing**: Artillery.io configuration included

## Project Structure

```
.
├── bin/                         # Bash scripts
│   ├── check-deps.sh           # Dependency checker
│   └── download-data.sh        # Kaggle dataset downloader
├── docs/                        # Documentation
│   ├── data_engineering.md     # Data engineering manual
│   ├── api.html                # Api wrapper
│   └── api.yaml                # Api definition file with OpenAPI@3
├── dpt/                         # Data Preparation & Transformation
│   ├── EXTEND.py               # Dataset extension with random data
│   ├── EDA.py                  # Find peak 2-hour window
│   └── ETL.py                  # Generate pickle files
├── src/                         # Source code for REST API
│   ├── app.py                  # FastAPI/Flask application
│   ├── models.py               # Data models
│   └── routes.py               # API endpoints
├── iac/                         # Infrastructure as Code
│   ├── main.tf                 # Terraform main configuration
│   ├── ecs.tf                  # ECS/Fargate resources
│   ├── api-gateway.tf          # API Gateway with caching
│   ├── cloudwatch.tf           # Dashboard and monitoring
│   └── variables.tf            # Terraform variables
├── data/                        # Data directory
│   ├── train.csv               # Original Kaggle dataset
│   ├── archive.zip             # Downloaded archive
│   └── *.pkl                   # Generated pickle files (gitignored)
├── tst/                         # Testing
│   ├── notebook.ipynb          # Example usage notebook
│   └── artillery.yml           # Load testing configuration
├── Dockerfile                  # Container definition
├── Makefile                    # Build and deployment commands
├── requirements.txt            # Production dependencies
├── requirements.dev.txt        # Development dependencies
├── .gitignore                  # Git ignore rules
├── LICENSE                     # MIT License
├── README.md                   # This file
└── TODOS.md                    # Task checklist

```

## Quick Start

### Prerequisites

```bash
# Check all dependencies
./bin/check-deps.sh
```

Required:
- Python 3.9+
- Docker
- Terraform
- AWS CLI configured
- Kaggle API credentials

### Installation

```bash
# Download dataset
./bin/download-data.sh

# Install development dependencies
pip install -r requirements.dev.txt

# Run EDA to find peak hours
python src/eda/EDA.py

# Extend dataset
python src/etl/EXTEND.py

# Generate pickle files
python src/etl/ETL.py
```

### Local Development

```bash
# Run API locally
make run-local

# Run tests
make test

# Build Docker image
make build
```

### Deployment

```bash
# Deploy infrastructure
make deploy

# Run load tests
make load-test
```

## API Usage

### Authentication

All requests require two headers:
- `x-api-key`: Your API key
- `x-group-name`: Your group identifier

### Endpoints

**GET /trips/current**
Returns trips happening "now" (simulated current time)

**GET /trips/range?start={timestamp}&end={timestamp}**
Returns trips within a time range

**GET /trips/{trip_id}**
Returns details for a specific trip

**GET /health**
Health check endpoint

### Example Request

```bash
curl -H "x-api-key: your-key" \
     -H "x-group-name: team-alpha" \
     https://api.example.com/trips/current
```

### Example Response

```json
{
  "timestamp": "2026-02-26T14:30:00Z",
  "trips": [
    {
      "trip_id": "T123456",
      "taxi_id": "20000001",
      "latitude": 41.1579,
      "longitude": -8.6291,
      "passengers": 2,
      "timestamp": "2026-02-26T14:30:00Z"
    }
  ]
}
```

## Architecture

- **API Layer**: Lightweight Python REST API (FastAPI)
- **Compute**: AWS ECS/Fargate with auto-scaling
- **Gateway**: API Gateway with caching and authentication
- **Monitoring**: CloudWatch dashboard with real-time metrics
- **Data**: Pre-computed pickle files for consistency

## Monitoring Dashboard

The CloudWatch dashboard displays:
- Request count per group
- API latency (p50, p95, p99)
- Container health and count
- Cache hit ratio
- Error rates

## Load Testing

```bash
# Run Artillery load test
artillery run tst/artillery.yml
```

## Development

### Adding New Endpoints

1. Define model in `src/api/models.py`
2. Add route in `src/api/routes.py`
3. Update API documentation

### Modifying Data Processing

1. Update `src/etl/EXTEND.py` for data generation
2. Regenerate pickle files with `python src/etl/ETL.py`
3. Rebuild container

## Licence

MIT Licence - see [LICENSE](LICENSE) file for details

## Dataset

Original dataset: [Kaggle - Taxi Service Trajectory Prediction Challenge](https://www.kaggle.com/c/pkdd-15-predict-taxi-service-trajectory-i)

## Contributing

This is a hackathon project. Feel free to fork and adapt for your needs.

## Support

For issues or questions, please open an issue on the repository.
