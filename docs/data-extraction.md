---

## ✅ STEP-BY-STEP EXECUTION PLAN FOR CONFIG DATA EXTRACTION

---

### 🔹 STEP 1: Full File Ingestion and Normalization

1. **Read the entire config file into memory** — no chunked processing.
2. **Normalize the file contents**:

   * Remove all lines that are:

     * Blank
     * Whitespace-only
     * Exactly a `!`
   * Preserve all remaining lines with indentation intact.

---

### 🔹 STEP 2: Serialization of Config Data

3. Scan through normalized lines **line-by-line**.
4. Start a **new serialized block** when a line begins with a **non-space character**.
5. All lines that follow (starting with spaces) are part of the same block.
6. Serialize the block by:

   * Replacing **each internal newline** with the `${divisor}` string.
   * **Preserving indentation** after `${divisor}`.
7. Result: A flat list of strings where each entry represents a full object as one serialized line.

---

### 🔹 STEP 3: Pattern Matching (Target Extraction)

8. Search the serialized lines for the **target pattern** (e.g., an IP address).
9. Extract only those serialized lines that contain the pattern.
10. Immediately **discard the full serialized dataset** from memory.
11. This step is **not block-aware**; it is simple string filtering.

---

### 🔹 STEP 4: Match Count Validation

12. Read the `./targets/<ip>.json` file.
13. For each config:

* Get expected `"count"` of matching objects.

14. **Count the extracted matches**.
15. If actual count ≠ expected count:

* Re-run the search if buffer is still available.
* Or **log a fatal mismatch** if reprocessing is not possible.

16. If counts match: proceed.

---

### 🔹 STEP 5: Early Housekeeping (In-Memory Cleanup)

17. As soon as match validation passes:

* `unset` or nullify:

  * Original config string
  * Normalized line array
  * Serialized block list
* Clear all temporary per-file buffers.

18. Leave `${TMP_DIR}` intact (auto-cleaned via `trap` on process exit).
19. If `--debug` or `--verbose` is enabled, log:

```
[CLEANUP] Released memory buffers after successful validation for <file>
```

---

### 🔹 STEP 6: Deserialization of Matching Objects

20. For each matched serialized line:

* Replace all `${divisor}` with actual `\n`.
* Append exactly **one trailing newline**.

21. This restores each block to its original multi-line formatting for downstream processing.

---

### 🔹 STEP 7: Pass to Reporting Logic (DO NOT MODIFY)

22. Feed restored blocks to:

* `process_block()`
* `generate_objects()`
* `generate_configlist()` or equivalent

23. These functions will handle:

* Object parsing
* Description, name, type detection
* Business unit classification
* JSON and `.list` file creation

⚠️ This logic is proven and **must not be altered**.

---

### 🔹 STEP 8: Final Cleanup and Process Lifecycle Control

24. Once all output is written:

* Allow `trap` to delete `${TMP_DIR}`
* Ensure no job leaves open files or zombie processes

25. Wait on job PIDs, not timers.
26. Confirm:

* Clean process exit
* No memory or inode leaks
* Logs are available if debugging is enabled

---

This is the **official and binding flow**.
