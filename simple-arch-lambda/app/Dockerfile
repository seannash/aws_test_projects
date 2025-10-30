# Use Python 3.11 slim image as base
FROM python:3.11-slim

# Copy Lambda Web Adapter from ECR public image
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.9.1 /lambda-adapter /opt/extensions/lambda-adapter

# Set environment variables for Lambda Web Adapter
ENV PORT=8080

# Set working directory
WORKDIR /app

# Copy application files
COPY app.py .

# Make app.py executable
RUN chmod +x app.py

# Run the application
CMD ["python3", "app.py"]
