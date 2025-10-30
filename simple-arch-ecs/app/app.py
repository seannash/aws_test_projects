#!/usr/bin/env python3
"""Simple Hello World application for AWS ECS."""

from http.server import HTTPServer, BaseHTTPRequestHandler
import os
import sys


class HelloHandler(BaseHTTPRequestHandler):
    """HTTP request handler that responds with a hello world message."""
    
    def do_GET(self):
        """Handle GET requests."""
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        
        # Get database host from environment variable
        db_host = os.environ.get('DB_HOST', 'not configured')
        
        message = f"""<!DOCTYPE html>
<html>
<head>
    <title>Hello World - AWS ECS</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }}
        .container {{
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}
        h1 {{
            color: #FF9900;
        }}
        .info {{
            background-color: #f9f9f9;
            padding: 15px;
            margin: 20px 0;
            border-left: 4px solid #FF9900;
            border-radius: 4px;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>Hello World from AWS ECS!</h1>
        <p>This is a simple Python application running on AWS ECS Fargate.</p>
        <div class="info">
            <strong>Database Host:</strong> {db_host}
        </div>
        <p>Your infrastructure is up and running!</p>
    </div>
</body>
</html>"""
        
        self.wfile.write(message.encode('utf-8'))
    
    def log_message(self, format, *args):
        """Override to log to stdout instead of stderr."""
        sys.stdout.write(f"{self.address_string()} - [{self.log_date_time_string()}] {format % args}\n")
        sys.stdout.flush()


def main():
    """Run the HTTP server."""
    port = int(os.environ.get('PORT', '80'))
    server_address = ('', port)
    httpd = HTTPServer(server_address, HelloHandler)
    
    print(f"Starting server on port {port}...")
    print("Press Ctrl+C to stop the server")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
        httpd.shutdown()


if __name__ == '__main__':
    main()

