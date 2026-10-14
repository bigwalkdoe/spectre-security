#!/bin/bash
# Check Wazuh agent status
echo "=== Wazuh Agent Status ==="
if [ -f /var/ossec/bin/wazuh-agent ]; then
    /var/ossec/bin/wazuh-agent -c 2>/dev/null || echo "Wazuh agent not connected"
    systemctl status wazuh-agent --no-pager 2>/dev/null || echo "Wazuh service not found"
else
    echo "Wazuh agent not installed"
fi
echo ""
echo "Agent logs: /var/ossec/logs/ossec.log"
echo "Active response: /var/ossec/active-response/bin/"
