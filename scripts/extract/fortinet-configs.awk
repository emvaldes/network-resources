## -------------------------------------------------------------------------- ##
## File: scripts/extract/fortinet/configs.awk
##
## Purpose:
##   Extract Fortinet-style configuration blocks matching one or more target patterns.
##
## Description:
##   - Accepts IPs or string tokens (e.g., edit object names).
##   - Accepts a customizable delimiter (defaults to comma `,`) for multiple matches.
##   - Parses `config ... edit ... next ... end` structure.
##   - Collects only those `edit` blocks that match any of the targets.
##   - Captures header-style metadata lines (e.g., `#model`, `#hostname`) and
##     emits them in JSON format at the top of the output.
##
## Parameters (passed via `-v`):
##   targets : Required. Delimiter-separated list of IPs or phrases to match.
##   divisor : Optional. Character used to split multiple targets (default: comma).
##
## Output:
##   - A structured JSON block with metadata fields: vendor, model, version, hostname
##   - A Fortinet-compatible reduced config containing only relevant blocks
##
## -------------------------------------------------------------------------- ##

## BEGIN block — Initialize parser state and metadata variables
BEGIN {

  ## Determine the pattern delimiter
  delim = (divisor == "") ? "," : divisor;

  ## Split the target patterns into an array
  split(targets, iplist, delim);

  ## State tracking for Fortinet-style config parsing
  in_config = 0;
  in_edit = 0;
  config_header = "";
  edit_block = "";
  match_found = 0;
  collected_edits = "";
  headers = "";
  output = "";

  ## Metadata initialization
  vendor = "fortinet";
  model = "";
  version = "";
  domain = "";
  hostname = "";

}

## Header comment lines (start with '#') — capture and parse for metadata
/^#/ {

  headers = headers $0 "\n";

  ## Extract model
  if ($0 ~ /^#model="?[^"]+"/) {
    model = $0;
    sub(/^#model="?/, "", model);
    sub(/"?$/, "", model);
  }

  ## Extract hostname
  else if ($0 ~ /^#hostname="?[^"]+"/) {
    hostname = $0;
    sub(/^#hostname="?/, "", hostname);
    sub(/"?$/, "", hostname);
  }

  ## Extract version from config-version line
  else if ($0 ~ /^#config-version=/) {
    version = $0;
    sub(/^#config-version=/, "", version);
    split(version, vparts, "-");
    version = vparts[2];  # Grab major.minor.patch (e.g., 7.4.5)
  }

  next;

}

## Begin of a config section
/^[[:space:]]*config[[:space:]]/ {

  ## Finalize any previous config block
  if (in_config && length(collected_edits) > 0) {
    output = output config_header "\n" collected_edits "end\n\n";
  }

  ## Start a new config block
  config_header = $0;
  in_config = 1;
  collected_edits = "";
  next;

}

## Begin of an edit block
/^[[:space:]]*edit[[:space:]]/ {

  if (in_edit && match_found) {
    collected_edits = collected_edits edit_block "next\n";
  }

  in_edit = 1;
  match_found = 0;
  edit_block = $0 "\n";
  next;

}

## End of an edit block
/^[[:space:]]*next[[:space:]]*/ {

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

## End of a config block
/^[[:space:]]*end[[:space:]]*$/ {

  if (in_edit && match_found) {
    collected_edits = collected_edits edit_block "next\n";
  }

  if (in_config && length(collected_edits) > 0) {
    output = output config_header "\n" collected_edits "end\n\n";
  }

  ## Reset section state
  in_config = 0;
  in_edit = 0;
  config_header = "";
  collected_edits = "";
  match_found = 0;
  next;

}

## Lines inside an edit block — check for pattern match
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

## Finalize output
END {

  ## Emit consistent metadata JSON (always includes all fields)
  printf("{\n");
  printf("  \"vendor\": \"%s\",\n", vendor);
  printf("  \"model\": \"%s\",\n", model);
  printf("  \"version\": \"%s\",\n", version);
  printf("  \"domain\": \"%s\"\n", domain);
  printf("  \"hostname\": \"%s\"\n", hostname);
  printf("}\n\n");

  ## Print full header and all matched config blocks
  if (length(output) > 0) {
    printf "%s\n%s", headers, output;
  }

}

## -------------------------------------------------------------------------- ##
## Examples:
##
## 1. Match IP addresses inside `edit` blocks:
##    awk -v targets="10.0.0.1,172.16.0.5" -f configs.awk input.cfg
##
## 2. Match Fortinet object names:
##    awk -v targets="edit VPN-PROFILE,edit BRANCH-TUNNEL" -f configs.awk input.cfg
##
## 3. Use a custom delimiter (e.g., pipe `|`):
##    awk -v targets="edit VPN1|edit VPN2|192.168.1.1" -v divisor="|" -f configs.awk input.cfg
##
## 4. Output to file:
##    awk -v targets="edit DMZ-ACCESS" -f configs.awk input.cfg > reduced.cfg
##
## 5. Shell-safe phrasing (quotes required when passing commas or spaces):
##    awk -v targets="edit A,edit B" -f configs.awk input.cfg
##
## Notes:
## - Captures structured metadata (vendor, model, version, hostname) as JSON before the config.
## - Retains valid `config ... edit ... next ... end` hierarchy.
## - Targets are matched only within `edit` blocks.
##
## -------------------------------------------------------------------------- ##
