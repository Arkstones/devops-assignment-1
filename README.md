# DevOps Assignment 1 - Linux, Bash & Networking

**Author:** Robert Olwoch

A small Linux diagnostic toolkit written in Bash. It has three scripts:

| Script | What it does |
|---|---|
| `system-info.sh` | Shows hostname, user, date/time, OS, kernel, uptime, CPU, memory and working directory |
| `disk-check.sh` | Checks disk usage for a path against a threshold |
| `network-check.sh` | Resolves a host, checks connectivity, lists network interfaces and optionally tests a TCP port |

All of them write timestamped log entries to `logs/toolkit.log`.

## Project structure

```
assignment-1/
├── README.md
├── system-info.sh
├── disk-check.sh
├── network-check.sh
├── grade.sh            # grader supplied with the assignment
├── lib/
│   └── logging.sh      # shared log() function used by the three scripts
└── logs/
    └── .gitkeep        # keeps the empty folder in Git, log files are ignored
```

## Setup

Needs a Linux machine with Bash 4+ and the usual core tools (`df`, `awk`, `getent`, `uname`, `free`, `timeout`).
`ping` and `ip` are used if they are installed, otherwise the scripts fall back to other methods (see Assumptions).

```bash
git clone https://github.com/Arkstones/devops-assignment-1.git
cd devops-assignment-1
chmod +x *.sh
```

## Usage

### system-info.sh

```bash
./system-info.sh
```

Example output:

```
==============================
      System Information
==============================
Hostname:            pop-os
Current user:        robertolwoch
Date/time:           2026-10-27 14:05:11 EAT
Operating system:    Pop!_OS 24.04 LTS
Kernel version:      6.x.x
...
```

### disk-check.sh

```bash
./disk-check.sh <threshold> [path]
```

- `threshold` is a whole number from 1 to 100 (percent)
- `path` is optional, default is `/`

```bash
./disk-check.sh 80          # check / against 80%
./disk-check.sh 90 /home    # check the filesystem that /home is on
```

| Exit code | Meaning |
|---|---|
| 0 | Usage is below the threshold |
| 1 | Usage is at or above the threshold (or the disk could not be read) |
| 2 | Invalid input (missing/non-numeric/out of range threshold, path not found, too many arguments) |

### network-check.sh

```bash
./network-check.sh <hostname-or-ip> [port]
```

```bash
./network-check.sh google.com
./network-check.sh 8.8.8.8 53
./network-check.sh localhost 22
```

Steps it runs:

1. Validates the host (letters, numbers, `.`, `-`, `:` only) and the port (1-65535)
2. Resolves the host with `getent ahosts` and prints the addresses
3. Connectivity check with `ping`
4. Shows network interfaces with `ip -brief address`
5. If a port was given, tries a TCP connection to it (3 second timeout)

| Exit code | Meaning |
|---|---|
| 0 | All checks passed |
| 1 | A network check failed (could not resolve, no reply, port closed) |
| 2 | Invalid input (missing host, bad characters, bad port) |

## Logging

Every run adds lines to `logs/toolkit.log`, in this format:

```
2026-10-27 14:05:11 [INFO] [disk-check.sh] Disk usage for / is 41% (threshold 80%) - OK
2026-10-27 14:05:20 [ERROR] [network-check.sh] Invalid input: port must be between 1 and 65535, got 70000
```

The log is always written next to the scripts, so it works no matter which folder you run them from.
Log files are listed in `.gitignore` so they are not committed.

## Testing

Run the grader that came with the assignment:

```bash
chmod +x grade.sh *.sh
./grade.sh
```

I also tested these by hand:

```bash
./disk-check.sh            # exit 2, missing threshold
./disk-check.sh 0          # exit 2
./disk-check.sh 101        # exit 2
./disk-check.sh abc        # exit 2
./disk-check.sh 50 /nope   # exit 2, path does not exist
./disk-check.sh 1          # exit 1, usage is above 1%

./network-check.sh                        # exit 2
./network-check.sh "a;b"                  # exit 2, bad characters
./network-check.sh localhost 0            # exit 2
./network-check.sh localhost 65536        # exit 2
./network-check.sh localhost abc          # exit 2
./network-check.sh nonexistent.invalid    # exit 1, cannot resolve
./network-check.sh github.com 443         # exit 0
```

## Git workflow

- Work was committed in small steps on `main`.
- `network-check.sh` was built on the `feature/network-check` branch and merged into `main` with `--no-ff` so the merge shows in the history.

```bash
git log --oneline --graph --all
```

## Assumptions

- Linux only (uses `/proc`, `/sys/class/net` and GNU coreutils).
- If `ping` is not installed (for example in a minimal container), connectivity is checked by opening a TCP connection instead: on the given port if there is one, otherwise on port 80 or 443.
- If `ip` is not installed, `ifconfig` is used, and if that is missing too, interface names, state and MAC addresses are read from `/sys/class/net`.
- Some networks block ping. In that case `network-check.sh` reports the ping as failed and exits 1, even though the host may be up.
- `disk-check.sh` treats usage equal to the threshold as a failure ("reaches or exceeds").
