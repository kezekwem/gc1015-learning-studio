* MASY1-GC1015 Lab 01: student SPSS workflow.
* Keep this syntax file and Session 01 - Analysis Practice Workbook.xlsx
* in the same working folder before running the commands.
* Both Excel and SPSS use the workbook's Data sheet as the authoritative dataset.

PRESERVE.
SET DECIMAL DOT.

GET DATA
  /TYPE=XLSX
  /FILE='Session 01 - Analysis Practice Workbook.xlsx'
  /SHEET=name 'Data'
  /CELLRANGE=FULL
  /READNAMES=ON.

DATASET NAME MetroFreshLab01 WINDOW=FRONT.

FORMATS
  items_ordered items_unfulfilled delivery_minutes spoilage_units customer_rating (F8.0)
  order_value (F10.2).

VARIABLE LABELS
  delivery_minutes 'Elapsed minutes from dispatch to delivery'
  order_value 'Recorded order value in U.S. dollars'
  spoilage_units 'Units written off as spoiled'.

VARIABLE LEVEL
  order_id customer_id fulfillment_hub product_category (NOMINAL)
  supplier_tier customer_rating (ORDINAL)
  items_ordered items_unfulfilled delivery_minutes order_value spoilage_units (SCALE).

EXECUTE.

* Required cross-tool output: N, mean, sample standard deviation, minimum, maximum.
DESCRIPTIVES VARIABLES=delivery_minutes order_value spoilage_units
  /STATISTICS=MEAN STDDEV MIN MAX.

* Save the Output Viewer through File > Save As using this example:
* Lab01_Jane_Doe_jd1234_SPSS.spv

RESTORE.
