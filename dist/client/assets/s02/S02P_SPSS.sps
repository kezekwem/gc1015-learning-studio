* ============================================================================.
* S02P practice: KPIs, variables, grain, chart critique, and bounded stories.
* MASY1-GC 1015: Quantitative Methods for Business Analysis.
* This practice is ungraded.
* ============================================================================.

CD 'CHANGE_TO_YOUR_EXTRACTED_LAB_FOLDER'.
* Change an SPSS setting for this session.
SET DECIMAL=DOT.

* Import the real MetroMeal CSV used in the guided build.
TITLE 'Import orders_story.csv: expect 2000 eligible completed deliveries'.
* Read the data file into SPSS (file type, name, and each variable's format).
GET DATA
 /TYPE=TXT
 /FILE='orders_story.csv'
 /ENCODING='UTF8'
 /DELCASE=LINE
 /DELIMITERS=","
 /QUALIFIER='"'
 /ARRANGEMENT=DELIMITED
 /FIRSTCASE=2
 /VARIABLES=
  order_id F8.0
  customer_id F8.0
  completed_date SDATE10
  week_start SDATE10
  weekend_flag F1.0
  region A12
  item_count F3.0
  promised_minutes F8.0
  delivery_minutes F8.2
  late_minutes F8.2
  satisfaction_category F2.0
  eligible_kpi_flag F1.0
  on_time_kpi_flag F1.0
  complaint_flag F1.0
  target_rate F8.4
  complaint_guardrail F8.4.
* Give the open dataset a name so later commands can point to it.
DATASET NAME OrdersStory.
* Set how values display (width and decimals); the stored values do not change.
FORMATS completed_date week_start (SDATE10).
* Attach readable descriptions to variables (they appear in output tables).
VARIABLE LABELS
 order_id 'Delivery identifier and candidate key'
 customer_id 'Customer identifier, not a measure'
 completed_date 'Date delivery was completed'
 week_start 'Start date of the reporting week'
 weekend_flag '1 for weekend completion, 0 otherwise'
 region 'MetroMeal region'
 item_count 'Number of items in the order'
 promised_minutes 'Promised delivery duration in minutes'
 delivery_minutes 'Observed delivery duration in minutes'
 late_minutes 'Minutes late, with zero for an on-time delivery'
 satisfaction_category 'Ordered satisfaction category from 1 to 5'
 eligible_kpi_flag '1 when the delivery is eligible for the KPI'
 on_time_kpi_flag '1 when the eligible delivery is on time'
 complaint_flag '1 when a complaint was recorded'
 target_rate 'Management on-time target'
 complaint_guardrail 'Maximum complaint-rate guardrail'.
* Attach readable names to codes such as 0 and 1.
VALUE LABELS weekend_flag 0 'Weekday' 1 'Weekend'
 /eligible_kpi_flag 0 'Not eligible' 1 'Eligible'
 /on_time_kpi_flag 0 'Late' 1 'On time'
 /complaint_flag 0 'No complaint' 1 'Complaint'.
* Run the pending transformations now.
EXECUTE.

* Guided Step 1.
TITLE 'Guided Step 1: source, candidate key, grain, and eligibility'.
* Switch to the named dataset; the next commands work on it.
DATASET ACTIVATE OrdersStory.
* Frequency table: how many cases fall in each category.
FREQUENCIES VARIABLES=eligible_kpi_flag.
* Make a working copy so the original data stay untouched.
DATASET COPY GrainCheck.
* Switch to the named dataset; the next commands work on it.
DATASET ACTIVATE GrainCheck.
* Collapse rows into group summaries (one row per group).
AGGREGATE
 /OUTFILE=*
 /BREAK=order_id
 /rows_per_order=N.
* Summary statistics (N, mean, standard deviation, minimum, maximum).
DESCRIPTIVES VARIABLES=rows_per_order /STATISTICS=SUM MIN MAX.
* Switch to the named dataset; the next commands work on it.
DATASET ACTIVATE OrdersStory.

* Guided Step 2.
TITLE 'Guided Step 2: weekly KPI, guardrail, aggregate, and late-delivery checks'.
* Switch to the named dataset; the next commands work on it.
DATASET ACTIVATE OrdersStory.
* Create an empty named dataset to receive results.
DATASET DECLARE WeeklyKPI.
* Collapse rows into group summaries (one row per group).
AGGREGATE
 /OUTFILE='WeeklyKPI'
 /BREAK=week_start
 /eligible=SUM(eligible_kpi_flag)
 /on_time=SUM(on_time_kpi_flag)
 /complaints=SUM(complaint_flag)
 /target=MAX(target_rate)
 /guardrail=MAX(complaint_guardrail).
* Switch to the named dataset; the next commands work on it.
DATASET ACTIVATE WeeklyKPI.
* Create or overwrite a variable with a formula, row by row.
COMPUTE rate=on_time/eligible.
* Create or overwrite a variable with a formula, row by row.
COMPUTE gap_pp=(rate-target)*100.
* Create or overwrite a variable with a formula, row by row.
COMPUTE complaint_rate=complaints/eligible.
* Set how values display (width and decimals); the stored values do not change.
FORMATS rate target guardrail complaint_rate (PCT5.1) gap_pp (F6.1).
* Sort the rows by the listed variables.
SORT CASES BY week_start.
* Print the listed variables row by row.
LIST VARIABLES=week_start eligible on_time rate gap_pp complaints complaint_rate target guardrail.
* Collapse rows into group summaries (one row per group).
AGGREGATE
 /OUTFILE=*
 /BREAK=
 /eligible_total=SUM(eligible)
 /on_time_total=SUM(on_time)
 /complaints_total=SUM(complaints)
 /target=MAX(target)
 /guardrail=MAX(guardrail).
* Create or overwrite a variable with a formula, row by row.
COMPUTE overall_rate=on_time_total/eligible_total.
* Create or overwrite a variable with a formula, row by row.
COMPUTE overall_gap_pp=(overall_rate-target)*100.
* Create or overwrite a variable with a formula, row by row.
COMPUTE overall_complaint_rate=complaints_total/eligible_total.
* Set how values display (width and decimals); the stored values do not change.
FORMATS overall_rate overall_complaint_rate target guardrail (PCT6.2) overall_gap_pp (F6.2).
* Print the listed variables row by row.
LIST.
* Switch to the named dataset; the next commands work on it.
DATASET ACTIVATE OrdersStory.
* Make the next transformation apply to the next procedure only.
TEMPORARY.
* Keep only the rows that meet the condition (others are deleted).
SELECT IF (week_start=DATE.DMY(24,8,2026) AND eligible_kpi_flag=1 AND late_minutes>0).
* Explore a variable: percentiles, spread and plots, optionally by group.
EXAMINE VARIABLES=late_minutes
 /STATISTICS=DESCRIPTIVES
 /PERCENTILES(50,90)
 /MISSING=LISTWISE.

* Rebuild WeeklyKPI because the aggregate listing above reduced its active copy.
DATASET ACTIVATE OrdersStory.
* Close a dataset you no longer need.
DATASET CLOSE WeeklyKPI.
* Create an empty named dataset to receive results.
DATASET DECLARE WeeklyKPI.
* Collapse rows into group summaries (one row per group).
AGGREGATE
 /OUTFILE='WeeklyKPI'
 /BREAK=week_start
 /eligible=SUM(eligible_kpi_flag)
 /on_time=SUM(on_time_kpi_flag)
 /complaints=SUM(complaint_flag)
 /target=MAX(target_rate)
 /guardrail=MAX(complaint_guardrail).
* Switch to the named dataset; the next commands work on it.
DATASET ACTIVATE WeeklyKPI.
* Create or overwrite a variable with a formula, row by row.
COMPUTE rate=on_time/eligible.
* Create or overwrite a variable with a formula, row by row.
COMPUTE gap_pp=(rate-target)*100.
* Create or overwrite a variable with a formula, row by row.
COMPUTE complaint_rate=complaints/eligible.
* Set how values display (width and decimals); the stored values do not change.
FORMATS rate target guardrail complaint_rate (PCT5.1) gap_pp (F6.1).
* Sort the rows by the listed variables.
SORT CASES BY week_start.
* Run the pending transformations now.
EXECUTE.

* Guided Step 3.
TITLE 'Guided Step 3: weekly on-time chart from checked values'.
* Switch to the named dataset; the next commands work on it.
DATASET ACTIVATE WeeklyKPI.
* Draw a chart.
GRAPH /BAR(SIMPLE)=MEAN(rate) BY week_start.

* Guided Step 4.
TITLE 'Guided Step 4: values to validate against the chart title and bounded story'.
* Switch to the named dataset; the next commands work on it.
DATASET ACTIVATE WeeklyKPI.
* Print the listed variables row by row.
LIST VARIABLES=week_start eligible on_time rate gap_pp complaints complaint_rate target guardrail.

* Hand-off Block H1.
TITLE 'Block H1: decision, KPI, target, and guardrail'.
NEW FILE.
DATA LIST FREE / ontime eligible target complaints guardrail.
BEGIN DATA
392 500 .85 14 .03
END DATA.
* Create or overwrite a variable with a formula, row by row.
COMPUTE rate=ontime/eligible.
* Create or overwrite a variable with a formula, row by row.
COMPUTE gap_pp=(rate-target)*100.
* Create or overwrite a variable with a formula, row by row.
COMPUTE complaint_rate=complaints/eligible.
* Set how values display (width and decimals); the stored values do not change.
FORMATS rate target guardrail complaint_rate (PCT5.1) gap_pp (F6.1).
* Print the listed variables row by row.
LIST.

* Hand-off Block H2.
TITLE 'Block H2: weekly and aggregate KPI calculations'.
NEW FILE.
DATA LIST FREE / week (A10) ontime eligible target.
BEGIN DATA
2026-08-03 420 500 .85
2026-08-10 438 500 .85
2026-08-17 425 500 .85
2026-08-24 392 500 .85
END DATA.
* Create or overwrite a variable with a formula, row by row.
COMPUTE rate=ontime/eligible.
* Create or overwrite a variable with a formula, row by row.
COMPUTE gap_pp=(rate-target)*100.
* Set how values display (width and decimals); the stored values do not change.
FORMATS rate target (PCT5.1) gap_pp (F6.1).
* Print the listed variables row by row.
LIST.
* Collapse rows into group summaries (one row per group).
AGGREGATE
 /OUTFILE=*
 /BREAK=
 /ontime_total=SUM(ontime)
 /eligible_total=SUM(eligible).
* Create or overwrite a variable with a formula, row by row.
COMPUTE overall_rate=ontime_total/eligible_total.
* Set how values display (width and decimals); the stored values do not change.
FORMATS overall_rate (PCT6.2).
* Print the listed variables row by row.
LIST.

* Hand-off Block H3.
TITLE 'Block H3: item grain, repeated order IDs, and restoration to order grain'.
NEW FILE.
DATA LIST FREE / order_id (A1) item_id (A2) returned.
BEGIN DATA
A I1 1
A I2 1
A I3 1
B I4 0
END DATA.
* Frequency table: how many cases fall in each category.
FREQUENCIES VARIABLES=order_id.
* Collapse rows into group summaries (one row per group).
AGGREGATE
 /OUTFILE=*
 /BREAK=order_id
 /returned_order=MAX(returned)
 /item_rows=N.
* Print the listed variables row by row.
LIST.

* Hand-off Block H4.
TITLE 'Block H4: four weekly rates and a simple zero-baseline bar chart'.
NEW FILE.
DATA LIST FREE / week (A10) rate target eligible.
BEGIN DATA
2026-08-03 .840 .850 500
2026-08-10 .876 .850 500
2026-08-17 .850 .850 500
2026-08-24 .784 .850 500
END DATA.
* Set how values display (width and decimals); the stored values do not change.
FORMATS rate target (PCT5.1).
* Print the listed variables row by row.
LIST.
* Draw a chart.
GRAPH /BAR(SIMPLE)=MEAN(rate) BY week.

* Hand-off Block H5.
TITLE 'Block H5: reconcile the latest evidence and calculate story values'.
NEW FILE.
DATA LIST FREE / ontime late eligible target complaints guardrail.
BEGIN DATA
392 108 500 .85 14 .03
END DATA.
* Create or overwrite a variable with a formula, row by row.
COMPUTE reconcile=ontime+late-eligible.
* Create or overwrite a variable with a formula, row by row.
COMPUTE rate=ontime/eligible.
* Create or overwrite a variable with a formula, row by row.
COMPUTE gap_pp=(rate-target)*100.
* Create or overwrite a variable with a formula, row by row.
COMPUTE complaint_rate=complaints/eligible.
* Set how values display (width and decimals); the stored values do not change.
FORMATS rate target guardrail complaint_rate (PCT5.1) gap_pp (F6.1).
* Print the listed variables row by row.
LIST.
