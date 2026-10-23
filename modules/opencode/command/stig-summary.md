---
description: "Extract STIG evaluation summary for copy/paste: /stig-summary [--copy]"
---

# STIG Summary Extractor

Extracts Status Summary and Finding Details from the most recent STIG evaluation for easy copy/paste into STIG Viewer Details field.

## Usage

```bash
# Format summary for copy
/stig-summary

# Auto-copy to clipboard
/stig-summary --copy
```

## What It Does

1. Searches conversation for most recent STIG evaluation report
2. Extracts Status Summary paragraph
3. Extracts Finding Details section
4. Combines into clean, copyable format
5. Optionally copies to clipboard

## Output Format

```
[Status Summary paragraph - 2-4 sentences explaining why the status is what it is]

**Status:** [Not a Finding | Open | Not Applicable | Not Reviewed]

[Finding Details bullets - verified evidence]
```

**Note:** Output is clean content only - no formatting boundaries or headers

## Summary Guidelines

**CRITICAL: Conservative and Concise**

- **Better to say too little than too much**
- **Never make up data or embellish details**
- **Don't over-promise or speculate**
- **Stick to verified evidence only**

**When extracting summary:**
- If Status Summary is verbose, condense to essential points only
- Remove any speculative language ("likely", "probably", "may")
- Cut any details not directly verified in evidence
- Prefer shorter summaries over longer ones
- If uncertain about a detail, omit it

**Conservative approach prevents:**
- Making false claims in official STIG report
- Over-promising remediation that isn't verified
- Including assumptions as facts
- Adding technical details that can't be defended

**Example - Before vs After:**

❌ **Too verbose/speculative:**
```
The system appears to be compliant based on the configuration review. The PostgreSQL database is likely configured correctly on port 5432, which should align with DoD PPSM requirements. The service appears to use ClusterIP which probably restricts access appropriately. Additional network policies may provide further isolation.
```

✅ **Conservative and verified:**
```
The system is compliant. PostgreSQL is configured on port 5432 per DoD PPSM guidance (verified via SHOW port). Service uses ClusterIP type, restricting access to cluster network only (verified via kubectl get svc).
```

**Key differences:**
- Removed: "appears", "likely", "should", "probably", "may"
- Kept: Only verified facts with verification method noted
- Result: Shorter, defensible, factual

## Implementation

When invoked:

1. **Search conversation history** for most recent STIG evaluation report
   - Look for "## STIG Evaluation Report" heading
   - Find "## Status Summary" section
   - Find "## Finding Details" section

2. **Extract Status Summary**
   - Paragraph text between "## Status Summary" and next heading
   - Should be 2-4 sentences in paragraph form
   - Generic language (no pod names, no STIG references)
   - **Apply conservative filter: remove speculation, keep only verified claims**

3. **Extract Finding Details**
   - Bullet points or structured content between "## Finding Details" and next heading
   - Includes Status line
   - Includes evidence bullets or justification
   - May include Compensating Controls, Remediation, etc.
   - **Keep only verified evidence, remove any "per notes" or unverified claims**

4. **Format output**
   - Status Summary paragraph first
   - Blank line
   - Finding Details section
   - No headers, footers, or formatting boundaries
   - **If Status Summary is overly verbose, condense to key points only**

5. **Handle --copy flag**
   - If --copy provided, detect OS and use appropriate clipboard command:
     - macOS: `pbcopy`
     - Linux: `xclip -selection clipboard` or `xsel --clipboard`
     - WSL: `clip.exe`
   - Pipe formatted output to clipboard command
   - Display confirmation message

## Examples

### Example 1: Not Applicable Finding

**Input:** Most recent /stig evaluation with Not Applicable status

**Output:**
```
This requirement does not apply due to architectural compensating controls. User authentication is managed by the identity provider rather than the database, eliminating direct user account management. Connection limits are enforced at the application layer through connection pooling.

**Status:** Not Applicable

**Compensating Controls:**
- User Authentication: Keycloak IdP manages users (verified via pg_hba.conf - no user accounts defined)
- Database Access: Only service account connects (verified via pg_stat_activity - 4 active connections)
- Connection Pooling: Application limits connections to ~4 (observed via pg_stat_database)
- Network Isolation: NetworkPolicy restricts access to app namespace (verified via kubectl get netpol)
- Global Cap: max_connections=100 (verified via SHOW max_connections)

**Justification:** STIG assumes PostgreSQL manages per-user accounts for direct human access. Architecture eliminates this scenario through IdP authentication and service account pattern (verified).
```

### Example 2: Open Finding

**Input:** Most recent /stig evaluation with Open status

**Output:**
```
The requirement is not met. The container security context does not specify runAsNonRoot, allowing potential privilege escalation. This presents a security risk as containers could execute with root privileges.

**Status:** Open

**Current State:**
- runAsNonRoot: not set (Expected: true)
- allowPrivilegeEscalation: not set (Expected: false)

**Risk:** Container can escalate to root, potential privilege escalation vulnerability.

**Remediation Required:**
- Add containerSecurityContext.runAsNonRoot: true to pod spec
- Add containerSecurityContext.allowPrivilegeEscalation: false
```

### Example 3: Not a Finding

**Input:** Most recent /stig evaluation with Not a Finding status

**Output:**
```
The system is compliant. Container security context is configured with runAsNonRoot set to true and allowPrivilegeEscalation set to false. All required security settings are properly implemented.

**Status:** Not a Finding

**Evidence:**
- runAsNonRoot: true (compliant)
- allowPrivilegeEscalation: false (compliant)
- capabilities.drop: [ALL] (compliant)

**Verification:** kubectl get pod shows compliant security context configuration.
```

## Error Handling

**No STIG evaluation found:**
```
❌ No STIG evaluation found in conversation history.

Run /stig first to evaluate a STIG rule, then use /stig-summary to extract the summary.
```

**Multiple evaluations found:**
```
✅ Found multiple STIG evaluations. Using the most recent one.

STIG ID: V-242376
Status: Not Applicable
```

**Clipboard copy failed:**
```
⚠️  Could not copy to clipboard.

Clipboard command not available. Please copy manually from output above.
```

## Clipboard Commands by OS

**macOS:**
```bash
echo "content" | pbcopy
```

**Linux (with xclip):**
```bash
echo "content" | xclip -selection clipboard
```

**Linux (with xsel):**
```bash
echo "content" | xsel --clipboard --input
```

**WSL/Windows:**
```bash
echo "content" | clip.exe
```

**Detection logic:**
```bash
if command -v pbcopy &> /dev/null; then
    # macOS
    echo "$output" | pbcopy
elif command -v xclip &> /dev/null; then
    # Linux with xclip
    echo "$output" | xclip -selection clipboard
elif command -v xsel &> /dev/null; then
    # Linux with xsel
    echo "$output" | xsel --clipboard --input
elif command -v clip.exe &> /dev/null; then
    # WSL/Windows
    echo "$output" | clip.exe
else
    echo "⚠️  Clipboard command not available. Copy manually."
fi
```

## Notes

- Extracts from most recent STIG evaluation in conversation
- Does not re-run evaluation - works with existing output
- Generic language preserved (no pod names, no STIG IDs in summary)
- Only includes Status Summary + Finding Details (Technical Details omitted)
- Clipboard copy is optional and OS-aware
- Designed for STIG Viewer Details field workflow
- **Conservative by design: prefers brevity over verbosity, facts over speculation**
- **Filters out unverified claims, speculative language, and embellishments**
