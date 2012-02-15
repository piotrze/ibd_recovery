module IbdRecovery 
  puts "## *.ibd recovery ##"
  require 'rubygems'
  require 'highline/import'

  @sql_schema = ask('enter filename with sql schema:')
  @sql_schema = "/home/foo/dump/database_structure.sql"
  @db_name = "bar"
  @ibd_source = "/home/foo/dump/bar_ibdfiles"
  @percona_path = "/home/foo/percona-data-recovery-tool-for-innodb-0.5"
  @sql_dump_path = "/home/foo/dump/bar_sqldump"


  def self.run
    file = File.open(@sql_schema)
    tables = []
    table = ["", ""]
    file.each_line do |line|
      if line =~ /CREATE\ TABLE/
        tables << table if !table[0].empty?
        table = ["", ""]
        table[1] = line.scan(/`(\w+)`/).first.first
        
      end
      table[0] << line.gsub(/\n/, '').gsub(/`/, "")
    end
    
    success = false

    for tab in tables
      say(tab.inspect)
      if success || ask("process(y/n): ") == "y"
        shell?("sudo /etc/init.d/mysql restart") 
        mysql_e?("SET FOREIGN_KEY_CHECKS = 0; " + tab[0]) #create table
        mysql_stop
        repeats = 0
        begin 
          success = ibdconnect(tab[1])
          repeats += 1
        end while(!success && repeats < 8 || !success && ask("repeat? (y/n):") == "y")
        innochecksum
        cp_ibdfile(tab[1])
        shell?("sudo chown -R mysql:mysql /var/lib/mysql/")
        mysql_start
        mysql_e?("optimize table #{tab[1]};")
        mysqldump(tab[1])
        mysql_e?("drop table #{tab[1]}")


      end

    end
  end


  def self.mysql_e?(statment)
    a = "mysql -u root #{@db_name} -e \"#{statment}\""
    `#{a}`
    return $?.exitstatus == 0 
  end

  def self.shell?(command)
    output = `#{command}`
    puts output
    puts $?.exitstatus
     return $?.exitstatus == 0
  end

  def self.mysql_stop
    shell?("sudo /etc/init.d/mysql stop")
  end

  def self.mysql_start
    shell?("sudo /etc/init.d/mysql start")
  end

  def self.ibdconnect(table)
    shell?("sudo #{@percona_path}/ibdconnect -o /var/lib/mysql/ibdata1 -f #{@ibd_source}/#{table}.ibd -d #{@db_name} -t #{table}")
  end

  def self.innochecksum
    3.times do
      shell?("sudo #{@percona_path}/innochecksum -f /var/lib/mysql/ibdata1")
    end
  end

  def self.mysqldump(table)
    shell?("sudo mysqldump -u root #{@db_name} #{table} > #{@sql_dump_path}/#{table}.sql")
  end

  def self.cp_ibdfile(table)
    shell?("sudo cp #{@ibd_source}/#{table}.ibd /var/lib/mysql/#{@db_name}/.")
  end

end

IbdRecovery.run
