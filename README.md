# faketime-ad
Faketime Wrapper for Active Directory - No more Clock Skew errors
Retrieves the time from the target network's Domain Controller through nmap smbtime script
Subtracts your current timezone
Uses libfaketime to run the supplied command with the correct time of the DC.

# Installation
Install faketime (APT based systems - apt install faketime)
Simply clone the repo and execute faketime-ad.sh
You can also add the function run_faketime to your RC file (.zshrc is the default for Kali) and then use run_faketime tho it might not work well with proxychains

# USAGE
## Without proxychains (direct access to the DC)
```bash
faketime-ad.sh {DC_IP} {CMD}
```
I.E
```bash
faketime-ad.sh 10.0.0.1 date
```

## With proxychains (requires root for nmap to work with proxychains)
```bash
sudo proxychains4 faketime-ad.sh {DC_IP} {CMD}
```
I.E
```bash
sudo proxychains4 faketime-ad.sh 10.0.0.1 date
```
