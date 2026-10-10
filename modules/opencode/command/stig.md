---
description: "Evaluate STIG compliance in Kubernetes pods: /stig [options]"
---

# STIG Compliance Evaluator

Evaluates DISA STIG rules against Kubernetes pods with automated checks, evidence collection, and remediation guidance.

## Usage

```bash
/stig [--pod <name>] [--namespace <ns>] [--container <name>] [--chart <path>] [--notes "<context>"] [--output-format <format>]

<paste STIG content here>
```

**Parameters:**
- `--pod <name>`: Target pod (omit for interactive selection)
- `--namespace <ns>`: Namespace (default: current context)
- `--container <name>`: Container in multi-container pod
- `--chart <path>`: Helm chart path/name for remediation (triggers helm-chart-stig-remediator on Open findings)
- `--notes "<context|file>"`: Environment context for decision-making - inline text OR file path (e.g., ./docs/env-notes.md). **Note:** Context only, not cited as evidence - agent verifies claims
- `--output-format <format>`: `text` (default), `json`, or `checklist`

**Examples:**
```bash
# Basic evaluation
/stig --pod nginx-7d64c8-abc12

V-242376 - API Server anonymous auth disabled
Check: kubectl get pod -n kube-system -l component=kube-apiserver -o yaml | grep anonymous-auth
Expected: --anonymous-auth=false
Fix: Edit API server manifest, add --anonymous-auth=false

# With helm chart remediation
/stig --pod app-backend-xyz --chart ./charts/backend

V-242400 - Containers must run as non-root
Check: Inspect securityContext.runAsNonRoot
Expected: true
Fix: Set securityContext.runAsNonRoot=true

# With environment context (inline)
/stig --pod postgres-db-0 --notes "Database not exposed outside cluster. NetworkPolicy restricts access to app namespace only. Uses cert-based auth for replication."

V-245XXX - Database must use TLS for all connections
Check: Verify pg_hba.conf requires SSL
Expected: hostssl entries only
Fix: Configure SSL-only connections

# With environment context (file)
/stig --pod postgres-db-0 --notes ./docs/postgres-environment.md

V-245XXX - Database must use TLS for all connections
Check: Verify pg_hba.conf requires SSL
Expected: hostssl entries only
Fix: Configure SSL-only connections
```

**Notes file example (./docs/postgres-environment.md):**
```markdown
# PostgreSQL Environment Context

## Network Isolation
- Database pods deployed in dedicated namespace: `databases`
- NetworkPolicy enforced: only allows traffic from `app` namespace
- No external ingress configured
- No LoadBalancer or NodePort services

## Authentication
- Password auth used for application connections
- Certificate-based authentication for streaming replication
- Peer auth for local postgres user
- No remote root access permitted

## Compensating Controls
- All connections monitored via pgAudit
- WAL archival encrypted with GPG
- Backup encryption at rest (AES-256)
- Network traffic encrypted via service mesh (mTLS)

## Risk Acceptance
- Password auth acceptable given network isolation and monitoring
- TLS on application connections waived due to service mesh mTLS
- Approved by Security Team: TICKET-12345 (2024-10-15)
```

**How notes are used:**
- Notes inform agent what to verify (e.g., "NetworkPolicy exists" → agent runs `kubectl get netpol`)
- Notes explain architectural context (helps determine Not Applicable)
- Notes suggest compensating controls to check (agent verifies they exist)
- **Finding Details only cite verified evidence, NOT notes directly**
- Example: Notes say "service mesh mTLS" → agent checks Istio config → Finding Details cite actual Istio policy found

## STIG Content Format

Paste STIG rule as plain text or markdown. Parser extracts:
- **STIG ID**: V-XXXXXX identifier
- **Title/Description**: Control purpose
- **Severity**: CAT I/II/III or High/Medium/Low
- **Check**: Commands/procedures to verify compliance
- **Expected**: Compliant configuration state
- **Fix**: Remediation steps

