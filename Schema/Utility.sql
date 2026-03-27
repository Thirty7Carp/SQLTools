-- Create Utility schema if it doesn't exist
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Utility')
BEGIN
    EXEC('CREATE SCHEMA Utility');
END
GO
