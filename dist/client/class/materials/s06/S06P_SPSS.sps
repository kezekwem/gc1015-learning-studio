* Lecture connection: Cross-Tool Reconciliation and SRM Audits .
* Why: Import the shared user-level CSV before testing or comparing outcomes .
* How: CD identifies the folder containing the CSV; GET DATA preserves string identifiers and reads numeric fields .
* How: FREQUENCIES shows imported group totals and recorded versus missing survey scores .
* Read the result: Check H0's group total of 800 cases and the recorded survey N; inspect variable roles in Data Editor .
* Watch out: Do not point CD at the syntax file or silently replace blank scores with zero .
* Run: Open the supplied syntax with File > Open > Syntax and adjust only its CD folder .
* Run: Select and run the complete H0 block with Run > Selection .
* Run: Use Window to open Output Viewer; inspect H0 frequencies and Data Editor Variable View .
* S06P supplied reproducible syntax. Replace only the CD folder below; keep CSV and syntax together.
CD '<REPLACE_WITH_FOLDER_CONTAINING_CSV_AND_SPS>'.
* Name the output block so you can find it in the Viewer.
TITLE 'H0 CedarCart Import and Data Screen'.
* Import numeric fields as text first so failed conversions cannot masquerade as blank source fields.
GET DATA
 /TYPE=TXT
 /FILE='cedarcart_ab_test.csv'
 /ENCODING='UTF8'
 /DELCASE=LINE
 /DELIMITERS=","
 /QUALIFIER='"'
 /ARRANGEMENT=DELIMITED
 /FIRSTCASE=2
 /VARIABLES=
 user_id A32
 group A1
 purchase_raw A255
 complaint_raw A255
 satisfaction_raw A255
 satisfaction_goal_points_raw A255
 margin_per_extra_purchase_usd_raw A255
 rollout_cost_per_b_user_usd_raw A255
 cost_per_excess_complaint_usd_raw A255
 complaint_uplift_limit_pp_raw A255.
* Give the open dataset a name so later commands can point to it.
DATASET NAME S06P_CedarCart.
* Create or overwrite a variable with a formula, row by row.
COMPUTE purchase=NUMBER(purchase_raw,F30.16).
* Create or overwrite a variable with a formula, row by row.
COMPUTE complaint=NUMBER(complaint_raw,F30.16).
* Create or overwrite a variable with a formula, row by row.
COMPUTE satisfaction=NUMBER(satisfaction_raw,F30.16).
* Create or overwrite a variable with a formula, row by row.
COMPUTE satisfaction_goal_points=NUMBER(satisfaction_goal_points_raw,F30.16).
* Create or overwrite a variable with a formula, row by row.
COMPUTE margin_per_extra_purchase_usd=NUMBER(margin_per_extra_purchase_usd_raw,F30.16).
* Create or overwrite a variable with a formula, row by row.
COMPUTE rollout_cost_per_b_user_usd=NUMBER(rollout_cost_per_b_user_usd_raw,F30.16).
* Create or overwrite a variable with a formula, row by row.
COMPUTE cost_per_excess_complaint_usd=NUMBER(cost_per_excess_complaint_usd_raw,F30.16).
* Create or overwrite a variable with a formula, row by row.
COMPUTE complaint_uplift_limit_pp=NUMBER(complaint_uplift_limit_pp_raw,F30.16).
* Create or overwrite a variable with a formula, row by row.
COMPUTE bad_purchase=(RTRIM(LTRIM(purchase_raw)) <> '' AND SYSMIS(purchase)).
* Create or overwrite a variable with a formula, row by row.
COMPUTE bad_complaint=(RTRIM(LTRIM(complaint_raw)) <> '' AND SYSMIS(complaint)).
* Create or overwrite a variable with a formula, row by row.
COMPUTE bad_purchase_domain=0.
* Compute a value only for rows that meet the condition.
IF (NOT SYSMIS(purchase)) bad_purchase_domain=(purchase <> 0 AND purchase <> 1).
* Create or overwrite a variable with a formula, row by row.
COMPUTE bad_complaint_domain=0.
* Compute a value only for rows that meet the condition.
IF (NOT SYSMIS(complaint)) bad_complaint_domain=(complaint <> 0 AND complaint <> 1).
* Create or overwrite a variable with a formula, row by row.
COMPUTE bad_satisfaction=(RTRIM(LTRIM(satisfaction_raw)) <> '' AND SYSMIS(satisfaction)).
* Create or overwrite a variable with a formula, row by row.
COMPUTE bad_goal=(RTRIM(LTRIM(satisfaction_goal_points_raw)) <> '' AND SYSMIS(satisfaction_goal_points)).
* Create or overwrite a variable with a formula, row by row.
COMPUTE bad_margin=(RTRIM(LTRIM(margin_per_extra_purchase_usd_raw)) <> '' AND SYSMIS(margin_per_extra_purchase_usd)).
* Create or overwrite a variable with a formula, row by row.
COMPUTE bad_rollout_cost=(RTRIM(LTRIM(rollout_cost_per_b_user_usd_raw)) <> '' AND SYSMIS(rollout_cost_per_b_user_usd)).
* Create or overwrite a variable with a formula, row by row.
COMPUTE bad_complaint_cost=(RTRIM(LTRIM(cost_per_excess_complaint_usd_raw)) <> '' AND SYSMIS(cost_per_excess_complaint_usd)).
* Create or overwrite a variable with a formula, row by row.
COMPUTE bad_limit=(RTRIM(LTRIM(complaint_uplift_limit_pp_raw)) <> '' AND SYSMIS(complaint_uplift_limit_pp)).
COUNT malformed_fields=bad_purchase bad_complaint bad_purchase_domain bad_complaint_domain bad_satisfaction bad_goal bad_margin bad_rollout_cost bad_complaint_cost bad_limit (1).
* Collapse rows into group summaries (one row per group).
AGGREGATE
 /OUTFILE=* MODE=ADDVARIABLES
 /BREAK=
 /malformed_any=MAX(malformed_fields).
