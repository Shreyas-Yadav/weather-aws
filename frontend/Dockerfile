# Multi-stage build for frontend
FROM nginx:alpine

# Copy frontend files to nginx html directory
COPY index.html /usr/share/nginx/html/
COPY style.css /usr/share/nginx/html/
COPY app.js /usr/share/nginx/html/

# Copy nginx configuration as TEMPLATE (not as default.conf)
COPY nginx.conf /etc/nginx/templates/default.conf.template

# Set default environment variables
ENV BACKEND_HOST=http://localhost:3000
ENV BACKEND_PORT=3000

# Expose port 80
EXPOSE 80

# Start nginx (it will automatically process templates)
CMD ["nginx", "-g", "daemon off;"]