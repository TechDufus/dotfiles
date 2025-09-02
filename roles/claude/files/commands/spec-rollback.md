---
description: "Rollback to a previous checkpoint: /spec-rollback <feature-name> [checkpoint-id]"
---

# Rollback to Checkpoint

## Feature: $ARGUMENTS

Safely revert implementation to a previous known-good state using checkpoint recovery system.

## Process

### Phase 1: Checkpoint Discovery

1. **Parse Arguments**
   ```python
   feature_name = parse_feature_name()
   checkpoint_id = parse_checkpoint_id()  # Optional, defaults to last stable
   
   # Load checkpoint history
   checkpoints = load(".state/checkpoints.json")
   progress = load(".state/progress.json")
   ```

2. **List Available Checkpoints**
   If no checkpoint specified, show options:
   ```
   🔄 Available Checkpoints for {feature-name}:
   
   ID: checkpoint-2024-01-15-14-30-00 [STABLE] ← (recommended)
   Phase: implementation
   Task: implement-api-endpoints
   Status: validation-passed
   Files: 12 modified, 8 added
   Tests: 15 passing
   Coverage: 87%
   
   ID: checkpoint-2024-01-15-13-45-00
   Phase: implementation
   Task: create-data-models
   Status: validation-passed
   Files: 5 modified, 3 added
   Tests: 8 passing
   Coverage: 82%
   
   ID: checkpoint-2024-01-15-12-00-00 [BASELINE]
   Phase: architecture-complete
   Status: ready-for-implementation
   Files: 0 modified
   ```

3. **Validate Checkpoint**
   ```python
   def validate_checkpoint(checkpoint_id):
       checkpoint = load_checkpoint(checkpoint_id)
       
       # Verify checkpoint integrity
       if not verify_checksum(checkpoint):
           raise CheckpointCorrupted(checkpoint_id)
       
       # Check if checkpoint is reachable
       if not can_rollback_to(checkpoint):
           raise CheckpointUnreachable(checkpoint_id)
       
       # Warn about data loss
       changes_since = get_changes_since(checkpoint)
       if changes_since:
           confirm_data_loss(changes_since)
   ```

### Phase 2: Pre-Rollback Analysis

4. **Impact Assessment**
   ```python
   impact = {
       "files_to_revert": [],
       "files_to_delete": [],
       "tests_affected": [],
       "features_lost": [],
       "time_lost": calculate_time_lost(),
       "commits_to_revert": []
   }
   
   # Show what will be lost
   print(f"""
   ⚠️ Rollback Impact Analysis:
   
   You will lose:
   • {len(impact['files_to_revert'])} file modifications
   • {len(impact['files_to_delete'])} new files
   • {len(impact['tests_affected'])} test additions
   • {impact['time_lost']} hours of work
   
   Features that will be removed:
   {format_list(impact['features_lost'])}
   
   Continue? [y/N]
   """)
   ```

5. **Create Recovery Point**
   Before rollback, save current state:
   ```bash
   # Create recovery branch
   git stash
   git checkout -b recovery/{feature-name}-{timestamp}
   git stash pop
   git add -A
   git commit -m "Recovery point before rollback to {checkpoint_id}"
   
   # Save recovery metadata
   save_recovery_point({
       "from_state": current_state,
       "to_checkpoint": checkpoint_id,
       "timestamp": now(),
       "reason": get_rollback_reason()
   })
   ```

### Phase 3: Execute Rollback

6. **File System Rollback**
   ```python
   def rollback_files(checkpoint):
       # Phase 1: Revert modified files
       for file in checkpoint.modified_files:
           restore_file(file, checkpoint.version)
       
       # Phase 2: Remove new files
       for file in checkpoint.new_files_since:
           safe_delete(file)
       
       # Phase 3: Restore deleted files
       for file in checkpoint.deleted_files_since:
           restore_deleted(file)
       
       # Phase 4: Reset permissions
       restore_permissions(checkpoint.permissions)
   ```

7. **Git State Management**
   ```bash
   # Option 1: Soft rollback (preserve history)
   git checkout {checkpoint.commit}
   git checkout -b spec/{feature-name}-rolled-back
   
   # Option 2: Hard rollback (rewrite history)
   # ⚠️ Only if no pushes since checkpoint
   git reset --hard {checkpoint.commit}
   
   # Option 3: Revert commits (safest)
   for commit in {commits_since_checkpoint}; do
       git revert --no-edit $commit
   done
   git commit -m "Rollback to checkpoint {checkpoint_id}"
   ```

8. **Database Rollback** (if applicable)
   ```python
   if checkpoint.has_migrations:
       # Reverse migrations
       for migration in reversed(checkpoint.migrations_since):
           run_migration_down(migration)
       
       # Verify schema state
       verify_schema_matches(checkpoint.schema_snapshot)
   ```

