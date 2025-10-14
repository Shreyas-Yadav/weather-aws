# Weather Application

A single-page weather application with frontend (Nginx) and backend (Node.js/Express).

## Features

- Real-time weather data from OpenWeatherMap API
- Responsive single-page application
- Dockerized microservices architecture
- Health checks for monitoring

## Project Structure

```
weather-aws/
├── frontend/
│   ├── index.html          # Main HTML file
│   ├── style.css           # Styling
│   ├── app.js              # Frontend logic
│   ├── nginx.conf.template # Nginx configuration template (dynamic)
│   └── Dockerfile          # Frontend container image
├── backend/
│   ├── server.js           # Express API server
│   ├── package.json        # Node.js dependencies
│   └── Dockerfile          # Backend container image
├── docker-compose.yml      # Local testing configuration
├── .env.example            # Environment variables template
├── .gitignore              # Git ignore file
└── README.md              # This file
```

## Prerequisites

1. Docker installed locally
2. OpenWeatherMap API key (free tier: https://openweathermap.org/api)

## Setup and Running Locally

### 1. Clone and Setup

```bash
# Navigate to project directory
cd weather-aws

# Copy environment file
cp .env.example .env

# Edit .env and add your OpenWeatherMap API key
# OPENWEATHER_API_KEY=your_actual_api_key_here
```

### 2. Start with Docker Compose

```bash
# Build and start containers
docker-compose up --build

# Access the application
# Frontend: http://localhost
# Backend API: http://localhost:3000/api/weather?city=London
# Backend Health: http://localhost:3000/health
```

### 3. Stop

```bash
docker-compose down
```
