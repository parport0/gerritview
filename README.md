# A simple Gerrit iOS client

This is nothing serious. My first Swift application. Learning.

I really wanted to see the statuses of changes from the change list on mobile. Gerrit web UI hides the status icons when the view is too narrow.

## What it can do

* Show a list of "is:open" changes
* Show a list of changes using any search query
* Show some details about a change: latest revision's commit message, list of changed files, diff from the branch to the last revision of the change, and all comments left under the change
* User can set any Gerrit instance URL
* User can supply a username and token when "HTTP credentials" are used

## TODO (in no particular order)

* Be able to comment and vote
* Show the comments, including inline ones
* An easy way to scroll to the top of the change list --- to refresh the list, for example
* Fetch and use the search filter presets from Gerrit (seen in "Settings" -> "Menu"), OR a way to save the search filters in the app (not as cool)
* Vote icons as colored letters (like "CR" letters in a green circle, instead of "Code-Review ✅")
* Hide/show previous patchset comments
* Comments under changes should probably be shown in reverse order on mobile (less scroll = good)
* Show that changes have unresolved comments as an icon
* Maybe a nicer way to show comments-that-are-votes (like on Gerrit web, a comment with a Code-Review+1 vote will show a green badge on the comment)
* Some event view would be nice? Checking latest Gerrit updates from the email inbox is unpleasant on mobile
* FIX AUTH to not use a hardcoded realm name. Needs a URLSession delegate to be set I suppose
* Find a good icon for the app
* Dark theme 😖
* Overall I need to understand how to use the standard colors
* WatchOS version hahaha
* Reset the search results when X is pressed in the search bar. It does not trigger onSubmit for some reason
* Fix the constraint conflict that gets logged when the search bar is first tapped
* Jenkins gerrit plugin integration
* Try to understand if it is possible to authenticate to https://android-review.googlesource.com or not
* Add an OPTION to download and show (and cache) userpics
* Consider adding suggestions for the search bar, like on the web??
* Add "/a/" to the Gerrit instance URL when using authentication
* Normalize Gerrit instance URLs (with or without https specified, with or without a slash in the end specified)
* Unwrap all optionals properly, pls no crash
* Give better diagnostics on network errors

## Won't do

* Bulk vote. If you need to bulk vote, something is seriously wrong with your WoW
