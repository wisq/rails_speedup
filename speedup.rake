module Rake
  class Application
    def alias_task(new, old)
      @tasks[new.to_s] = Rake::Task[old]
    end
  end
end

class IO
  def partial(*args)
    print(*args)
    sync
  end
end

namespace :speedup do
  task :db_test_prepare_fast => :db_auto_migrate do
    databases = YAML.load_file('config/database.yml')
    ActiveRecord::Base.establish_connection(databases['test'])

    schema_digest = Digest::MD5.file(ENV['SCHEMA'] || "#{Rails.root}/db/schema.rb").hexdigest

    sm_table = ActiveRecord::Migrator.schema_migrations_table_name
    migrated = ActiveRecord::Base.connection.select_values("SELECT version FROM #{sm_table}")

    unless migrated.include?(schema_digest)
      $stderr.partial 'Cloning test database ... '
      Rake::Task['db:test:clone'].invoke
      $stderr.puts 'done.'
      ActiveRecord::Base.establish_connection(databases['test'])
      ActiveRecord::Base.connection.execute("INSERT INTO #{sm_table} (version) VALUES ('#{schema_digest}');")
    end
  end

  task :db_auto_migrate do
    databases = YAML.load_file('config/database.yml')
    ActiveRecord::Base.establish_connection(databases[Rails.env])

    migrations = {}
    Dir.entries('db/migrate').each do |name|
      next unless name =~ /^(\d+)_.*\.rb$/
      migrations[$1] = name
    end

    sm_table = ActiveRecord::Migrator.schema_migrations_table_name
    migrated = ActiveRecord::Base.connection.select_values("SELECT version FROM #{sm_table}")
    missing  = migrations.keys - migrated

    unless missing.empty?
      $stderr.puts 'Missing migrations:'
      missing.each do |num|
        $stderr.puts "\t#{migrations[num]}"
      end
      $stderr.puts

      $stderr.puts 'Automatically running db:migrate in 5 seconds.'
      $stderr.partial 'Control-C to abort: '
      5.times do
        $stderr.partial '.'
        sleep(1)
      end
      $stderr.puts ' running.'

      Rake::Task['db:migrate'].invoke
      Rake::Task['db:abort_if_pending_migrations'].invoke
    end
  end
end

Rake.application.alias_task 'db:test:prepare', 'speedup:db_test_prepare_fast'
