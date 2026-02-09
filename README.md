# Why?

These are SQL Tools for when you only have MSSQL available. Not as uncommon as you would like.

Hopefully this repo will be useful for you if you are TSQL bound.

There's more coming, so stay tuned!

## Object Profile

_Find out stuff about tables on your DB_

Stored procedure dbo.reportObjectDataProfile provides a summary of each column in a table.

the larger your object is, the longer it will take so be careful.  You probably don't want to do this over a billion rows. 
  
EXEC dbo.reportObjectDataProfile 'DB.Schema.Object' and you will find out a bunch of details about every field. 

## Date & Time Stuff

### Time
 - Run the Create table script Tables\DimTime
 - Run the stored procedure for DimTime.
   
 You now have a DimTime you never need to touch again!

 ### Date
 - Load your public holidays into  dbo.PublicHoliday. An example load file is provided (WA Public Holidays Insert Script.sql)
     - DimDate_SK = the date in YYYYMMDD
     - PublicHolidayType = The Group it falls into, I have used AustraliaWA as a demo.
     - PublicHolidayName = The name of the public holiday.
     - PublicHolidaySubstitute = If the public holiday is a substitute. e.g. a Monday is set to 1 because the public holiday was on a Sunday the day before.
     - CountBusinessDays = setting this field to 1 will create a column in your dimdate that calculates Business Days based on a PublicHoldidayType.
       The more PublicHolidayTypes that have this set to 1, the longer dimDate takes to update each day.
       
      **You can update this at any time, but when you add new public holiday types, You will need to drop and recreate DimDate**

  - Run the Create table script Tables\DimDate for the first time.
  
  - Execute dbo.loadDimDate after updating these variables in the script:
    - @FiscalYearStartMMDD = The Month and Day your financial year starts.
    - @MinimumDate = The minimum date in your dimdate.
    - @MaximumDate = The Maximum date in your dimdate.
    - @UTCOffsetMinutes = I want to run this each day according to perth time, so when I execute just after midnight, it will update all the relative dates correctly.

**Run LoadDimDate once each day. All relative dates will update, while the keys remain the same.**



More to come! I swear!
