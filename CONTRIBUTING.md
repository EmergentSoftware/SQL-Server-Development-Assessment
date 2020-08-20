# Contributing to the SQL Server Assess

First of all, welcome! We're excited that you'd like to contribute. How would you like to help?

* [I'd like to report a bug](#how-to-report-bugs)
* [I'd like someone else to build something](#how-to-request-features)
* [I'd like to build a new feature myself](#how-to-build-features-yourself)


## How to Report Bugs

Check out the [Github issues list]. Search for what you're interested in - there may already be an issue for it. 

Make sure to search through [closed issues list], too, because we may have already fixed the bug in the development branch. To try the most recent version of the code that we haven't released to the public yet, [download the dev branch version].

If you can't find a similar issue, go ahead and open your own. Include as much detail as you can - what you're seeing now, and what you'd expect to see instead.


## How to Request Features

Open source is community-built software. Anyone is welcome to build things that would help make their job easier.

Open source isn't free development, though. Working on these scripts is hard work: they have to work on case-sensitive instances, and on all supported versions of SQL Server (currently 2008 through 2017.) If you just waltz in and say, "Someone please bake me a cake," you're probably not going to get a cake.

If you want something, you're going to either need to build it yourself, or convince someone else to devote their free time to your feature request. You can do that by sponsoring development (offering to hire a developer to build it for you), or getting people excited enough that they volunteer to build it for you.


## How to Build Features Yourself

When you're ready to start coding, discuss it with the community. Check the [Github issues list] and the [closed issues list] because folks may have tried it in the past, or the community may have decided it's not a good fit for these tools.

If you can't find it in an existing issue, open a new Github issue for it. Outline what you'd like to do, why you'd like to do it, and optionally, how you'd think about coding it. This just helps make sure other users agree that it's a good idea to add to these tools. Other folks will respond to the idea, and if you get a warm reception, go for it!

After your Github issue has gotten good responses from a couple of volunteers who are willing to test your work, get started by forking the project and working on your own server. The Github instructions are below - it isn't exactly easy, and we totally understand if you're not up for it. Thing is, we can't take code contributions via text requests - Github makes it way easier for us to compare your work versus the changes other people have made, and merge them all together.

Note that if you're not ready to get started coding in the next week, or if you think you can't finish the feature in the next 30 days, you probably don't want to bother opening an issue. You're only going to feel guilty over not making progress, because we'll keep checking in with you to see how it's going. We don't want to have stale "someday I'll build that" issues in the list - we want to keep the open issues list easy to scan for folks who are trying to troubleshoot bugs and feature requests.

### Code Requirements and Standards

We're picky about style and formatting, but a few things to know:

Your code needs to compile & run on all currently supported versions of SQL Server. It's okay if functionality degrades, like if not all features are available, but at minimum the code has to compile and run.

Your code must handle:

* Case sensitive databases & servers
* Unicode object names (databases, tables, indexes, etc.)
* Different date formats - "2013-01-27", "01/27/2013"

We know that's a pain, but that's the kind of thing we find out in the wild. Of course you would never build a server like that, but...


### Contributing T-SQL Code: Git Flow for Pull Requests

1. [Fork] the project, clone your fork, and configure the remotes:

   ```bash
   # Clone your fork of the repo into the current directory
   git clone git@github.com:<YOUR_USERNAME>/SQL-Server-Assess.git
   # Navigate to the newly cloned directory
   cd SQL-Server-Assess
   # Assign the original repo to a remote called "upstream"
   git remote add upstream https://github.com/EmergentSoftware/SQL-Server-Assess/
   ```

2. If you cloned a while ago, get the latest changes from upstream:

   ```bash
   git checkout dev
   git pull upstream dev
   ```

3. Create a new topic branch (off the main project development branch) to
   contain your feature, change, or fix:

   ```bash
   git checkout -b <topic-branch-name>
   ```

4. Make changes.

   Make changes to one or more of the files in the project. If your change requires a new CheckId look here: https://github.com/EmergentSoftware/SQL-Server-Assess#current-high-check-id.
   
   You should modify the file 'README.md' in the project by yourself.

5. Commit your changes in logical chunks. Please adhere to these [git commit message guidelines]
   or your code is unlikely be merged into the main project. Use Git's [interactive rebase]
   feature to tidy up your commits before making them public.

6. Locally merge (or rebase) the upstream development branch into your topic branch:

   ```bash
   git pull [--rebase] upstream dev
   ```

7. Push your topic branch up to your fork:

   ```bash
   git push origin <topic-branch-name>
   ```

8. [Open a Pull Request] with a clear title and description.

**IMPORTANT**: By submitting the work, you agree to allow the project owner to license your work under the MIT [LICENSE]


[Github issues list]:https://github.com/EmergentSoftware/SQL-Server-Assess/issues
[closed issues list]: https://github.com/EmergentSoftware/SQL-Server-Assess/issues?q=is%3Aissue+is%3Aclosed
[Fork]:https://help.github.com/articles/fork-a-repo/
[git commit message guidelines]:http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
[interactive rebase]:https://help.github.com/articles/about-git-rebase/
[Open a Pull Request]:https://help.github.com/articles/about-pull-requests/
[LICENSE]:https://github.com/EmergentSoftware/SQL-Server-Assess/blob/master/LICENSE.md
[download the dev branch version]: https://github.com/EmergentSoftware/SQL-Server-Assess/archive/dev.zip
