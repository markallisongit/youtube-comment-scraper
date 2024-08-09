# Overview

Retrieves videos and their comments from a specified YouTube channel, and exports the results to CSV files, using PowerShell.

# Description

This script uses the YouTube Data API to gather video metadata and comments 
from a given YouTube channel. The script fetches all videos associated with 
the specified channel, retrieves comments for each video, and processes the 
data to include relevant details such as video titles, publish times, and 
comment details. The output includes two CSV files: one containing detailed 
video and comment information, and another containing only the comment 
texts. The data is sorted by video publish time and comment publish time.
