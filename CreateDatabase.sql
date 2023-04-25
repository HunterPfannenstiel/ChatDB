--DB
DROP DATABASE IF EXISTS ChatApplication
CREATE DATABASE ChatApplication
USE ChatApplication

--Tables
IF SCHEMA_ID(N'Chat') IS NULL
	EXEC(N'CREATE SCHEMA Chat;');
GO

DROP TABLE IF EXISTS Chat.Follower;
DROP TABLE IF EXISTS Chat.[Like];
DROP TABLE IF EXISTS Chat.CommunityUser;
DROP TABLE IF EXISTS Chat.CommunityTag;
DROP TABLE IF EXISTS Chat.PostTag;
DROP TABLE IF EXISTS Chat.Tag;
DROP TABLE IF EXISTS Chat.PostImage;
DROP TABLE IF EXISTS Chat.Post;
DROP TABLE IF EXISTS Chat.Community;
DROP TABLE IF EXISTS Chat.Visibility;
DROP TABLE IF EXISTS Chat.[User];
DROP TABLE IF EXISTS Chat.[Image];

CREATE TABLE Chat.[Image]
(
	imageId INT IDENTITY(1, 1) PRIMARY KEY,
	imageUrl NVARCHAR(500) NOT NULL UNIQUE,
	publicId NVARCHAR(100) NOT NULL UNIQUE,
)

CREATE TABLE Chat.[User]
(
	userId INT IDENTITY(1, 1) PRIMARY KEY,
	name NVARCHAR(30) NOT NULL,
	handle NVARCHAR(30) NOT NULL UNIQUE,
	imageId INT FOREIGN KEY
		REFERENCES Chat.[Image](imageId) NOT NULL,
	bio NVARCHAR(150),
	email NVARCHAR(128),
	ethereumAddress NVARCHAR(64),
	status BIT NOT NULL DEFAULT 1,
	createdDate DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
)

CREATE UNIQUE INDEX UQ_User_Email
ON Chat.[User] (email)
WHERE email IS NOT NULL

CREATE UNIQUE INDEX UQ_User_Ether
ON Chat.[User] (ethereumAddress)
WHERE ethereumAddress IS NOT NULL

CREATE TABLE Chat.Follower
(
	followedUserId INT FOREIGN KEY
		REFERENCES Chat.[User](userId) NOT NULL,
	followerUserId INT FOREIGN KEY
		REFERENCES Chat.[User](userId) NOT NULL,
	followDate DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
	CONSTRAINT PK_Follower PRIMARY KEY (followedUserId, followerUserId),
	CONSTRAINT CHK_FollowedIsNotFollower CHECK (followedUserId <> followerUserId)
)

CREATE TABLE Chat.Visibility
(
	name NVARCHAR(10) PRIMARY KEY
)

CREATE TABLE Chat.Community
(
	communityId INT IDENTITY(1, 1) PRIMARY KEY,
	creatorId INT FOREIGN KEY
		REFERENCES Chat.[User](userId) NOT NULL,
	name NVARCHAR(50) NOT NULL,
	description NVARCHAR(200) NOT NULL,
	visbility NVARCHAR(10) FOREIGN KEY
		REFERENCES Chat.Visibility(name),
)

CREATE TABLE Chat.CommunityUser
(
	communityId INT FOREIGN KEY
		REFERENCES Chat.Community(communityId),
	userId INT FOREIGN KEY
		REFERENCES Chat.[User](userId),
	joinDate DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
	CONSTRAINT PK_CommUser PRIMARY KEY (communityId, userId)
)

CREATE TABLE Chat.Post
(
	postId INT IDENTITY(1, 1) PRIMARY KEY,
	userId INT FOREIGN KEY
		REFERENCES Chat.[User](userId) NOT NULL,
	content NVARCHAR(280) NOT NULL,
	replyToPostId INT FOREIGN KEY
		REFERENCES Chat.Post(postId),
	communityId INT FOREIGN KEY
		REFERENCES Chat.Community(communityId),
	isPinned BIT NOT NULL DEFAULT 0,
	createdOn DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
)

CREATE TABLE Chat.PostImage
(
	imageId INT FOREIGN KEY
		REFERENCES Chat.[Image](imageId),
	postId INT FOREIGN KEY
		REFERENCES Chat.Post(postId),
	aspectRatio NUMERIC(5, 3) NOT NULL,
	CONSTRAINT PK_ImgPost PRIMARY KEY (imageId, postId)
)

CREATE TABLE Chat.[Like]
(
	userId INT FOREIGN KEY
		REFERENCES Chat.[User](userId),
	postId INT FOREIGN KEY
		REFERENCES Chat.Post(postId),
	CONSTRAINT PK_Like PRIMARY KEY (userId, postId)
)

CREATE TABLE Chat.Tag
(
	tagId INT IDENTITY(1, 1) PRIMARY KEY,
	name NVARCHAR(10) NOT NULL UNIQUE,
	description NVARCHAR(75) NOT NULL,
	color NVARCHAR(20) NOT NULL
)

