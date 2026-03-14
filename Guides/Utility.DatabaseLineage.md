# Database Lineage Tracking

A set of tables, views, and stored procedures to help you understand your database dependencies.

This tracking will not capture 100% of your system dependencies, but it will quickly establish a lot of trackign you don't have recorded.

Things it won't work with:
- MS DB prior to 2016 - though I can work on it if you have a demand.
- Dynamic SQL. But what does?
- Spaces in table names - Why would you even?
- Meta data driven loads - Working on it!

## Step 1 - Create!

### Tables
- Create the 'Utility' Schema if does not already exist.
- Create Utility.LNG_ObjectList - Stores a list of all objects.
- Create Utility.LNG_ObjectExclusions - A place to record tables you want ignored from dependency mapping. e.g. Log Tables
- Create Utility.LNG_DatabaseExclusions  - A place to list objects you want exclued from lineage tracking.
- #POSSIBLE ACTION REQUIRED# Create Utility.LNG_DynamicMerge - #If# you have a dynamic Source -> Process -> Target updating/merging, you need to enter those values into this table.
- Create Utility.LNG_ObjectDefinitions - lists all the object definitions. Useful for obtaining DDL values.
- Create Utility.LNG_ObjectExpressionDependency - Stored the output from sys.sql_expression_dependencies that can be used for lineage.
- Create Utility.LNG_ObjectParsedDependency - Stored all the identified operations that occur, with a source and target.
- Create Utility.LNG_ObjectDirectDependency  - Lists all Source and Target objects.
- Create Utility.LNG_ObjectExtendedDependency - Stores each object, and lists the upstream and downstream dependencies
- Create Utility.LNG_ObjectExtendedDependencyLimit - Stores a list of objects where the downstread dependency reaches your desired limit.

### Stored Procedures for Generating Objects
- Create Utility.LNG_loadObjectList - Loads LNG_ObjectList. - You need to load the @UtilitySchemaDatabase variable with your database name.
- Create Utility.LNG_loadObjectDefinitions - Loads LNG_ObjectDefinitions
- Create Utility.LNG_updateObjectDefinitions_RemoveComments - Removes all the commented codes from LNG_ObjectDefintions. Ensures no commented out values are returned.
- Create Utility.LNG_updateObjectDefinitions_RemoveWhitespace - Removes carriage returns, tabs, and double spaces in order to make reading the definition easier.
- Create Utility.LNG_loadObjec]tExpressionDependency - loads LNG_ObjectExpressionDependency.
- Create Utility.LNG_loadObjectParsedDependency - loads LNG_ObjectParsedDependency
- Create Utility.LNG_updateObjectParsedDependency_ObjectCleanse - Updates LNG_ObjectParsedDependency
- Create Utility.LNG_loadObjectDirectDependency - Loads LNG_ObjectDirectDependency.
- Create Utility.LNG_updateObjectExtendedDependency - Loads LNG_ObjectExtendedDependency.


### ENTIRELY OPTIONAL - Views
- Create Utility.LNG_vwObjectSummary - Summarises the dependencies for each object.
- Create Utility.LNG_vwObjectCircularDependency - Lists the circular dependencies.
- Create Utility.LNG_vwObjectOrphaned - Lists objects without any upstream or downstream dependencies.

### Batch procedurer to run the Lineage Process
- Create Utility.LNG_batchFullLoad


## Step 2 - Populate!

Exec LNG_batchFullLoad

### ENTIRELY OPTIONAL - Stored Procedures for enhanced querying and modifying tables
- Create Utility.LNG_outputObjectDependency - Gets all dependencies for a specific object.
- Create Utility.LNG_outputImpactAnalysis - Gets impact analysis for a specific object.
- Create Utility.LNG_outputCrossDatabaseDependency - Gets all cross server dependencies.
- Create Utility.LNG_updateDatabaseExclusionsAddDefaults - Adds in the MS DB objects you probably don't need to track.
- Create Utility.LNG_updateDatabaseExclusionsAdd - Inserts values into LineageObjectExclusions.
- Create Utility.LNG_updateDatabaseExclusionsRemove - Removes values from LineageObjectExclusions.
- Create Utility.LNG_outputDatabaseExclusions - View all values in LineageDatabaseExclusions.
- Create Utility.LNG_updateObjectExclusionsAdd - Add Objects to LineageDatabaseExclusions.
- Create Utility.LNG_updateObjectExclusionsRemove - Remove Objects from LineageDatabaseExclusions.
- Create Utility.LNG_outputObjectExclusions - View all objects in outputLineageObjectExclusions.
- Create Utility.LNG_outputDependencyTree - Dependency Tree as a hierarchical output


## Step 3 - Schedule!

I recommend you run this manually to see how long it takes for your database.

Make sure to run on a regular basis to keep your lineage tracking up to date!