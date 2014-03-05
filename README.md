Deadlock Example
================

An example showing why you should never perform coordinated file accesses in a file presentation handler. 

This example employs two file presenters. Both are handling `-relinquishPresentedItemToReader:` and `-presentedItemDidChange`. Whenever `-presentedItemDidChange` is called, the presenters perform a coordinated read. By that, both presenters are querying each other for relinquishing the file. This is done by enqueuing a block on the sequential `-presentedItemOperationQueue` of each other presenter. By that, the request will be never confirmed: the queue is already blocked by the `-presentedItemDidChange` notification that waits for the confirmation request of the other presenter.
