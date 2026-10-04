# T24-STMT-ENTRY-Archival

Oracle-based archive routine for STMT.ENTRY to STMT.ENTRY$ARC using dev-environment parallel processing.

This version targets the rule:
- BOOKING.DATE < 20260101
- Oracle database
- archive to STMT.ENTRY$ARC
- suitable for development/test use

It includes:
- a direct parallel INSERT/SELECT pattern
- an optional DBMS_PARALLEL_EXECUTE method for multi-worker execution

