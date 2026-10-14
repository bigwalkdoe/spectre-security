#!/usr/bin/env python3
# Security Baseline HTTP Exporter
# Serves Prometheus metrics on HTTP endpoint using Python's http.server

import http.server
import socketserver
import subprocess
import time
import os
import threading
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
PORT = int(os.environ.get('PORT', '9100'))
METRICS_FILE = '/tmp/security-baseline-metrics.prom'
FAST_EXPORTER_SCRIPT = SCRIPT_DIR / 'security-baseline-fast-exporter.sh'

class MetricsHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics' or self.path == '/':
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain; version=0.0.4')
            self.end_headers()
            
            # Generate fresh metrics using fast exporter
            try:
                subprocess.run([str(FAST_EXPORTER_SCRIPT)], cwd=SCRIPT_DIR, 
                             capture_output=True, timeout=30)
            except subprocess.TimeoutExpired:
                pass
            except Exception:
                pass
            
            # Serve metrics file
            if os.path.exists(METRICS_FILE):
                with open(METRICS_FILE, 'rb') as f:
                    self.wfile.write(f.read())
            else:
                self.wfile.write(b'# No metrics available yet\n')
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'Not Found\n')
    
    def log_message(self, format, *args):
        # Suppress default log messages
        pass

def run_exporter_loop():
    """Background thread to periodically update metrics"""
    while True:
        try:
            subprocess.run([str(FAST_EXPORTER_SCRIPT)], cwd=SCRIPT_DIR, 
                         capture_output=True, timeout=30)
        except subprocess.TimeoutExpired:
            pass
        except Exception:
            pass
        time.sleep(30)  # Update every 30 seconds

if __name__ == '__main__':
    # Start background metrics updater
    updater_thread = threading.Thread(target=run_exporter_loop, daemon=True)
    updater_thread.start()
    
    # Initial metrics generation
    try:
        subprocess.run([str(FAST_EXPORTER_SCRIPT)], cwd=SCRIPT_DIR, 
                     capture_output=True, timeout=30)
    except Exception:
        pass
    
    # Start HTTP server
    with socketserver.TCPServer(("", int(os.environ.get('PORT', '9100'))), MetricsHandler) as httpd:
        print(f"Security Baseline Exporter serving on port {PORT}")
        print(f"Metrics available at http://localhost:{PORT}/metrics")
        httpd.serve_forever()