CREATE TABLE Chat.PostTag
(
	postId INT FOREIGN KEY
		REFERENCES Chat.Post(postId),
	tagId INT FOREIGN KEY
		REFERENCES Chat.Tag(tagId),
	CONSTRAINT PK_PostTag PRIMARY KEY (postId, tagId)
)

CREATE TABLE Chat.CommunityTag
(
	communityId INT FOREIGN KEY
		REFERENCES Chat.Community(communityId),
	tagId INT FOREIGN KEY
		REFERENCES Chat.Tag(tagId),
	CONSTRAINT PK_CommTag PRIMARY KEY (communityId, tagId)
)

--Drop everything in one spot
DROP PROCEDURE IF EXISTS Chat.CreateUser
DROP PROCEDURE IF EXISTS Chat.CreatePost;
DROP PROCEDURE IF EXISTS Chat.FetchFollowers;
DROP PROCEDURE IF EXISTS Chat.FetchFollowing;
DROP PROCEDURE IF EXISTS Chat.LikePost;
DROP PROCEDURE IF EXISTS Chat.FollowUser;
DROP PROCEDURE IF EXISTS Chat.IsValidHandle;
DROP PROCEDURE IF EXISTS Chat.UpdatePost;
DROP PROCEDURE IF EXISTS Chat.UpdateUser;
DROP PROCEDURE IF EXISTS Chat.FetchLikedPosts;
DROP PROCEDURE IF EXISTS Chat.FetchReplyPosts;
DROP FUNCTION IF EXISTS Chat.IsUserFollowing;
DROP FUNCTION IF EXISTS Chat.FetchImages;
DROP FUNCTION IF EXISTS Chat.FetchWeb3User;
DROP FUNCTION IF EXISTS Chat.FetchEmailUser;
DROP FUNCTION IF EXISTS Chat.FetchPostComments;
DROP FUNCTION IF EXISTS Chat.FetchUser;
DROP FUNCTION IF EXISTS Chat.FetchFollowerCount;
DROP FUNCTION IF EXISTS Chat.FetchFollowingCount;
DROP FUNCTION IF EXISTS Chat.IsUSerFollowing;
DROP TYPE IF EXISTS IMAGES;
GO

--Stored Procedures
CREATE TYPE IMAGES AS TABLE (
	imageUrl NVARCHAR(500),
	publicId NVARCHAR(100),
	aspectRatio NUMERIC(5, 3)
)
GO

CREATE PROCEDURE Chat.CreateUser(@name NVARCHAR(30), @handle NVARCHAR(30), @bio NVARCHAR(150), @email NVARCHAR(128), @ethereumAddress NVARCHAR(64), @imageUrl NVARCHAR(500), @publicId NVARCHAR(100), @userId INT OUTPUT)
AS
BEGIN
	INSERT INTO Chat.[Image](imageUrl, publicId)
	VALUES(@imageUrl, @publicId)

	DECLARE @imageId INT = SCOPE_IDENTITY();
	INSERT INTO Chat.[User]([name], handle, imageId, bio, email, ethereumAddress)
	VALUES(@name, @handle, @imageId, @bio, @email, @ethereumAddress)

	SET @userId = SCOPE_IDENTITY();
END
GO

