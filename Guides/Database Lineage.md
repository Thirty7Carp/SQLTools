# Database Lineage Tracking

A set of tables, views, and stored procedures to help you understand your database dependencies.

This tracking will not capture 100% of your system dependencies, but it will quickly establish a lot of trackign you don't have recorded.

Things it won't work with:
- MS DB prior to 2016 - though I can work on it if you have a demand.
- Meta data driven loads - Working on it!
- Dynamic SQL. But what does?

## Step 1 - Create!

### Tables
- Create the 'Utility' Schema if does not already exist.
- Create LineageObjectList - Stores a list of all objects.
- Create LineageObjectDirectDependency  - Lists all Source and Target objects.
- Create LineageObjectExtendedDependency - Stores each object, and lists the upstream and downstream dependencies
- Create LineageColumnDependency  - Provides a list of column dependencies.
- Create LineageObjectExclusions - A place to record tables you want ignored from dependency mapping. e.g. Log Tables
- Create LineageDatabaseExclusions  - A place to list objects you want exclued from lineage tracking.

### Stored Procedures for Generating Objects
- Create loadLineageObjectList - Loads LineageObjectList.
- Create loadLineageObjectDirectDependency - Loads LineageObjectDirectDependency.
- Create updateLineageObjectExtendedDependency - Loads LineageObjectExtendedDependency.
- Create loadLineageColumnDependency - Loads columns dependencies.

### Views
- Create vwLineageObjectSummary - Summarises the dependencies for each object.
- Create vwLineageObjectDirectDependency - Lists the direct dependencies.
- Create vwLineageObjectCircularDependency - Lists the circular dependencies.
- Create vwLineageObjectOrphaned - Lists objects without any upstream or downstream dependencies.

### Optional Stored Procedures for enhanced querying and modifying
- Create outputLineageObjectDependency - Gets all dependencies for a specific object.
- Create outputLineageImpactAnalysis - Gets impact analysis for a specific object.
- Create outputLineageCrossDatabaseDependency - Gets all cross server dependencies.
- Create updateLineageDatabaseExclusionsAddDefaults - Addes in the MS DB objects you probably don't need to track.
- Create updateLineageDatabaseExclusionsAdd - Inserts values into LineageObjectExclusions.
- Create updateLineageDatabaseExclusionsRemove - Removes values from LineageObjectExclusions.
- Create updateLineageObjectExclusionsAdd - Add Objects to LineageDatabaseExclusions.
- Create updateLineageObjectExclusionsRemove - Remove Objects from LineageDatabaseExclusions.
- Create outputLineageDatabaseExclusions - View all values in LineageDatabaseExclusions.
- Create outputLineageObjectExclusions - View all objects in outputLineageObjectExclusions.
- Create outputLineageColumnDependency - Object dependency for a single column.
- Create outputLineageColumnUsage - Lists all objects required to populate a single column
- Create outputLineageDependencyTree - Dependency Tree as a hierarchical output

### Batch procedurer to run the Lineage Process
- Create batchLineageAnalysis


## Step 2 - Populate!

Exec batchLineageAnalysis

## Step 3 - Schedule!

I recommend you run this manually to see how long it takes for your database.

Make sure to run on a regular basis to keep your lineage tracking up to date!