USE ChatApplication
GO

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

--@userId is the user who is viewing the page.
CREATE OR ALTER FUNCTION Chat.FetchPostComments (
	@postId INT,
	@userId INT,
	@page INT
)
RETURNS TABLE
AS
RETURN
	SELECT U.[name] AS userName,
		U.handle AS userHandle,
		I.imageUrl AS userImage,
		P.postId,
		P.content,
		COUNT(DISTINCT L.userId) AS likeCount,
		COUNT(DISTINCT P2.postId) AS commentCount,
		Chat.FetchImages(P.postId) AS imageUrls,
		IIF(L2.userId IS NULL, 0, 1) AS isLiked,
		P.createdOn
	FROM Chat.Post P
		LEFT JOIN Chat.[Like] L ON P.postId = L.postId
		LEFT JOIN Chat.Post P2 ON P.postId = P2.replyToPostId
		INNER JOIN Chat.[User] U ON P.userId = U.userId
		INNER JOIN Chat.[Image] I ON U.imageId = I.imageId
		LEFT JOIN Chat.[Like] L2 ON @userId = L2.userId
			AND P.postId = L2.postId
	WHERE P.replyToPostId = @postId 
		OR P.postId = @postId
	GROUP BY U.[name], U.handle, I.imageUrl, P.postId, P.content, L2.userId, P.createdOn
	ORDER BY P.postId
	OFFSET (@page * 15) ROWS FETCH NEXT 15 ROWS ONLY
GO

CREATE OR ALTER PROCEDURE Chat.FetchUserProfile
	@userHandle NVARCHAR(30)
AS
DECLARE @userId INT = (SELECT U.userId FROM Chat.[User] U WHERE U.handle = @userHandle);
SELECT I.imageUrl AS userImage,
	U.[name] AS userName,
	U.bio,
	U.createdDate,
	U.ethereumAddress,
	COUNT(DISTINCT F.followerUserId) AS followerCount,
	COUNT(DISTINCT F2.followedUserId) AS followingCount,
	(
		SELECT P.postId,
			P.content,
			COUNT(DISTINCT L.userId) AS likeCount,
			COUNT(DISTINCT P2.postId) AS commentCount,
			Chat.FetchImages(P.postId) AS imageUrls,
			P.createdOn,
			IIF(L2.userId IS NULL, 0, 1) AS isLiked
		FROM Chat.Post P
			LEFT JOIN Chat.[Like] L ON P.postId = L.postId
			LEFT JOIN Chat.Post P2 ON P.postId = P2.replyToPostId
			LEFT JOIN Chat.[Like] L2 ON P.postId = L2.postId
				AND L2.userId = @userId
		WHERE P.userId = @userId
		GROUP BY P.postId, P.content, P.createdOn, L2.userId
		FOR JSON PATH
	) AS posts
	FROM Chat.[User] U
		LEFT JOIN Chat.Follower F ON U.userId = F.followedUserId
		LEFT JOIN Chat.Follower F2 ON U.userId = F2.followerUserId
		INNER JOIN Chat.[Image] I ON U.imageId = I.imageId
	WHERE U.userId = @userId
	GROUP BY I.imageUrl, U.[name], U.bio, U.createdDate, U.ethereumAddress
GO

EXEC Chat.FetchFollowing 'rhyams1', 0

EXEC Chat.FetchFollowers 'rhyams1', 0

EXEC Chat.FetchUserProfile 'kscogings0'

SELECT *
FROM Chat.FetchPostComments(1, 1, 0)

SELECT *
FROM Chat.Post P
WHERE P.replyToPostId IS NULL

SELECT *
FROM Chat.Follower;

SELECT U.[name], U.userId, U.handle
FROM Chat.[User] U 
WHERE U.userId = 1;
