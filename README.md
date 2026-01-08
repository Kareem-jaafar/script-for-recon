thes script can 
— Look for open ports 
— Look for subdomains 
— Look for file paths 
- store the scan results to file. 
- able to scan multiple domains at once.
- produce human-readable report files.
  
  --->Requirements To Run
  1- Bash 4.0+
  2- curl 
  3- nmap 
  4- git 
  5- jq 
  6- awk 
  7- sed
  8- subfinder
  9- assetfinder
  10- amass
  11- httpx
  12- fuff
  13- waybackurls
  14- whatweb
  15- go language
  
  How Run 
 1- chmod +x recon.sh
 2- bash recon-tool.sh example.com
------------|
            |
            |-------------------------------|
                                            | 
                    In the output, a folder will be created in this format
Recon_2026-01-08_14-32-10/
└── example.com/
    ├── report_summary.txt
    ├── 01_subdomains.txt
    ├── 02_alive_subdomains.txt
    ├── 03_ports.txt
    ├── 04_all_endpoints.txt
    ├── 05_endpoints_with_params.txt
    ├── 06_technology_fingerprint.txt
    ├── ffuf_blog.example.com.csv
    ├── ffuf_api.example.com.csv
    └── ...
