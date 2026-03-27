-- Create Utility schema if it doesn't exist
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Common')
BEGIN
    EXEC('CREATE SCHEMA Common');
END
GO