* Set each variable's measurement level (nominal, ordinal, scale).
VARIABLE LEVEL group purchase complaint (NOMINAL).
* Set each variable's measurement level (nominal, ordinal, scale).
VARIABLE LEVEL satisfaction satisfaction_goal_points margin_per_extra_purchase_usd rollout_cost_per_b_user_usd cost_per_excess_complaint_usd complaint_uplift_limit_pp (SCALE).
* Run the pending transformations now.
EXECUTE.
DISPLAY DICTIONARY.
* Frequency table: how many cases fall in each category.
FREQUENCIES VARIABLES=group purchase complaint satisfaction satisfaction_goal_points malformed_fields malformed_any.
* Every case must have malformed_any=0. If not, inspect the flagged raw fields, including nonbinary purchase or complaint values, and resolve the input before interpreting H1-H3.
TEMPORARY.
* Keep only the rows that meet the condition (others are deleted).
SELECT IF (malformed_fields > 0).
* Print the listed variables row by row.
LIST VARIABLES=user_id group bad_purchase bad_complaint bad_purchase_domain bad_complaint_domain bad_satisfaction bad_goal bad_margin bad_rollout_cost bad_complaint_cost bad_limit.
* Confirm satisfaction_goal_points has one recorded value, 70, with no missing values, matching H1 TESTVAL before interpreting H1.

* %% .

* Lecture connection: One-Sample t-Test for Benchmark Goals .
* Why: Test recorded satisfaction against the fixed source-checked 70-point goal .
* How: TESTVAL sets the fixed goal; VARIABLES selects satisfaction and excludes blank scores .
* How: CI(.95) requests the 95% interval for the difference from the goal .
* Read the result: Read H1 N, mean, sample SD, t, df, two-sided significance and whether the difference interval covers zero .
* Watch out: Do not interpret the difference-from-goal interval as a between-arm interval .
* Run: After H0, find H1 in the supplied Syntax Editor and select the complete block .
* Run: Choose Run > Selection, not Run > All for this single block .
* Run: Switch with Window to Output Viewer and find H1 One-Sample Statistics and Test .
TITLE 'H1 Satisfaction Benchmark'.
* Make the next transformation apply to the next procedure only.
TEMPORARY.
* Keep only the rows that meet the condition (others are deleted).
SELECT IF (malformed_any=0).
* Compare means with a t test.
T-TEST /TESTVAL=70 /MISSING=ANALYSIS
 /VARIABLES=satisfaction /CRITERIA=CI(.95).

* %% .

* Lecture connection: Two-Proportion z-Test Mechanics .
* Why: Compare purchase outcomes among users with observed 0 or 1 outcomes .
* How: TEMPORARY and SELECT IF retain A/B assignments with observed binary purchases for the following CROSSTABS only .
* How: CHISQ supplies the uncorrected Pearson 2×2 statistic and df 1 .
* Read the result: Read H2 counts, row percentages and the Pearson row; its uncorrected statistic matches conversion z squared .
* Watch out: Do not separate TEMPORARY and SELECT IF from CROSSTABS or compare Yates' correction with z squared .
* Run: Run H0 first; find H2 and select its entire block, including TEMPORARY and CROSSTABS .
* Run: Choose Run > Selection .
* Run: In Output Viewer, locate H2 Crosstabulation and Pearson Chi-Square, not Continuity Correction .
TITLE 'H2 Purchase by Group'.
* Make the next transformation apply to the next procedure only.
TEMPORARY.
* Keep only the rows that meet the condition (others are deleted).
SELECT IF (malformed_any=0 AND (group='A' OR group='B') AND (purchase=0 OR purchase=1)).
* Two-way table: counts and percentages for one variable by another.
CROSSTABS /TABLES=group BY purchase
 /FORMAT=AVALUE TABLES /STATISTICS=CHISQ
 /CELLS=COUNT ROW /COUNT ROUND CELL.

* %% .

* Lecture connection: Cross-Tool Reconciliation and SRM Audits .
* Why: Inspect the complaint guardrail using its own observed-outcome table .
* How: TEMPORARY and SELECT IF retain A/B users with observed binary complaint outcomes .
* How: CROSSTABS reports complaint row counts and its own uncorrected Pearson statistic .
* Read the result: Compare H3's Pearson row, df 1, with Part C B14; its table is distinct from H2's purchase table .
* Watch out: Do not copy H2's chi-square into a caption about complaints .
* Run: Run H0 first; select H3 from TITLE through the final CROSSTABS period .
* Run: Choose Run > Selection .
* Run: Use Window to find H3 complaint Crosstabulation and its uncorrected Pearson row .
TITLE 'H3 Complaint by Group'.
* Make the next transformation apply to the next procedure only.
TEMPORARY.
* Keep only the rows that meet the condition (others are deleted).
SELECT IF (malformed_any=0 AND (group='A' OR group='B') AND (complaint=0 OR complaint=1)).
* Two-way table: counts and percentages for one variable by another.
CROSSTABS /TABLES=group BY complaint
 /FORMAT=AVALUE TABLES /STATISTICS=CHISQ
 /CELLS=COUNT ROW /COUNT ROUND CELL.
