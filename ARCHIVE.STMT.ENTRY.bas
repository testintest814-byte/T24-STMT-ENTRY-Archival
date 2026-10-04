*---------------------------------------------------------------
* ARCHIVE.STMT.ENTRY
* Purpose: Archive STMT.ENTRY records to STMT.ENTRY$ARC table
* Logic:
*   1. Select candidate STMT.ENTRY ids older than cutoff date
*   2. Split into batch ranges
*   3. Trigger worker jobs per batch to copy and archive
*---------------------------------------------------------------

SUBROUTINE ARCHIVE.STMT.ENTRY(CUTOFF.DATE, BATCH.SIZE, WORKER.COUNT)

    COMMON /STMT.ARCHIVE/ CANDIDATES(50000), TOTAL.CANDIDATES
    COMMON /STMT.ARCHIVE/ BATCH.START(100), BATCH.END(100), BATCH.COUNT
    COMMON /STMT.ARCHIVE/ ARCHIVE.LOG.FILE

    IF CUTOFF.DATE EQ '' THEN
        CUTOFF.DATE = TODAY - 365  ;* Default: 1 year old
    END

    IF BATCH.SIZE EQ '' OR BATCH.SIZE LE 0 THEN
        BATCH.SIZE = 1000
    END

    IF WORKER.COUNT EQ '' OR WORKER.COUNT LE 0 THEN
        WORKER.COUNT = 4
    END

    *-------------------------------------
    * Initialize logging
    *-------------------------------------
    ARCHIVE.LOG.FILE = "ARCHIVE.LOG." : TODAY : "." : TIMEDATE()
    TOTAL.CANDIDATES = 0
    TOTAL.ARCHIVED = 0
    TOTAL.FAILED = 0
    TOTAL.SKIPPED = 0
    START.TIME = TIMEDATE()

    PRINT "Starting STMT.ENTRY Archive Process"
    PRINT "Cutoff Date: " : OCONV(CUTOFF.DATE, "D2/")
    PRINT "Batch Size: " : BATCH.SIZE
    PRINT "Worker Count: " : WORKER.COUNT
    PRINT ""

    *-------------------------------------
    * Validate archive table exists
    *-------------------------------------
    OPEN "STMT.ENTRY$ARC" TO ARC.FILE ELSE
        PRINT "ERROR: STMT.ENTRY$ARC table not found!"
        RETURN
    END

    *-------------------------------------
    * Select records to archive
    * Condition: Posting date older than cutoff AND not already archived
    *-------------------------------------
    OPEN "STMT.ENTRY" TO STMT.FILE ELSE
        PRINT "ERROR: STMT.ENTRY table not found!"
        RETURN
    END

    SELECT STMT.ENTRY
    LOOP WHILE 1
        READNEXT KEY.ID FROM SELECT.LIST ELSE KEY.ID = ''
        IF KEY.ID EQ '' THEN BREAK
        END

        * Read the record
        READ STMT.REC, KEY.ID FROM STMT.FILE ELSE CONTINUE

        * Extract posting date field (adjust field position as needed)
        * Common field positions in T24: @17 for posting date
        POSTING.DATE = STMT.REC<17>  ;* Adjust index per your schema
        ARCHIVE.FLAG = STMT.REC<99>  ;* Example archive flag field

        IF POSTING.DATE LT CUTOFF.DATE THEN
            IF ARCHIVE.FLAG NE 'Y' THEN
                TOTAL.CANDIDATES += 1
                CANDIDATES(TOTAL.CANDIDATES) = KEY.ID
                IF TOTAL.CANDIDATES MOD 1000 EQ 0 THEN
                    PRINT TOTAL.CANDIDATES : " candidates selected..."
                END
            END
        END
    REPEAT

    IF TOTAL.CANDIDATES EQ 0 THEN
        PRINT "No records found to archive."
        RETURN
    END

    PRINT "Total candidates for archival: " : TOTAL.CANDIDATES
    PRINT ""

    *-------------------------------------
    * Split into batches
    *-------------------------------------
    BATCH.COUNT = 0
    CURR = 1

    WHILE CURR LE TOTAL.CANDIDATES
        BATCH.COUNT += 1
        BATCH.START(BATCH.COUNT) = CURR
        BATCH.END(BATCH.COUNT) = CURR + BATCH.SIZE - 1
        IF BATCH.END(BATCH.COUNT) GT TOTAL.CANDIDATES THEN
            BATCH.END(BATCH.COUNT) = TOTAL.CANDIDATES
        END
        CURR = BATCH.END(BATCH.COUNT) + 1
    REPEAT

    PRINT "Batches created: " : BATCH.COUNT
    PRINT ""

    *-------------------------------------
    * Process batches (sequential or parallel via job submission)
    * For true parallelism in T24, submit each batch as separate job
    * For demonstration, we call workers sequentially
    *-------------------------------------
    FOR I = 1 TO BATCH.COUNT
        PRINT "Processing Batch " : I : " (records " : BATCH.START(I) : " to " : BATCH.END(I) : ")..."
        CALL ARCHIVE.STMT.ENTRY.WORKER(BATCH.START(I), BATCH.END(I), TOTAL.ARCHIVED, TOTAL.FAILED, TOTAL.SKIPPED)
    NEXT I

    *-------------------------------------
    * Summary report
    *-------------------------------------
    END.TIME = TIMEDATE()
    ELAPSED.SECS = END.TIME - START.TIME

    PRINT ""
    PRINT "========== ARCHIVE SUMMARY =========="
    PRINT "Total Candidates:    " : TOTAL.CANDIDATES
    PRINT "Successfully Archived: " : TOTAL.ARCHIVED
    PRINT "Failed:              " : TOTAL.FAILED
    PRINT "Skipped:             " : TOTAL.SKIPPED
    PRINT "Elapsed Time (sec):  " : ELAPSED.SECS
    PRINT "Average per sec:     " : INT(TOTAL.ARCHIVED / (ELAPSED.SECS+1))
    PRINT "===================================="
    PRINT ""

END
