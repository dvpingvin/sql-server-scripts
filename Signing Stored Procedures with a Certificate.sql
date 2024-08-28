/* Step 1 - Create a certificate in the [master] database */
USE [master];
GO
CREATE CERTIFICATE TestCer
ENCRYPTION BY PASSWORD = '<strong_password>'
WITH SUBJECT = 'Execute stored procedurs with extended rights',
EXPIRY_DATE = '12/31/2025'; -- Error 3701 will occur if this date is not in the future
GO

/* Step 2 - Create a stored procedure and
sign it using the certificate */
CREATE PROCEDURE TestSP
AS
BEGIN
-- Shows who is running the stored procedure
SELECT SYSTEM_USER 'system Login'
, USER AS 'Database Login'
, NAME AS 'Context'
, TYPE
, USAGE
FROM sys.user_token;
END
GO

ADD SIGNATURE TO TestSP
BY CERTIFICATE TestCer
WITH PASSWORD = '<strong_password>';
GO

/* Step 3 - Create a login for the certificate.
This login has the ownership chain associated with it. */
USE [master];
GO
CREATE LOGIN TestAccount
FROM CERTIFICATE TestCer;
GO

/* Step 4 - Grant the login rights */
GRANT CONTROL SERVER
TO TestAccount;
GO

/* Step 5 - Grant EXECUTE to unprivileged User */
GRANT EXECUTE
ON TestSP
TO TestCreditRatingUser;
GO

ALTER CERTIFICATE TestCer REMOVE PRIVATE KEY