Supported formats: structured text, markdown, minimal ID+checks, CKL XML

## Workflow

### 1. Parse STIG Content
Extract ID, severity, check procedures, expected results, remediation steps from pasted content.

### 2. Interactive Pod Selection
**If pod not specified:**
```bash
kubectl get pods -n <namespace> -o wide
kubectl get pods -n kube-system -o wide  # For system components
```

Present selection menu with pod status and node. For multi-container pods, prompt for container selection.

### 3. Delegate to stig-evaluator Agent

**Process --notes parameter:**
- If notes provided, check if it's a file path (contains `/`, `./`, or ends with `.md`, `.txt`)
- If file: Pass file path to agent (agent will read file on-demand)
- If inline text: Pass text directly to agent

Invoke stig-evaluator agent via Task tool with:
- Parsed STIG (ID, checks, expected, fixes)
- Target pod/namespace/container
- Environment notes: inline text OR file path
- Output format

**Agent executes (read-only):**
1. Load environment notes (read file if path provided, or use inline text)
2. Validate pod exists and is accessible
3. Run kubectl/exec commands to gather evidence
4. Compare evidence against expected results
5. Consider environment notes for context (compensating controls, network isolation, risk acceptance)
6. Determine finding status: Not a Finding | Open | Not Applicable | Not Reviewed
7. Generate report with remediation guidance and environmental context

**Common check patterns:**
```bash
# Config flags
kubectl get pod <pod> -n <ns> -o yaml | grep <flag>

# Files/permissions
kubectl exec -n <ns> <pod> -c <container> -- stat -c '%a' /path

# Security context
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[*].securityContext}'

# Processes
kubectl exec -n <ns> <pod> -- ps aux

# Network
kubectl exec -n <ns> <pod> -- netstat -tuln
```

### 4. Present Report

Agent returns three-part report:

**Part 1: Status Summary (For STIG Comments)**
- Concise 2-4 sentence paragraph
- Addresses why status is what it is
- NO pod names, NO STIG references (generic language)
- Ready to copy/paste into STIG Comments field

**Part 2: Finding Details (For STIG Details Field)**
- Concise, AO-focused bullet points (3-7 bullets)
- Ready for STIG Details field
- Includes: verified evidence, compensating controls, justification
- Audience: Authorizing Official, security team, auditors

**Part 3: Technical Details (Audit Trail)**
- Full command outputs
- Technical analysis
- Implementation details
- For reference, NOT for STIG report

### 5. Helm Chart Remediation (Optional)

**If --chart provided AND finding status is Open:**

Invoke helm-chart-stig-remediator agent via Task tool with:
- STIG evaluation results (ID, what failed, expected state)
- Helm chart path/name
- Pod/container details
- Environment notes (if provided)

**Agent executes:**
1. Locate helm chart (search filesystem or helm repo)
2. Analyze chart structure (values.yaml, templates, Chart.yaml)
3. Identify configuration gap causing STIG failure
4. Propose values.yaml changes (preferred) or template modifications
5. Generate helm upgrade command with new values
6. Write remediation plan to `.stigs/<STIG-ID>_helm-remediation.md`
7. Return summary with file path

**Output:**
- Creates `.stigs/` directory in project root if not exists
- Writes detailed remediation to `.stigs/<STIG-ID>_helm-remediation.md`
- Returns summary to main session with file location

**Helm remediation principles:**
- Prefer values.yaml changes over template edits
- Use existing configurability when available
- Add new values for reusability
- Hard-code only security defaults that shouldn't be configurable
- Maintain chart simplicity and upgradability

## Output Formats

**Text (default):** Human-readable markdown report
**JSON:** Structured data for automation/CI pipelines
**Checklist:** CKL XML for STIG Viewer import

## STIG Check Categories

