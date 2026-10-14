# Locust load testing script
# Run: locust -f locustfile.py --host=http://localhost:3000

from locust import HttpUser, task, between
import json
import random


class SystemMaintenanceUser(HttpUser):
    wait_time = between(0.5, 3.0)

    def on_start(self):
        """Login or setup before starting"""
        pass

    @task(3)
    def health_check(self):
        """Check API health endpoint"""
        with self.client.get("/health", name="Health Check",
                             catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Health check failed: {response.status_code}")

    @task(2)
    def query_api(self):
        """Test API query endpoint"""
        payload = {
            "query": f"test_query_{random.randint(1, 1000)}",
            "timestamp": __import__('time').time()
        }
        headers = {"Content-Type": "application/json"}

        with self.client.post("/api/query",
                              json=payload,
                              headers=headers,
                              name="API Query",
                              catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            elif response.status_code == 429:
                response.failure("Rate limited")
            else:
                response.failure(f"Query failed: {response.status_code}")

    @task(1)
    def dashboard(self):
        """Load main dashboard"""
        with self.client.get("/", name="Dashboard",
                             catch_response=True) as response:
            if response.elapsed.total_seconds() > 2.0:
                response.failure(f"Dashboard too slow: {response.elapsed.total_seconds():.2f}s")
            elif response.status_code == 200:
                response.success()
            else:
                response.failure(f"Dashboard failed: {response.status_code}")

    @task(1)
    def metrics(self):
        """Test metrics endpoint"""
        with self.client.get("/metrics", name="Metrics",
                             catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Metrics failed: {response.status_code}")

    @task(1)
    def static_assets(self):
        """Load static assets"""
        with self.client.get("/static/styles.css", name="Static CSS",
                             catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Static asset failed: {response.status_code}")
