const express = require('express');
const axios = require('axios');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// Weather API endpoint
app.get('/api/weather', async (req, res) => {
    try {
        const { city } = req.query;

        if (!city) {
            return res.status(400).json({ error: 'City parameter is required' });
        }

        const apiKey = process.env.OPENWEATHER_API_KEY;

        if (!apiKey) {
            console.error('OPENWEATHER_API_KEY not configured');
            return res.status(500).json({ error: 'Weather service not configured' });
        }

        // Call OpenWeatherMap API
        const weatherResponse = await axios.get(
            `https://api.openweathermap.org/data/2.5/weather`,
            {
                params: {
                    q: city,
                    appid: apiKey,
                    units: 'metric'
                }
            }
        );

        const data = weatherResponse.data;

        // Format the response
        const formattedData = {
            city: data.name,
            country: data.sys.country,
            temperature: data.main.temp,
            feelsLike: data.main.feels_like,
            humidity: data.main.humidity,
            pressure: data.main.pressure,
            windSpeed: data.wind.speed,
            description: data.weather[0].description,
            icon: data.weather[0].icon,
            timestamp: new Date().toISOString()
        };

        console.log(formattedData);
        

        res.json(formattedData);

    } catch (error) {
        console.error('Error fetching weather:', error.message);

        if (error.response) {
            // OpenWeatherMap API error
            if (error.response.status === 404) {
                return res.status(404).json({ error: 'City not found' });
            }
            return res.status(error.response.status).json({
                error: error.response.data.message || 'Failed to fetch weather data'
            });
        }

        // Network or other errors
        res.status(500).json({ error: 'Internal server error' });
    }
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({ error: 'Endpoint not found' });
});

// Error handler
app.use((err, req, res, next) => {
    console.error('Unhandled error:', err);
    res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Backend server running on port ${PORT}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`Health check available at: http://localhost:${PORT}/health`);
});
