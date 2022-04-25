CREATE TABLE Customer (
    Id int IDENTITY(1,1) PRIMARY KEY,
    FirstName varchar(255) NOT NULL,
    LastName varchar(255),
    [Status] int DEFAULT 0,
    [timestamp] datetime DEFAULT GETDATE()
)