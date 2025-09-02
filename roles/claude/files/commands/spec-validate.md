---
description: "Execute comprehensive validation gates: /spec-validate <feature-name> [--gate <specific-gate>]"
---

# Execute Validation Gates

## Feature: $ARGUMENTS

Run comprehensive quality gates to ensure implementation meets all specifications, performance targets, and security requirements.

## Process

### Phase 1: Load Validation Context

1. **Parse Arguments**
   ```python
   feature_name = parse_feature_name()
   specific_gate = parse_optional_gate()  # Run single gate if specified
   validation_config = load("validation/gates.md")
   progress = load(".state/progress.json")
   ```

2. **Pre-Validation Checks**
   ```bash
   # Ensure clean working directory
   git diff --stat
   
   # Check all dependencies installed
   make deps-verify
   
   # Verify test environment ready
   make test-env-check
   ```

### Phase 2: Code Quality Gates

3. **Syntax & Style Validation**
   ```bash
   echo "🔍 Running syntax validation..."
   
   # Language-specific linting
   if [[ -f "Makefile" && -n "$(grep lint Makefile)" ]]; then
       make lint
   elif [[ -f "package.json" ]]; then
       npm run lint
   elif [[ -f "pyproject.toml" ]]; then
       ruff check . || pylint .
   elif [[ -f "Cargo.toml" ]]; then
       cargo clippy -- -D warnings
   fi
   
   # Format checking
   make format-check || echo "⚠️ Format issues detected"
   ```

4. **Type Safety Validation**
   ```bash
   echo "🔍 Checking type safety..."
   
   # TypeScript/JavaScript
   if [[ -f "tsconfig.json" ]]; then
       npx tsc --noEmit
   fi
   
   # Python
   if [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]]; then
       mypy . --strict
   fi
   
   # Go
   if [[ -f "go.mod" ]]; then
       go vet ./...
   fi
   ```

5. **Complexity Analysis**
   ```python
   metrics = {
       "cyclomatic_complexity": analyze_complexity(),
       "cognitive_complexity": analyze_cognitive_load(),
       "coupling": measure_coupling(),
       "cohesion": measure_cohesion(),
       "duplication": detect_duplication()
   }
   
   for metric, value in metrics.items():
       if value > thresholds[metric]:
           log_warning(f"{metric} exceeds threshold: {value}")
   ```

### Phase 3: Testing Gates

6. **Unit Test Execution**
   ```bash
   echo "🧪 Running unit tests..."
   
   # Run with coverage
   if [[ -f "Makefile" ]]; then
       make test-unit-coverage
   else
       # Auto-detect test runner
       if [[ -f "pytest.ini" ]] || [[ -f "pyproject.toml" ]]; then
           pytest tests/unit --cov --cov-report=term-missing
       elif [[ -f "package.json" ]]; then
           npm test -- --coverage
       fi
   fi
   
   # Validate coverage threshold
   coverage_result=$(get_coverage_percentage)
   if [[ $coverage_result -lt 85 ]]; then
       echo "❌ Coverage below 85%: ${coverage_result}%"
       exit 1
   fi
   ```

7. **Integration Test Execution**
   ```bash
   echo "🔗 Running integration tests..."
   
   # Start test dependencies
   make test-deps-up || docker-compose -f test-compose.yml up -d
   
   # Run integration suite
   make test-integration || npm run test:integration
   
   # Cleanup
   make test-deps-down || docker-compose -f test-compose.yml down
   ```

8. **End-to-End Test Execution**
   ```bash
   echo "🌐 Running E2E tests..."
   
   # Start application in test mode
   make run-test-server &
   SERVER_PID=$!
   
   # Wait for server ready
   wait_for_server localhost:8080
   
   # Run E2E suite
   make test-e2e || npm run test:e2e
   
   # Cleanup
   kill $SERVER_PID
   ```

### Phase 4: Performance Gates

9. **Performance Benchmarks**
   ```python
   echo "⚡ Running performance benchmarks..."
   
   benchmarks = {
       "latency": {
           "p50": measure_latency(percentile=50),
           "p99": measure_latency(percentile=99),
           "max": measure_latency(percentile=100)
       },
       "throughput": measure_requests_per_second(),
       "memory": {
           "heap": measure_heap_usage(),
           "rss": measure_rss_memory()
       },
       "cpu": measure_cpu_usage()
   }
   
   # Validate against targets
   for metric, target in performance_targets.items():
       if not meets_target(benchmarks[metric], target):
           log_failure(f"Performance gate failed: {metric}")
   ```

10. **Load Testing**
    ```bash
    echo "📊 Running load tests..."
    
    # Use appropriate load testing tool
    if command -v k6 &> /dev/null; then
        k6 run tests/load/spike-test.js
        k6 run tests/load/stress-test.js
        k6 run tests/load/soak-test.js
    elif command -v ab &> /dev/null; then
        ab -n 10000 -c 100 http://localhost:8080/
    fi
    ```

### Phase 5: Security Gates

