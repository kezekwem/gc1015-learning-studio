* Lecture connection: Target Population and Sampling Frame .
* Why: Validate and import the one provisional pickup roster before any dependent analysis .
* How: CD points to the folder containing the supplied CSV; GET DATA preserves the ID as text and imports numeric blanks as missing .
* How: The supplied validation rejects malformed nonblank numeric tokens and unexpected binary values before import .
* Read the result: H0 invitation frequencies account for the 2,400 recorded rows; that count does not certify frame completeness .
* Watch out: Running H1–H3 before H0 or pointing CD at the syntax file instead of its folder .
* Run: Choose File > Open > Syntax and open S05P_SPSS.sps; set CD to the extracted folder .
* Run: Select the complete CD-through-H0 block and choose Run > Selection .
* Run: Use Window to open Output Viewer; find H0 Import and Frame Check .
* S05P supplied reproducible syntax. Edit only the CD folder path; keep the CSV beside this file.
* Select and run the complete H0 block once per session before H1, H2 or H3.
CD 'REPLACE_WITH_FOLDER_CONTAINING_CSV_AND_SPS'.
BEGIN PROGRAM PYTHON3.
import csv
import math
import os
from decimal import Decimal, InvalidOperation
path = os.path.join(os.getcwd(), 'cedar_loop_pickups.csv')
expected = ['pickup_id', 'invitation_status', 'delay_flag', 'slow_flag', 'duration']
with open(path, newline='', encoding='utf-8-sig') as source:
    reader = csv.DictReader(source)
    if reader.fieldnames != expected:
        raise ValueError('H0 input error: CSV headers do not match the supplied data dictionary')
    rows = list(reader)
if len(rows) != 2400:
    raise ValueError('H0 input error: expected 2400 recorded pickup rows')
for line_number, row in enumerate(rows, start=2):
    if not row['pickup_id'] or row['invitation_status'] not in ('responded', 'nonresponse', 'not_invited'):
        raise ValueError('H0 input error: invalid identifier or invitation status on CSV line {}'.format(line_number))
    for field in ('delay_flag', 'slow_flag', 'duration'):
        token = row[field]
        if token == '':
            continue
        try:
            value = Decimal(token)
            if not value.is_finite() or not math.isfinite(float(value)):
                raise InvalidOperation
        except (InvalidOperation, ValueError, OverflowError):
            raise ValueError('H0 input error: malformed nonblank {} on CSV line {}'.format(field, line_number))
        if field in ('delay_flag', 'slow_flag') and value not in (Decimal(0), Decimal(1)):
            raise ValueError('H0 input error: {} must be 0, 1 or blank on CSV line {}'.format(field, line_number))
