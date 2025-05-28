## -------------------------------------------------------------------------- ##
## File: scripts/extract/cisco/configs.awk
##
## Purpose:
##   Extract Cisco-style configuration blocks that match one or more target patterns.
##
## Description:
##   - Accepts IPs, keywords, phrases, or arbitrary token-based matches.
##   - Supports a customizable delimiter (default: comma `,`) for splitting targets.
##   - Identifies blocks that begin at top-level (non-indented) lines.
##   - Collects and preserves matched blocks along with global headers.
##   - Extracts optional metadata: version, model, domain, hostname.
##
## Parameters (passed via `-v`):
##   targets : Required. Comma- or delimiter-separated patterns to match.
##   divisor : Optional. Custom delimiter (defaults to comma).
##
## Output:
##   - A structured JSON metadata block followed by the reduced config.
##
## Disclaimer: This is an Artificial Intelligence generated contribution:
##
## -------------------------------------------------------------------------- ##

## Initialize state, parse input targets, and setup metadata variables
BEGIN {

  ## Determine IP list delimiter (defaults to comma)
  delim = (divisor == "") ? "," : divisor;

  ## Split list of IP addresses into array
  split(targets, iplist, delim);

  ## Initialize block tracking state
  block = "";
  block_has_match = 0;
  inside_block = 0;
  collected = "";

  ## Metadata defaults
  vendor = "cisco";
  model = "";
  version = "";
  domain = "";
  hostname = "";

  ## Used to insert a newline after header section exactly once
  injected_newline = 0;

}

## Skip completely empty lines
/^$/ { next; }

## Skip comment-only lines that contain just '!'
/^[[:space:]]*!$/ { next; }

## Capture global headers and detect metadata (runs outside object blocks)
/^(ASA Version|version|hostname|domain-name|#)/ {

  ## Append header lines to collected output (even if not related to IPs)
  if (collected != "") {
    collected = collected $0 "\n";
  } else {
    collected = $0 "\n";
  }

  ## Remember last header seen (used for formatting logic)
  last_header = $0;

  ## Extract metadata fields
  if ($0 ~ /^ASA Version[[:space:]]+/) {
    model = "ASA";          # Set model based on ASA version line
    version = $3;           # Capture version string
  }
  else if ($0 ~ /^version[[:space:]]+/ && version == "") {
    version = $2;           # Fallback version if ASA-specific is not present
  }
  else if ($0 ~ /^domain-name[[:space:]]+/) {
    domain = $2;            # Extract domain name
  }
  else if ($0 ~ /^hostname[[:space:]]+/) {
    hostname = $2;          # Extract hostname
  }

  next;

}

## Match the start of a new top-level block (non-indented keyword)
/^[^[:space:]]/ {

  ## Insert newline between headers and first block (once only)
  if (last_header != "" && !injected_newline) {
    collected = collected "\n";
    injected_newline = 1;
  }

  ## If we were in a block that matched an IP, store it
  if (inside_block && block_has_match) {
    collected = collected block "\n";
  }

  ## Start a new block
  block = $0 "\n";
  block_has_match = 0;
  inside_block = 1;
  next;

}

## Handle end of block when '!' line is encountered
/^[[:space:]]*!$/ {

  if (inside_block) {
    if (block_has_match) {
      collected = collected block "\n";
    }
    ## Reset block tracking
    block = "";
    block_has_match = 0;
    inside_block = 0;
  }
  next;

}

## Handle indented lines inside a block — these are the contents
/^[[:space:]]+/ {

  if (inside_block) {
    block = block $0 "\n";
    ## Check if this line contains any of the target IPs
    for (i in iplist) {
      if (iplist[i] == "") continue;
      if ($0 ~ ("(^|[^0-9])" iplist[i] "($|[^0-9])")) {
        block_has_match = 1;
        break;
      }
    }
  }

}

## Final output and cleanup
END {

  ## Catch any final block still in memory
  if (inside_block && block_has_match) {
    collected = collected block "\n";
  }

  ## Emit structured metadata in consistent JSON form (even if values are empty)
  printf("{\n");
  printf("  \"vendor\": \"%s\",\n", vendor);
  printf("  \"model\": \"%s\",\n", model);
  printf("  \"version\": \"%s\",\n", version);
  printf("  \"domain\": \"%s\",\n", domain);
  printf("  \"hostname\": \"%s\"\n", hostname);
  printf("}\n\n");

  ## Emit all collected matching blocks + headers
  if (collected != "") {
    printf "%s", collected;
  }

}

## -------------------------------------------------------------------------- ##
## Examples:
##
## 1. Match multiple IPs in ACL/object blocks:
##    awk -v targets="10.0.0.1,192.168.1.10" -f configs.awk input.cfg
##
## 2. Match ACL names, service rules, or object phrases:
##    awk -v targets="access-list OUTSIDE,permit ip any" -f configs.awk input.cfg
##
## 3. Use a custom delimiter (e.g., pipe `|`) for bulk targets:
##    awk -v targets="object-group DMZ|object-group CORE|10.0.0.1" -v divisor="|" -f configs.awk input.cfg
##
## 4. Save matched output to file:
##    awk -v targets="permit tcp any any eq 443" -f configs.awk input.cfg > ssl-policy.cfg
##
## 5. Shell-safe phrasing for multi-token expressions:
##    awk -v targets="access-list INSIDE,object-group WEB-SERVERS" -f configs.awk input.cfg
##
## Notes:
## - Only top-level blocks (`^[^[:space:]]`) are considered block starts.
## - Each matched block includes all its subsequent indented lines.
## - Output includes JSON metadata (vendor, model, version, domain, hostname).
##
## -------------------------------------------------------------------------- ##
