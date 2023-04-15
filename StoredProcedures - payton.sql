CREATE OR ALTER PROCEDURE Chat.FetchFollowers
	@userId INT,
	@page INT
AS
BEGIN
	SELECT U.[name] AS userName,
		U.handle AS userHandle,
		I.imageUrl AS userImage,
		U.bio AS userBio
	FROM Chat.[User] U 
		INNER JOIN Chat.Follower F ON U.userId = F.followerUserId 
			AND @userId = F.followedUserId
		INNER JOIN Chat.[Image] I ON U.imageId = I.imageId
	ORDER BY F.followDate
	OFFSET (@page * 20) ROWS FETCH NEXT 20 ROWS ONLY
END;

EXEC Chat.FetchFollowers 1, 0;