11. **Security Scanning**
    ```bash
    echo "🔒 Running security scans..."
    
    # Dependency vulnerabilities
    if [[ -f "package.json" ]]; then
        npm audit --audit-level=moderate
        npx snyk test
    elif [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
        safety check
        pip-audit
    elif [[ -f "go.mod" ]]; then
        gosec ./...
        nancy go.sum
    fi
    
    # SAST scanning
    if command -v semgrep &> /dev/null; then
        semgrep --config=auto .
    fi
    
    # Secret scanning
    if command -v gitleaks &> /dev/null; then
        gitleaks detect --source . --verbose
    fi
    ```

12. **Permission & Access Control**
    ```python
    echo "🔐 Validating permissions..."
    
    # Check for overly permissive settings
    check_file_permissions()
    validate_api_auth()
    verify_least_privilege()
    audit_iam_policies()
    ```

### Phase 6: Documentation Gates

13. **Documentation Completeness**
    ```bash
    echo "📚 Checking documentation..."
    
    # API documentation
    if [[ -f "openapi.yaml" ]] || [[ -f "swagger.json" ]]; then
        swagger-cli validate openapi.yaml
    fi
    
    # Code documentation coverage
    if [[ -f "package.json" ]]; then
        npx documentation coverage src/**/*.js
    elif [[ -f "setup.py" ]]; then
        pydocstyle . --count
    fi
    
    # README validation
    if [[ -f "README.md" ]]; then
        markdownlint README.md
        markdown-link-check README.md
    fi
    ```

### Phase 7: Results Aggregation

14. **Generate Validation Report**
    ```python
    report = {
        "timestamp": datetime.now().isoformat(),
        "feature": feature_name,
        "gates": {
            "syntax": syntax_results,
            "types": type_results,
            "unit_tests": unit_test_results,
            "integration": integration_results,
            "e2e": e2e_results,
            "performance": performance_results,
            "security": security_results,
            "documentation": doc_results
        },
        "overall_status": "PASS" if all_gates_pass else "FAIL",
        "blocking_issues": get_blocking_issues(),
        "warnings": get_warnings()
    }
    
    # Save report
    save_json("artifacts/validation-report.json", report)
    ```

15. **Update Progress Tracking**
    ```json
    {
      "validation_history": [
        {
          "timestamp": "{iso_timestamp}",
          "status": "passed|failed",
          "gates_passed": ["syntax", "types", "unit_tests"],
          "gates_failed": [],
          "report_path": "artifacts/validation-report.json"
        }
      ]
    }
    ```

## Gate Definitions

```yaml
validation_gates:
  mandatory:  # Must pass for success
    - syntax_clean
    - type_check_pass
    - unit_tests_pass
    - security_scan_clean
    
  recommended:  # Should pass, warnings if not
    - coverage_above_80
    - integration_tests_pass
    - performance_targets_met
    - documentation_complete
    
  optional:  # Nice to have
    - e2e_tests_pass
    - load_test_pass
    - accessibility_check
    - i18n_validation
```

## Output

```
🎯 Validation Report: SPECS/active/{feature-name}/

✅ GATES PASSED (8/10):
   ✓ Syntax & Formatting
   ✓ Type Safety
   ✓ Unit Tests (92% coverage)
   ✓ Integration Tests
   ✓ Security Scan
   ✓ Documentation
   ✓ Performance (p99 < 95ms)
   ✓ Memory Usage (< 450MB)

⚠️ WARNINGS (2):
   ! E2E Tests: 1 flaky test
   ! Load Test: Degradation at 1500 rps

❌ FAILED GATES (0):
   (No critical failures)

📊 Detailed Metrics:
   • Test Coverage: 92.3%
   • Cyclomatic Complexity: 8.2 (avg)
   • Security Issues: 0 critical, 2 low
   • API Latency p99: 94ms
   • Memory Usage: 423MB
   • Documentation: 87% coverage

📁 Full Report: artifacts/validation-report.json

✨ Overall Status: PASSED

Next Actions:
   /spec-refine {feature-name}    - Address warnings
   /spec-complete {feature-name}  - Mark as done
   /spec-rollback {checkpoint}    - If issues found
```

## Error Handling

```python
def handle_gate_failure(gate_name, error):
    # Log detailed error
    log_error(f"Gate {gate_name} failed: {error}")
    
    # Attempt auto-fix for known issues
    if can_auto_fix(gate_name, error):
        fix_result = auto_fix(gate_name, error)
        if fix_result.success:
            return rerun_gate(gate_name)
    
    # Provide actionable feedback
    suggestions = get_fix_suggestions(gate_name, error)
    display_fix_guide(suggestions)
    
    # Offer rollback option
    if is_critical(gate_name):
        prompt_rollback_option()
```

## Notes
- Gates can be run individually with `--gate` flag
- Validation is non-destructive (read-only)
- Results are cached for 15 minutes
- Use `--force` to bypass cache
- Critical gates block progress
- Warnings don't block but should be addressed
- All results saved to artifacts for audit trail