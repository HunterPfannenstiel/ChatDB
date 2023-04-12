--DB
DROP DATABASE IF EXISTS ChatApplication
CREATE DATABASE ChatApplication

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
	handle NVARCHAR(30) NOT NULL,
	imageId INT FOREIGN KEY
		REFERENCES Chat.[Image](imageId) NOT NULL,
	bio NVARCHAR(150),
	email NVARCHAR(128),
	ethereumAddress NVARCHAR(64),
	status BIT NOT NULL DEFAULT 1,
	createdDate DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
)

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

--Stored Procedures
DROP PROCEDURE IF EXISTS Chat.CreateUser
DROP PROCEDURE IF EXISTS Chat.CreatePost;
DROP PROCEDURE IF EXISTS Chat.FetchFeed;
DROP TYPE IF EXISTS IMAGES;
GO

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

CREATE PROCEDURE Chat.CreatePost(@userId INT, @content NVARCHAR(280), @replyToPostId INT, @communityId INT, @images IMAGES READONLY, @postId INT OUTPUT)
AS
BEGIN

DECLARE @ImageInfo TABLE (
	id INT,
	publicId NVARCHAR(100)
)

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
END
GO

CREATE PROCEDURE Chat.FetchFeed(@userId INT, @feed NVARCHAR(MAX) OUTPUT) 
AS
BEGIN
SET @feed = 
	(SELECT U.[name] AS userName, I.imageUrl AS userImage, U.handle AS userHandle, COUNT(Followed.followedUserId) AS followerCount, COUNT([Following].followerUserId) AS followingCount, (
		SELECT U.[name] AS userName, I.imageUrl AS userImage, U.handle AS userHandle, P.content, P.postId, P.createdOn, P.replyToPostId, COUNT(L.postId) AS likeCount, COUNT(R.postId) AS commentCount, Chat.FetchImages(P.postId) AS images,
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
		GROUP BY P.content, P.postId, P.createdOn, P.replyToPostId, U.[name], I.imageUrl, U.handle, IIF(UL.userId IS NOT NULL, 1, 0)
		ORDER BY P.createdOn DESC
		FOR JSON PATH
	) AS posts
	FROM Chat.[User] U
	JOIN Chat.[Image] I ON I.imageId = U.imageId
	LEFT JOIN Chat.[Follower] Followed ON Followed.followedUserId = @userId
	LEFT JOIN Chat.[Follower] [Following] ON [Following].followerUserId = @userId
	WHERE U.userId = @userId
	GROUP BY U.[name], I.imageUrl, U.handle
	FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
END
GO

--Functions
DROP FUNCTION IF EXISTS Chat.IsValidHandle;
DROP FUNCTION IF EXISTS Chat.FetchImages;
GO

CREATE FUNCTION Chat.FetchImages(@postId INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
RETURN(
	SELECT I.imageUrl, P.aspectRatio
	FROM Chat.PostImage P
	JOIN Chat.[Image] I ON I.imageId = P.imageId
	WHERE P.postId = @postId
	FOR JSON PATH
)
END
GO

CREATE FUNCTION Chat.IsValidHandle(@handle NVARCHAR(30))
RETURNS BIT
AS
BEGIN
DECLARE @output BIT;
IF NOT EXISTS (
	SELECT U.handle FROM Chat.[User] U WHERE U.handle = @handle
)
	SET @output = 1;
ELSE SET @output = 0;
RETURN @output
END
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
INSERT INTO Chat.[User](name, handle, email, ethereumAddress, imageId, bio)
VALUES ('fartis0', 'kscogings0', 'jelbourn0@pagesperso-orange.fr', '0x405a59640c0aa2b46d0eb42d949f3ae571c385db', 1, 'Wuhan Transportation University'), 
('garkill1', 'rhyams1', 'gdyne1@shinystat.com', '0xf0b68b5cfdd9076ca609d9358bc81bc53dd04cdc', 2, 'Pace University'),
('njarmain2', 'edelaperrelle2', null, null, 3, 'Universidad Nicaragüense de Ciencia y Tecnológica'),
('cswenson3', 'nesp3', 'gbeaument3@berkeley.edu', '0x3848cc6af7eb069b26f479b3d1d140f94ad2438b', 4, 'Creighton University'),
('bstirrip4', 'fgribbell4', null, null, 5, 'University of Essex'),
('gellams5', 'czarfati5', 'bburress5@photobucket.com', '0x03cdacd611fbbd90f2a1b884161cc4e94a4698b5', 6, 'Arizona Christian University');


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

	--Post Likes
INSERT INTO Chat.[Like](postId, userId)
VALUES(1, 2), (1, 3), (1, 4), (2, 2), (2, 3), (10, 2), (10, 1), (10, 4)

	--Followers
INSERT INTO Chat.Follower(followedUserId, followerUserId)
VALUES(1, 2), (2, 1), (1, 3), (3, 1), (5, 6)

	--Post Image
INSERT INTO Chat.[Image](imageUrl, publicId)
VALUES('https://res.cloudinary.com/dwg1i9w2u/image/upload/v1673400247/item_images/pihzt8aa2r2fo3va0yfx.png', N'543')

INSERT INTO Chat.PostImage(imageId, postId, aspectRatio)
VALUES(1, 1, 1.777)