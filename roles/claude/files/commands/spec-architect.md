---
description: "Architect technical design from specification: /spec-architect <feature-name>"
---

# Architect Technical Design

## Feature: $ARGUMENTS

Transform validated specifications into comprehensive technical architecture using SPARC methodology, emphasizing pseudocode blueprints and implementation patterns.

## Prerequisites
- Feature has complete specification in `SPECS/active/{feature-name}/`
- Requirements are validated and complete
- Open questions are resolved
- Context research is cached

## Process

### Phase 1: Load & Analyze

1. **Load Full Context**
   ```python
   # Parallel context loading
   context = {
       "specification": load("specification/requirements.md"),
       "pseudocode": load("pseudocode/initial.md"),
       "architecture": load("architecture/initial.md"),
       "validation": load("validation/gates.md"),
       "progress": load(".state/progress.json"),
       "patterns": load_dir("context/"),
       "similar_features": analyze_codebase_patterns()
   }
   ```

2. **Deep Codebase Analysis**
   Execute parallel research:
   - **Pattern Mining**: Extract similar implementations
   - **Dependency Mapping**: Chart integration landscape
   - **Convention Analysis**: Document coding standards
   - **Test Strategy**: Identify testing patterns
   - **Security Audit**: Review security implementations
   - **Performance Patterns**: Analyze optimization approaches

### Phase 2: Pseudocode Development

3. **ULTRATHINK: Blueprint Design**
   Before implementation, think deeply about:
   - Algorithmic approach and complexity
   - Data structures and flow
   - State management strategy
   - Error propagation patterns
   - Concurrency considerations
   - Caching strategies

4. **Generate Detailed Pseudocode**
   Create `pseudocode/detailed.md`:
   ```
   COMPONENT: {name}
   PURPOSE: {single responsibility}

   INTERFACE:
     inputs: {typed parameters}
     outputs: {return types}
     errors: {exception types}

   ALGORITHM:
     1. Validate inputs
        - Check {condition}
        - Enforce {constraint}
     2. Core logic
        - Transform {data}
        - Apply {business rule}
     3. Handle edge cases
        - If {condition}: {action}
     4. Return results

   INTEGRATION:
     - Calls: {downstream services}
     - Called by: {upstream services}
     - Events: {published/subscribed}
   ```

### Phase 3: Architecture Design

5. **Component Architecture**
   Create `architecture/components.md`:
   - **Layered Design**: Presentation → Business → Data
   - **Service Boundaries**: Clear interfaces
   - **Data Flow**: Unidirectional where possible
   - **State Management**: Centralized vs distributed
   - **Caching Layers**: L1/L2/L3 strategies

6. **Technical Specifications**
   Document in `architecture/technical-spec.md`:
   ```yaml
   apis:
     - endpoint: /api/v1/{resource}
       method: POST
       request_schema: {ref}
       response_schema: {ref}
       auth: bearer_token
       rate_limit: 100/min

   data_models:
     - entity: {name}
       attributes: {typed_fields}
       relations: {foreign_keys}
       indexes: {performance_keys}

   infrastructure:
     compute: {requirements}
     storage: {requirements}
     network: {requirements}
     scaling: {auto_scale_rules}
   ```

7. **Integration Design**
   Map in `architecture/integrations.md`:
   - External service contracts
   - Message queue patterns
   - Event streaming design
   - API gateway configuration
   - Circuit breaker patterns

### Phase 4: Implementation Planning

8. **Task Decomposition**
   Generate `architecture/tasks.md`:
   ```markdown
   ## Phase 1: Foundation (2-3 hours)
   - [ ] Set up project structure
   - [ ] Configure dependencies
   - [ ] Initialize testing framework
   - [ ] Create CI/CD pipeline

   ## Phase 2: Core Implementation (4-6 hours)
   - [ ] Implement data models
   - [ ] Build service layer
   - [ ] Create API endpoints
   - [ ] Add validation logic

   ## Phase 3: Integration (2-3 hours)
   - [ ] Connect external services
   - [ ] Set up message queues
   - [ ] Configure monitoring
   - [ ] Add logging

   ## Phase 4: Refinement (2-3 hours)
   - [ ] Performance optimization
   - [ ] Security hardening
   - [ ] Documentation
   - [ ] Error handling enhancement
   ```