print('H0 CSV validation passed: 2400 rows; blank numeric tokens remain missing.')
END PROGRAM.
* Read the data file into SPSS (file type, name, and each variable's format).
GET DATA
 /TYPE=TXT
 /FILE='cedar_loop_pickups.csv'
 /ENCODING='UTF8'
 /DELCASE=LINE
 /DELIMITERS=","
 /QUALIFIER='"'
 /ARRANGEMENT=DELIMITED
 /FIRSTCASE=2
 /VARIABLES=pickup_id A8 invitation_status A16 delay_flag F1.0 slow_flag F1.0 duration F24.15.
* Attach readable descriptions to variables (they appear in output tables).
VARIABLE LABELS duration 'Recorded pickup duration (minutes)' delay_flag 'Delay over 50 minutes: 1 yes, 0 no' slow_flag 'Alias of delay_flag: 1 yes, 0 no'.
* Set each variable's measurement level (nominal, ordinal, scale).
VARIABLE LEVEL pickup_id (NOMINAL) invitation_status (NOMINAL) delay_flag (NOMINAL) slow_flag (NOMINAL) duration (SCALE).
* Run the pending transformations now.
EXECUTE.
* Name the output block so you can find it in the Viewer.
TITLE 'H0 Import and Frame Check'.
* Frequency table: how many cases fall in each category.
FREQUENCIES VARIABLES=invitation_status /ORDER=ANALYSIS.

* %% .

* Lecture connection: Nonresponse Sensitivity Bounds .
* Why: Inspect invited statuses and observed delay outcomes that underpin Part A's denominators .
* How: FREQUENCIES lists exact invitation_status categories and recorded delay_flag values; blank flags remain missing .
* How: Do not equate all missing flags with invited nonresponse: most recorded rows were not invited .
* Read the result: Read status counts separately from the valid 0/1 delay count; Excel calculates the invitation scenarios .
* Watch out: Mistaking 2,300 missing delay flags for 2,300 invited nonrespondents .
* Run: In Syntax Editor, find H1 and select its complete titled block .
* Run: Choose Run > Selection; use Window to reach Output Viewer .
* Run: Find H1 Invitation and Recorded Delay Frequencies and inspect both tables .
TITLE 'H1 Invitation and Recorded Delay Frequencies'.
* Frequency table: how many cases fall in each category.
FREQUENCIES VARIABLES=invitation_status /ORDER=ANALYSIS.
* Make the next transformation apply to the next procedure only.
TEMPORARY.
* Keep only the rows that meet the condition (others are deleted).
SELECT IF (invitation_status = 'responded' AND (delay_flag = 0 OR delay_flag = 1)).
* Frequency table: how many cases fall in each category.
FREQUENCIES VARIABLES=delay_flag /ORDER=ANALYSIS.

* %% .

* Lecture connection: Student t Confidence Interval for a Mean .
* Why: Cross-check Part B's interval for average observed pickup duration .
* How: EXAMINE uses nonmissing duration in minutes; DESCRIPTIVES requests valid N, mean, sample SD, SE and 95% confidence limits .
* How: The interval estimates a mean, using sample spread rather than known population sigma .
* Read the result: Read H2 Descriptives' mean limits in minutes and compare with B10:B11 to displayed precision .
* Watch out: Confusing the mean interval with the range covering individual pickups .
* Run: After H0, find H2 in Syntax Editor and select its complete titled block .
* Run: Choose Run > Selection; switch through Window to Output Viewer .
* Run: Read H2 Mean Duration Interval, especially Descriptives and its mean limits .
TITLE 'H2 Mean Duration Interval'.
* Explore a variable: percentiles, spread and plots, optionally by group.
EXAMINE VARIABLES=duration
 /PLOT=NONE
 /STATISTICS=DESCRIPTIVES
 /CINTERVAL 95
 /MISSING=LISTWISE.

* %% .

* Lecture connection: Confidence Interval for a Population Proportion .
* Why: Cross-check the eligible observed 0/1 inputs for Part C's Excel proportion interval .
* How: FREQUENCIES displays the recorded delay_flag 0 and 1 rows and valid N; blanks remain missing .
* How: Excel, not this SPSS block, applies the normal interval and completed-sample planning formula .
* Read the result: Read valid 0/1 counts; compare their total with the observed-outcome denominator in Part C .
* Watch out: Using /FORMAT=NOTABLE, which suppresses the frequency rows needed here .
* Run: After H0, find H3 in Syntax Editor and select its complete titled block .
* Run: Choose Run > Selection; switch through Window to Output Viewer .
* Run: Read H3 Recorded Delay Frequencies, including both 0 and 1 rows .
TITLE 'H3 Recorded Delay Frequencies'.
* Make the next transformation apply to the next procedure only.
TEMPORARY.
* Keep only the rows that meet the condition (others are deleted).
SELECT IF (invitation_status = 'responded' AND (delay_flag = 0 OR delay_flag = 1)).
* Frequency table: how many cases fall in each category.
FREQUENCIES VARIABLES=delay_flag /ORDER=ANALYSIS.
