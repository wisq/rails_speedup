speedup.rake
============

speedup.rake is a Rake task file you can slot into your Rails projects in order to improve testing speed in large projects.  It does this by re-implementing the Rails "db:test:prepare" and "db:abort_if_pending_migrations" tests in a way that doesn't require loading the Rails environment, and doesn't perform unnecessary work.

This will NOT make the actual test suites faster.  It will simply eliminate the (potentially long) delay while Rails loads your project environment and rebuilds your test database unnecessarily.

Installation
------------

Put speedup.rake in your lib/tasks directory.

You can either check it in to version control, or set your version control to ignore it if you don't want it to be an official part of your build.

__Git users:__ You can stick it in ".git/info/exclude" if you don't want to acknowledge it in ".gitignore".

Caveats
-------

This method is only designed to work with databases that use schema.rb, not SQL schemas.

The contents of db/schema.rb are hashed and compared against a value in the test database.  If this value is missing -- e.g. because you ran db:test:clone manually, or ran a test suite without speedup.rake installed -- it will reload the database once unnecessarily.

The Rails environment will not be loaded if the test suite can be run without it.  This means that most attempts to configure the migration process or database configuration via configuration files will fail.

The current database and test database must be configured in config/database.yml using normal parameters; you cannot alias them to other databases (e.g. "production: development").

Benchmarks
----------

### With speedup.rake

     0.00s: (in /Users/wisq/Code/Ruby/...)
     3.49s: ** Invoke test:units (first_time)
     3.49s: ** Invoke test:prepare (first_time)
     3.49s: ** Invoke speedup:db_test_prepare_fast (first_time)
     3.49s: ** Invoke speedup:db_auto_migrate (first_time)
     3.49s: ** Execute speedup:db_auto_migrate
     3.51s: ** Execute speedup:db_test_prepare_fast
     3.52s: ** Execute test:prepare
     3.52s: ** Execute test:units
    18.24s: Loaded suite .../gems/rake-0.8.7/lib/rake/rake_test_loader
    18.24s: Started
    22.41s: .......................................
    22.41s: Finished in 4.168728 seconds.
    22.41s: 
    22.41s: 39 tests, 93 assertions, 0 failures, 0 errors

### Without speedup.rake

     0.00s: (in /Users/wisq/Code/Ruby/...)
     3.58s: ** Invoke test:units (first_time)
     3.58s: ** Invoke test:prepare (first_time)
     3.58s: ** Invoke db:test:prepare (first_time)
     3.58s: ** Invoke db:abort_if_pending_migrations (first_time)
     3.58s: ** Invoke environment (first_time)
     3.58s: ** Execute environment
    13.84s: ** Execute db:abort_if_pending_migrations
    13.90s: ** Execute db:test:prepare
    13.90s: ** Invoke db:test:load (first_time)
    13.90s: ** Invoke db:test:purge (first_time)
    13.90s: ** Invoke environment 
    13.90s: ** Execute db:test:purge
    14.64s: ** Execute db:test:load
    14.67s: ** Invoke db:schema:load (first_time)
    14.67s: ** Invoke environment 
    14.67s: ** Execute db:schema:load
    47.03s: ** Execute test:prepare
    47.03s: ** Execute test:units
    62.03s: Loaded suite .../gems/rake-0.8.7/lib/rake/rake_test_loader
    62.03s: Started
    66.14s: .......................................
    66.14s: Finished in 4.1047 seconds.
    66.14s: 
    66.14s: 39 tests, 93 assertions, 0 failures, 0 errors

