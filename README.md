SSH Scanner
-
A parallel and robust scanner to find SSH access on IP address ranges, with MAC address and vendor information.


________
Features
-
Parallel scanning tests up to 15 IPs simultaneously for maximum speed

Fast SSH testing using "/dev/tcp" for non-invasive testing without dependencies

MAC address lookup via ARP extracts MAC addresses

Vendor identification based on IEEE OUI database auto-downloaded at first run

Results are organized by IP address

Temporary buffer to avoid parallel conflicts

**ONLY /24 NETWORK WILL BE SCANNED**


____________
Installation
-
Download .sh file and make it executable (chmod +x ssh_scanner.sh)

_____
Usage
-
Simple scan with default parallel process number, 15
bash ./ssh_scanner.sh 192.168.0.1 192.168.0.254

Scan with custom number of parallel processes, like 20
bash ./ssh_scanner.sh 192.168.1.1 192.168.1.254 20



______________
Output Example
-
=== SSH SCANNER ===

Scanning from 192.168.0.xx to 192.168.0.YY. Please wait...

__________________________________________

Scan completed.


Testing 192.168.0.xx ... SSH OK | Host: --- | MAC: --- | Vendor: ---

Testing 192.168.0.xx ... SSH OK | Host: --- | MAC: FF:11:AA:BB:CC:DD | Vendor: R*****

Testing 192.168.0.xx ... SSH OK | Host: --- | MAC: FF:11:AA:BB:CC:DD | Vendor: U*****

Testing 192.168.0.xx ... SSH OK | Host: --- | MAC: FF:11:AA:BB:CC:DD | Vendor: U*****

Testing 192.168.0.xx ... SSH OK | Host: --- | MAC: FF:11:AA:BB:CC:DD | Vendor: C*****


____________
How it works
-
For each IP in the range, launches an SSH test in the background, maintains up to N parallel processes (default 15)

Tests connectivity on port 22 using /dev/tcp, in the meantime it extracts MAC address via arp

Writes results to a temporary buffer and sorts it by IP address

Downloads IEEE OUI database (only on first run) and for each MAC found it looks up vendor in local database



____________
Requirements
-
Use bash, ping, arp, curl, nslookup

Tested on OSX Terminal


____________
Dependencies
-
OUI Database https://standards-oui.ieee.org/oui/oui.txt automatically downloaded if needed just for the first time saved in: /tmp/oui.txt

Subsequent runs reuse the file locally (zero download).

_______________
Troubleshooting
-
Slow at first run, because needs to download OUI vendor database from IEEE. Subsequent runs are instant.

No MAC address found. ARP cache might be empty or report just your local network. Pings are used here, if arp table are not populated could be empty.

Host empty. It use nslookup, if your DNS has not the right record of the IP, you're not able to reach this value.



___________
MIT License
-
TonoTek - Copyright 2025 

https://tonotek.com

Developed for network testing and device discovery in embedded/IoT environments.

Note: Use responsibly. Make sure you have permissions to scan the target network.
