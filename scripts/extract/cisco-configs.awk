## -------------------------------------------------------------------------- ##
## File: scripts/extract/cisco/configs.awk
##
## Purpose:
##   Extract Cisco-style configuration blocks that match one or more patterns.
##
## Description:
##   - Matches may include IPs, phrases, or arbitrary tokens.
##   - Accepts a custom delimiter for separating multiple targets.
##   - Defaults to comma (`,`) if no delimiter is provided.
##   - Captures blocks starting at top-level non-indented lines.
##   - Preserves ASA-specific headers like hostname, version, etc.
##
## Parameters (passed via `-v`):
##   targets : Space/phrase/IP patterns to match (e.g., "10.0.0.1,permit ip any")
##   divisor : (optional) Pattern separator. Defaults to comma.
##
## Disclaimer: This is an Artificial Intelligence generated contribution:
## -------------------------------------------------------------------------- ##

BEGIN {
  delim = (divisor == "") ? "," : divisor;
  split(targets, iplist, delim);

  block = "";
  block_has_match = 0;
  inside_block = 0;
  collected = "";
}

/^$/ { next; }
/^[[:space:]]*!$/ { next; }

# Always keep header-style or comment lines (even if outside block)
/^(ASA Version|version|hostname|domain-name|#)/ {
  if (collected != "") {
    collected = collected $0 "\n";
  } else {
    collected = $0 "\n";
  }

  # Track last seen header
  last_header = $0;
  next;
}

/^[^[:space:]]/ {
  # Inject newline after the last header (once)
  if (last_header != "" && !injected_newline) {
    collected = collected "\n";
    injected_newline = 1;
  }

  if (inside_block && block_has_match) {
    collected = collected block "\n";
  }

  block = $0 "\n";
  block_has_match = 0;
  inside_block = 1;
  next;
}

# End current block when encountering '!'
/^[[:space:]]*!$/ {
  if (inside_block) {
    if (block_has_match) {
      collected = collected block "\n";
    }
    block = "";
    block_has_match = 0;
    inside_block = 0;
  }
  next;
}

# Any indented line belonging to current block
/^[[:space:]]+/ {
  if (inside_block) {
    block = block $0 "\n";
    for (i in iplist) {
      if (iplist[i] == "") continue;
      if ($0 ~ ("(^|[^0-9])" iplist[i] "($|[^0-9])")) {
        block_has_match = 1;
        break;
      }
    }
  }
}

END {
  if (inside_block && block_has_match) {
    collected = collected block "\n";
  }
  if (collected != "") {
    printf "%s", collected;
  }
}

## -------------------------------------------------------------------------- ##
## Examples:
##
## 1. Match multiple IPs in access-list or object-group lines:
##    awk -v targets="10.0.0.1,192.168.1.10" -f configs.awk input.cfg
##
## 2. Match ACL names, service rules, or object phrases:
##    awk -v targets="access-list OUTSIDE,permit ip any" -f configs.awk input.cfg
##
## 3. Use a custom delimiter (e.g., pipe `|` for long lists):
##    awk -v targets="object-group DMZ|object-group CORE|10.0.0.1" -v divisor="|" -f configs.awk input.cfg
##
## 4. Save matched output to a separate file:
##    awk -v targets="permit tcp any any eq 443" -f configs.awk input.cfg > ssl-policy.cfg
##
## 5. Safe quoting for complex multi-token targets:
##    awk -v targets="access-list INSIDE,object-group WEB-SERVERS" -f configs.awk input.cfg
##
## Notes:
## - Matching starts at top-level non-indented config lines.
## - Blocks include subsequent lines until the next top-level entry.
##
## -------------------------------------------------------------------------- ##
