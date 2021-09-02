/* Source: https://github.com/reubensultana/DBAScripts/blob/master/Audit+Security/MyEffectiveDatabasePermisisons.sql */

/* Retrieve Effective Database Permisisons */

EXECUTE AS USER='MyUser';
SELECT * FROM sts.fn_my_permissions(NULL, 'DATABASE')
ORDER BY [subentity_name], [permissions_name];
REVERT;
GO
