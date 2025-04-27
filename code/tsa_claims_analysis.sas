/* ===========================================
   Set Library and Import Data
   =========================================== */

%let path=./data;
libname tsa "&path";

options validvarname=v7;

/* Import CSV file into SAS */
proc import datafile="&path/TSAClaims2002_2017.csv"
     dbms=csv
     out=tsa.claims_import
     replace;
     guessingrows=max;
run;

/* ===========================================
   Step 2: Explore and Preview Data
   =========================================== */

proc print data=tsa.claims_import (obs=10);
run;

proc contents data=tsa.claims_import varnum;
run;


/* ===========================================
   Step 3: Clean the Data
   =========================================== */

/* Step 3.1: Remove duplicate rows */
proc sort data=tsa.claims_import out=tsa.claims_nodups nodupkey;
    by _all_;
run;

/* Step 3.2: Sort data by ascending Incident_Date */
proc sort data=tsa.claims_nodups out=tsa.claims_sorted;
    by Incident_Date;
run;


/* ===========================================
   Step 4: Continue Cleaning - Fix Missing Values and Correct Text
   =========================================== */
data tsa.claims_cleaned;
    set tsa.claims_sorted;

    /* Fix missing or dash values */
    if Claim_Site in ('', '-') then Claim_Site = 'Unknown';
    if Claim_Type in ('', '-') then Claim_Type = 'Unknown';
    if Disposition in ('', '-') then Disposition = 'Unknown';

    /* Fix typos and inconsistencies */
    if Disposition = 'Closed: Canceled' then Disposition = 'Closed:Canceled';
    if Disposition = 'losed: Contractor Claim' then Disposition = 'Closed:Contractor Claim';

    if Claim_Type = 'Passenger Property Loss/Personal Injury' then Claim_Type = 'Passenger Property Loss';
    if Claim_Type = 'Property Damage/Personal Injury' then Claim_Type = 'Property Damage';

    /* Format state names */
    StateName = propcase(StateName);
    State = upcase(State);

    /* Create Date_Issues column */
    if (missing(Incident_Date) or missing(Date_Received)) or
       (year(Incident_Date) < 2002 or year(Incident_Date) > 2017) or
       (year(Date_Received) < 2002 or year(Date_Received) > 2017) or
       (Incident_Date > Date_Received) then Date_Issues = "Needs Review";

    /* Drop County and City columns */
    drop County City;

    /* Format Close_Amount as currency and dates properly */
    format Close_Amount dollar20.2 Incident_Date Date_Received date9.;

    /* Add labels */
    label Claim_Number = "Claim Number"
          Date_Received = "Date Received"
          Incident_Date = "Incident Date"
          Airport_Code = "Airport Code"
          Airport_Name = "Airport Name"
          Claim_Type = "Claim Type"
          Claim_Site = "Claim Site"
          Item_Category = "Item Category"
          Close_Amount = "Close Amount"
          Disposition = "Disposition"
          StateName = "State Name"
          State = "State"
          Date_Issues = "Date Issues";
run;


/* ===========================================
   Step 5: Analyze Overall Data
   =========================================== */

/* 5.1 How many Date Issues in the dataset? */
title "Overall Date Issues in the Data";
proc freq data=tsa.claims_cleaned;
    table Date_Issues / nocum nopercent;
run;
title;

/* 5.2 How many claims per year of Incident Date? (with a plot) */
ods graphics on;
title "Overall Claims by Year";
proc freq data=tsa.claims_cleaned;
    table Incident_Date / nocum nopercent plots=freqplot;
    where Date_Issues is missing;
    format Incident_Date year4.;
run;
ods graphics off;
title;


/* ===========================================
   Step 6: Analyze Data for a Specific State
   =========================================== */

/* Choose your state */
%let StateName = California;

/* Frequencies for Claim Type */
title "&StateName - Frequency of Claim Type";
proc freq data=tsa.claims_cleaned;
    tables Claim_Type / nocum nopercent;
    where StateName = "&StateName" and Date_Issues is missing;
run;

/* Frequencies for Claim Site */
title "&StateName - Frequency of Claim Site";
proc freq data=tsa.claims_cleaned;
    tables Claim_Site / nocum nopercent;
    where StateName = "&StateName" and Date_Issues is missing;
run;

/* Frequencies for Disposition */
title "&StateName - Frequency of Disposition";
proc freq data=tsa.claims_cleaned;
    tables Disposition / nocum nopercent;
    where StateName = "&StateName" and Date_Issues is missing;
run;

/* Summary Statistics for Close Amount */
title "&StateName - Close Amount Summary";
proc means data=tsa.claims_cleaned mean min max sum maxdec=0;
    var Close_Amount;
    where StateName = "&StateName" and Date_Issues is missing;
run;
title;


/* ===========================================
   Step 7: Export Results to a PDF Report
   =========================================== */

/* Set output path */
%let outpath=./output; /* Relative path to the 'output' folder */

/* Start PDF */
ods pdf file="&outpath/ClaimsReport.pdf" style=Meadow;

/* Overall Date Issues */
title "Overall Date Issues in the Data";
proc freq data=tsa.claims_cleaned;
    table Date_Issues / nocum nopercent;
run;
title;

/* Claims by Year */
ods graphics on;
title "Overall Claims by Year";
proc freq data=tsa.claims_cleaned;
    table Incident_Date / nocum nopercent plots=freqplot;
    where Date_Issues is missing;
    format Incident_Date year4.;
run;
ods graphics off;
title;

/* California Analysis (Dynamic State Analysis) */
%let StateName = California;

/* Claim Type */
title "&StateName - Frequency of Claim Type";
proc freq data=tsa.claims_cleaned;
    tables Claim_Type / nocum nopercent;
    where StateName = "&StateName" and Date_Issues is missing;
run;

/* Claim Site */
title "&StateName - Frequency of Claim Site";
proc freq data=tsa.claims_cleaned;
    tables Claim_Site / nocum nopercent;
    where StateName = "&StateName" and Date_Issues is missing;
run;

/* Disposition */
title "&StateName - Frequency of Disposition";
proc freq data=tsa.claims_cleaned;
    tables Disposition / nocum nopercent;
    where StateName = "&StateName" and Date_Issues is missing;
run;

/* Close Amount Summary */
title "&StateName - Close Amount Summary";
proc means data=tsa.claims_cleaned mean min max sum maxdec=0;
    var Close_Amount;
    where StateName = "&StateName" and Date_Issues is missing;
run;
title;

/* Close PDF */
ods pdf close;
