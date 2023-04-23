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

--Fetche a user's profile
CREATE OR ALTER PROCEDURE Chat.FetchUserProfile
	@userHandle NVARCHAR(30)
AS
DECLARE @userId INT = (SELECT U.userId FROM Chat.[User] U WHERE U.handle = @userHandle);
SELECT I.imageUrl AS userImage,
	U.[name] AS userName,
	U.bio,
	U.createdDate,
	U.ethereumAddress,
	Chat.FetchFollowingCount(U.userId) AS followingCount,
	Chat.FetchFollowerCount(U.userId) AS followerCount,
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
		INNER JOIN Chat.[Image] I ON U.imageId = I.imageId
	WHERE U.userId = @userId
GO

--Updates a given post with the given parameters
CREATE OR ALTER PROCEDURE Chat.UpdatePost
	@postId INT,
	@content NVARCHAR(280),
	@images IMAGES READONLY,
	@deleteImages BIT,
	@deletedImages NVARCHAR(MAX) OUTPUT
AS
IF @deleteImages = 1
	BEGIN
		SET @deletedImages = (
			SELECT I.publicId
			FROM Chat.[Image] I 
				INNER JOIN Chat.PostImage P ON I.imageId = P.imageId
			WHERE P.postId = @postId
			FOR JSON PATH
		)
		DELETE Chat.PostImage
		WHERE postId = @postId

		DELETE I
		FROM Chat.[Image] I
		WHERE EXISTS (
			SELECT *
			FROM Chat.PostImage P
			WHERE I.imageId = P.imageId 
				AND P.postId = @postId
		)
	END
IF EXISTS (SELECT * FROM @images)
	BEGIN
		INSERT Chat.[Image] (imageUrl, publicId)
		SELECT I.imageUrl, I.publicId
		FROM @images I

		INSERT Chat.PostImage (imageId, postId, aspectRatio)
		SELECT I.imageId, @postId, IT.aspectRatio
		FROM Chat.[Image] I
			INNER JOIN @images IT ON I.publicId = IT.publicId
	END
UPDATE Chat.Post
SET content = @content
WHERE postId = @postId
GO

--Returns all users whose handle is like the given filter
CREATE OR ALTER FUNCTION Chat.FilterUsers (
	@searcher INT,
	@filter NVARCHAR(30)
)
RETURNS TABLE
AS
RETURN
	SELECT U.[name] AS userName,
		U.handle AS userHandle,
		I.imageUrl AS userImage,
		U.bio AS userBio,
		Chat.FetchFollowingCount(U.userId) AS followingCount,
		Chat.FetchFollowerCount(U.userId) AS followerCount,
		IIF(F.followedUserId IS NULL, 0, 1) AS isFollowing
	FROM Chat.[User] U
		INNER JOIN Chat.[Image] I ON U.imageId = I.imageId
		LEFT JOIN Chat.[Follower] F ON U.userId = F.followedUserId
			AND F.followerUserId = @searcher
	WHERE U.handle LIKE '%' + @filter + '%'
GO

--Fetches a users following count
CREATE OR ALTER FUNCTION Chat.FetchFollowingCount (
	@userId INT
)
RETURNS INT
AS
BEGIN
RETURN (
	SELECT COUNT(*)
	FROM Chat.Follower F
	WHERE F.followerUserId = @userId
)
END
GO

--Fetches a user's follower count
CREATE OR ALTER FUNCTION Chat.FetchFollowerCount (
	@userId INT
)
RETURNS INT
AS
BEGIN
RETURN (
	SELECT COUNT(*)
	FROM Chat.Follower F
	WHERE F.followedUserId = @userId
)
END
GO

--Fetches @userId's posts that they have liked.
CREATE OR ALTER FUNCTION Chat.FetchLikedPosts (
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
		INNER JOIN Chat.[Like] L2 ON @userId = L2.userId
			AND P.postId = L2.postId
	GROUP BY U.[name], U.handle, I.imageUrl, P.postId, P.content, L2.userId, P.createdOn
	ORDER BY P.postId
	OFFSET (@page * 15) ROWS FETCH NEXT 15 ROWS ONLY
GO

--Fetches @userId's posts that are replies.
CREATE OR ALTER FUNCTION Chat.FetchUserReplies (
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
		P.replyToPostId,
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
	WHERE P.replyToPostId IS NOT NULL
		AND P.userId = @userId
	GROUP BY U.[name], U.handle, I.imageUrl, P.postId, P.content, P.replyToPostId, L2.userId, P.createdOn
	ORDER BY P.postId
	OFFSET (@page * 15) ROWS FETCH NEXT 15 ROWS ONLY
GO

--Fetch the amount of posts a user has liked
CREATE OR ALTER FUNCTION Chat.FetchTotalLikedPosts (
	@userId INT
)
RETURNS INT
AS
BEGIN
RETURN (
	SELECT COUNT(*)
	FROM Chat.[Like] L
	WHERE L.userId = @userId
)
END
GO

--Fetchs the amount of posts a user has that are replies
CREATE OR ALTER FUNCTION Chat.FetchTotalUserReplies (
	@userId INT
)
RETURNS INT
AS
BEGIN
RETURN (
	SELECT COUNT(*)
	FROM Chat.Post P
	WHERE P.userId = @userId
		AND P.replyToPostId IS NOT NULL
)
END
GO

--Filter test
SELECT *
FROM Chat.FilterUsers(1, 'gar')

--Follower/Following count test
SELECT Chat.FetchFollowingCount(1)
SELECT Chat.FetchFollowerCount(1)

--Update post test
DECLARE @deletedPosts NVARCHAR(MAX);
DECLARE @images IMAGES;
EXEC Chat.UpdatePost 1, "new content", @images, 1, @deletedPosts OUTPUT
SELECT @deletedPosts

--Fetch following/follower test
EXEC Chat.FetchFollowing 'rhyams1', 0
EXEC Chat.FetchFollowers 'rhyams1', 0

--Fetch user profile test
EXEC Chat.FetchUserProfile 'kscogings0'

--Fetch a posts a user has liked and posts that are replies
SELECT Chat.FetchTotalLikedPosts(8)
SELECT *
FROM Chat.FetchLikedPosts(8, 0)
SELECT Chat.FetchTotalUserReplies(8)
SELECT * 
FROM Chat.FetchUserReplies(8, 0)

--Fetch comments to a post
SELECT *
FROM Chat.FetchPostComments(1, 1, 0)

--Primary key information
SELECT *
FROM Chat.Post P
WHERE P.replyToPostId IS NULL

SELECT *
FROM Chat.Follower;

SELECT U.[name], U.userId, U.handle
FROM Chat.[User] U 
WHERE U.userId = 1 OR U.userId = 2;
