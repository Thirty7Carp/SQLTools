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
- Create Utility.LineageObjectList - Stores a list of all objects.
- Create Utility.LineageObjectExclusions - A place to record tables you want ignored from dependency mapping. e.g. Log Tables
- Create Utility.LineageDatabaseExclusions  - A place to list objects you want exclued from lineage tracking.
- #POSSIBLE ACTION REQUIRED# Create Utility.DynamicMerge - #If# you have a dynamic Source -> Process -> Target updating/merging, you need to enter those values into this table.
- Create Utility.LineageObjectDefinitions - lists all the object definitions. Useful for obtaining DDL values.
- Create Utility.loadLineageObjectExpressionDependency - Stored the output from sys.sql_expression_dependencies that can be used for lineage.
- Create Utility.LineageObjectParsedDependency - Stored all the identified operations that occur, with a source and target.
- Create Utility.updateLineageObjectParsedDependency_ObjectCleanse - Remove objects identified that are not DB objects, dedupe results, switch around source and targets for Select and Execute. 
- Create Utility.LineageObjectDirectDependency  - Lists all Source and Target objects.
- Create Utility.LineageObjectExtendedDependency - Stores each object, and lists the upstream and downstream dependencies
- Create Utility.LineageObjectExtendedDependencyLimit - Stores a list of objects where the downstread dependency reaches your desired limit.

### Stored Procedures for Generating Objects
- Create Utility.loadLineageObjectList - Loads LineageObjectList.
- Create Utility.loadLineageObjectDefinitions - Loads LineageObjectDefinitions
- Create Utility.updateLineageObjectDefinitions_RemoveComments - Removes all the commented codes from LineageObjectDefintions. Ensures no commented out values are returned.
- Create Utility.updateLineageObjectDefinitions_RemoveWhitespace - Removes carriage returns, tabs, and double spaces in order to make reading the defintion easier.
- Create Utility.loadLineageObjec]tExpressionDependency - populates LineageObjectExpressionDependency.
- Create Utility.loadLineageObjectParsedDependency - populates LineageObjectParsedDependency
- Create Utility.updateLineageObjectParsedDependency_ObjectCleanse - Updates LineageObjectParsedDependency
- Create Utility.loadLineageObjectDirectDependency - Loads LineageObjectDirectDependency.
- Create Utility.updateLineageObjectExtendedDependency - Loads LineageObjectExtendedDependency.


### ENTIRELY OPTIONAL - Views
- Create vwLineageObjectSummary - Summarises the dependencies for each object.
- Create vwLineageObjectCircularDependency - Lists the circular dependencies.
- Create vwLineageObjectOrphaned - Lists objects without any upstream or downstream dependencies.

### ENTIRELY OPTIONAL - Stored Procedures for enhanced querying and modifying tables
- Create outputLineageObjectDependency - Gets all dependencies for a specific object.
- Create outputLineageImpactAnalysis - Gets impact analysis for a specific object.
- Create outputLineageCrossDatabaseDependency - Gets all cross server dependencies.
- Create updateLineageDatabaseExclusionsAddDefaults - Adds in the MS DB objects you probably don't need to track.
- Create updateLineageDatabaseExclusionsAdd - Inserts values into LineageObjectExclusions.
- Create updateLineageDatabaseExclusionsRemove - Removes values from LineageObjectExclusions.
- Create outputLineageDatabaseExclusions - View all values in LineageDatabaseExclusions.
- Create updateLineageObjectExclusionsAdd - Add Objects to LineageDatabaseExclusions.
- Create updateLineageObjectExclusionsRemove - Remove Objects from LineageDatabaseExclusions.
- Create outputLineageObjectExclusions - View all objects in outputLineageObjectExclusions.
- Create outputLineageDependencyTree - Dependency Tree as a hierarchical output

### Batch procedurer to run the Lineage Process
- Create batchLineageAnalysis


## Step 2 - Populate!

Exec batchLineageAnalysis

## Step 3 - Schedule!

I recommend you run this manually to see how long it takes for your database.

Make sure to run on a regular basis to keep your lineage tracking up to date!