# udwall

# UFW Firewall Management Script (`f.py`)

## 1. What It Does

`f.py` is a powerful command-line tool designed to simplify and automate the management of the Uncomplicated Firewall (UFW) on Debian-based systems.

Its primary purpose is to solve a critical security flaw where **Docker containers bypass UFW rules**, potentially exposing container ports to the public internet unexpectedly. This script correctly configures `iptables` to ensure that all Docker traffic is properly filtered by UFW.

### Key Features:

- **Docker & UFW Integration**: Automatically applies the necessary `iptables` rules to make Docker respect UFW policies.
- **Configuration as Code**: Manages firewall rules through a simple and readable `firewall.conf` file.
- **Atomic Rule Application**: Safely removes old rules before applying new ones to prevent rule accumulation and ensure a clean state.
- **Reverse Engineering**: Can generate a `firewall.conf` file from the current live firewall rules.
- **Idempotent Operations**: All actions are designed to be safely re-run without causing errors or unintended side effects.
- **Backup & Safety**: Includes functionality to back up your entire firewall configuration before making changes.



## 2. How to Use

The script must be run with `sudo` privileges as it directly manipulates system firewall settings.

If you run the script without `sudo`, it will exit with a clear error message guiding you on how to run it correctly.

### Basic Syntax

```bash
sudo python3 f.py <command>
````

### Example Workflow

1.  **Enable UFW and apply the Docker fix:**

    ```bash
    sudo python3 f.py --enable
    ```

2.  **Define your rules** in a `firewall.conf` file (see format below).

3.  **Atomically apply your rules:**
    This command removes old, non-essential rules and applies the ones from your `firewall.conf`.

    ```bash
    sudo python3 f.py --apply
    ```


## 3\. Command Options Explained

All commands are mutually exclusive (you can only run one at a time).

| Command       | Description                                                                                                                                                           |
|---------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `--enable`    | **Applies the Docker fix and enables UFW.** It adds the necessary rules to `/etc/ufw/after.rules` to make Docker respect UFW and ensures UFW is active.                 |
| `--disable`   | **Safely disables the Docker fix and UFW.** It removes the `iptables` rules and cleans the configuration files before stopping the UFW service.                          |
| `--apply`     | **Atomically applies the configuration from `firewall.conf`.** It first removes all existing user-added rules (except for protected ones like SSH) and then applies the new rules from the `firewall.conf` file. This is the recommended way to update rules. |
| `--create`    | **Generates a `firewall.conf` file from live rules.** It inspects the active UFW rules on the system and writes them into a `firewall.conf` file in the correct format. |
| `--backup`    | **Creates a full, timestamped backup** of your UFW and `iptables` configurations in `/home/ubuntu/backup/firewall-backup/`.                                            |
| `--status`    | **Shows the current UFW status,** including both the standard and numbered rule views.                                                                                |
| `--dry-run`   | **Shows what rules would be applied without making changes.** It reads `firewall.conf` and prints the `ufw` commands that would be executed by `--apply`, but does not run them. |
| `-h`, `--help`| **Displays the help message** with a summary of all available commands.                                                                                               |

-----

## 4\. The `firewall.conf` File

This file defines the list of firewall rules you want to manage. The script expects it to be in the same directory and to contain a Python list named `rules`.

### Rule Dictionary Format

Each rule is a Python dictionary with the following keys:

  - `from` (string): The source IP address or CIDR. Use `'any'` for all sources.
  - `connectionType` (string): The protocol, either `'tcp'` or `'udp'`.
  - `to` (string or int): The destination port. Can be a single port number (e.g., `80`), a port range (e.g., `'60000:61000'`), or a service name (e.g., `'OpenSSH'`).
  - `isDockerServed` (boolean): Set to `True` to create a `ROUTE` rule for traffic forwarded to a Docker container. Set to `False` for regular host rules.
  - `isEnabled` (boolean): Set to `True` to create an `allow` rule.

### Example `firewall.conf`

```python
rules = [
    # Allow SSH access from any source
    {'from': 'any', 'connectionType': 'tcp', 'to': 'OpenSSH', 'isDockerServed': False, 'isEnabled': True},

    # Allow HTTP and HTTPS traffic to the host
    {'from': 'any', 'connectionType': 'tcp', 'to': 80, 'isDockerServed': False, 'isEnabled': True},
    {'from': 'any', 'connectionType': 'tcp', 'to': 443, 'isDockerServed': False, 'isEnabled': True},

    # Allow traffic to a Docker container on port 8080 from a specific IP
    {'from': '192.168.1.100', 'connectionType': 'tcp', 'to': 8080, 'isDockerServed': True, 'isEnabled': True},

    # Allow a UDP port range for an application like Mosh
    {'from': 'any', 'connectionType': 'udp', 'to': '60000:61000', 'isDockerServed': False, 'isEnabled': True},
]
```



## 5\. Detailed Explanation of Command Options

### 1\. `--backup`

**Goal:** Creates a timestamped snapshot of the current firewall state.

  * **Directory Structure:** Creates a directory at `/home/ubuntu/backup/firewall-backup/YYYY-MM-DD_HH-MM-SS`.
  * **UFW Configs:** Copies the entire `/etc/ufw` directory and the `/etc/default/ufw` configuration file.
  * **IPv4 Rules:** Runs `iptables-save` and dumps the output to `iptables.rules`.
  * **IPv6 Rules:** Runs `ip6tables-save` and dumps the output to `ip6tables.rules`.
  * **Permissions:** Checks for root/sudo permissions before attempting file writes.

### 2\. `--enable`

**Goal:** Configures the environment to support Docker correctly and turns the firewall on.

  * **Docker Security Fix (The "After" Rules):**
      * Checks `/etc/ufw/after.rules` for the presence of the custom `# BEGIN UFW AND DOCKER` block.
      * If missing, it appends the required iptables logic (defined in the `DOCKER_UFW_BLOCK` constant) to the end of the file.
      * This block handles packet filtering for the `DOCKER-USER` chain, preventing containers from bypassing the firewall.
  * **Safety Net:** Idempotently executes `ufw allow ssh` to ensure you do not lock yourself out of the server.
  * **Activation:**
      * Checks `ufw status`.
      * If inactive, runs `ufw enable` (handling the confirmation prompt automatically).
      * Reloads UFW via `ufw reload` if changes were made to the rules files.