--Have to create these functions here because procedures need it
CREATE FUNCTION Chat.FetchImages(@postId INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
RETURN (
	SELECT I.imageUrl, P.aspectRatio
	FROM Chat.PostImage P
	JOIN Chat.[Image] I ON I.imageId = P.imageId
	WHERE P.postId = @postId
	FOR JSON PATH
	)
END
GO

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

CREATE OR ALTER FUNCTION Chat.IsUserFollowing (
	@viewerUserId INT,
	@viewingUserId INT
)
RETURNS BIT
AS
BEGIN
	DECLARE @isFollowing BIT;
	IF EXISTS (SELECT * FROM Chat.Follower WHERE followedUserId = @viewingUserId AND followerUserId = @viewerUserId)
		SET @isFollowing = 1;
	ELSE
		SET @isFollowing = 0;
	RETURN @isFollowing;
END
GO

--Beginning of procedures
CREATE PROCEDURE Chat.CreatePost(@userId INT, @content NVARCHAR(280), @replyToPostId INT, @communityId INT, @images IMAGES READONLY)
AS
BEGIN

DECLARE @ImageInfo TABLE (
	id INT,
	publicId NVARCHAR(100)
)

DECLARE @postId INT;

INSERT INTO Chat.[Image](imageUrl, publicId)
OUTPUT INSERTED.imageId, INSERTED.publicId INTO @ImageInfo
SELECT i.imageUrl, i.publicId FROM @images i


INSERT INTO Chat.Post(userId, content, replyToPostId, communityId)
VALUES(@userId, @content, @replyToPostId, @communityId)
SET @postId = SCOPE_IDENTITY();

INSERT INTO Chat.PostImage(imageId, postId, aspectRatio)
SELECT II.id, @postId, I.aspectRatio
FROM @ImageInfo II
JOIN @images I ON I.publicId = II.publicId

SELECT U.name AS userName, U.handle AS userHandle, I.imageUrl AS userImage, @postId AS postId, @content AS content, Chat.FetchImages(@postId) AS images, SYSDATETIMEOFFSET() AS createdOn, @replyToPostId AS replyToPostId
FROM Chat.[User] U
JOIN Chat.[Image] I ON I.imageId = U.imageId
WHERE U.userId = @userId
END
GO

--'FetchFollowing' means fetch the users that @userId follows.
CREATE OR ALTER PROCEDURE Chat.FetchFollowing
	@userHandle NVARCHAR(30),
	@queryUserId INT = 0,
	@page INT,
	@createdDateTime DATETIMEOFFSET
AS
DECLARE @userId INT = (SELECT U.userId FROM Chat.[User] U WHERE U.handle = @userHandle);
SELECT U.[name] AS userName,
	U.handle AS userHandle,
	I.imageUrl AS userImage,
	U.userId AS userId,
	U.bio,
	Chat.FetchFollowerCount(@userId) AS followerCount,
	Chat.FetchFollowingCount(@userId) AS followingCount,
	Chat.IsUserFollowing(@queryUserId, U.userId) AS isFollowing
FROM Chat.[User] U 
	LEFT JOIN Chat.Follower F ON @userId = F.followerUserId
		AND U.userId = F.followedUserId
	INNER JOIN Chat.[Image] I ON U.imageId = I.imageId
WHERE F.followDate <= @createdDateTime
ORDER BY F.followDate DESC
OFFSET (@page * 20) ROWS FETCH NEXT 20 ROWS ONLY
GO

--'FetchFollowers' means fetch the users that follow @userId.
CREATE OR ALTER PROCEDURE Chat.FetchFollowers
	@userHandle NVARCHAR(30),
	@queryUserId INT = 0,
	@page INT,
	@createdDateTime DATETIMEOFFSET
AS
DECLARE @userId INT = (SELECT U.userId FROM Chat.[User] U WHERE U.handle = @userHandle);
SELECT U.[name] AS userName,
	U.handle AS userHandle,
	I.imageUrl AS userImage,
	U.userId AS userId,
	U.bio,
	Chat.FetchFollowerCount(@userId) AS followerCount,
	Chat.FetchFollowingCount(@userId) AS followingCount,
	Chat.IsUserFollowing(@queryUserId, U.userId) AS isFollowing
FROM Chat.[User] U 
	LEFT JOIN Chat.Follower F ON @userId = F.followedUserId
		AND U.userId = F.followerUserId
	INNER JOIN Chat.[Image] I ON U.imageId = I.imageId
WHERE F.followDate <= @createdDateTime
ORDER BY F.followDate DESC
OFFSET (@page * 20) ROWS FETCH NEXT 20 ROWS ONLY
GO

CREATE OR ALTER PROCEDURE Chat.FetchUserProfile
	@userHandle NVARCHAR(30),
	@queryUserId INT = 0
AS
DECLARE @userId INT = (SELECT U.userId FROM Chat.[User] U WHERE U.handle = @userHandle);
SELECT I.imageUrl AS userImage,
	U.[name] AS userName,
	@userHandle AS userHandle,
	@userId AS userId,
	U.bio,
	U.createdDate,
	U.ethereumAddress,
	Chat.FetchFollowerCount(@userId) AS followerCount,
	Chat.FetchFollowingCount(@userId) AS followingCount,
	Chat.IsUserFollowing(@queryUserId, @userId) AS isFollowing,
	JSON_QUERY((
		SELECT P.postId,
			P.content,
			COUNT(DISTINCT L.userId) AS likeCount,
			COUNT(DISTINCT P2.postId) AS commentCount,
			JSON_QUERY(Chat.FetchImages(P.postId)) AS images,
			P.createdOn,
			IIF(L2.userId IS NOT NULL, 1, 0) AS isLiked
		FROM Chat.Post P
			LEFT JOIN Chat.[Like] L ON P.postId = L.postId
			LEFT JOIN Chat.Post P2 ON P.postId = P2.replyToPostId
			LEFT JOIN Chat.[Like] L2 ON P.postId = L2.postId
				AND L2.userId = @queryUserId
		WHERE P.userId = @userId
		GROUP BY P.postId, P.content, P.createdOn, L2.userId
		ORDER BY P.createdOn DESC
		FOR JSON PATH
	)) AS posts
	FROM Chat.[User] U
		INNER JOIN Chat.[Image] I ON U.imageId = I.imageId
	WHERE U.userId = @userId
	GROUP BY I.imageUrl, U.[name], U.bio, U.createdDate, U.ethereumAddress
GO

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

CREATE OR ALTER PROCEDURE Chat.LikePost
    @postId INT,
    @userId INT,
	@like INT
AS
BEGIN
    SET NOCOUNT ON;
	IF @like = 1
		INSERT INTO Chat.[Like] (postId, userId)
		VALUES (@postId, @userId)
	ELSE
		DELETE Chat.[Like]
		WHERE userId = @userId AND postId = @postId
END
GO

CREATE OR ALTER PROCEDURE Chat.FollowUser 
	@followedUserId INT, 
	@followerUserId INT, 
	@follow INT
AS
BEGIN
	IF @follow = 1
		INSERT INTO Chat.Follower(followedUserId, followerUserId)
		VALUES(@followedUserId, @followerUserId)
	ELSE
		DELETE Chat.Follower
		WHERE followedUserId = @followedUserId AND followerUserId = @followerUserId
END
GO

CREATE OR ALTER PROCEDURE Chat.IsValidHandle
	@handle NVARCHAR(30)
AS
IF EXISTS (SELECT * FROM Chat.[User] U WHERE U.handle = @handle)
    SELECT 0 AS isValidHandle
ELSE 
    SELECT 1 AS isValidHandle
GO


--Update User - INPUT: @userId, @image (IMAGE), @bio, @handle, @name, OUTPUT: @deletedImage (the publicId of the iamge that was replaced (if a new image was provided))
CREATE OR ALTER PROCEDURE Chat.UpdateUser
    @userId INT,
    @image IMAGES READONLY,
    @bio NVARCHAR(150),
    @handle NVARCHAR(30),
    @name NVARCHAR(30),
    @deletedImage NVARCHAR(100) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE @newImageId INT;

    -- Check if a new handle is provided and if it already exists
    IF @handle IS NOT NULL
    BEGIN
        IF EXISTS (SELECT 1 FROM Chat.[User] WHERE handle = @handle AND userId != @userId)
        BEGIN
            RAISERROR('Handle already exists.', 16, 1);
            RETURN;
        END
    END

	--@image will be null if no new image is was supplied
	IF EXISTS (SELECT * FROM @image)
		--Store the old image's publicId so it can be deleted after the reference in Chat.User is removed
		SET @deletedImage = (SELECT I.publicId FROM Chat.[User] U INNER JOIN Chat.[Image] I ON U.imageId = I.imageId WHERE U.userId = @userId)
		--Insert the new image into Chat.Image
		INSERT Chat.[Image] (imageUrl, publicId)
		SELECT imageUrl,
			publicId
		FROM @image
		SET @newImageId = @@IDENTITY
		
    -- Update user information
    UPDATE Chat.[User]
    SET imageId = COALESCE(@newImageId, imageId),
        bio = COALESCE(@bio, bio),
        handle = COALESCE(@handle, handle),
        name = COALESCE(@name, name)
    WHERE userId = @userId;

	--If a new image was given, delete the old image
	IF @deletedImage IS NOT NULL
		--This delete from the PostImage table can be removed once the default inserted data is refactored to not have two users reference the same imageId
		DELETE Chat.PostImage
		WHERE imageId = (SELECT imageId FROM Chat.[Image] WHERE publicId = @deletedImage)
		DELETE Chat.[Image]
		WHERE publicId = @deletedImage
END
GO

------Delete a User Post - INPUT: @postId, OUTPUT: none
CREATE OR ALTER PROCEDURE Chat.DeleteUserPost
    @postId INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM Chat.Post
    WHERE postId = @postId
END
GO

---------------Fetch all users who liked a post - INPUT: @postId, @page, OUTPUT: userName ('User.name'), userImage ('Image.imageUrl'), userHandle ('User.handle'), bio ('User.bio')
--NOTE: We will want to only return ~20 users for each stored procedure call. Use OFFSET-FETCH with the @page parameter to return the correct users
CREATE OR ALTER PROCEDURE Chat.GetUsersWhoLikedPost
    @postId INT,
    @page INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @pageSize INT = 20
    DECLARE @offset INT = (@page - 1) * @pageSize

    SELECT userName, userImage, userHandle, bio
    FROM (
        SELECT [User].name AS userName,
            Image.imageUrl AS userImage,
            [User].handle AS userHandle,
            [User].bio,
            ROW_NUMBER() OVER (ORDER BY [Like].postId) AS rownum
        FROM Chat.[Like]
        INNER JOIN Chat.[User] ON [Like].userId = [User].userId
        INNER JOIN Chat.[Image] ON [User].imageId = [Image].imageId
        WHERE [Like].postId = @postId
    ) AS subquery
    WHERE rownum > @offset AND rownum <= (@offset + @pageSize)
    ORDER BY rownum
END
GO

--Fetch User Posts - INPUT: @userId, @page, OUTPUT: Same exact structure as the 'posts' array above except doesn't need to be JSON data (and we don't need to return 
--the user info)
--NOTE: Limit the amount of posts to 10 for each stored procedure call.
CREATE OR ALTER PROCEDURE Chat.GetUserPosts
    @userId INT,
    @page INT,
	@createdDateTime DATETIMEOFFSET
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @pageSize INT = 10
    DECLARE @offset INT = (@page - 1) * @pageSize

    SELECT Post.postId, Post.content, Post.replyToPostId, Post.isPinned, Post.createdOn
    FROM Chat.Post
    WHERE Post.userId = @userId
		AND Post.createdOn <= @createdDateTime
    ORDER BY Post.createdOn DESC
    OFFSET @offset ROWS
    FETCH NEXT @pageSize ROWS ONLY
