# Use a lightweight Python base image
FROM python:3.10-slim-buster

# Set the working directory inside the container
WORKDIR /app

# Copy requirements.txt and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all your application files and the chroma_db directory
# Ensure chroma_db folder is in the same directory as your Dockerfile
COPY . .

# Expose the port your Flask app will listen on
EXPOSE 5000

# Command to run the Flask application using Gunicorn for production
# Gunicorn is a production-ready WSGI HTTP Server
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "rag_server:app"]