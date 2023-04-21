
--Update User - INPUT: @userId, @image (IMAGE), @bio, @handle, @name, OUTPUT: @deletedImage (the publicId of the iamge that was replaced (if a new image was provided))
--have not added to db file 
CREATE PROCEDURE Chat.UpdateUser
    @userId INT,
    @imagePublicId NVARCHAR(100),
    @bio NVARCHAR(150),
    @handle NVARCHAR(30),
    @name NVARCHAR(30),
    @deletedImage NVARCHAR(100) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @imageId INT;
    DECLARE @publicId NVARCHAR(100);

    -- Check if a new handle is provided and if it already exists
    IF @handle IS NOT NULL
    BEGIN
        IF EXISTS (SELECT 1 FROM Chat.[User] WHERE handle = @handle AND userId != @userId)
        BEGIN
            RAISERROR('Handle already exists.', 16, 1);
            RETURN;
        END
    END

    -- Check if a new image was provided
    IF @imagePublicId IS NOT NULL
    BEGIN
        -- Get imageId of the image to set
        SELECT @imageId = imageId, @publicId = publicId
        FROM Chat.[Image]
        WHERE publicId = @imagePublicId;

        -- Raise an error if the image publicId is not found
        IF @imageId IS NULL
        BEGIN
            RAISERROR('Image publicId not found.', 16, 1);
            RETURN;
        END
    END
    ELSE
    BEGIN
        -- Get imageId and publicId of the image the user currently has
        SELECT @imageId = imageId, @publicId = publicId
        FROM Chat.[Image]
        WHERE imageId = (SELECT imageId FROM Chat.[User] WHERE userId = @userId);
    END

    -- Update user information
    UPDATE Chat.[User]
    SET imageId = COALESCE(@imageId, imageId),
        bio = COALESCE(@bio, bio),
        handle = COALESCE(@handle, handle),
        name = COALESCE(@name, name)
    WHERE userId = @userId;

    -- Update user image reference
    IF @imageId IS NOT NULL
    BEGIN
        DECLARE @oldImageId INT;
        SELECT @oldImageId = imageId FROM Chat.[User] WHERE userId = @userId;

        IF @oldImageId IS NOT NULL
        BEGIN
            -- Check the number of users referencing the old image
            DECLARE @userCount INT;
            SELECT @userCount = COUNT(*) FROM Chat.[User] WHERE imageId = @oldImageId;

            -- Delete old image if there are no other users referencing it
            IF @userCount = 1
            BEGIN
                DELETE FROM Chat.[Image]
                WHERE imageId = @oldImageId;
            END
        END

        SET @deletedImage = @publicId;
    END
    ELSE
    BEGIN
        SET @deletedImage = NULL;
    END
END

------Delete a User Post - INPUT: @postId, OUTPUT: none
CREATE PROCEDURE Chat.DeleteUserPost
    @postId INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM Chat.Post
    WHERE postId = @postId
END
---------------Fetch all users who liked a post - INPUT: @postId, @page, OUTPUT: userName ('User.name'), userImage ('Image.imageUrl'), userHandle ('User.handle'), bio ('User.bio')
--NOTE: We will want to only return ~20 users for each stored procedure call. Use OFFSET-FETCH with the @page parameter to return the correct users
CREATE PROCEDURE Chat.GetUsersWhoLikedPost
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

-------Create a post like - INPUT: @postId, @userId, OUTPUT: none
CREATE PROCEDURE Chat.LikePost
    @postId INT,
    @userId INT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Chat.[Like] (postId, userId)
    VALUES (@postId, @userId)
END

--Fetch User Posts - INPUT: @userId, @page, OUTPUT: Same exact structure as the 'posts' array above except doesn't need to be JSON data (and we don't need to return 
--the user info)
--NOTE: Limit the amount of posts to 10 for each stored procedure call.
CREATE PROCEDURE Chat.GetUserPosts
    @userId INT,
    @page INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @pageSize INT = 10
    DECLARE @offset INT = (@page - 1) * @pageSize

    SELECT Post.postId, Post.content, Post.replyToPostId, Post.isPinned, Post.createdOn
    FROM Chat.Post
    WHERE Post.userId = @userId
    ORDER BY Post.createdOn DESC
    OFFSET @offset ROWS
    FETCH NEXT @pageSize ROWS ONLY
END
