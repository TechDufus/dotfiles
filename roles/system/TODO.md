# System Role TODOs and Known Issues

## /etc/hosts Management Refactor

**Priority**: High  
**Status**: Archived, needs complete refactor  
**File**: `tasks/main.yml` (lines 11-51)

### Current Issues:
1. Hardcoded 1Password vault paths specific to personal use
2. Repetitive code for each host entry
3. No error handling for missing 1Password entries
4. WSL handling is too simplistic
5. Overwrites entire /etc/hosts file (dangerous!)

### Proposed Solution:
```yaml
# Example of better approach:
system_custom_hosts:
  - name: "myapp.local"
    ip: "127.0.0.1"
  - name: "database.local"
    ip: "192.168.1.100"
    source: "op://vault/item/field"  # Optional 1Password source

# Or use blockinfile for safer updates:
- name: "System | Manage custom hosts entries"
  ansible.builtin.blockinfile:
    path: /etc/hosts
    marker: "# {mark} ANSIBLE MANAGED CUSTOM HOSTS"
    block: |
      {% for host in system_custom_hosts %}
      {{ host.ip }} {{ host.name }}
      {% endfor %}
```

### Action Items:
- [ ] Create a new `hosts` role or submodule
- [ ] Support multiple host sources (static, 1Password, files)
- [ ] Use blockinfile to preserve system entries
- [ ] Add host validation
- [ ] Better WSL detection and handling
- [ ] Make 1Password integration optional
- [ ] Add tests

### References:
- Original code archived in: `tasks/hosts-management-archive.yml`
- Related issue: #XX (create GitHub issue)