9. **Dependency Rollback**
   ```bash
   # Restore package versions
   if [[ -f "{checkpoint.path}/package-lock.json" ]]; then
       cp {checkpoint.path}/package-lock.json .
       npm ci
   elif [[ -f "{checkpoint.path}/poetry.lock" ]]; then
       cp {checkpoint.path}/poetry.lock .
       poetry install --sync
   elif [[ -f "{checkpoint.path}/go.sum" ]]; then
       cp {checkpoint.path}/go.sum .
       go mod download
   fi
   ```

### Phase 4: Post-Rollback Validation

10. **Verify Rollback Success**
    ```python
    def verify_rollback():
        # Check file states
        for file, checksum in checkpoint.file_checksums.items():
            current = calculate_checksum(file)
            assert current == checksum
        
        # Run checkpoint's validation
        validation_results = run_validation_gates(checkpoint.gates)
        assert validation_results.passed
        
        # Verify tests pass
        test_results = run_tests(checkpoint.test_suite)
        assert test_results.all_passing
    ```

11. **Update State Tracking**
    ```json
    {
      "current_checkpoint": "{checkpoint_id}",
      "rollback_history": [
        {
          "timestamp": "{iso_timestamp}",
          "from": "{previous_checkpoint}",
          "to": "{checkpoint_id}",
          "reason": "{user_provided_reason}",
          "recovery_branch": "recovery/{feature}-{timestamp}"
        }
      ],
      "phase": "{checkpoint.phase}",
      "tasks_completed": "{checkpoint.tasks_completed}"
    }
    ```

### Phase 5: Recovery Options

12. **Post-Rollback Actions**
    Present options to user:
    ```
    ✅ Rollback Complete
    
    Current State:
    • Checkpoint: {checkpoint_id}
    • Phase: {phase}
    • Tasks Complete: {X}/{Y}
    • Tests Passing: {count}
    • Coverage: {percent}%
    
    Recovery Options:
    1. Continue from this checkpoint
       → /spec-implement {feature-name}
    
    2. Revise architecture
       → /spec-architect {feature-name}
    
    3. Cherry-pick specific changes
       → git cherry-pick {commit-range}
    
    4. View recovery branch
       → git checkout recovery/{feature}-{timestamp}
    
    5. Abandon and restart
       → /spec-init {new-feature-name}
    ```

## Checkpoint Structure

```yaml
checkpoint:
  id: checkpoint-{timestamp}
  feature: {name}
  phase: specification|architecture|implementation|refinement
  task: {current_task_id}
  git:
    branch: {branch_name}
    commit: {commit_sha}
    uncommitted: {stash_ref}
  files:
    modified: [{path: checksum}]
    added: [paths]
    deleted: [paths]
  tests:
    suite: {test_ids}
    passing: {count}
    coverage: {percent}
  validation:
    gates_passed: [gate_names]
    gates_failed: []
  metadata:
    timestamp: {iso_timestamp}
    stability: stable|unstable|experimental
    notes: {optional_description}
```

## Error Recovery

```python
def handle_rollback_failure(error):
    # Attempt automatic recovery
    if isinstance(error, CheckpointCorrupted):
        # Try previous checkpoint
        previous = get_previous_checkpoint()
        if previous:
            return rollback_to(previous)
    
    elif isinstance(error, GitConflict):
        # Create conflict resolution branch
        create_conflict_branch()
        log_conflicts()
        provide_resolution_guide()
    
    elif isinstance(error, DatabaseMigrationError):
        # Restore database backup
        restore_database_backup(checkpoint.db_backup)
    
    # If all else fails
    create_emergency_backup()
    provide_manual_recovery_instructions()
```

## Output

```
🔄 Rollback to checkpoint-2024-01-15-14-30-00

📊 Rollback Summary:
   • Reverted 12 files
   • Removed 3 new files  
   • Restored 2 deleted files
   • Reset 15 test files
   • Reverted 3 commits
   
✅ Validation Status:
   • Syntax: ✓ Clean
   • Tests: ✓ 15 passing
   • Coverage: ✓ 87%
   • Build: ✓ Success

💾 Recovery Point Saved:
   Branch: recovery/{feature}-{timestamp}
   You can return to pre-rollback state anytime
   
📍 Current Position:
   Checkpoint: {checkpoint_id}
   Phase: implementation
   Task: implement-api-endpoints
   Next: /spec-implement {feature-name}

⚠️ Work Lost:
   • 2 hours of development
   • 3 features incomplete
   • View in recovery branch for reference
```

## Safety Features

- **No destructive operations**: Original work saved in recovery branch
- **Validation before rollback**: Ensures checkpoint is stable
- **Atomic operation**: All-or-nothing rollback
- **Multiple recovery paths**: Soft/hard/revert options
- **Audit trail**: Complete history of rollbacks
- **Emergency backup**: Created before any rollback

## Notes
- Rollbacks are always safe - work is never truly lost
- Recovery branches preserve all work for reference
- Checkpoints are created automatically during implementation
- Manual checkpoints can be created with `/spec-checkpoint`
- Database rollbacks require migration down methods
- Use `--force` flag to skip confirmations (dangerous)
- Rollback history is preserved in `.state/rollback-history.json`