
#!/bin/bash

# --- Configuration ---
# Set the name of the directory where all results will be stored
OUTPUT_DIR="Recon_$(date +%F_%H-%M-%S)"

# Wordlist for directory brute-forcing (must exist on your system)
# CHANGE THIS PATH to a valid wordlist, e.g., /usr/share/wordlists/dirb/common.txt
WORDLIST="/usr/share/wordlists/dirbuster/directory-list-2.3-small.txt"

# List of User-Agents to rotate through for better stealth
UAGENTS=(
"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36"
"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15"
"Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0"
)

# --- Utility Functions ---

# Picks a random User-Agent string
pick_ua() {
    echo "${UAGENTS[$RANDOM % ${#UAGENTS[@]}]}"
}

# Function to check if a necessary tool is installed
check_tool() {
    command -v "$1" >/dev/null 2>&1 || { echo -e "\n[ERROR] Required tool '$1' is missing. Please install it to continue." ; exit 1; }
}

# --- Tool Checks (Required for your script) ---
# الأدوات الأساسية
check_tool "nmap"
check_tool "subfinder"
check_tool "assetfinder"
check_tool "amass"
check_tool "httprobe"
check_tool "ffuf"
# الأدوات الجديدة والمتقدمة
check_tool "waybackurls" # لجمع عناوين URL التاريخية
check_tool "whatweb"     # لبصمات التكنولوجيا