9. **Risk Analysis**
   Document in `architecture/risks.md`:
   - Technical risks with mitigation
   - Performance bottlenecks
   - Security vulnerabilities
   - Scalability concerns
   - Dependency risks

### Phase 5: Validation Planning

10. **Test Strategy**
    Create `validation/test-strategy.md`:
    ```yaml
    test_pyramid:
      unit:
        coverage_target: 85%
        critical_paths: 100%
        frameworks: [pytest, jest]

      integration:
        api_tests: contract_based
        db_tests: transactional
        external_mocks: wiremock

      e2e:
        user_journeys: 5
        browsers: [chrome, firefox]
        devices: [desktop, mobile]

      performance:
        load_test: 1000_concurrent
        stress_test: 5x_normal_load
        soak_test: 24_hours
    ```

11. **Quality Gates**
    Update `validation/gates.md`:
    ```bash
    # Automated gates (must pass)
    make lint          # Code style
    make typecheck     # Type safety
    make test          # Unit tests
    make integration   # Integration tests
    make security      # Security scan
    make performance   # Performance benchmarks

    # Manual gates (review required)
    - Architecture review approved
    - Security review passed
    - Performance targets met
    - Documentation complete
    ```

### Phase 6: Context Enrichment

12. **External Research**
    Perform and cache:
    - Library documentation URLs
    - Best practice guides
    - Common pitfall articles
    - Performance tuning guides
    - Security advisories

13. **Decision Documentation**
    Record in `architecture/decisions.md`:
    ```markdown
    ## ADR-001: {Decision Title}
    **Status**: Accepted
    **Context**: {Why this decision was needed}
    **Decision**: {What was decided}
    **Alternatives**: {Other options considered}
    **Consequences**: {Impact of decision}
    **References**: {Links to research}
    ```

## Output

```
✅ Architecture Complete: SPECS/active/{feature-name}/

📐 Design Artifacts:
   • Pseudocode blueprints: {X} components
   • API specifications: {Y} endpoints
   • Data models: {Z} entities
   • Integration points: {N} services

📊 Complexity Analysis:
   • Cyclomatic complexity: {score}
   • Coupling score: {score}
   • Cohesion rating: {score}
   • Test complexity: {score}

🎯 Implementation Readiness: {8.5}/10

📋 Task Breakdown:
   • Total tasks: {count}
   • Estimated time: {hours}
   • Risk level: {low|medium|high}
   • Dependencies: {count}

✓ Validation Gates Defined:
   • Automated checks: {X}
   • Manual reviews: {Y}
   • Performance targets: Set
   • Security controls: Defined

Next Commands:
   /spec-implement {feature-name}  - Begin implementation
   /spec-validate {feature-name}   - Run validation gates
   /spec-status {feature-name}     - Check progress

Agent Delegation:
   @@spec-implement on SPECS/active/{feature-name}
```

## Quality Checklist
- [ ] All requirements mapped to components
- [ ] Pseudocode covers all logic paths
- [ ] API contracts fully specified
- [ ] Data models normalized
- [ ] Integration points documented
- [ ] Test strategy comprehensive
- [ ] Performance targets defined
- [ ] Security controls identified
- [ ] Rollback strategy included
- [ ] Decision rationale recorded

## Notes
- ULTRATHINK before designing complex algorithms
- Reference existing patterns from context cache
- Include URLs to documentation for agent reference
- Ensure pseudocode is detailed enough for one-pass implementation
- Validation gates must be executable by automation
- Architecture should enable parallel development where possible