END
GO

CREATE OR ALTER PROCEDURE Chat.FetchUserPosts
    @userHandle NVARCHAR(30),
	@page INT,
	@createdDateTime DATETIMEOFFSET,
    @queryUserId INT = 0
AS
DECLARE @userId INT = (SELECT U.userId FROM Chat.[User] U WHERE U.handle = @userHandle);

SELECT P.postId, 
	P.content, 
	P.createdOn,
	Chat.IsUserFollowing(@queryUserId, @userId) AS isFollowing,
	COUNT(DISTINCT L.userId) AS likeCount, 
	COUNT(DISTINCT P2.postId) AS commentCount,
    JSON_QUERY(Chat.FetchImages(P.postId)) AS images,
    IIF(L2.userId IS NOT NULL, 1, 0) AS isLiked
FROM Chat.Post P
	LEFT JOIN Chat.[Like] L ON P.postId = L.postId
	LEFT JOIN Chat.Post P2 ON P.postId = P2.replyToPostId
	LEFT JOIN Chat.[Like] L2 ON P.postId = L2.postId
		AND L2.userId = @queryUserId
WHERE P.userId = @userId AND P.createdOn <= @createdDateTime
GROUP BY P.postId, P.content, P.createdOn, L2.userId
ORDER BY P.createdOn DESC
OFFSET @page * 10 ROWS
FETCH NEXT 10 ROWS ONLY
GO

