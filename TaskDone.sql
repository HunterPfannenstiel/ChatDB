
Update User - INPUT: @userId, @image (IMAGE), @bio, @handle, @name, OUTPUT: @deletedImage (the publicId of the iamge that was replaced (if a new image was provided))
--have not added to db file 
CREATE PROCEDURE dbo.UpdateUser
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

