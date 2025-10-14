// Configuration
const config = {
    // Backend API URL - will be set based on environment
    apiUrl: window.location.hostname === 'localhost'
        ? 'http://localhost:3000/api'
        : '/api'  // In production, requests will go through ALB
};

// DOM Elements
const cityInput = document.getElementById('cityInput');
const searchBtn = document.getElementById('searchBtn');
const loading = document.getElementById('loading');
const error = document.getElementById('error');
const weatherCard = document.getElementById('weatherCard');

// Weather data elements
const cityName = document.getElementById('cityName');
const dateTime = document.getElementById('dateTime');
const temp = document.getElementById('temp');
const weatherIcon = document.getElementById('weatherIcon');
const description = document.getElementById('description');
const feelsLike = document.getElementById('feelsLike');
const humidity = document.getElementById('humidity');
const windSpeed = document.getElementById('windSpeed');
const pressure = document.getElementById('pressure');

// Event Listeners
searchBtn.addEventListener('click', searchWeather);
cityInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        searchWeather();
    }
});

// Functions
function showLoading() {
    loading.classList.remove('hidden');
    error.classList.add('hidden');
    weatherCard.classList.add('hidden');
}

function hideLoading() {
    loading.classList.add('hidden');
}

function showError(message) {
    error.textContent = message;
    error.classList.remove('hidden');
    weatherCard.classList.add('hidden');
}

function showWeather(data) {
    weatherCard.classList.remove('hidden');
    error.classList.add('hidden');

    // Update weather data
    cityName.textContent = `${data.city}, ${data.country}`;
    dateTime.textContent = new Date().toLocaleString('en-US', {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });

    temp.textContent = Math.round(data.temperature);
    description.textContent = data.description;
    weatherIcon.src = `https://openweathermap.org/img/wn/${data.icon}@2x.png`;
    weatherIcon.alt = data.description;

    feelsLike.textContent = `${Math.round(data.feelsLike)}°C`;
    humidity.textContent = `${data.humidity}%`;
    windSpeed.textContent = `${data.windSpeed} m/s`;
    pressure.textContent = `${data.pressure} hPa`;
}

async function searchWeather() {
    const city = cityInput.value.trim();

    if (!city) {
        showError('Please enter a city name');
        return;
    }

    showLoading();

    try {
        const response = await fetch(`${config.apiUrl}/weather?city=${encodeURIComponent(city)}`);

        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.error || 'Failed to fetch weather data');
        }

        const data = await response.json();
        hideLoading();
        showWeather(data);
    } catch (err) {
        hideLoading();
        showError(err.message || 'Failed to fetch weather data. Please try again.');
        console.error('Error fetching weather:', err);
    }
}

// Load default city on page load
window.addEventListener('load', () => {
    cityInput.value = 'London';
    searchWeather();
});