CREATE OR ALTER PROCEDURE Chat.FetchLikedPosts
    @userHandle NVARCHAR(30),
	@page INT,
	@createdDateTime DATETIMEOFFSET,
    @queryUserId INT = 0
AS
DECLARE @userId INT = (SELECT U.userId FROM Chat.[User] U WHERE U.handle = @userHandle);

SELECT P.postId, 
	P.content, 
	P.createdOn,
	Chat.IsUserFollowing(@queryUserId, @userId) AS isFollowing,
	COUNT(DISTINCT L.userId) AS likeCount, 
	COUNT(DISTINCT P2.postId) AS commentCount,
    JSON_QUERY(Chat.FetchImages(P.postId)) AS images,
    IIF(L2.userId IS NOT NULL, 1, 0) AS isLiked
FROM Chat.Post P
	LEFT JOIN Chat.[Like] L ON P.postId = L.postId
	LEFT JOIN Chat.Post P2 ON P.postId = P2.replyToPostId
	LEFT JOIN Chat.[Like] L2 ON P.postId = L2.postId
		AND L2.userId = @queryUserId
WHERE P.createdOn <= @createdDateTime AND L.userId = @userId
GROUP BY P.postId, P.content, P.createdOn, L2.userId
ORDER BY P.createdOn DESC
OFFSET @page * 10 ROWS
FETCH NEXT 10 ROWS ONLY
GO

CREATE OR ALTER PROCEDURE Chat.FetchReplyPosts
    @userHandle NVARCHAR(30),
	@page INT,
	@createdDateTime DATETIMEOFFSET,
    @queryUserId INT = 0
AS
DECLARE @userId INT = (SELECT U.userId FROM Chat.[User] U WHERE U.handle = @userHandle);

SELECT P.postId, 
	P.content, 
	P.createdOn,
	Chat.IsUserFollowing(@queryUserId, @userId) AS isFollowing,
	COUNT(DISTINCT L.userId) AS likeCount, 
	COUNT(DISTINCT P2.postId) AS commentCount,
    JSON_QUERY(Chat.FetchImages(P.postId)) AS images,
    IIF(L2.userId IS NOT NULL, 1, 0) AS isLiked
FROM Chat.Post P
	LEFT JOIN Chat.[Like] L ON P.postId = L.postId
	LEFT JOIN Chat.Post P2 ON P.postId = P2.replyToPostId
	LEFT JOIN Chat.[Like] L2 ON P.postId = L2.postId
		AND L2.userId = @queryUserId
WHERE P.createdOn <= @createdDateTime AND P.userId = @userId AND P.replyToPostId IS NOT NULL
GROUP BY P.postId, P.content, P.createdOn, L2.userId
ORDER BY P.createdOn DESC
OFFSET @page * 10 ROWS
FETCH NEXT 10 ROWS ONLY
GO

CREATE OR ALTER PROCEDURE Chat.FetchUserDetails(
	@handle NVARCHAR(30), 
	@queryUserId INT = 0
)
AS
BEGIN
DECLARE @userId INT = (SELECT U.userId FROM Chat.[User] U WHERE U.handle = @handle);
SELECT I.imageUrl AS userImage,
    U.[name] AS userName,
    @handle AS userHandle,
    @userId AS userId,
    U.bio,
    U.createdDate,
    Chat.FetchFollowerCount(@userId) AS followerCount,
    Chat.FetchFollowingCount(@userId) AS followingCount,
	Chat.IsUserFollowing(@queryUserId, @userId) AS isFollowing
        FROM Chat.[User] U
        INNER JOIN Chat.[Image] I ON U.imageId = I.imageId
    WHERE U.userId = @userId
    GROUP BY I.imageUrl, U.[name], U.bio, U.createdDate, U.ethereumAddress
END
GO

CREATE OR ALTER PROCEDURE Chat.FetchUserStats
	@userHandle NVARCHAR(30), @queryUserId INT
