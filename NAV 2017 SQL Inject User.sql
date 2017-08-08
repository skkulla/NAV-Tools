SET NOCOUNT ON
GO



DECLARE @UserID varchar(100)
SET @UserID = 'ARCHER\SKULLA'  -- Windows Login you want to add

-- Get security identifier (SID) for specified user.  Login must be setup in SQL Server first.
DECLARE @BinarySID binary(100)
SELECT @BinarySID = sid FROM sys.syslogins WHERE name = @UserID

IF @BinarySID IS NULL
  RAISERROR('SQL Server login not found for User %s.', 10, 1, @UserID)

-- SID is stored in the User table as a formatted string.  Need to convert it.
DECLARE @StringSID varchar(238)
DECLARE @i AS int
DECLARE @j AS int
DECLARE @Grp AS int

SELECT @StringSID = 'S-'
    + CONVERT(VARCHAR, CONVERT(INT, CONVERT(VARBINARY, SUBSTRING(@BinarySID, 1, 1))))
SELECT @StringSID = @StringSID + '-'
    + CONVERT(VARCHAR, CONVERT(INT, CONVERT(VARBINARY, SUBSTRING(@BinarySID, 3, 6))))

SET @j = 9
SET @i = LEN(@BinarySID)
SET @Grp = 1

WHILE (@j < @i) AND (@Grp <= 5) BEGIN
  SET @Grp = @Grp + 1

  DECLARE @val BINARY(4)
  SELECT @val = SUBSTRING(@BinarySID, @j, 4)

  SELECT @StringSID = @StringSID + '-'
    + CONVERT(VARCHAR, CONVERT(BIGINT, CONVERT(VARBINARY, REVERSE(CONVERT(VARBINARY, @val)))))
  SET @j = @j + 4 
END

-- Check to see if User record already exists
DECLARE @UserGUID uniqueidentifier

SELECT @UserGUID = [User Security ID]
FROM [User] WHERE [Windows Security ID] = @StringSID

IF @UserGUID IS NOT NULL
  PRINT 'User ID ' + @UserID + ' already exists in User table.'
 
ELSE BEGIN
  -- Generate new GUID for NAV security ID
  SET @UserGUID = NEWID()
 
  -- Create User record
  INSERT INTO [User]
  ([User Security ID], [User Name], [Full Name], [State], [Expiry Date], [Windows Security ID], [Change Password],[License Type], [Authentication Email],
  [Application ID],[Contact Email],[Exchange Identifier])
  VALUES(@UserGUID, @UserID, '', 0, '1/1/1753', @StringSID, 0, 0,'',NEWID(),'','') 

  PRINT 'Created User record for User ID ' + @UserID + '. - ' + CAST(@@ROWCOUNT AS varchar) + ' row(s) affected.'
END

-- Check to see if user is assigned to SUPER role 
IF EXISTS(SELECT * FROM [Access Control] WHERE [User Security ID] = @UserGUID AND [Role ID] = 'SUPER' AND [Company Name] = '')
  PRINT 'User ID ' + @UserID + ' is already assigned to SUPER role.'
 
ELSE BEGIN 
  -- Create Access Control record to add user to SUPER role
  INSERT INTO [Access Control]
  ([User Security ID], [Role ID], [Company Name], [App ID], [Scope])
  VALUES(@UserGUID, 'SUPER', '',NEWID(),0)

  PRINT 'Added User ID ' + @UserID + ' to SUPER role. - ' + CAST(@@ROWCOUNT AS varchar) + ' row(s) affected.'
END

-- User Property record required to allow login
IF EXISTS(SELECT * FROM [User Property] WHERE [User Security ID] = @UserGUID)
  PRINT 'User Property record already exists for User ID ' + @UserID + '.'
 
ELSE BEGIN
  INSERT INTO [User Property]
  ([User Security ID], [Password], [Name Identifier], [Authentication Key], [WebServices Key], [WebServices Key Expiry Date], [Authentication Object ID])
  VALUES(@UserGUID, '', '', '', '', '1/1/1753','')

  PRINT 'Created User Property record for User ID ' + @UserID + '. - ' +  CAST(@@ROWCOUNT AS varchar) + ' row(s) affected.'
END

SET NOCOUNT OFF
GO
