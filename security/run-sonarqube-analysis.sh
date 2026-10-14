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
