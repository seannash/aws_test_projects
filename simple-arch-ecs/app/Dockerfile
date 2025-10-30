# Use Python 3.11 slim image as base
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy application files
COPY app.py .

# Make app.py executable
RUN chmod +x app.py

# Expose port 80
EXPOSE 80

# Set environment variable for port
ENV PORT=80

# Run the application
CMD ["python3", "app.py"]


