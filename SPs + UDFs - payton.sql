--'FetchFollowing' means fetch the users that @userId follows.
CREATE OR ALTER PROCEDURE Chat.FetchFollowing
	@userHandle NVARCHAR(30),
	@page INT
AS
DECLARE @userId INT = (SELECT U.userId FROM Chat.[User] U WHERE U.handle = @userHandle);
SELECT U.[name] AS userName,
	U.handle AS userHandle,
	I.imageUrl AS userImage,
	U.bio AS userBio
FROM Chat.[User] U 
	INNER JOIN Chat.Follower F ON @userId = F.followerUserId
		AND U.userId = F.followedUserId
	INNER JOIN Chat.[Image] I ON U.imageId = I.imageId
ORDER BY F.followDate DESC
OFFSET (@page * 20) ROWS FETCH NEXT 20 ROWS ONLY
GO

--'FetchFollowers' means fetch the users that follow @userId.
CREATE OR ALTER PROCEDURE Chat.FetchFollowers
	@userHandle NVARCHAR(30),
	@page INT
AS
DECLARE @userId INT = (SELECT U.userId FROM Chat.[User] U WHERE U.handle = @userHandle);
SELECT U.[name] AS userName,
	U.handle AS userHandle,
	I.imageUrl AS userImage,
	U.bio AS userBio
FROM Chat.[User] U 
	INNER JOIN Chat.Follower F ON @userId = F.followedUserId
		AND U.userId = F.followerUserId
	INNER JOIN Chat.[Image] I ON U.imageId = I.imageId
ORDER BY F.followDate DESC
OFFSET (@page * 20) ROWS FETCH NEXT 20 ROWS ONLY
GO

SELECT *
FROM Chat.FetchFollowers(5, 0);

SELECT *
FROM Chat.FetchFollowing(5, 0);

SELECT *
FROM Chat.Follower;

SELECT U.[name], U.userId
FROM Chat.[User] U 
WHERE U.userId = 2;
