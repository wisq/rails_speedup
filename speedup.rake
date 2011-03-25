# Set to 'true' to automatically run db:migrate.
# Set to 'false' to just whine and stop.
AUTO_MIGRATE = true


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

    schema_file = ENV['SCHEMA'] || "#{Rails.root}/db/schema.rb"
    schema_digest = Digest::MD5.file(schema_file).hexdigest

    found = false
    begin
      sm_table = ActiveRecord::Migrator.schema_migrations_table_name
      migrated = ActiveRecord::Base.connection.select_values("SELECT version FROM #{sm_table}")
      found = migrated.include?(schema_digest)
    rescue Exception => ActiveRecord::StatementInvalid
    end

    unless found
      $stderr.partial 'Cloning test database ... '
      Rake::Task['db:test:clone'].invoke
      $stderr.puts 'done.'
      ActiveRecord::Base.establish_connection(databases['test'])

      schema_digest = Digest::MD5.file(schema_file).hexdigest # might have changed
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
      $stderr.puts "You have #{missing.count} pending migrations:"
      missing.each do |num|
        $stderr.puts "\t#{migrations[num]}"
      end

      abort('Run "rake db:migrate" to update your database then try again.') unless AUTO_MIGRATE

      $stderr.puts
      $stderr.puts 'Applying migrations ...'
      Rake::Task['db:migrate'].invoke
      $stderr.puts 'Database migrated.'
    end
  end
end

Rake.application.alias_task 'db:test:prepare', 'speedup:db_test_prepare_fast'
