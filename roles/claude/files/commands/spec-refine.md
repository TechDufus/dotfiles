---
description: "Refine implementation through iterative improvement: /spec-refine <feature-name> [--focus performance|security|quality|ux]"
---

# Refine Implementation

## Feature: $ARGUMENTS

Execute the Refinement phase of SPARC methodology through iterative optimization, focusing on performance, quality, security, and user experience.

## Prerequisites
- Implementation complete with all tests passing
- Validation gates executed at least once
- No critical blockers active
- Baseline metrics established

## Process

### Phase 1: Refinement Analysis

1. **Load Implementation State**
   ```python
   # Load current metrics and identify improvement areas
   metrics = load_current_metrics()
   validation_results = load_latest_validation()
   user_feedback = load_feedback_if_available()
   performance_profile = run_profiling()

   # Determine refinement focus
   focus_area = parse_focus() or auto_detect_focus()
   ```

2. **Identify Refinement Opportunities**
   ```python
   opportunities = {
       "performance": [
           analyze_bottlenecks(),
           identify_slow_queries(),
           find_memory_leaks(),
           detect_unnecessary_computations()
       ],
       "quality": [
           find_code_duplication(),
           identify_complex_functions(),
           detect_missing_tests(),
           analyze_error_handling()
       ],
       "security": [
           scan_vulnerabilities(),
           audit_permissions(),
           check_input_validation(),
           review_authentication()
       ],
       "ux": [
           measure_response_times(),
           analyze_error_messages(),
           review_api_consistency(),
           check_accessibility()
       ]
   }
   ```

3. **Prioritize Improvements**
   ```
   🎯 Refinement Priority Matrix:

   High Impact + Easy:
   1. Cache database queries (2hr, +40% speed)
   2. Add input validation (1hr, security fix)
   3. Simplify error messages (30min, better UX)

   High Impact + Hard:
   4. Refactor auth system (4hr, maintainability)
   5. Optimize algorithms (3hr, -50% CPU)

   Low Impact + Easy:
   6. Update documentation (1hr)
   7. Add debug logging (30min)
   ```

### Phase 2: Performance Refinement

4. **Performance Profiling**
   ```bash
   echo "⚡ Running performance analysis..."

   # CPU profiling
   if [[ "$LANGUAGE" == "python" ]]; then
       python -m cProfile -o profile.stats main.py
       snakeviz profile.stats
   elif [[ "$LANGUAGE" == "node" ]]; then
       node --prof app.js
       node --prof-process isolate-*.log
   elif [[ "$LANGUAGE" == "go" ]]; then
       go test -cpuprofile=cpu.prof -bench .
       go tool pprof cpu.prof
   fi

   # Memory profiling
   run_memory_profiler()
   detect_memory_leaks()
   analyze_heap_usage()
   ```

5. **Query Optimization**
   ```python
   # Database query analysis
   slow_queries = identify_slow_queries()

   for query in slow_queries:
       # Add indexes
       suggest_indexes(query)

       # Optimize joins
       rewrite_inefficient_joins(query)

       # Add caching
       implement_query_cache(query)

       # Batch operations
       batch_similar_queries(query)
   ```

6. **Algorithm Optimization**
   ```python
   # Complexity analysis
   for function in get_complex_functions():
       current_complexity = analyze_complexity(function)

       if current_complexity > O_N_SQUARED:
           # Suggest better algorithm
           better_algo = suggest_algorithm(function)
           implement_optimization(better_algo)

       # Add memoization where applicable
       if is_pure_function(function):
           add_memoization(function)
   ```

### Phase 3: Quality Refinement

7. **Code Quality Improvements**
   ```python
   # Refactoring for maintainability
   refactoring_tasks = [
       extract_methods(long_functions),
       reduce_coupling(tightly_coupled_modules),
       improve_naming(ambiguous_names),
       simplify_conditionals(complex_conditions),
       remove_dead_code(unused_code)
   ]

   for task in refactoring_tasks:
       # Ensure tests still pass after each change
       apply_refactoring(task)
       run_test_suite()
       verify_behavior_unchanged()
   ```

8. **Test Enhancement**
   ```python
   # Improve test coverage and quality
   coverage_gaps = find_uncovered_code()

   for gap in coverage_gaps:
       if is_critical_path(gap):
           priority = "high"
       else:
           priority = "normal"

       write_test(gap, priority)

   # Add property-based tests
   add_property_tests(critical_functions)

   # Add performance tests
   add_benchmark_tests(performance_critical_paths)
   ```

9. **Error Handling Refinement**
   ```python
   # Improve error handling and recovery
   error_points = find_error_prone_areas()

   for point in error_points:
       # Add proper error types
       define_specific_errors(point)

       # Implement retry logic
       add_retry_mechanism(point)

       # Improve error messages
       enhance_error_context(point)

       # Add telemetry
       add_error_tracking(point)
   ```

### Phase 4: Security Refinement

