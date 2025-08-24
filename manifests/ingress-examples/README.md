# Ingress Examples and Testing

This directory contains example applications and ingress configurations for testing the nginx-ingress-controller deployment.

## Quick Start

1. **Deploy a sample application:**
   ```bash
   kubectl apply -f sample-app.yml
   kubectl apply -f sample-ingress.yml
   ```

2. **Test the ingress:**
   ```bash
   # Add to /etc/hosts or use curl with Host header
   curl -H "Host: sample.local" http://10.10.1.1:30080
   ```

3. **Run validation script:**
   ```bash
   ./scripts/validate-ingress.sh
   ```

4. **Deploy all test applications:**
   ```bash
   ./scripts/deploy-ingress-tests.sh
   ```

5. **Run comprehensive tests:**
   ```bash
   ./scripts/test-ingress-comprehensive.sh
   ```

## Available Examples

### 1. Sample Application (`sample-app.yml`)
- Basic nginx-based web application
- Includes health check endpoints
- Demonstrates basic ingress functionality

### 2. Sample Ingress Resources (`sample-ingress.yml`)
- **Basic ingress:** Simple host-based routing
- **Path-based routing:** Multiple paths to same service
- **Multi-host ingress:** Multiple hostnames

### 3. NextJS Application (`nextjs-example.yml`)
- Full NextJS application deployment
- API endpoints for health checks
- Production-ready configuration

### 4. REST API Application (`rest-api-example.yml`)
- Express.js-based REST API server
- Multiple API endpoints (users, status, metrics)
- CORS configuration and health checks
- Demonstrates API ingress patterns

### 5. Advanced Ingress Tests (`advanced-ingress-tests.yml`)
- Comprehensive test scenarios
- Multiple ingress configurations
- Performance and timeout testing
- Rate limiting and annotation testing

## Testing Scenarios

### Basic Functionality Tests
```bash
# Test basic routing
curl -H "Host: sample.local" http://10.10.1.1:30080

# Test path-based routing
curl -H "Host: api.local" http://10.10.1.1:30080/app
curl -H "Host: api.local" http://10.10.1.1:30080/health

# Test multiple hosts
curl -H "Host: app1.local" http://10.10.1.1:30080
curl -H "Host: app2.local" http://10.10.1.1:30080
```

### REST API Tests
```bash
# Test API status
curl -H "Host: api.local" http://10.10.1.1:30080/api/status

# Test GET users
curl -H "Host: api.local" http://10.10.1.1:30080/api/users

# Test POST users
curl -X POST -H "Host: api.local" -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com"}' \
  http://10.10.1.1:30080/api/users

# Test metrics
curl -H "Host: api.local" http://10.10.1.1:30080/api/metrics
```

### Advanced Tests
```bash
# Test advanced application
curl -H "Host: advanced.local" http://10.10.1.1:30080

# Test health endpoint
curl -H "Host: advanced.local" http://10.10.1.1:30080/health

# Test large content
curl -H "Host: advanced.local" http://10.10.1.1:30080/large

# Test slow response
curl -H "Host: advanced.local" http://10.10.1.1:30080/slow

# Test path rewriting
curl -H "Host: paths.local" http://10.10.1.1:30080/app/
curl -H "Host: paths.local" http://10.10.1.1:30080/service/health
```

### HTTPS Testing
```bash
# Test HTTPS (ignore certificate warnings for self-signed)
curl -k -H "Host: sample.local" https://10.10.1.1:30443
```

### Load Testing
```bash
# Simple load test
for i in {1..100}; do
  curl -s -H "Host: sample.local" http://10.10.1.1:30080 > /dev/null
done
```

## Ingress Annotations Reference

### Common Annotations
```yaml
annotations:
  # Basic routing
  nginx.ingress.kubernetes.io/rewrite-target: /
  nginx.ingress.kubernetes.io/ssl-redirect: "false"
  
  # Performance
  nginx.ingress.kubernetes.io/proxy-body-size: "1m"
  nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
  nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
  
  # Security
  nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
```

### Advanced Annotations
```yaml
annotations:
  # Rate limiting
  nginx.ingress.kubernetes.io/rate-limit: "100"
  nginx.ingress.kubernetes.io/rate-limit-window: "1m"
  
  # Authentication
  nginx.ingress.kubernetes.io/auth-type: basic
  nginx.ingress.kubernetes.io/auth-secret: basic-auth
  
  # CORS
  nginx.ingress.kubernetes.io/enable-cors: "true"
  nginx.ingress.kubernetes.io/cors-allow-origin: "*"
```

## Troubleshooting

### Common Issues

1. **Ingress not working:**
   ```bash
   # Check ingress controller pods
   kubectl get pods -n ingress-nginx
   
   # Check ingress resources
   kubectl get ingress -A
   
   # Check service endpoints
   kubectl get endpoints
   ```

2. **DNS resolution:**
   ```bash
   # Add to /etc/hosts for testing
   echo "10.10.1.1 sample.local api.local app1.local app2.local nextjs.local" >> /etc/hosts
   ```

3. **Certificate issues:**
   ```bash
   # Check TLS secrets
   kubectl get secrets -A | grep tls
   
   # Describe ingress for events
   kubectl describe ingress <ingress-name>
   ```

### Validation Commands

```bash
# Check ingress controller status
kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller

# Check ingress class
kubectl get ingressclass

# Check service
kubectl get service -n ingress-nginx ingress-nginx-controller

# Test health endpoint
curl http://10.10.1.1:30080/healthz

# Check logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

## Performance Considerations

### Resource Limits
- Controller: 500m CPU, 512Mi memory
- Default backend: 10m CPU, 20Mi memory

### Scaling
- Increase replicas for high availability
- Use horizontal pod autoscaler for dynamic scaling
- Consider node affinity for optimal placement

### Monitoring
- Enable metrics collection
- Use Prometheus for monitoring
- Set up alerts for ingress failures

## Security Best Practices

1. **Use TLS certificates:**
   ```yaml
   spec:
     tls:
     - hosts:
       - example.com
       secretName: example-tls
   ```

2. **Implement rate limiting:**
   ```yaml
   annotations:
     nginx.ingress.kubernetes.io/rate-limit: "100"
   ```

3. **Enable authentication:**
   ```yaml
   annotations:
     nginx.ingress.kubernetes.io/auth-type: basic
     nginx.ingress.kubernetes.io/auth-secret: basic-auth
   ```

4. **Restrict access by IP:**
   ```yaml
   annotations:
     nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8,192.168.0.0/16"
   ```