AS
DECLARE @userId INT = (SELECT userId FROM Chat.[User] WHERE handle = @userHandle)
SELECT U.[name] AS userName,
	U.bio,
	I.imageUrl,
	COUNT(DISTINCT L.userId) AS likesReceived,
	COUNT(DISTINCT L2.postId) AS likesGiven,
	Chat.FetchFollowerCount(@userId) AS followerCount,
	Chat.FetchFollowingCount(@userId) AS followingCount,
	Chat.IsUserFollowing(@queryUserId, @userId) AS isFollowing,
	COUNT(DISTINCT P.postId) AS postsCreated,
	COUNT(DISTINCT P2.postId) AS repliesReceived
FROM Chat.[User] U
	LEFT JOIN Chat.Post P ON U.userId = P.userId
	LEFT JOIN Chat.[Like] L ON P.postId = L.postId
	LEFT JOIN Chat.[Like] L2 ON U.userId = L2.userId
	LEFT JOIN Chat.Post P2 ON P.postId = P2.replyToPostId
		AND P2.userId <> @userId
	INNER JOIN Chat.[Image] I ON U.imageId = I.imageId
WHERE U.userId = @userId
GROUP BY U.[name], bio, imageUrl
GO

--Functions

CREATE FUNCTION Chat.FetchWeb3User(@ethereumAddress NVARCHAR(64))
RETURNS TABLE
AS
RETURN (SELECT U.userId
	FROM Chat.[User] U
	WHERE U.ethereumAddress = @ethereumAddress)
GO

CREATE FUNCTION Chat.FetchEmailUser(@email NVARCHAR(128))
RETURNS TABLE
AS
RETURN (SELECT U.userId
	FROM Chat.[User] U
	WHERE U.email = @email)
GO

