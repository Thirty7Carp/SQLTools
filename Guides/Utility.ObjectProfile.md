# Object Profile

_Find out stuff about tables on your DB_

Stored procedure Utility.outputObjectDataProfile provides a summary of each column in a table.

the larger your object is, the longer it will take so be careful.  

You probably don't want to do this over a billion rows. 
  
EXEC dbo.reportObjectDataProfile 'DB.Schema.Object' and you will find out a bunch of details about every field. 
