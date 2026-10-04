* Lecture connection: Descriptive Frequency Tables .
* Why: Import the exact cohort as strings and inspect row counts and allowed category values .
* How: GET DATA reads the exact CSV basename .
* How: String formats preserve AccountID and category labels; blank strings are declared missing .
* Read the result: Inspect H0 for 1,000 cases and only recorded Yes or No category values .
* Watch out: Do not let SPSS infer AccountID as numeric .
* Run: Open the supplied syntax through File > Open > Syntax .
* Run: Select the complete H0 block and choose Run > Selection .
* Run: Switch to Output Viewer and locate H0 Import and Data Screen .
CD '/REPLACE/WITH/LAB02_FOLDER'.

* Name the output block so you can find it in the Viewer.
TITLE 'H0 Import and Data Screen'.
* Read the data file into SPSS (file type, name, and each variable's format).
GET DATA
  /TYPE=TXT
  /FILE='cloudflow_churn_cohort.csv'
  /ENCODING='UTF8'
  /ARRANGEMENT=DELIMITED
  /FIRSTCASE=2
  /DELCASE=LINE
  /DELIMITERS=','
  /QUALIFIER='"'
  /VARIABLES=
    AccountID A32
    Churn A3
    HighTickets A3.
* Keep a working copy in memory so later passes are fast.
CACHE.
* Run the pending transformations now.
EXECUTE.
* Give the open dataset a name so later commands can point to it.
DATASET NAME CohortData.
* Declare which codes mean "missing" so they are left out of statistics.
MISSING VALUES Churn HighTickets ('').
* Attach readable descriptions to variables (they appear in output tables).
VARIABLE LABELS
  AccountID 'Recorded CloudFlow account identifier'
  Churn 'Recorded churn outcome'
  HighTickets 'Recorded high-ticket indicator'.
* Frequency table: how many cases fall in each category.
FREQUENCIES VARIABLES=Churn HighTickets
  /ORDER=ANALYSIS.

* %% .

* Lecture connection: Bayesian Updating .
* Why: Cross-tabulate Churn by HighTickets using observed category pairs .
* How: Rows represent Churn and columns represent HighTickets .
* How: Column percentages use observed Churn within each ticket column .
* Read the result: Read the Churn=Yes count and column percentage within HighTickets=Yes .
* Watch out: Do not report the row percentage as posterior churn risk .
* Run: Select the complete H1 block after H0 has run .
* Run: Choose Run > Selection .
* Run: Locate H1 Conditional Churn Risk in the Viewer .
TITLE 'H1 Conditional Churn Risk'.
* Two-way table: counts and percentages for one variable by another.
CROSSTABS
  /TABLES=Churn BY HighTickets
  /FORMAT=AVALUE TABLES
  /CELLS=COUNT ROW COLUMN TOTAL
  /COUNT ROUND CELL.

* %% .

* Lecture connection: Expected Monetary Value .
* Why: Audit the probability weights and capacity EMVs using the same stated CloudFlow assumptions .
* How: Three retained cohort rows provide a reproducible workspace .
* How: Weighted payoffs are summed by capacity alternative .
* Read the result: Read the probability total, both EMVs and rolled-back node value in million dollars .
* Watch out: Do not mistake the largest state payoff for the largest EMV .
* Run: Select the complete H2 block .
* Run: Choose Run > Selection .
* Run: Locate H2 Capacity EMV Audit and read its listed values .
TITLE 'H2 Capacity EMV Audit'.
* Make a working copy so the original data stay untouched.
DATASET COPY CapacityAudit.
* Switch to the named dataset; the next commands work on it.
DATASET ACTIVATE CapacityAudit.
* Keep only the rows that meet the condition (others are deleted).
SELECT IF ($CASENUM <= 3).
* Declare new text variables.
STRING DemandState (A6).
* Start a block of commands that run only when the condition is true.
DO IF ($CASENUM = 1).
  COMPUTE DemandState='High'.
  COMPUTE StateProbability=.30.
  COMPUTE LargePayoff=12.
  COMPUTE ModularPayoff=9.
* Alternative condition inside a DO IF block.
ELSE IF ($CASENUM = 2).
  COMPUTE DemandState='Medium'.
  COMPUTE StateProbability=.50.
  COMPUTE LargePayoff=3.
  COMPUTE ModularPayoff=5.
ELSE.
  COMPUTE DemandState='Low'.
  COMPUTE StateProbability=.20.
  COMPUTE LargePayoff=-9.
  COMPUTE ModularPayoff=1.
* Close the DO IF block.
END IF.
* Create or overwrite a variable with a formula, row by row.
COMPUTE LargeWeighted=StateProbability*LargePayoff.
* Create or overwrite a variable with a formula, row by row.
COMPUTE ModularWeighted=StateProbability*ModularPayoff.
* Collapse rows into group summaries (one row per group).
AGGREGATE
  /OUTFILE=* MODE=ADDVARIABLES
  /ProbabilityTotal=SUM(StateProbability)
  /LargeHubEMV=SUM(LargeWeighted)
  /ModularHubEMV=SUM(ModularWeighted).
* Create or overwrite a variable with a formula, row by row.
COMPUTE RolledBackValue=MAX(LargeHubEMV,ModularHubEMV).
* Set how values display (width and decimals); the stored values do not change.
FORMATS StateProbability ProbabilityTotal (F5.3)
  LargePayoff ModularPayoff LargeHubEMV ModularHubEMV RolledBackValue (F8.2).
* Make the next transformation apply to the next procedure only.
TEMPORARY.
* Keep only the rows that meet the condition (others are deleted).
SELECT IF ($CASENUM=1).
* Print the listed variables row by row.
LIST VARIABLES=ProbabilityTotal LargeHubEMV ModularHubEMV RolledBackValue.
* Close a dataset you no longer need.
DATASET CLOSE CapacityAudit.
* Switch to the named dataset; the next commands work on it.
DATASET ACTIVATE CohortData.

* %% .

* Lecture connection: Monte Carlo Simulation Engine .
* Why: Reproduce the in-class demand and profit summaries from shared reference probabilities .
* How: IDF.NORMAL transforms fixed u_001 values using mean 1,000 and standard deviation 250 .
* How: A temporary sorted copy uses h=1+(n-1)p and linear interpolation for the inclusive percentile .
* Read the result: Read mean profit, sample standard deviation, inclusive fifth percentile and numeric trial count .
* Watch out: Do not substitute random draws or SPSS default percentile definitions for the fixed inputs .
* Run: Select the complete H3 block, including the reference import .
* Run: Choose Run > Selection .
* Run: Locate H3 Reference Profit Summary and inspect the listed summary .
TITLE 'H3 Reference Profit Summary'.
* Read the data file into SPSS (file type, name, and each variable's format).
GET DATA
  /TYPE=TXT
  /FILE='reference_trials.csv'
  /ENCODING='UTF8'
  /ARRANGEMENT=DELIMITED
  /FIRSTCASE=2
  /DELCASE=LINE
  /DELIMITERS=','
  /QUALIFIER='"'
  /VARIABLES=
    trial F10.0
    u_001 F20.16.
* Keep a working copy in memory so later passes are fast.
CACHE.
* Run the pending transformations now.
EXECUTE.
* Give the open dataset a name so later commands can point to it.
DATASET NAME ReferenceTrials.
* Create or overwrite a variable with a formula, row by row.
COMPUTE ValidU=0.
* Compute a value only for rows that meet the condition.
IF (NOT MISSING(u_001) AND u_001 > 0 AND u_001 < 1) ValidU=1.
* Compute a value only for rows that meet the condition.
IF (ValidU=1) SimDemand=IDF.NORMAL(u_001,1000,250).
* Compute a value only for rows that meet the condition.
IF (ValidU=1) SimProfit=MIN(SimDemand,1000)*100+MAX(1000-SimDemand,0)*15-1000*40.
* Run the pending transformations now.
EXECUTE.
* Make a working copy so the original data stay untouched.
DATASET COPY ProfitSummary.
* Switch to the named dataset; the next commands work on it.
DATASET ACTIVATE ProfitSummary.
* Create or overwrite a variable with a formula, row by row.
COMPUTE ValidProfit=NOT MISSING(SimProfit).
* Sort the rows by the listed variables.
SORT CASES BY ValidProfit(D) SimProfit(A).
* Collapse rows into group summaries (one row per group).
AGGREGATE
  /OUTFILE=* MODE=ADDVARIABLES
  /NTrials=N(SimProfit)
  /MeanProfit=MEAN(SimProfit)
  /SDProfit=SD(SimProfit).
* Create or overwrite a variable with a formula, row by row.
COMPUTE Rank5=$SYSMIS.
* Create or overwrite a variable with a formula, row by row.
COMPUTE LowerRank=$SYSMIS.
* Create or overwrite a variable with a formula, row by row.
COMPUTE UpperRank=$SYSMIS.
* Start a block of commands that run only when the condition is true.
DO IF (NTrials > 0).
  COMPUTE Rank5=1+(NTrials-1)*.05.
  COMPUTE LowerRank=TRUNC(Rank5).
  COMPUTE UpperRank=MIN(LowerRank+1,NTrials).
* Close the DO IF block.
END IF.
* Create or overwrite a variable with a formula, row by row.
COMPUTE P5LowCell=$SYSMIS.
* Create or overwrite a variable with a formula, row by row.
COMPUTE P5HighCell=$SYSMIS.
* Compute a value only for rows that meet the condition.
IF (NTrials > 0 AND $CASENUM=LowerRank) P5LowCell=SimProfit.
* Compute a value only for rows that meet the condition.
IF (NTrials > 0 AND $CASENUM=UpperRank) P5HighCell=SimProfit.
* Collapse rows into group summaries (one row per group).
AGGREGATE
  /OUTFILE=* MODE=ADDVARIABLES
  /P5Low=MAX(P5LowCell)
  /P5High=MAX(P5HighCell).
* Create or overwrite a variable with a formula, row by row.
COMPUTE P5Profit=$SYSMIS.
* Compute a value only for rows that meet the condition.
IF (NTrials > 0) P5Profit=P5Low+(Rank5-LowerRank)*(P5High-P5Low).
* Set how values display (width and decimals); the stored values do not change.
FORMATS MeanProfit SDProfit P5Profit (DOLLAR14.2) NTrials (F8.0).
* Make the next transformation apply to the next procedure only.
TEMPORARY.
* Keep only the rows that meet the condition (others are deleted).
SELECT IF ($CASENUM=1).
* Print the listed variables row by row.
LIST VARIABLES=MeanProfit SDProfit P5Profit NTrials.
* Close a dataset you no longer need.
DATASET CLOSE ProfitSummary.
* Switch to the named dataset; the next commands work on it.
DATASET ACTIVATE ReferenceTrials.

* %% .

* Lecture connection: Downside Risk and Shortfall Probability .
* Why: Demonstrate a shortfall numerator and numeric denominator with the in-class profit trials .
* How: LossFlag identifies profit below zero .
* How: The sum of flags is divided by the numeric profit count .
* Read the result: Read the shortfall count, trial denominator and stored loss fraction .
* Watch out: Do not include missing outcomes in the denominator .
* Run: Run H3 before selecting the complete H4 block .
* Run: Choose Run > Selection .
* Run: Locate H4 Applied Downside Check in the Viewer .
TITLE 'H4 Applied Downside Check'.
* Create or overwrite a variable with a formula, row by row.
COMPUTE LossFlag=(SimProfit < 0).
* Collapse rows into group summaries (one row per group).
AGGREGATE
  /OUTFILE=* MODE=ADDVARIABLES
  /ShortfallCount=SUM(LossFlag)
  /NumericDenominator=N(SimProfit).
* Create or overwrite a variable with a formula, row by row.
COMPUTE ShortfallProbability=ShortfallCount/NumericDenominator.
* Set how values display (width and decimals); the stored values do not change.
FORMATS ShortfallCount NumericDenominator (F8.0) ShortfallProbability (PCT6.1).
* Make the next transformation apply to the next procedure only.
TEMPORARY.
* Keep only the rows that meet the condition (others are deleted).
SELECT IF ($CASENUM=1).
* Print the listed variables row by row.
LIST VARIABLES=ShortfallCount NumericDenominator ShortfallProbability.