--@userId is the user who is viewing the page.
CREATE OR ALTER FUNCTION Chat.FetchPostComments (
	@postId INT,
	@userId INT,
	@page INT,
	@createdDateTime DATETIMEOFFSET
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
		JSON_QUERY(Chat.FetchImages(P.postId)) AS images,
		IIF(L2.userId IS NULL, 0, 1) AS isLiked,
		P.createdOn
	FROM Chat.Post P
		LEFT JOIN Chat.[Like] L ON P.postId = L.postId
		LEFT JOIN Chat.Post P2 ON P.postId = P2.replyToPostId
		INNER JOIN Chat.[User] U ON P.userId = U.userId
		INNER JOIN Chat.[Image] I ON U.imageId = I.imageId
		LEFT JOIN Chat.[Like] L2 ON @userId = L2.userId
			AND P.postId = L2.postId
	WHERE P.createdOn <= @createdDateTime 
		AND (P.replyToPostId = @postId OR P.postId = @postId)
	GROUP BY U.[name], U.handle, I.imageUrl, P.postId, P.content, L2.userId, P.createdOn
	ORDER BY P.postId
	OFFSET (@page * 15) ROWS FETCH NEXT 15 ROWS ONLY
GO

CREATE OR ALTER FUNCTION Chat.FetchFeedPage (
	@userId INT, 
	@page INT,
	@createdDateTime DATETIMEOFFSET
)
RETURNS TABLE
AS
RETURN(
	SELECT U.[name] AS userName, I.imageUrl AS userImage, U.handle AS userHandle, P.content, P.postId, P.createdOn, P.replyToPostId, COUNT(DISTINCT L.userId) AS likeCount, COUNT(DISTINCT R.postId) AS commentCount, JSON_QUERY(Chat.FetchImages(P.postId)) AS images,
	IIF(UL.userId IS NOT NULL, 1, 0) AS isLiked
	FROM Chat.Follower F
	JOIN Chat.Post P ON P.userId = F.followedUserId AND P.replyToPostId IS NULL
	LEFT JOIN Chat.[Like] L ON L.postId = P.postId
	LEFT JOIN Chat.[Like] UL ON UL.postId = P.postId 
		AND UL.userId = @userId
	LEFT JOIN Chat.Post R ON R.replyToPostId = P.postId
	JOIN Chat.[User] U ON U.userId = P.userId
	JOIN Chat.[Image] I ON I.imageId = U.imageId
	WHERE F.followerUserId = @userId
		AND P.createdOn <= @createdDateTime
	GROUP BY P.content, P.postId, P.createdOn, P.replyToPostId, U.[name], I.imageUrl, U.handle, IIF(UL.userId IS NOT NULL, 1, 0)
	ORDER BY P.createdOn DESC
	OFFSET @page * 10 ROWS
	FETCH FIRST 10 ROWS ONLY
)
GO



CREATE OR ALTER FUNCTION Chat.FetchGlobalFeed (
	@page INT, 
	@userId INT = 0,
	@createdDateTime DATETIMEOFFSET
)
RETURNS TABLE
AS
RETURN(
		SELECT U.[name] AS userName, I.imageUrl AS userImage, U.handle AS userHandle, P.content, P.postId, P.createdOn, P.replyToPostId, COUNT(DISTINCT L.userId) AS likeCount, COUNT(DISTINCT R.postId) AS commentCount, JSON_QUERY(Chat.FetchImages(P.postId)) AS images,
	IIF(UL.userId IS NOT NULL, 1, 0) AS isLiked
	FROM Chat.Post P
	LEFT JOIN Chat.[Like] L ON L.postId = P.postId
	LEFT JOIN Chat.[Like] UL ON UL.postId = P.postId 
		AND UL.userId = @userId
	LEFT JOIN Chat.Post R ON R.replyToPostId = P.postId
	JOIN Chat.[User] U ON U.userId = P.userId
	JOIN Chat.[Image] I ON I.imageId = U.imageId
	WHERE P.createdOn <= @createdDateTime
	GROUP BY P.content, P.postId, P.createdOn, P.replyToPostId, U.[name], I.imageUrl, U.handle, IIF(UL.userId IS NOT NULL, 1, 0)
	ORDER BY P.createdOn DESC
	OFFSET @page * 10 ROWS
	FETCH FIRST 10 ROWS ONLY
)
GO

CREATE OR ALTER FUNCTION Chat.FetchUser (
	@userId INT
)
RETURNS TABLE
AS
RETURN (
	SELECT U.name AS userName, U.handle AS userHandle, I.imageUrl AS userImage,
	COUNT(DISTINCT F.followedUserId) AS followingCount, COUNT(DISTINCT F2.followerUserId) AS followerCount
	FROM Chat.[User] U
	JOIN Chat.[Image] I ON I.imageId = U.imageId
	LEFT JOIN Chat.Follower F ON F.followerUserId = @userId
	LEFT JOIN Chat.Follower F2 ON F2.followedUserId = @userId
	WHERE U.userId = @userId
	GROUP BY U.name, U.handle, I.imageUrl
)
GO

CREATE OR ALTER FUNCTION Chat.FilterUsers (
	@searcher INT,
	@filter NVARCHAR(30)
)
RETURNS TABLE
AS
RETURN
	SELECT U.[name] AS userName,
		U.userId,
		U.handle AS userHandle,
		I.imageUrl AS userImage,
		U.bio,
		Chat.FetchFollowingCount(U.userId) AS followingCount,
		Chat.FetchFollowerCount(U.userId) AS followerCount,
		Chat.IsUserFollowing(@searcher, U.userId) AS isFollowing
	FROM Chat.[User] U
		INNER JOIN Chat.[Image] I ON U.imageId = I.imageId
	WHERE U.handle LIKE '%' + @filter + '%'
	ORDER BY followerCount DESC
	OFFSET 0 ROWS
	FETCH FIRST 10 ROWS ONLY
GO

--Types
DROP TYPE IF EXISTS NEW_IMAGE;
DROP TYPE IF EXISTS FEED_IMAGE;

CREATE TYPE NEW_IMAGE AS TABLE (
	imageUrl NVARCHAR(500),
	publicId NVARCHAR(100),
	aspectRatio NUMERIC(5, 3)
)
GO

CREATE TYPE FEED_IMAGE AS TABLE (
	imageUrl NVARCHAR(500),
	aspectRatio NUMERIC(5, 3)
)
GO

--Data initialization
	--User Images
INSERT INTO Chat.[Image](imageUrl, publicId)
VALUES('https://res.cloudinary.com/dwg1i9w2u/image/upload/v1673400003/item_images/tjah32egdkq8idarjgkd.png', '123'),
('https://res.cloudinary.com/dwg1i9w2u/image/upload/v1673400244/item_images/fgvymicizcsmmwqgbgyh.png', '124'),
('https://res.cloudinary.com/dwg1i9w2u/image/upload/v1680569645/profile-images/jemgr7rpgs9v7wtkyscg.png', '125'),
('https://res.cloudinary.com/dwg1i9w2u/image/upload/v1681089807/profile-images/mofjwd7zjrj9hvd4wngm.jpg', '126'),
('https://res.cloudinary.com/dwg1i9w2u/image/upload/v1673400258/item_images/hvptjhpyprv1xe1egio5.png', '127'),
('https://res.cloudinary.com/dwg1i9w2u/image/upload/v1673400263/item_images/qcbl4s4wet0ift8kxyfj.png', '128');

	--Users
INSERT INTO Chat.[User](name, handle, ethereumAddress, imageId, bio) VALUES ('fartis0', 'kscogings0', '0x405a59640c0aa2b46d0eb42d949f3ae571c385db', 1, 'Wuhan Transportation University')
INSERT INTO Chat.[User](name, handle, email, imageId, bio) VALUES ('garkill1', 'rhyams1', 'gdyne1@shinystat.com', 2, 'Pace University')
INSERT INTO Chat.[User](name, handle, ethereumAddress, imageId, bio) VALUES ('njarmain2', 'edelaperrelle2', '0x3848cc6af7eb069b26f479b3d1d140f94ad2438b', 3, 'Universidad Nicaragüense de Ciencia y Tecnológica')
INSERT INTO Chat.[User](name, handle, email, imageId, bio) VALUES ('cswenson3', 'nesp3', 'gbeaument3@berkeley.edu', 4, 'Creighton University')
INSERT INTO Chat.[User](name, handle, email, imageId, bio) VALUES ('bstirrip4', 'fgribbell4', 'test@gmail.com', 5, 'University of Essex')
INSERT INTO Chat.[User](name, handle, email, imageId, bio) VALUES ('gellams5', 'czarfati5', 'bburress5@photobucket.com', 6, 'Arizona Christian University')
INSERT INTO Chat.[User](name, handle, email, imageId, bio) VALUES ('gellams5', 't', 'hunterstatek@gmail.com', 6, 'Arizona Christian University')
INSERT INTO Chat.[User](name, handle, email, imageId, bio) VALUES ('admin', 'admin', 'pfannenstielpayton@gmail.com', 6, ':O')


	--UserPosts
INSERT INTO Chat.Post (userId, content)
VALUES (1, 'quisque ut erat curabitur gravida nisi at nibh in hac habitasse platea dictumst'),
(1, 'ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae donec pharetra magna vestibulum aliquet ultrices erat'),
(1, 'vestibulum quam sapien varius ut blandit non interdum in ante vestibulum ante ipsum primis in faucibus orci luctus'),
(1, 'eget nunc donec quis orci eget orci vehicula condimentum curabitur'),
(2, 'blandit mi in porttitor pede justo eu massa donec dapibus duis at velit eu est congue elementum'),
(2, 'in faucibus orci luctus et ultrices posuere cubilia curae nulla dapibus'),
(2, 'vulputate vitae nisl aenean lectus pellentesque eget nunc donec quis orci eget orci vehicula condimentum curabitur in libero'),
(2, 'imperdiet sapien urna pretium nisl ut volutpat sapien arcu sed augue aliquam erat volutpat in congue'),
(2, 'odio elementum eu interdum eu tincidunt in leo maecenas pulvinar lobortis est phasellus sit amet erat'),
(3, 'vitae nisi nam ultrices libero non mattis pulvinar nulla pede ullamcorper augue a suscipit nulla'),
(3, 'hac habitasse platea dictumst maecenas ut massa quis augue luctus tincidunt nulla mollis molestie lorem quisque ut erat curabitur gravida'),
(3, 'ultrices vel augue vestibulum ante ipsum primis in faucibus orci luctus et'),
(3, 'enim lorem ipsum dolor sit amet consectetuer adipiscing elit proin interdum'),
(4, 'sapien cum sociis natoque penatibus et magnis dis parturient montes nascetur ridiculus mus etiam vel augue vestibulum rutrum'),
(4, 'porta volutpat quam pede lobortis ligula sit amet eleifend pede libero quis'),
(5, 'pede ullamcorper augue a suscipit nulla elit ac nulla sed vel enim sit amet nunc viverra dapibus nulla suscipit ligula'),
(5, 'eu tincidunt in leo maecenas pulvinar lobortis est phasellus sit amet erat nulla tempus vivamus in felis eu sapien'),
(5, 'risus semper porta volutpat quam pede lobortis ligula sit amet eleifend pede libero quis orci nullam molestie nibh'),
(6, 'curae nulla dapibus dolor vel est donec odio justo sollicitudin ut suscipit a feugiat et eros'),
(6, 'vestibulum sed magna at nunc commodo placerat praesent blandit nam');

	--Post Comments
INSERT Chat.Post (userId, content, replyToPostId)
VALUES (1, 'quisque ut erat curabitur gravida nisi at nibh in hac habitasse platea dictumst', 1),
(1, 'ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae donec pharetra magna vestibulum aliquet ultrices erat', 1),
(1, 'ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae donec pharetra magna vestibulum aliquet ultrices erat', 1)

	--Comments to comments
DECLARE @PostComment INT = @@IDENTITY
INSERT Chat.Post (userId, content, replyToPostId)
VALUES (1, 'vestibulum quam sapien varius ut blandit non interdum in ante vestibulum ante ipsum primis in faucibus orci luctus', @PostComment),
(1, 'eget nunc donec quis orci eget orci vehicula condimentum curabitur', @PostComment),
(2, 'blandit mi in porttitor pede justo eu massa donec dapibus duis at velit eu est congue elementum', 1),
(2, 'in faucibus orci luctus et ultrices posuere cubilia curae nulla dapibus', @PostComment),
(2, 'vulputate vitae nisl aenean lectus pellentesque eget nunc donec quis orci eget orci vehicula condimentum curabitur in libero', @PostComment),
(2, 'imperdiet sapien urna pretium nisl ut volutpat sapien arcu sed augue aliquam erat volutpat in congue', @PostComment);

	--Post Likes
INSERT INTO Chat.[Like](postId, userId)
VALUES(1, 2), (1, 3), (1, 4), (2, 2), (2, 3), (10, 2), (10, 1), (10, 4), (@PostComment, 1), (@PostComment, 2), (1, 1)

	--Followers
INSERT INTO Chat.Follower(followedUserId, followerUserId)
VALUES(1, 2), (2, 1), (1, 3), (3, 1), (5, 6)
	--Post Image
INSERT INTO Chat.[Image](imageUrl, publicId)
VALUES('https://res.cloudinary.com/dwg1i9w2u/image/upload/v1673400247/item_images/pihzt8aa2r2fo3va0yfx.png', N'543')

INSERT INTO Chat.PostImage(imageId, postId, aspectRatio)
VALUES(1, 1, 1.777)
