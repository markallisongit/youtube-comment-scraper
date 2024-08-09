<#
.SYNOPSIS
    Retrieves videos and their comments from a specified YouTube channel, 
    and exports the results to CSV files.

.DESCRIPTION
    This script uses the YouTube Data API to gather video metadata and comments 
    from a given YouTube channel. The script fetches all videos associated with 
    the specified channel, retrieves comments for each video, and processes the 
    data to include relevant details such as video titles, publish times, and 
    comment details. The output includes two CSV files: one containing detailed 
    video and comment information, and another containing only the comment 
    texts. The data is sorted by video publish time and comment publish time.

.PARAMETER channelId
    The unique identifier of the YouTube channel from which to retrieve videos 
    and comments. 

.EXAMPLE
    .\GetYouTubeChannelComments.ps1 -channelId "UCIkSRiwfhiSA0wOQNB8ANBA"
    Retrieves videos and comments from the specified YouTube channel and saves 
    the data to CSV files.

.NOTES
    This script requires an API key from the Google Developer Console, which 
    should be stored in a file named `youtube-api-key.txt` in the same directory 
    as the script. The script uses this API key to authenticate requests to the 
    YouTube Data API.

    Ensure that PowerShell execution policy allows the script to run, and that 
    the necessary API access is granted for the key being used.

    Author: Mark Allison
#>


[cmdletbinding()]
param (
    [Parameter(Mandatory=$true)]
    $channelId # the YouTube channel Id
)

function Get-ChannelVideos {
    # get a list of videos with some brief metadata from a channel
    param(
        [string]$channelId,
        [string]$apiKey,
        [string]$baseUrl
    )

    $videos = @()
    $nextPageToken = $null

    do {
        $response = Invoke-RestMethod -Uri "$baseUrl/search?part=snippet&channelId=$channelId&maxResults=50&pageToken=$nextPageToken&type=video&key=$apiKey" -Method Get
        $videos += $response.items
        $nextPageToken = $response.nextPageToken
    } while ($nextPageToken)

    return $videos
}

function Get-VideoComments {
    # get a list of comments given a videoId
    param(
        [string]$videoId,
        [string]$apiKey,
        [string]$baseUrl
    )

    $comments = @()
    $nextPageToken = $null

    do {
        $response = Invoke-RestMethod -Uri "$baseUrl/commentThreads?part=snippet&videoId=$videoId&maxResults=100&pageToken=$nextPageToken&textFormat=plainText&key=$apiKey" -Method Get
        $response.items.ForEach({
            $comments += $_
        })
        $nextPageToken = $response.nextPageToken
    } while ($nextPageToken)

    return $comments
}

# the YouTube API
$baseUrl = "https://www.googleapis.com/youtube/v3"

# get your own API key from the Google Developer Console and then put it in a file called youtube-api-key.txt
$apiKey = Get-Content .\youtube-api-key.txt -Raw -Encoding utf8 

# get a list of videos 
$videos = Get-ChannelVideos -channelId $channelId -apiKey $apiKey -baseUrl $baseUrl
Write-Output "Found $($videos.Count) videos in the channel"

# format the video data returned to only the info we need
$videoData = $videos | ForEach-Object {
    [PSCustomObject]@{
        URL          = "https://www.youtube.com/watch?v=$($_.id.videoId)"
        VideoID      = $_.id.videoId
        PublishTime  = $_.snippet.publishTime
        Title        = $_.snippet.title
        Description  = $_.snippet.description
    }
}

# Get all comments from the videos
$allCommentData = @()

foreach ($video in $videoData) {
    $videoComments = Get-VideoComments -videoId $video.VideoID -apiKey $apiKey -baseUrl $baseUrl
    $commentData = $videoComments | ForEach-Object {
        [PSCustomObject]@{
            VideoID             = $video.VideoID
            PublishTime         = $video.PublishTime
            Title               = $video.Title
            CommentPublishedAt  = $_.snippet.topLevelComment.snippet.publishedAt
            CommentUpdatedAt    = $_.snippet.topLevelComment.snippet.updatedAt
            CommentLikeCount    = $_.snippet.topLevelComment.snippet.likeCount
            AuthorDisplayName   = $_.snippet.topLevelComment.snippet.authorDisplayName
            CommentTextDisplay  = $_.snippet.topLevelComment.snippet.textDisplay
        }
    }
    $allCommentData += $commentData
    Write-Output "Retrieved $($commentData.Count) comments from video $videoId"
}

# Sort comments first by PublishTime then by CommentPublishedAt
$allCommentData = $allCommentData | Sort-Object PublishTime, CommentPublishedAt

# write out the video data to csv files
$videoData | Sort-Object -Property PublishTime | Export-Csv -path "$($channelId)-videolist.csv" -Encoding utf8 -NoTypeInformation
Write-Output "Video list saved to $($channelId)-videolist.csv"

$allCommentData | Export-Csv -Path "$($channelId)-youtube_comments.csv" -NoTypeInformation -Encoding UTF8
Write-Output "Comment data saved to $($channelId)-youtube_comments.csv"

$allCommentData | Select-Object -Property CommentTextDisplay | Export-Csv -Path "$($channelId)_youtube_comment_texts.csv" -NoTypeInformation -Encoding UTF8
Write-Output "Comment texts only saved to  $($channelId)_youtube_comment_texts.csv"