Agent handles:
- **Configuration**: API server, kubelet, controller manager, etcd flags
- **Filesystem**: Permissions, ownership, content, certificates
- **Network**: Ports, TLS/SSL, policies, service mesh
- **RBAC**: Role bindings, service accounts, ClusterRoles
- **Pod/Container**: Security context, capabilities, resource limits, rootless
- **Admission Control**: Plugins, webhooks, OPA/Gatekeeper

## Batch Evaluation

Evaluate multiple STIGs against same pod:
```bash
/stig --pod <pod>

<STIG 1>
---
<STIG 2>
---
<STIG 3>
```

Outputs consolidated report.

## Error Handling

**Pod inaccessible:** Verify pod exists (`kubectl get pod`), check RBAC (`kubectl auth can-i exec pods`)
**Insufficient permissions:** Grant pods/exec, pods/get, pods/list
**Container not found:** List containers (`kubectl get pod -o jsonpath='{.spec.containers[*].name}'`)
**Evidence inconclusive:** Mark as Not Reviewed, document ambiguity

## Environment Variables

- `STIG_DEFAULT_NAMESPACE`: Override default namespace
- `STIG_OUTPUT_DIR`: Report save directory (default: `./stig-reports/`)
- `KUBECTL_CONTEXT`: Kubernetes context to use
- `STIG_AUTO_SAVE`: Auto-save reports (default: true)
- `HELM_CHART_PATH`: Default helm chart path for --chart flag

## CI/CD Integration

```yaml
# Fail on Open findings
- run: claude /stig --pod $POD --output-format json < stig.txt > result.json
- run: |
    if [ "$(jq -r '.finding.status' result.json)" = "Open" ]; then exit 1; fi

# Generate helm remediation, commit to repo
- run: claude /stig --pod $POD --chart ./charts/app < stig.txt
- run: |
    if [ -d .stigs ]; then
      git add .stigs/
      git commit -m "chore: STIG helm remediation plans"
    fi

# Post remediation to PR for review
- run: |
    if [ -d .stigs ]; then
      cat .stigs/*.md | gh pr comment $PR --body-file -
    fi
```

## Special Considerations

**Static Pods (control plane):** Config in `/etc/kubernetes/manifests/` on nodes. Provide both kubectl and SSH remediation options.

**Managed K8s (EKS/GKE/AKS):** Control plane inaccessible. Document provider-specific compliance, mark N/A with justification when appropriate.

**CIS Benchmark:** Many STIGs align with CIS. Cross-reference controls, leverage kube-bench tooling.

**PSS/PSA:** Adapt legacy PSP STIGs to Pod Security Standards equivalents.

## Notes

- **Read-only operation**: No cluster state modifications
- **RBAC required**: pods/get, pods/exec, pods/list in target namespace
- **Manual remediation**: All fix steps are guidance - execute manually after review
- **Output format**: Three-part report - Status Summary (paragraph for Comments) + Finding Details (bullets for Details) + Technical Details (audit trail)
- **AO-focused**: Status Summary and Finding Details sections optimized for Authorizing Official review and copy/paste into STIG fields
- **Generic language**: Status Summary uses generic terms (the system, the database) - no pod names or STIG references
- **Environment notes**: Context for decision-making (inline text or file path); suggests what to verify but NOT cited as evidence
- **Notes verification**: Agent verifies claims from notes with actual checks; Finding Details only include verified evidence
- **Notes from file**: Saves context window - agents read file on-demand using Read tool
- **Helm remediation**: When --chart provided, proposes values.yaml changes for Open findings
- **Remediation files**: Helm remediations saved to `.stigs/<STIG-ID>_helm-remediation.md` for persistence and version control
- **Chart configurability**: Helm proposals prioritize values.yaml, avoid hard-coding
- **Secret protection**: Sensitive values redacted from evidence
- **Context**: Uses current kubectl context unless overridden
- **Multi-cluster**: Use `--context` flag or `KUBECTL_CONTEXT` variable
