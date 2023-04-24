--Aggregated Queries
--1.
CREATE VIEW Chat.ActiveUsersCount AS
SELECT
    COUNT(*) AS TotalActiveUsers
FROM
    Chat.[User]
WHERE
    status = 1;

--2.
CREATE FUNCTION Chat.ActiveUsersInCommunity (@communityId INT)
RETURNS TABLE
AS
RETURN (
    SELECT
        COUNT(*) AS TotalActiveUsersInSpecificCommunity
    FROM
        Chat.[User] u
    JOIN
        Chat.CommunityUser cu ON u.userId = cu.userId
    WHERE
        u.status = 1
        AND cu.communityId = @communityId
);
--2.1 
SELECT
    TotalActiveUsersInSpecificCommunity
FROM
    Chat.ActiveUsersInCommunity(1); -- Replace 1 with the desired communityId

--3
WITH PostsInLastMonth AS (
    SELECT *
    FROM Chat.Post
    WHERE DATEADD(MONTH, -1, SYSDATETIMEOFFSET()) < createdOn
),
PostsInCommunities AS (
    SELECT
        postId,
        communityId,
        createdOn,
        LAG(createdOn) OVER (PARTITION BY communityId ORDER BY createdOn) AS previousCreatedOn
    FROM
        PostsInLastMonth
),
TimeDifferenceInCommunities AS (
    SELECT
        communityId,
        AVG(DATEDIFF(SECOND, previousCreatedOn, createdOn)) AS AvgTimeBtwnPosts
    FROM
        PostsInCommunities
    WHERE
        previousCreatedOn IS NOT NULL
    GROUP BY
        communityId
)
SELECT
    c.communityId,
    c.name,
    tdic.AvgTimeBtwnPosts,
    RANK() OVER (ORDER BY tdic.AvgTimeBtwnPosts ASC) AS Rank
FROM
    Chat.Community c
JOIN
    TimeDifferenceInCommunities tdic ON c.communityId = tdic.communityId
ORDER BY
    tdic.AvgTimeBtwnPosts;



--4
CREATE FUNCTION Chat.MostDiscussedPostsInCommunity (
    @communityId INT,
    @startDate DATETIMEOFFSET,
    @endDate DATETIMEOFFSET
)
RETURNS TABLE
AS
RETURN (
    SELECT
        p.communityId,
        p.postId,
        COUNT(r.postId) AS replyToPost,
        p.userId
    FROM
        Chat.Post p
    LEFT JOIN
        Chat.Post r ON p.postId = r.replyToPostId
    WHERE
        p.communityId = @communityId
        AND p.createdOn BETWEEN @startDate AND @endDate
    GROUP BY
        p.communityId,
        p.postId,
        p.userId
);

--4.1
SELECT
    CommunityId,
    PostId,
    replyToPost,
    userId
FROM
    Chat.MostDiscussedPostsInCommunity(1, '2023-01-01T00:00:00', '2023-01-31T23:59:59')
ORDER BY
    replyToPost DESC;
