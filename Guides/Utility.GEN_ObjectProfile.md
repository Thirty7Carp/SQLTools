# Object Profile

_Find out stuff about tables on your DB_

Stored procedure Utility.GEN_outputObjectDataProfile provides a summary of each column in one table.

the larger your object is, the longer it will take so be careful.  

You probably don't want to do this over a few million rows. 
  
EXEC Utility.GEN_outputObjectDataProfile 'DB.Schema.Object' and you will find out a bunch of details about every field. 