10. **Security Hardening**
    ```bash
    echo "🔒 Security refinement..."

    # Input validation
    add_input_sanitization()
    implement_rate_limiting()
    add_request_validation()

    # Authentication & Authorization
    strengthen_password_requirements()
    implement_mfa_support()
    audit_permission_checks()

    # Data protection
    encrypt_sensitive_data()
    implement_field_level_encryption()
    add_audit_logging()

    # Dependencies
    update_vulnerable_dependencies()
    add_dependency_scanning()
    ```

11. **Security Testing**
    ```python
    # Run security test suite
    security_tests = [
        test_sql_injection(),
        test_xss_vulnerabilities(),
        test_csrf_protection(),
        test_authentication_bypass(),
        test_authorization_flaws(),
        test_sensitive_data_exposure()
    ]

    for test in security_tests:
        result = run_security_test(test)
        if result.vulnerable:
            fix_vulnerability(result)
            verify_fix(test)
    ```

### Phase 5: UX Refinement

12. **API/CLI Usability**
    ```python
    # Improve developer experience
    dx_improvements = {
        "consistency": standardize_api_responses(),
        "documentation": generate_openapi_spec(),
        "examples": add_usage_examples(),
        "errors": improve_error_messages(),
        "defaults": set_sensible_defaults(),
        "shortcuts": add_convenience_methods()
    }
    ```

13. **Performance Perception**
    ```python
    # Optimize perceived performance
    perception_optimizations = [
        implement_progressive_loading(),
        add_optimistic_updates(),
        implement_request_debouncing(),
        add_loading_indicators(),
        implement_graceful_degradation()
    ]
    ```

### Phase 6: Iteration & Validation

14. **Iterative Refinement Cycles**
    ```python
    for iteration in range(max_iterations):
        # Apply refinements
        apply_improvements(prioritized_list)

        # Validate improvements
        new_metrics = measure_metrics()

        # Compare with baseline
        improvement = calculate_improvement(baseline, new_metrics)

        if improvement < threshold:
            # Try different approach
            adjust_strategy()
        elif meets_all_targets(new_metrics):
            break

        # Update baseline for next iteration
        baseline = new_metrics
    ```

15. **Final Validation**
    ```bash
    # Run comprehensive validation
    /spec-validate {feature-name} --detailed

    # Performance benchmarks
    run_load_tests()
    run_stress_tests()

    # Security audit
    run_security_audit()

    # Quality metrics
    measure_code_quality()
    check_documentation_coverage()
    ```

## Refinement Strategies

```yaml
performance_focus:
  - Profile first, optimize second
  - Focus on bottlenecks, not micro-optimizations
  - Measure impact of each change
  - Consider caching before algorithm changes
  - Database queries often biggest wins

quality_focus:
  - Refactor in small, safe steps
  - Keep tests green throughout
  - Improve naming and clarity
  - Reduce complexity scores
  - Eliminate duplication

security_focus:
  - Assume all input is malicious
  - Defense in depth approach
  - Least privilege principle
  - Audit all changes
  - Regular dependency updates

ux_focus:
  - Consistency over cleverness
  - Clear error messages
  - Sensible defaults
  - Progressive enhancement
  - Fast perceived performance
```

## Output

```
🔧 Refinement Complete: {feature-name}

📊 Improvement Metrics:
Performance:
  • Response time: 250ms → 95ms (-62%)
  • Throughput: 500 rps → 1200 rps (+140%)
  • Memory usage: 512MB → 380MB (-26%)
  • CPU usage: 45% → 22% (-51%)

Quality:
  • Cyclomatic complexity: 12 → 6 (-50%)
  • Code duplication: 8% → 2% (-75%)
  • Test coverage: 85% → 94% (+9%)
  • Documentation: 70% → 95% (+25%)

Security:
  • Vulnerabilities: 3 → 0 (resolved all)
  • OWASP compliance: 7/10 → 10/10
  • Dependency risks: 2 high → 0
  • Security score: B → A+

UX:
  • Error clarity: improved 40%
  • API consistency: 100% standardized
  • Response time p99: <100ms achieved
  • Documentation examples: +15 added

🎯 Targets Achieved:
  ✅ Performance: All metrics within SLA
  ✅ Security: Passed all security gates
  ✅ Quality: Exceeds code quality standards
  ✅ UX: Developer satisfaction improved

📈 Iteration Summary:
  • Iterations completed: 3
  • Total refinement time: 6.5 hours
  • ROI: 250% performance improvement
  • Technical debt reduced: 40%

Next Steps:
  /spec-complete {feature-name}  - Finalize and archive
  /spec-validate {feature-name}  - Run final validation
  /spec-status {feature-name}    - View detailed metrics
```

## Notes
- Refinement is iterative - multiple passes normal
- Always measure before and after changes
- Focus on highest-impact improvements first
- Keep validation gates green throughout
- Document rationale for significant changes
- Consider creating benchmarks for regression prevention
- Profile in production-like environment
- Balance perfectionism with practical delivery