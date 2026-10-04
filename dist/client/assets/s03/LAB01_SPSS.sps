* Lecture connection: Observational Grain and Missingness Screening .
* Why: Import all 10,000 recorded orders with correct types and establish variable-specific missing-value rules .
* How: GET DATA reads the exact CSV and declares identifier fields as strings .
* How: MISSING VALUES marks -1 only for age and 999 only for latency .
* How: FREQUENCIES on Hub provides an imported-case check .
* Read the result: H0 should show 10,000 imported cases while preserving every source row .
* Watch out: Do not edit the CSV or import identifiers as numbers .
* Run: Choose File > Open > Syntax and open the personalized LAB01 syntax .
* Run: Select the complete H0 block, including GET DATA .
* Run: Choose Run > Selection .
* Run: Locate H0 Import and Data Screen in the Viewer .
* LAB01 Metro E-Commerce Logistics.
* Update only the folder path below, then run H0 before later blocks.
CD 'CHANGE_TO_YOUR_EXTRACTED_LAB_FOLDER'.
* Change an SPSS setting for this session.
SET DECIMAL=DOT.
* Name the output block so you can find it in the Viewer.
TITLE 'H0 Import and Data Screen'.
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
  OrderID A8
  CustomerID A5
  OrderTier F1.0
  Hub A5
  Age_Years F3.0
  Latency_Minutes F8.3.
* Give the open dataset a name so later commands can point to it.
DATASET NAME OrdersData.
* Set each variable's measurement level (nominal, ordinal, scale).
VARIABLE LEVEL OrderID CustomerID Hub (NOMINAL) OrderTier (ORDINAL) Age_Years Latency_Minutes (SCALE).
* Attach readable descriptions to variables (they appear in output tables).
VARIABLE LABELS
 OrderID 'Unique recorded order identifier'
 CustomerID 'Customer identifier; repetition does not imply duplicate orders'
 OrderTier 'Ordered service tier; median and ranks are admissible'
 Hub 'Regional fulfillment hub'
 Age_Years 'Recorded age in years; -1 is a sentinel'
 Latency_Minutes 'Fulfillment latency in minutes; 999 is a sentinel'.
* Declare which codes mean "missing" so they are left out of statistics.
MISSING VALUES Age_Years (-1) Latency_Minutes (999).
* Frequency table: how many cases fall in each category.
FREQUENCIES VARIABLES=Hub.
* Run the pending transformations now.
EXECUTE.

* %% .

* Lecture connection: Measurement Scale Admissibility .
* Why: Inspect sentinel categories and confirm the assigned identifier, ordinal, nominal and scale roles before calculating summaries .
* How: DISPLAY DICTIONARY shows variable roles and formats .
* How: FREQUENCIES includes user-missing sentinel categories and the OrderTier distribution .
* Read the result: Read the -1 and 999 rows as documented missing codes and confirm OrderTier is ordinal .
* Watch out: Numeric storage does not make OrderTier a scale measurement .
* Run: Run H0 first in the same clean session .
* Run: Select the complete H1 block and choose Run > Selection .
* Run: Locate H1 Scale and Sentinel Audit .
* Run: Read the dictionary and frequency output .
TITLE 'H1 Scale and Sentinel Audit'.
DISPLAY DICTIONARY /VARIABLES=OrderID CustomerID OrderTier Hub Age_Years Latency_Minutes.
* Frequency table: how many cases fall in each category.
FREQUENCIES VARIABLES=OrderTier Age_Years Latency_Minutes
 /MISSING=INCLUDE
 /ORDER=ANALYSIS.

* %% .

* Lecture connection: Central Tendency and Resistance .
* Why: Produce valid-latency center, sample spread and exclusive-method quartiles for comparison with Excel .
* How: EXAMINE excludes the declared 999 user-missing values .
* How: HAVERAGE percentiles match the required exclusive position convention .
* How: Descriptives reports valid N, mean and sample standard deviation .
* Read the result: Read valid N, mean, median, SD, Q1 and Q3; calculate IQR as Q3 minus Q1 when needed .
* Watch out: Do not infer the median from the mean or another table .
* Run: Select the complete H2 block after H0 and H1 .
* Run: Choose Run > Selection .
* Run: Locate H2 Center and Spread .
* Run: Read Descriptives and Percentiles, including the named median .
TITLE 'H2 Center and Spread'.
* Explore a variable: percentiles, spread and plots, optionally by group.
EXAMINE VARIABLES=Latency_Minutes
 /PLOT=NONE
 /STATISTICS=DESCRIPTIVES
 /PERCENTILES(25,50,75) HAVERAGE
 /MISSING=LISTWISE
 /NOTOTAL.

