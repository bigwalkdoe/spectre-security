package kubernetes.admission

# Test: Privileged container denied
test_privileged_denied {
    deny := data.kubernetes.admission.deny with input as {
        "request": {
            "object": {
                "spec": {
                    "containers": [{
                        "name": "test",
                        "securityContext": {"privileged": true}
                    }]
                }
            }
        }
    }
    deny[_] == "Privileged containers are not allowed"
}

# Test: Non-root required
test_non_root_required {
    deny := data.kubernetes.admission.deny with input as {
        "request": {
            "object": {
                "spec": {
                    "containers": [{
                        "name": "test",
                        "securityContext": {}
                    }]
                }
            }
        }
    }
    deny[_] == "Container test must run as non-root user"
}

# Test: Host network denied
test_host_network_denied {
    deny := data.kubernetes.admission.deny with input as {
        "request": {
            "object": {
                "spec": {
                    "hostNetwork": true,
                    "containers": [{"name": "test"}]
                }
            }
        }
    }
    deny[_] == "Host network namespace sharing is not allowed"
}

# Test: Host PID denied
test_host_pid_denied {
    deny := data.kubernetes.admission.deny with input as {
        "request": {
            "object": {
                "spec": {
                    "hostPID": true,
                    "containers": [{"name": "test"}]
                }
            }
        }
    }
    deny[_] == "Host PID namespace sharing is not allowed"
}

# Test: Memory limit required
test_memory_limit_required {
    deny := data.kubernetes.admission.deny with input as {
        "request": {
            "object": {
                "spec": {
                    "containers": [{
                        "name": "test",
                        "resources": {"requests": {"cpu": "100m"}}
                    }]
                }
            }
        }
    }
    deny[_] == "Container test must have memory limit"
}

# Test: CPU limit required
test_cpu_limit_required {
    deny := data.kubernetes.admission.deny with input as {
        "request": {
            "object": {
                "spec": {
                    "containers": [{
                        "name": "test",
                        "resources": {"requests": {"memory": "128Mi"}}
                    }]
                }
            }
        }
    }
    deny[_] == "Container test must have CPU limit"
}

# Test: Dangerous capability denied
test_dangerous_capability_denied {
    deny := data.kubernetes.admission.deny with input as {
        "request": {
            "object": {
                "spec": {
                    "containers": [{
                        "name": "test",
                        "securityContext": {"capabilities": {"add": ["SYS_ADMIN"]}}
                    }]
                }
            }
        }
    }
    deny[_] == "Dangerous capability SYS_ADMIN not allowed"
}

# Test: Read-only root filesystem required
test_readonly_rootfs_required {
    deny := data.kubernetes.admission.deny with input as {
        "request": {
            "object": {
                "spec": {
                    "containers": [{
                        "name": "test",
                        "securityContext": {"readOnlyRootFilesystem": false}
                    }]
                }
            }
        }
    }
    deny[_] == "Container test must have readOnlyRootFilesystem=true"
}

# Test: Liveness probe required
test_liveness_probe_required {
    deny := data.kubernetes.admission.deny with input as {
        "request": {
            "object": {
                "spec": {
                    "containers": [{"name": "test"}]
                }
            }
        }
    }
    deny[_] == "Container test must have liveness probe"
}

# Test: Readiness probe required
test_readiness_probe_required {
    deny := data.kubernetes.admission.deny with input as {
        "request": {
            "object": {
                "spec": {
                    "containers": [{"name": "test"}]
                }
            }
        }
    }
    deny[_] == "Container test must have readiness probe"
}

# Test: Disallowed hostPath denied
test_disallowed_hostpath_denied {
    deny := data.kubernetes.admission.deny with input as {
        "request": {
            "object": {
                "spec": {
                    "volumes": [{
                        "name": "host-volume",
                        "hostPath": {"path": "/etc"}
                    }],
                    "containers": [{"name": "test"}]
                }
            }
        }
    }
    deny[_] == "HostPath volume /etc not allowed"
}

# Test: Allowed hostPath allowed
test_allowed_hostpath_allowed {
    deny := data.kubernetes.admission.deny with input as {
        "request": {
            "object": {
                "metadata": {
                    "labels": {
                        "pod-security.kubernetes.io/enforce": "restricted"
                    }
                },
                "spec": {
                    "volumes": [{
                        "name": "log-volume",
                        "hostPath": {"path": "/var/log"}
                    }],
                    "containers": [{
                        "name": "test",
                        "securityContext": {
                            "privileged": false,
                            "runAsNonRoot": true,
                            "runAsUser": 1000,
                            "readOnlyRootFilesystem": true,
                            "capabilities": {"drop": ["ALL"]}
                        },
                        "resources": {
                            "limits": {"memory": "512Mi", "cpu": "500m"},
                            "requests": {"memory": "256Mi", "cpu": "250m"}
                        },
                        "livenessProbe": {"httpGet": {"path": "/health", "port": 8080}},
                        "readinessProbe": {"httpGet": {"path": "/ready", "port": 8080}}
                    }]
                }
            }
        }
    }
    count(deny) == 0
}

# Test: Pod security label required
test_pod_security_label_required {
    deny := data.kubernetes.admission.deny with input as {
        "request": {
            "object": {
                "metadata": {"labels": {}},
                "spec": {"containers": [{"name": "test"}]}
            }
        }
    }
    deny[_] == "Pod must have pod-security.kubernetes.io/enforce label"
}

# Test: hostPort denied
test_hostport_denied {
    deny := data.kubernetes.admission.deny with input as {
        "request": {
            "object": {
                "spec": {
                    "containers": [{
                        "name": "test",
                        "ports": [{"containerPort": 8080, "hostPort": 8080}]
                    }]
                }
            }
        }
    }
    deny[_] == "hostPort 8080 not allowed"
}

# Test: Compliant pod passes
test_compliant_pod {
    deny := data.kubernetes.admission.deny with input as {
        "request": {
            "object": {
                "metadata": {
                    "labels": {
                        "pod-security.kubernetes.io/enforce": "restricted"
                    }
                },
                "spec": {
                    "containers": [{
                        "name": "test",
                        "securityContext": {
                            "privileged": false,
                            "runAsNonRoot": true,
                            "runAsUser": 1000,
                            "readOnlyRootFilesystem": true,
                            "capabilities": {"drop": ["ALL"]}
                        },
                        "resources": {
                            "limits": {"memory": "512Mi", "cpu": "500m"},
                            "requests": {"memory": "256Mi", "cpu": "250m"}
                        },
                        "livenessProbe": {"httpGet": {"path": "/health", "port": 8080}},
                        "readinessProbe": {"httpGet": {"path": "/ready", "port": 8080}}
                    }]
                }
            }
        }
    }
    count(deny) == 0
}