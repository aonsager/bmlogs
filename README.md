== Brewmaster Logs

Brewmaster Logs is made for Brewmasters in the World of Warcraft who want to improve by tracking their performance across raid encounters, based on a small number of key metrics.

It is designed primarily for those who want to improve their basic rotation. It probably will not provide enough information to be useful to advanced players who are already very comfortable with the class and are now trying to maximize their output.

== Setup

Requirements:

- Ruby >= 2.0
- Rails >= 4.0
- PostgreSQL 

```
bundle install
bundle exec rake db:migrate
rails server
```

== Processing Queue

Log parsing is handled by Resque, and can be accessed at localhost:3000/resque/

You need to run separate worker processes to go through the queue, and this is the command I use for that:

```
TERM_CHILD=1 bundle exec rake environment resque:work QUEUE=parse
```

I'll update this doc as I think of more things to write.