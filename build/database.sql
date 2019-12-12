-- Drop the foreign keys
IF EXISTS
(
    SELECT *
FROM sys.foreign_keys
WHERE object_id = OBJECT_ID(N'FK__Table2_Table1')
    AND parent_object_id = OBJECT_ID(N'dbo.Table2')
)
    ALTER TABLE [dbo].[Table2] DROP CONSTRAINT [FK__Table2_Table1]

IF EXISTS
(
    SELECT *
FROM sys.foreign_keys
WHERE object_id = OBJECT_ID(N'FK__Table3_Table2')
    AND parent_object_id = OBJECT_ID(N'dbo.Table3')
)
    ALTER TABLE [dbo].[Table3] DROP CONSTRAINT [FK__Table3_Table2]
GO

-- Dropping tables
DROP TABLE IF EXISTS [dbo].[Table1];
DROP TABLE IF EXISTS [dbo].[Table2];
DROP TABLE IF EXISTS [dbo].[Table3];
GO

-- Dropping data types
DROP TYPE IF EXISTS [dbo].[DataType1];
DROP TYPE IF EXISTS [dbo].[DataType2];
DROP TYPE IF EXISTS [dbo].[DataType3];
GO

-- Dropping table types
DROP TYPE IF EXISTS [dbo].[TableType1];
DROP TYPE IF EXISTS [dbo].[TableType2];
GO

-- Create the tables
CREATE TABLE [dbo].[Table1]
(
    id INT NOT NULL,
    column1 VARCHAR(20) NOT NULL,
    column2 VARCHAR(30) NULL,
    column3 BIGINT NOT NULL,
    CONSTRAINT [PK_Table1]
        PRIMARY KEY (id)
);

CREATE TABLE [dbo].[Table2]
(
    id INT NOT NULL,
    column1 VARCHAR(20) NOT NULL,
    column2 VARCHAR(30) NULL,
    table1id INT NOT NULL,
    CONSTRAINT [PK_Table2]
        PRIMARY KEY (id),
    CONSTRAINT [FK__Table2_Table1]
        FOREIGN KEY (table1id)
        REFERENCES [dbo].[Table1] (id)
);

CREATE NONCLUSTERED INDEX [NIX__Table2_table1id]
ON [dbo].[Table2] (table1id);
GO

CREATE TABLE [dbo].[Table3]
(
    id INT NOT NULL,
    column1 VARCHAR(20) NOT NULL,
    column2 VARCHAR(30) NULL,
    table2id INT NOT NULL,
    CONSTRAINT [PK_Table3]
        PRIMARY KEY (id),
    CONSTRAINT [FK__Table3_Table2]
        FOREIGN KEY (table2id)
        REFERENCES [dbo].[Table2] (id)
);
GO

CREATE NONCLUSTERED INDEX [NIX__Table3_table2id]
ON [dbo].[Table3] (table2id);
GO

-- Creating data types
CREATE TYPE [dbo].[DataType1] FROM [BIGINT] NOT NULL;
CREATE TYPE [dbo].[DataType2] FROM [INT] NOT NULL;
CREATE TYPE [dbo].[DataType3] FROM [SMALLINT] NOT NULL;
GO

-- Creating table types
CREATE TYPE [dbo].[TableType1] AS TABLE
(
    [id] [VARCHAR](50) NOT NULL,
    [column1] [VARCHAR](30) NOT NULL,
    [column2] [VARCHAR](50) NULL
);

CREATE TYPE [dbo].[TableType2] AS TABLE
(
    [id] [VARCHAR](50) NOT NULL,
    [column1] [VARCHAR](30) NOT NULL,
    [column2] [VARCHAR](50) NULL
);
GO