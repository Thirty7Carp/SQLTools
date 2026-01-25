CREATE PROCEDURE dbo.loadObjectMetadata
AS
BEGIN
    SET NOCOUNT ON;

    -- Clear out old metadata
    TRUNCATE TABLE dbo.ObjectDefinitions;
    TRUNCATE TABLE dbo.ObjectAll;

    -- Reload metadata
    EXEC dbo.loadObjectAll;
    EXEC dbo.loadObjectDefinitions;
    EXEC dbo.loadForeignKeyDefinitions;
END;