# --- Main Scan Function ---
scan_domain() {
    local domain=$1
    TARGET="$OUTPUT_DIR/$domain"
    mkdir -p "$TARGET"
    REPORT_SUMMARY="$TARGET/report_summary.txt"

    echo -e "\n=======================================================" >> "$REPORT_SUMMARY"
    echo -e "🚀 Starting Advanced Recon for: $domain" >> "$REPORT_SUMMARY"
    echo -e "=======================================================\n" >> "$REPORT_SUMMARY"
    echo -e "\n[INFO] Starting Advanced Reconnaissance for $domain (PID: $$)..."

    # --- 1. Subdomain Enumeration (Multi-tool approach) ---
    echo -e "\n[INFO] Running Subdomain Enumeration (Subfinder, Assetfinder, Amass)..."
    sleep $((RANDOM % 4 + 1))
    subfinder -silent -all -d "$domain" -t 10 > "$TARGET/subs_raw.txt"
    sleep $((RANDOM % 3 + 1))
    assetfinder --subs-only "$domain" >> "$TARGET/subs_raw.txt"
    sleep $((RANDOM % 3 + 1))
    amass enum -passive -d "$domain" -o "$TARGET/amass_temp.txt" >> "$TARGET/subs_raw.txt"
    
    # Sort and unique the final list
    sort -u "$TARGET/subs_raw.txt" -o "$TARGET/01_subdomains.txt"
    rm -f "$TARGET/amass_temp.txt" "$TARGET/subs_raw.txt" # Clean up temp files

    # --- 2. Check for Live Subdomains (httprobe) ---
    echo -e "\n[INFO] Checking for live HTTP/HTTPS services (httprobe)..."
    cat "$TARGET/01_subdomains.txt" | httprobe -c 30 -t 5000 > "$TARGET/02_alive_subdomains.txt"

    echo "--- Live Subdomains Found ---" >> "$REPORT_SUMMARY"
    cat "$TARGET/02_alive_subdomains.txt" >> "$REPORT_SUMMARY"
    echo -e "\nLive subdomains saved to: $TARGET/02_alive_subdomains.txt"

    # --- 3. Port Scanning (Stealthy Full Scan) ---
    echo -e "\n[INFO] Running Nmap (Stealthy Full Port Scan)..."
    # -T2 is slower but stealthier
    nmap -sS -Pn -T2 -p- "$domain" --scan-delay 100ms --max-rate 50 -oN "$TARGET/03_ports.txt"
    
    echo -e "\n--- Open Ports ---" >> "$REPORT_SUMMARY"
    # Extract "open" ports and append to the summary
    grep "open" "$TARGET/03_ports.txt" | grep -v "filtered" >> "$REPORT_SUMMARY"
    echo -e "\nNmap results saved to: $TARGET/03_ports.txt"

    # --- 4. Directory Brute-forcing (ffuf) on Live Subdomains ---
    echo -e "\n[INFO] Running FFUF for common file paths on live subdomains..."
    
    if [ ! -f "$WORDLIST" ]; then
        echo -e "\n[WARNING] Wordlist not found at: $WORDLIST. Skipping FFUF."
        echo "--- Directory Scan Skipped (Wordlist Missing) ---" >> "$REPORT_SUMMARY"
    else
        echo -e "\n--- File Paths / Directories Found (Status 200, 3xx) ---" >> "$REPORT_SUMMARY"
        
        cat "$TARGET/02_alive_subdomains.txt" | while read url; do
            ua=$(pick_ua)
            host=$(echo "$url" | sed 's~http[s]*://~~g')
            out="$TARGET/ffuf_$(echo "$host" | tr '/' '_').csv"
            
            # ffuf command with stealth and User-Agent rotation
            ffuf -w "$WORDLIST" -u "$url/FUZZ" -H "User-Agent: $ua" -mc 200,204,301,302,307 -rate 40 -timeout 5 -of csv -o "$out" >/dev/null 2>&1
            
            # Extract readable output for the summary
            if [ -f "$out" ]; then
                echo "Domain: $host" >> "$REPORT_SUMMARY"
                awk -F',' '{print $4 " (" $3 ") - Size: " $5 " bytes"}' "$out" | grep -v 'url (status' >> "$REPORT_SUMMARY"
            fi
            sleep $((RANDOM % 2 + 1)) # Random delay between targets
        done
    fi

    # --- 5. Wayback Machine URLs (Initial Fetch) ---
    echo -e "\n[INFO] Collecting URLs from Wayback Machine (curl)..."
    ua=$(pick_ua)
    curl -A "$ua" --compressed -m 10 -s "http://web.archive.org/cdx/search/coll?url=*.$domain/*&output=txt&fl=original" > "$TARGET/wayback_temp.txt"

    # --- 6. Advanced URL Discovery and Parameter Extraction (waybackurls) ---
    echo -e "\n[INFO] Running Advanced URL Discovery (waybackurls)..."
    cat "$TARGET/wayback_temp.txt" | waybackurls >> "$TARGET/04_urls_raw.txt"
    cat "$TARGET/wayback_temp.txt" >> "$TARGET/04_urls_raw.txt" # Include curl results
    rm -f "$TARGET/wayback_temp.txt"

    # Sort unique and extract final URLs
    sort -u "$TARGET/04_urls_raw.txt" -o "$TARGET/04_all_endpoints.txt"
    
    # Extract only URLs that contain parameters (potential injection points)
    grep '=' "$TARGET/04_all_endpoints.txt" | sort -u > "$TARGET/05_endpoints_with_params.txt"

    echo -e "\n--- Total Endpoints Found ---" >> "$REPORT_SUMMARY"
    wc -l "$TARGET/04_all_endpoints.txt" >> "$REPORT_SUMMARY"
    echo -e "\n--- Endpoints with Parameters ---" >> "$REPORT_SUMMARY"
    wc -l "$TARGET/05_endpoints_with_params.txt" >> "$REPORT_SUMMARY"
    
    echo -e "All endpoints saved to: $TARGET/04_all_endpoints.txt"
    echo -e "Parameter-rich endpoints saved to: $TARGET/05_endpoints_with_params.txt"

    # --- 7. Technology Fingerprinting (whatweb) ---
    echo -e "\n[INFO] Running Technology Fingerprinting (whatweb)..."
    WHATWEB_FILE="$TARGET/06_technology_fingerprint.txt"
    echo "--- Technology Fingerprinting (WhatWeb) ---" >> "$REPORT_SUMMARY"
    
    # Fingerprint the main domain
    echo "Scanning Main Domain: $domain" >> "$WHATWEB_FILE"
    whatweb "$domain" >> "$WHATWEB_FILE"
    
    # Fingerprint the live subdomains
    cat "$TARGET/02_alive_subdomains.txt" | while read url; do
        echo -e "\nScanning Subdomain: $url" >> "$WHATWEB_FILE"
        whatweb -a 1 "$url" >> "$WHATWEB_FILE"
    done
    
    echo "Technology details saved to: $WHATWEB_FILE"

    echo -e "\n[SUCCESS] Scan for $domain complete. Detailed summary in $REPORT_SUMMARY"
}

# --- Main Execution ---

# 1. Check for required arguments
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <domain1> [domain2] [domain3] ..."
    echo "Example: $0 example.com test.org"
    exit 1
fi

# 2. Create the main output directory
mkdir -p "$OUTPUT_DIR"
echo -e "Starting advanced reconnaissance scan for $# domain(s)..."
echo -e "Results will be stored in the directory: $OUTPUT_DIR"

# 3. Loop through all provided domains (Parallel Processing)
for d in "$@"; do
    scan_domain "$d" & # Run in background
    sleep 2 # Small delay between starting scans to avoid flooding the system/network
done

# 4. Wait for all background jobs to finish
wait

echo -e "\n\n======================================================="
echo "✅ All advanced scans complete!"
echo "Find detailed results and summaries in the '$OUTPUT_DIR' directory."
echo "======================================================="
