/*
No Cross Server Sorry.

Object Creation:
	ObjectAll - Script out all the objects names
	ObjectColumns - Stores named segments and the object ID for each object in Object All
	ObjectDefinition - Stores all the definitions for objects on SQL DB
	ObjectFullLinage - Stores a "Full Lineage" which looks at every object, then traces where it ends up on the server.
	ObjectFullLinageSkippedObjects - Stores a list of objects that were skipped from lineage due to recursion limit being hit
	ObjectToObjectByProcess - Creates a list of Source Object, process, Target Object. Also stores the defintions of just source and Target for views.

Run Steps
	LoadObjectAll - Update the list of DBs to exclude - Create Then Run
	LoadObjectColumns - Set the @ObjectLoggingDatabase to the database where your logging objects are stored. Create then Run.
	LoadObjectDefinitions - Create and Run
	LoadForeignKeyDefinitions - Create and Run
	updateObjectDefinitions_RemoveComments - Create and Run

*/


CREATE PROCEDURE dbo.loadObjectMetadata
AS
BEGIN
    SET NOCOUNT ON;

    -- Clear out old metadata
    TRUNCATE TABLE dbo.ObjectDefinitions;
    TRUNCATE TABLE dbo.ObjectAll;
	Truncate Table dbo.ObjectColumns;

    -- Reload metadata
    EXEC dbo.loadObjectAll;
	EXEC dbo.LoadObjectColumns;
    EXEC dbo.loadObjectDefinitions;
    EXEC dbo.loadForeignKeyDefinitions;
	EXEC dbo.updateObjectDefinitions_RemoveComments

END;


	/* Testing */
    select top 100 * from  dbo.ObjectAll;
	select top 100 * from  dbo.ObjectColumns; 
	select top 100 * from  dbo.ObjectDefinitions;