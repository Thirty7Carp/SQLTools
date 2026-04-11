# Dynamic Merge

A set of tables, triggers, and stored procedures to perform metadata-driven merging across SCD types.

Built with data warehouse engineers in mind for when:
- You need a consistent, repeatable merge pattern across multiple tables.
- You want to manage merge behaviour through configuration rather than code.
- You need to support multiple SCD types without writing bespoke merge logic for each.

## How It Works

Merge behaviour is driven entirely by configuration stored in `Utility.MRG_DynamicMergeConfiguration`. Each row in this table defines a single merge job — the source, the target, the columns to merge on, and the SCD type to apply.

A trigger on the configuration table validates all entries on insert or update, resolving any unspecified warehouse meta column names against the defaults table `Utility.MRG_DynamicMergeConfigurationDefaults`.

Once a configuration row exists, you execute the appropriate merge procedure for its SCD type, passing the configuration name.

## Step 1 - Configure

### Tables
- Create the `Utility` schema if it does not already exist.
- Create `Utility.MRG_DynamicMergeConfigurationDefaults` - Stores global default warehouse meta column names. Only one row can ever exist.
- Create `Utility.MRG_DynamicMergeConfiguration` - Stores one row per merge job. Validated on insert and update by trigger.

### Triggers
- Create `Utility.MRG_triggerDynamicMergeConfiguration_Upsert` - Fires on insert and update of `Utility.MRG_DynamicMergeConfiguration`. Validates source and target objects, merge columns, warehouse meta columns, and resolves defaults.

### Stored Procedures

#### Active
- Create `Utility.MRG_processSCD1` - Performs a dynamic SCD Type 1 merge.

#### In Development
- Create `Utility.MRG_processSCD2Date` - Performs a dynamic SCD Type 2 merge using date ranges.
- Create `Utility.MRG_processSCD2DateAndCurrent` - Performs a dynamic SCD Type 2 merge using date ranges and an IsCurrent flag.
- Create `Utility.MRG_processSCD2Version` - Performs a dynamic SCD Type 2 merge using version numbers.
- Create `Utility.MRG_processSCD4` - Performs a dynamic SCD Type 4 merge using a separate history table.

## Step 2 - Set Your Defaults

Before inserting any configuration rows, populate `Utility.MRG_DynamicMergeConfigurationDefaults` with your standard warehouse meta column names. These are used as fallbacks when a configuration row does not specify them explicitly.


You need to decide what you want your default column names and values should be to best support the naming conventions and time zone of your warehouse.
```sql
INSERT INTO Utility.MRG_DynamicMergeConfigurationDefaults
(
    WH_CreateDateColumnName
    , WH_ModifiedDateColumnName
    , WH_RowEffectiveDateColumnName
    , WH_RowExpirationDateColumnName
    , WH_RowExpirationDateValue
    , WH_VersionColumnName
    , WH_isCurrentColumnName
    , WH_isDeletedColumnName
    , WH_UTCOffset
)
/* These are my values */
VALUES
(
    'WH_CreateDate'
    , 'WH_ModifiedDate'
    , 'WH_RowEffectiveDate'
    , 'WH_RowExpirationDate'
    , '9999-12-31 00:00:00'
    , 'WH_Version'
    , 'WH_IsCurrent'
    , 'WH_IsDeleted'
    , 480 /* Go Perth! */
);
```

## Step 3 - Add a Configuration Row

Insert a row into `Utility.MRG_DynamicMergeConfiguration` for each merge job. The trigger will validate the configuration and resolve any unspecified warehouse meta column names against the defaults table.

The below is an example row.

```sql
INSERT INTO Utility.MRG_DynamicMergeConfiguration
(
    MergeConfigurationName
    , QualifiedSourceName
    , QualifiedTargetName
    , SCDType
    , MergeOnColumns
    , DeleteIfNotMatchedBySource
)
VALUES
(
    'Customer_SCD1'
    , 'SourceDB.dbo.Customer'
    , 'TargetDB.dbo.Customer'
    , 'SCD1'
    , 'CustomerID'
    , 0
);
```

## Step 4 - Run a Merge

Execute the appropriate stored procedure for the SCD type of your configuration row, passing the configuration name.

```sql
EXEC Utility.MRG_processSCD1
    @MergeConfigurationName = 'Customer_SCD1';
```

To preview the dynamic SQL without executing it, use debug mode.

```sql
EXEC Utility.MRG_processSCD1
    @MergeConfigurationName = 'Customer_SCD1'
    , @DebugMode = 1;
```

## Configuration Reference

The following table describes which fields are required, optional, or must be left blank for each SCD type. Fields marked as **Default** can be left blank if a value is configured in `Utility.MRG_DynamicMergeConfigurationDefaults`.

| Field | SCD1 (LIVE) | SCD2Date (DEV) | SCD2DateAndCurrent (DEV) | SCD2Version (DEV) | SCD4 (DEV) |
|---|---|---|---|---|---|
| `MergeConfigurationName` | Required | Required | Required | Required | Required |
| `QualifiedSourceName` | Required | Required | Required | Required | Required |
| `QualifiedTargetName` | Required | Required | Required | Required | Required |
| `QualifiedTargetHistoryName` | NULL | NULL | NULL | NULL | Required |
| `SCDType` | `SCD1` | `SCD2Date` | `SCD2DateAndCurrent` | `SCD2Version` | `SCD4` |
| `MergeOnColumns` | Required | Required | Required | Required | Required |
| `IgnoreColumns` | Optional | Optional | Optional | Optional | Optional |
| `DeleteIfNotMatchedBySource` | Required | Required | Required | Required | Required |
| `IgnoreIdentityColumns` | Optional | Optional | Optional | Optional | Optional |
| `WH_CreateDateColumnName` | Default | Default | Default | Default | Default |
| `WH_ModifiedDateColumnName` | Default | NULL | Default | NULL | NULL |
| `WH_RowEffectiveDateColumnName` | NULL | Default | Default | NULL | NULL |
| `WH_RowExpirationDateColumnName` | NULL | Default | Default | NULL | NULL |
| `WH_RowExpirationDateValue` | NULL | Default | Default | NULL | NULL |
| `WH_VersionColumnName` | NULL | NULL | NULL | Default | NULL |
| `WH_IsCurrentColumnName` | NULL | NULL | Default | Default | NULL |
| `WH_isDeletedColumnName` | NULL | Default | Default | Default | NULL |
| `WH_UTCOffset` | Optional | Optional | Optional | Optional | Optional |

**Required** — must be supplied on the configuration row.
**Default** — can be left blank if configured in `Utility.MRG_DynamicMergeConfigurationDefaults`.
**Optional** — can be left blank; behaviour is defined by the merge procedure.
**NULL** — must be left blank. The trigger will reject rows where this field is populated for the given SCD type.

## Notes

- `QualifiedSourceName`, `QualifiedTargetName`, and `QualifiedTargetHistoryName` must be in three-part format: `Database.Schema.Table`.
- `MergeOnColumns` and `IgnoreColumns` are comma-separated lists of column names.
- The trigger automatically adds all warehouse meta columns to `IgnoreColumns` if not already present.
- All string comparisons are case-insensitive.