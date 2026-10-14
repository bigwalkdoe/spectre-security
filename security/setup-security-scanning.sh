#!/bin/bash
# Automated Security Scanning Setup
# - Trivy for container vulnerability scanning
# - SonarQube for code security analysis
# - OWASP ZAP for web application security testing
set -euo pipefail

echo "=== Automated Security Scanning Setup ==="
echo ""

# 1. Trivy - Container vulnerability scanner
setup_trivy() {
    echo "[1/3] Setting up Trivy container vulnerability scanner..."
    
    if ! command -v trivy >/dev/null 2>&1; then
        echo "Installing Trivy..."
        wget -qO- https://github.com/aquasecurity/trivy/releases/download/v0.50.0/trivy_0.50.0_Linux-64bit.tar.gz | tar -xz
        sudo mv trivy /usr/local/bin/
        sudo chmod +x /usr/local/bin/trivy
        echo "Trivy installed"
    fi

    # Create comprehensive scan script
    cat > /home/deon/scripts/security/run-trivy-scan.sh << 'TRIVY_SCAN'
#!/bin/bash
# Comprehensive Trivy vulnerability scan
set -euo pipefail

REPORT_DIR="/home/deon/scripts/security/reports"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p "$REPORT_DIR"

echo "=== Trivy Security Scan - $DATE ==="

# Scan Docker images
echo "Scanning Docker images..."
docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>" | sort -u | while read image; do
    echo "  Scanning: $image"
    trivy image --severity HIGH,CRITICAL --format json -o "$REPORT_DIR/trivy_image_$(echo $image | tr '/:' '__')_$DATE.json" "$image" 2>/dev/null || true
    trivy image --severity HIGH,CRITICAL "$image" 2>/dev/null | tail -20 || true
done

# Scan filesystem
echo "Scanning filesystem..."
trivy fs --severity HIGH,CRITICAL --format json -o "$REPORT_DIR/trivy_fs_$DATE.json" /home/deon/projects 2>/dev/null || true
trivy fs --severity HIGH,CRITICAL /home/deon/projects 2>/dev/null | tail -20 || true

# Scan Git repos
echo "Scanning Git repositories..."
for repo in /home/deon/projects/*/; do
    if [ -d "$repo/.git" ]; then
        echo "  Scanning: $(basename $repo)"
        trivy repo --severity HIGH,CRITICAL --format json -o "$REPORT_DIR/trivy_repo_$(basename $repo)_$DATE.json" "$repo" 2>/dev/null || true
    fi
done

# Generate summary
echo ""
echo "=== Scan Summary ==="
echo "Reports saved to: $REPORT_DIR/"
echo ""
echo "View JSON reports for detailed findings"
echo "Quick summary per image: trivy image --severity HIGH,CRITICAL <image>"

# Check for critical vulnerabilities
if ls "$REPORT_DIR"/trivy_image_*_"$DATE".json >/dev/null 2>&1; then
    TOTAL_CRITICAL=$(grep -o '"Severity":"CRITICAL"' "$REPORT_DIR"/trivy_*_"$DATE".json 2>/dev/null | wc -l || echo 0)
    TOTAL_HIGH=$(grep -o '"Severity":"HIGH"' "$REPORT_DIR"/trivy_*_"$DATE".json 2>/dev/null | wc -l || echo 0)
    echo ""
    echo "$TOTAL_CRITICAL CRITICAL, $TOTAL_HIGH HIGH vulnerabilities found"
    
    if [ "$TOTAL_CRITICAL" -gt 0 ]; then
        logger -p user.warning "Trivy scan found $TOTAL_CRITICAL critical vulnerabilities"
    fi
fi

echo ""
echo "Trivy scan completed: $DATE"
TRIVY_SCAN
    chmod +x /home/deon/scripts/security/run-trivy-scan.sh
    echo "Trivy scan script created"
}

# 2. SonarQube - Code security analysis
setup_sonarqube() {
    echo "[2/3] Setting up SonarQube for code analysis..."
    
    # Create Docker Compose for SonarQube
    mkdir -p /home/deon/scripts/security/sonarqube
    cat > /home/deon/scripts/security/sonarqube/docker-compose.yml << 'SONAR_COMPOSE'
services:
  sonarqube:
    image: sonarqube:community
    container_name: sonarqube
    ports:
      - "9000:9000"
    environment:
      - SONAR_JDBC_URL=jdbc:postgresql://sonarqube-db:5432/sonarqube
      - SONAR_JDBC_USERNAME=sonarqube
      - SONAR_JDBC_PASSWORD=sonarqube
    volumes:
      - sonarqube-data:/opt/sonarqube/data
      - sonarqube-extensions:/opt/sonarqube/extensions
      - sonarqube-logs:/opt/sonarqube/logs
    restart: unless-stopped
    networks:
      - sonarqube

  sonarqube-db:
    image: postgres:15
    container_name: sonarqube-db
    ports:
      - "5433:5432"
    environment:
      - POSTGRES_USER=sonarqube
      - POSTGRES_PASSWORD=sonarqube
      - POSTGRES_DB=sonarqube
    volumes:
      - sonarqube-db-data:/var/lib/postgresql/data
    restart: unless-stopped
    networks:
      - sonarqube

volumes:
  sonarqube-data:
  sonarqube-extensions:
  sonarqube-logs:
  sonarqube-db-data:

networks:
  sonarqube:
    driver: bridge
SONAR_COMPOSE

    # Create SonarQube analysis script
    cat > /home/deon/scripts/security/run-sonarqube-analysis.sh << 'SONAR_SCRIPT'
#!/bin/bash
# Run SonarQube code analysis
set -euo pipefail

SONAR_HOST_URL="${SONAR_HOST_URL:-http://localhost:9000}"
SONAR_TOKEN="${SONAR_TOKEN:-squ_changeme}"

if ! command -v sonar-scanner >/dev/null 2>&1; then
    echo "Installing SonarQube scanner..."
    wget -q https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.4406-linux.zip
    unzip -q sonar-scanner-cli-5.0.1.4406-linux.zip
    sudo mv sonar-scanner-5.0.1.4406-linux /opt/sonar-scanner
    sudo ln -sf /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner
    rm sonar-scanner-cli-5.0.1.4406-linux.zip
fi

echo "Running SonarQube analysis..."
for project in Guardrail-AI Modelink; do
    PROJECT_DIR="/home/deon/projects/$project"
    if [ -d "$PROJECT_DIR" ]; then
        echo "Analyzing $project..."
        cd "$PROJECT_DIR"
        sonar-scanner \
            -Dsonar.projectKey="$project" \
            -Dsonar.sources="." \
            -Dsonar.host.url="$SONAR_HOST_URL" \
            -Dsonar.login="$SONAR_TOKEN" \
            -Dsonar.exclusions="node_modules/**,.git/**,dist/**,build/**,__pycache__/**" \
            -Dsonar.javascript.lcov.reportPaths="coverage/lcov.info" 2>/dev/null || true
    fi
done

echo "SonarQube analysis completed"
echo "View results at: $SONAR_HOST_URL"
SONAR_SCRIPT
    chmod +x /home/deon/scripts/security/run-sonarqube-analysis.sh
    echo "SonarQube configured (start with: docker-compose -f sonarqube/docker-compose.yml up -d)"
}

# 3. OWASP ZAP - Web application security testing
setup_zap() {
    echo "[3/3] Setting up OWASP ZAP for web security testing..."
    
    # Create Docker Compose for ZAP
    mkdir -p /home/deon/scripts/security/zap
    cat > /home/deon/scripts/security/zap/docker-compose.yml << 'ZAP_COMPOSE'
services:
  zap:
    image: ghcr.io/zaproxy/zaproxy:stable
    container_name: zap
    ports:
      - "8080:8080"
    command: >
      zap.sh -daemon -host 0.0.0.0 -port 8080
      -config api.disablekey=true
    restart: unless-stopped
    networks:
      - zap
    volumes:
      - zap-data:/home/zap/.ZAP

volumes:
  zap-data:

networks:
  zap:
    driver: bridge
ZAP_COMPOSE

    # Create ZAP scan script
    cat > /home/deon/scripts/security/run-zap-scan.sh << 'ZAP_SCAN'
#!/bin/bash
# OWASP ZAP automated security scan
set -euo pipefail

ZAP_URL="http://localhost:8080"
REPORT_DIR="/home/deon/scripts/security/reports"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p "$REPORT_DIR"

TARGET_URL="${1:-http://localhost:3000}"

echo "=== OWASP ZAP Security Scan ==="
echo "Target: $TARGET_URL"
echo ""

# Wait for ZAP to be ready
echo "Waiting for ZAP to be ready..."
for i in $(seq 1 30); do
    if curl -s "$ZAP_URL" >/dev/null 2>&1; then
        echo "ZAP is ready"
        break
    fi
    sleep 2
done

# Run spider scan
echo "Running spider scan on $TARGET_URL..."
curl -s "$ZAP_URL/JSON/spider/action/scan/?url=$TARGET_URL&maxChildren=10" >/dev/null

# Run active scan
echo "Running active scan..."
curl -s "$ZAP_URL/JSON/ascan/action/scan/?url=$TARGET_URL&recurse=true" >/dev/null

# Wait for scan to complete
echo "Waiting for scan to complete..."
sleep 30

# Generate HTML report
echo "Generating report..."
curl -s "$ZAP_URL/OTHER/core/other/htmlreport/" > "$REPORT_DIR/zap_report_$DATE.html"

# Generate JSON report
curl -s "$ZAP_URL/JSON/core/view/alerts/" > "$REPORT_DIR/zap_alerts_$DATE.json"

# Get alert summary
ALERT_COUNT=$(curl -s "$ZAP_URL/JSON/core/view/numberOfAlerts/" | python3 -c "import sys,json;print(json.load(sys.stdin).get('numberOfAlerts',0))" 2>/dev/null || echo 0)
echo ""
echo "=== Scan Summary ==="
echo "Alerts found: $ALERT_COUNT"
echo "Report saved: $REPORT_DIR/zap_report_$DATE.html"
echo ""
if [ "$ALERT_COUNT" -gt 0 ]; then
    echo "High risk alerts:"
    curl -s "$ZAP_URL/JSON/core/view/alerts/?risk=High" | python3 -m json.tool 2>/dev/null | grep -A2 '"alert"' || true
fi

echo "ZAP scan completed: $DATE"
ZAP_SCAN
    chmod +x /home/deon/scripts/security/run-zap-scan.sh
    echo "OWASP ZAP configured (start with: docker-compose -f zap/docker-compose.yml up -d)"
}

# Run all setups
setup_trivy
echo ""
setup_sonarqube
echo ""
setup_zap
echo ""

# Add scheduled scans to cron
if ! crontab -l 2>/dev/null | grep -q "run-trivy-scan"; then
    (crontab -l 2>/dev/null
     echo "# Automated security scanning"
     echo "0 6 * * 0 /home/deon/scripts/security/run-trivy-scan.sh"
     echo "0 7 * * 0 /home/deon/scripts/security/run-zap-scan.sh http://localhost:3000"
    ) | crontab -
    echo "Weekly security scans scheduled (Sundays)"
fi

echo ""
echo "=== Automated Security Scanning Setup Complete ==="
echo ""
echo "Components installed:"
echo "  - Trivy (container/filesystem/REPO vulnerability scan)"
echo "  - SonarQube (code security analysis on port 9000)"
echo "  - OWASP ZAP (web app security testing on port 8080)"
echo ""
echo "Usage:"
echo "  Trivy:   /home/deon/scripts/security/run-trivy-scan.sh"
echo "  SonarQube: Start with: docker-compose -f sonarqube/docker-compose.yml up -d"
echo "            Then run:    /home/deon/scripts/security/run-sonarqube-analysis.sh"
echo "  ZAP:     Start with: docker-compose -f zap/docker-compose.yml up -d"
echo "            Then run:    /home/deon/scripts/security/run-zap-scan.sh <target_url>"