* %% .

* Lecture connection: Visual Distribution Geometry and Tukey Fences .
* Why: Display the valid latency distribution and identify extreme recorded cases without deleting them .
* How: EXAMINE uses OrderID as the case label .
* How: The boxplot and Extreme Values table use latency after declared missing values are excluded .
* How: HAVERAGE percentile-table Q1/Q3 support the exclusive numerical check; the native plot uses Tukey hinges .
* Read the result: Use HAVERAGE Q1/Q3 for the exclusive numerical check; Inspect the hinge-based plot qualitatively; its near-boundary flags may differ from the Excel fence .
* Watch out: A plotted extreme value does not prove an error or a cause .
* Run: Select the complete H3 block and choose Run > Selection .
* Run: Locate H3 Tukey and Boxplot Evidence .
* Run: Read HAVERAGE Q1/Q3 in Percentiles for the numerical check; inspect the native plot qualitatively and the Extreme Values table as ranked cases .
* Native boxplot: Tukey hinges for qualitative inspection only.
* For the Excel exclusive check, read HAVERAGE Q1 and Q3 in Percentiles.
* Do not require identical near-boundary case flags from the native plot.
TITLE 'H3 Tukey and Boxplot Evidence'.
* Explore a variable: percentiles, spread and plots, optionally by group.
EXAMINE VARIABLES=Latency_Minutes
 /ID=OrderID
 /PLOT=BOXPLOT
 /STATISTICS=DESCRIPTIVES EXTREME(5)
 /PERCENTILES(25,50,75) HAVERAGE
 /MISSING=LISTWISE
 /NOTOTAL.

* %% .

* Lecture connection: Comparative Distribution Audits and Causal Boundaries .
* Why: Compare valid count, center and spread across Hub A, Hub B and Hub C using one common rule .
* How: BY Hub creates separate summaries from the stacked Hub column .
* How: Each group uses its own valid latency denominator .
* How: HAVERAGE provides the required quartile convention .
* Read the result: Compare each hub's valid N, median, Q1 and Q3 without assigning operational cause .
* Watch out: Do not compare groups that use different missing-value filters .
* Run: Select the complete H4 block and choose Run > Selection .
* Run: Locate H4 Hub Comparative Audit .
* Run: Read each hub's valid N and percentile table .
* Run: Confirm the group counts reconcile .
TITLE 'H4 Hub Comparative Audit'.
* Explore a variable: percentiles, spread and plots, optionally by group.
EXAMINE VARIABLES=Latency_Minutes BY Hub
 /PLOT=NONE
 /STATISTICS=DESCRIPTIVES
 /PERCENTILES(25,50,75) HAVERAGE
 /MISSING=LISTWISE.

* %% .

* Lecture connection: Comparative Distribution Audits and Causal Boundaries .
* Why: Produce the overall and Hub C descriptive evidence used in the final SLA discussion .
* How: The first EXAMINE reports overall valid N, center and the 95th percentile .
* How: TEMPORARY and SELECT IF restrict only the next EXAMINE to Hub C .
* How: HAVERAGE preserves the exclusive percentile convention .
* Read the result: Read the overall and Hub C valid N, mean, median and 95th-percentile latency in minutes .
* Watch out: Do not treat descriptive Hub C differences as proof of carrier fault .
* Run: Select the complete H5 block without separating TEMPORARY from its EXAMINE .
* Run: Choose Run > Selection .
* Run: Locate both H5 named outputs .
* Run: Read valid N, mean, median and the 95th percentile .
TITLE 'H5 Overall SLA Threshold'.
* Explore a variable: percentiles, spread and plots, optionally by group.
EXAMINE VARIABLES=Latency_Minutes
 /PLOT=NONE
 /STATISTICS=DESCRIPTIVES
 /PERCENTILES(50,95) HAVERAGE
 /MISSING=LISTWISE
 /NOTOTAL.
* Name the output block so you can find it in the Viewer.
TITLE 'H5 Hub C SLA Evidence'.
* Make the next transformation apply to the next procedure only.
TEMPORARY.
* Keep only the rows that meet the condition (others are deleted).
SELECT IF (Hub='Hub C').
* Explore a variable: percentiles, spread and plots, optionally by group.
EXAMINE VARIABLES=Latency_Minutes
 /PLOT=NONE
 /STATISTICS=DESCRIPTIVES
 /PERCENTILES(50,95) HAVERAGE
 /MISSING=LISTWISE
 /NOTOTAL.