### 3\. `--apply`

**Goal:** Atomically resets the firewall to a clean state and then applies the configuration from `firewall.conf`.

  * **Protected Rules Mechanism:**
      * The script defines a **Hardcoded Allow List** of services that are *never* deleted to prevent locking the admin out during the reset.
      * **Protected List:** `22/tcp`, `OpenSSH`, `80/tcp`, `443/tcp`, and `60000:61000/udp`.
  * **Smart Detection (Regex Update):**
      * The script fetches current rules using `sudo ufw status numbered`.
      * **Improved Regex:** It now uses the pattern `(?:ALLOW IN|DENY IN|REJECT IN|ALLOW FWD)`.
      * **Significance:** This allows the script to detect and delete not just standard input rules, but also **Docker Forwarding (`ALLOW FWD`) rules**, ensuring a truly clean slate before reapplying the config.
  * **Reverse Deletion:**
      * Identifies all rules *not* in the protected list.
      * Deletes them in **descending numerical order** (e.g., 10, then 9, then 5). This is critical because deleting rule \#1 shifts the index of all subsequent rules; deleting from the bottom up avoids index mismatch errors.
  * **Handover:** Once the cleanup is complete, it calls the `add_rules()` helper logic to install the new configuration.

#### Logic: `add_rules()`

**Goal:** The core engine that reads the configuration file and applies it to the system.

  * **Sequence of Operations:**
    1.  **Load Config:** Reads `firewall.conf` and parses the Python `rules` list.
    2.  **Docker Safety Check:** Calls `ensure_docker_config()`.
          * If the Docker `iptables` block is missing from `after.rules`, it adds it.
          * **Critical Stop:** If this step fails, the script exits immediately to prevent exposing Docker containers.
    3.  **Rule Iteration:** Loops through every rule defined in `firewall.conf`.
          * Generates the specific `ufw` command (handling ports, ranges, and Docker routes).
          * Executes the command immediately.
          * **Error Handling:** If *any* single rule fails to apply, the script stops execution to allow the user to debug the invalid rule.
    4.  **Final Enable:** Calls `enable_ufw()` to ensure the firewall service is active and that SSH is specifically allowed (as a final safety net).
    5.  **Status Report:** Prints the final `ufw status` to the console.

### 4\. `--create`

**Goal:** Reverse-engineers the current firewall state into a configuration file.

  * **Extraction:** Runs `sudo ufw show added` to get a clean list of user-added rules.
  * **Parsing:** Uses Regex to identify:
      * Single ports (`80/tcp`)
      * Port ranges (`60000:61000/udp`)
      * Service names (`OpenSSH`)
      * Source IPs (`from 192.168.x.x`)
      * Docker routes (`route allow`)
  * **File Generation:** Overwrites `firewall.conf` in the current directory with a valid Python list representing the active state.

### 5\. `--dry-run`

**Goal:** Simulates the application of rules from `firewall.conf` without execution.

  * **Loading:** Parses the local `firewall.conf` file.
  * **Translation:** Converts each Python dictionary in the `rules` list into its corresponding shell command.
      * *Example:* `{'to': 80, 'connectionType': 'tcp' ...}` becomes `sudo ufw allow 80/tcp`.
      * *Docker Route:* `{'isDockerServed': True ...}` becomes `sudo ufw route allow ...`.
  * **Output:** Prints the exact command string to the console for verification.

### 6\. `--disable`

**Goal:** Shows the current firewall status.

  * **Action:** Runs `sudo ufw status` and `sudo ufw status numbered`.
  * **Use Case:** A quick and easy way to see if the firewall is active and what rules are currently loaded, including their numerical order.

### 7\. `--disable`

**Goal:** A complete, clean uninstall of the Docker integration.

  * **IPv4 and IPv6 Processing:** Runs identical cleanup procedures for both `after.rules` and `after6.rules`.
  * **Live Chain Removal:**
      * Reads the config file to find the Docker block.
      * Parses specific iptables rules (lines starting with `-A`).
      * Executes `iptables -D` to delete these rules from the live system.
      * Executes `iptables -F` (flush) and `iptables -X` (delete) on custom chains (e.g., `ufw-docker-logging-deny`).
      * *Idempotency:* Ignores "No such rule/chain" errors if the system is already clean.
  * **File Cleanup:** Rewrites the `after.rules` files, physically removing the text block between `# BEGIN UFW AND DOCKER` and `# END UFW AND DOCKER`.
  * **Deactivation:** Runs `sudo ufw disable` to turn off the firewall.



## 6\. Technical Notes

  * **Constants:** The script relies on `/etc/ufw/after.rules`. Ensure your UFW installation uses standard paths.
  * **Logging:** The Docker rules inserted by this script include a logging directive. Blocked packets targeting Docker containers will be logged with the prefix `[UFW DOCKER BLOCK]`.
  * **Idempotency:** Almost every function (run command, file appending, rule deletion) checks the current state before acting. It is safe to run `--enable` multiple times without duplicating rules or causing errors.
