## -------------------------------------------------------------------------- ##
## File: scripts/extract/fortinet/configs.awk
##
## Purpose:
##   Extract Fortinet-style configuration blocks that match one or more patterns.
##
## Description:
##   - Matches may include IPs, phrases, or arbitrary tokens.
##   - Accepts a custom delimiter for separating multiple targets.
##   - Defaults to comma (`,`) if no delimiter is provided.
##   - Captures `edit ... next` blocks within `config ... end` sections.
##   - Reconstructs valid Fortinet config fragments preserving hierarchy.
##
## Parameters (passed via `-v`):
##   targets : Space/phrase/IP patterns to match (e.g., "10.0.0.1,edit VPN-1")
##   divisor : (optional) Pattern separator. Defaults to comma.
##
## Disclaimer: This is an Artificial Intelligence generated contribution:
## -------------------------------------------------------------------------- ##

BEGIN {
  delim = (divisor == "") ? "," : divisor;
  split(targets, iplist, delim);

  in_config = 0;
  in_edit = 0;
  config_header = "";
  edit_block = "";
  match_found = 0;
  collected_edits = "";
  headers = "";
  output = "";
}

/^#/ {
  headers = headers $0 "\n";
  next;
}

/^config / {
  if (in_config && length(collected_edits) > 0) {
    output = output config_header "\n" collected_edits "end\n\n";
  }
  config_header = $0;
  in_config = 1;
  collected_edits = "";
  next;
}

/^ edit / {
  if (in_edit && match_found) {
    collected_edits = collected_edits edit_block "next\n";
  }
  in_edit = 1;
  match_found = 0;
  edit_block = $0 "\n";
  next;
}

/^ next/ {
  if (in_edit) {
    edit_block = edit_block $0 "\n";
    if (match_found) {
      collected_edits = collected_edits edit_block;
    }
  }
  in_edit = 0;
  edit_block = "";
  match_found = 0;
  next;
}

/^end$/ {
  if (in_edit && match_found) {
    collected_edits = collected_edits edit_block "next\n";
  }
  if (in_config && length(collected_edits) > 0) {
    output = output config_header "\n" collected_edits "end\n\n";
  }
  in_config = 0;
  in_edit = 0;
  config_header = "";
  collected_edits = "";
  match_found = 0;
  next;
}

{
  if (in_edit) {
    edit_block = edit_block $0 "\n";
    for (i in iplist) {
      if (iplist[i] == "") continue;
      if ($0 ~ ("(^|[^0-9])" iplist[i] "($|[^0-9])")) {
        match_found = 1;
        break;
      }
    }
  }
}

END {
  if (length(output) > 0) {
    printf "%s\n%s", headers, output;
  }
}

## -------------------------------------------------------------------------- ##
## Examples:
##
## 1. Match multiple IPs within `edit` blocks:
##    awk -v targets="10.0.0.1,172.16.0.5" -f configs.awk input.cfg
##
## 2. Match `edit` object names (e.g., address or VPN entries):
##    awk -v targets="edit VPN-PROFILE,edit BRANCH-TUNNEL" -f configs.awk input.cfg
##
## 3. Use a custom delimiter (pipe `|` for clarity):
##    awk -v targets="edit VPN1|edit VPN2|192.168.1.1" -v divisor="|" -f configs.awk input.cfg
##
## 4. Redirect matching config fragments to a new file:
##    awk -v targets="edit DMZ-ACCESS" -f configs.awk input.cfg > reduced.cfg
##
## 5. Handle shell-safe phrasing with quotes:
##    awk -v targets="edit A,edit B" -f configs.awk input.cfg
##
## Notes:
## - Patterns are searched inside each `edit` block.
## - Full `config ... edit ... next ... end` structures are preserved.
##
## -------------------------------------------------------------------------- ##
