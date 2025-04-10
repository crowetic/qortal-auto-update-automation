# Qortal Auto-Update Publisher Script

This script provides a modern, simplified, and testable way to publish an auto-update transaction for Qortal. It replaces the legacy Perl-based script with a more maintainable Python version.

## 🔧 Requirements (Before Running)

Ensure the following steps and conditions are met:

1. **Node Environment**
   - A local Qortal node must be running and fully synced.
   - The node must expose its API (default port: `12391`).
   - Ensure your node's `settings.json` includes access to the relevant endpoints (i.e., it's not locked down).

2. **Qortal Update Prepared**
   - You have run the `tools/build-auto-update.sh` script (or the improved `build-auto-update.sh` version).
   - This should generate a `.update` file (e.g. `qortal.update`) and commit it to a new branch named: `auto-update-<commit-hash>`.

3. **Git Repository Setup**
   - You must be inside the root of the Qortal Git repository.
   - The `pom.xml` file should contain the correct `<artifactId>`.
   - You have pushed your commit + branch to a public GitHub repository, preferably a fork (for testing).

4. **Authentication**
   - You possess the **Base58-encoded private key** for a non-admin member of the `dev` group.
   - The key must correspond to a Qortal account that can submit `ARBITRARY` transactions to the group (group ID 1).

5. **Python Requirements**
   - Python 3.6+
   - `requests` package (`pip install requests`)

## 🚀 Full Auto-Update Workflow

### Step 1: Prepare Your Code
- Ensure your latest code changes are committed and pushed.
- Bump the version in `pom.xml` if needed.
- Tag the commit with the version number (e.g. `v1.4.2`) and push the tag.

```bash
git commit -m "Bump version to 1.4.2" pom.xml
git tag v1.4.2
git push origin v1.4.2
```

### Step 2: Build the XOR-Obfuscated Update
Use the improved `build-auto-update.sh`:
```bash
./build-auto-update.sh
```
- This builds the JAR.
- XORs it into `qortal.update`.
- Creates a new branch named `auto-update-<commit>` and pushes it.

### Step 3: Test the Update Transaction (Dry Run)
```bash
python3 publish_auto_update.py <Base58PrivateKey> <CommitHash> --repo YourUser/qortal-test --dry-run
```
- This will validate the timestamp, hash, and download URL, without submitting anything to the chain.

### Step 4: Publish the Auto-Update
```bash
python3 publish_auto_update.py <Base58PrivateKey> <CommitHash> --repo YourUser/qortal-test
```
- This will sign and submit the auto-update transaction.

### Step 5: Approve the Update (Admin Only)
- Use `tools/approve-auto-update.sh` from a dev group admin account to approve the update.
- A minimum number of approvals + block confirmations will trigger update rollout.

### Step 6: Monitor and Confirm
- Nodes will download the update over the next ~20 minutes (per `CHECK_INTERVAL`).
- Confirm via logs or block explorer that the update was received and applied.

---

By following this workflow, new contributors and developers can easily participate in the Qortal auto-update process with minimal risk and clear validation checkpoints.

