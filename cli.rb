require "rubygems"
require "socket"
require 'active_support/json'

@r = ["127.0.0.1", 1234]
@s = nil

@w = {}

class Array
  def hh
    self.inject({}){|m,e| m[e[0]]=e[1]; m}
  end
end

def s_open()
  begin
		@s = TCPSocket.open @r[0], @r[1]
		@s.sync = true
	rescue Errno::ECONNREFUSED
		puts "CONN FAIL"
		exit 1
	end
end

def sp(val) # send ruby line
  s_open; @s.puts val
  x = ''; while z=@s.read(1024); x+=z; end
  @s.close; x.chop
end

def spe(cmd) # send sys cmd
  sp("`#{cmd}`").chop
end

def get_h(var)
  ActiveSupport::JSON.decode sp "ActiveSupport::JSON.encode #{var}"
end

@ht = {
  "hosts"   => "Host.all.collect{|h| [h.id, h.attributes]}",
  "hosts-name"   => "Host.all.collect{|h| [h.name, h.attributes]}",
  "servers" => "Server.all.collect{|h| [h.id, h.attributes]}",
  "users"   => "User.all.collect{|h| [h.id, h.attributes]}",
  "ponude"  => "Ponuda.all.collect{|h| [h.id, h.attributes]}",
}

def ht(val)
  get_h(@ht[val].gsub(/\t+/, '\t').gsub(/ +/, ' ').gsub(/\n/, ' ')).hh
end

def init()
  # @hosts   = ht "hosts"
  # @servers = ht "servers"
  # @users   = ht "users"
  # @ponuda  = ht "ponude"
  # @disk    = spe("df / | tail -1 | awk '{print $2\" \"$4}'").split(' ').collect{|i| i.to_f/1024} # [all, used]
  # @procn   = spe("cat /proc/cpuinfo | grep processor | wc -l").chop.to_i # (int)N
  # @proc    = spe("cat /proc/cpuinfo | grep MHz | head -1 | awk '{print $4}'").to_f # (float)MHz
end

def srv_status(v) # user_id ili id
  v = v.to_s
  if v =~ /^\d+$/
    id = v
  elsif v =~ /_/
    id = v.split('_')[1].to_i
  else
    return false
  end
  sp "Server.find(#{id}).real_active?"
end

def fetch(v)
  @w[v] = ht v
end

s_open(); init()

# def list(k, c) # key name, columns
#   puts "#{k.capitalize}:"
#   fetch k
#   puts @w[k].keys.sort.each{|s| s = @w[k][s]
#     print "#{s["id"]}: "
#     c.map{|x|s[c].class==String ? "'#{s[c]}'" : "#{s[c]}"}.join ', '
#   }
# end

if ARGV[0]
  if %w(l li list).include?(ARGV[0])
    if %w(h hosts).include?(ARGV[1]) && (k="hosts")
      puts "Hosts:"
      fetch k
      @w[k].keys.sort.each{|s| s = @w[k][s]
        puts "#{s['id']}: #{s['name']}, #{s['address']}"
      }
    elsif %w(u users).include?(ARGV[1]) && (k="users")
      puts "Users:"
      fetch k
      @w[k].keys.sort.each{|s| s = @w[k][s]
        puts "#{s['id']}: #{s['email']}, #{!!s['confirmed_at'] ? 'act' : 'inact'}"
      }
    elsif %w(c containers s servers).include?(ARGV[1]) && (k="servers")
      puts "Servers:"
      fetch k
      fetch "users"
      fetch "hosts"
      @w[k].keys.sort.each{|s| s = @w[k][s]
        print "#{s['id']}: "
        c = [
          (@w['hosts'][s['host_id']]['name'] rescue '?'),
          (@w['users'][s['user_id']]['email'] rescue '?'),
          (s['active'] ? "Dact" : "Dinact"),
        ]
        if ARGV[2] == "-v"
          path = "/hosting/#{s['gametype']}/#{@w['users'][s['user_id']]['email'][/(.+)\@/,1] rescue "*"}_#{sprintf("%3d", s['id']).gsub(' ', '0')}"
          size = spe("du -s '#{path}'").to_f/1024 rescue "?"
          c += [
            path,
            (sprintf "%.2fM", size),
            (sp("Server.find(#{s['id']}).real_active?").chomp == "true" ? "Ract" : "Rinact"),
          ]
        end
        puts c.join ', '
      }
    end

    # puts @servers.keys.collect{|k| "#{@servers[k]["server"]["gametype"]}/#{@servers[k]["server"]}"}
  end

  # if ARGV[0] == "testconn"
  #   if ARGV[1]
  #     fetch "hosts-name"
  #     h = @w['hosts-name'][ARGV[1]]['address']
  #     if h.nil? || h.empty?
  #       puts "Unknown host"
  #       exit 1
  #     end
  #     puts "from #{h}: " + spe("ssh hosting@#{h} whoami")
  #   end
  # end

  # rsync -avhe ssh ./samp/user1_001 hosting@192.168.1.60:samp/

  if ARGV[0] == "add"
    if ARGV[1] == "host" && ARGV[2] && ARGV[3]
      sp "Host.create :name=>'#{ARGV[2]}', :address=>'#{ARGV[3]}'"
    end
  end

  # =>                       srv ID     dest host
  if ARGV[0] == "migrate" && ARGV[1] && ARGV[2]
    if ARGV[1] =~ /^\d+$/
      fetch "hosts-name"; fetch "servers"
      sid, dest  = ARGV[1].to_i, ARGV[2]
      fsid = sprintf("%3d", sid).gsub(/ /, "0")
      # gts  = sp "$gt.keys.join ','"
      gts = "samp,cod2,cs16"
      dir  = sp "Dir['/hosting/{#{gts}}/*_#{fsid}'].collect{|d| d if File.directory? d}.compact.first"
      puts "dir: #{dir}"
      gt   = @w['servers'][sid]['gametype']
      print "rsync ... "; c = "rsync -avhe ssh #{dir} hosting@192.168.1.60:#{gt}/"; puts "spe #{c}"; spe c; print "OK\n"
      print "db query ... "; c = "s=Server.find(#{sid}); s.host=Host.find(#{@w['hosts-name'][dest]['id']}); s.save"
      puts "sp #{c}"; sp c; print "OK\n"
    else
      puts "Container ID nije int"
    end
  end

  # =>                                            srv ID     src host
  if ARGV[0] == "migrate" && ARGV[1] == "back" && ARGV[2] && ARGV[3]
    if ARGV[2] =~ /^\d+$/
      # get current status
      # get srv size ...
      
      fetch "hosts-name"; fetch "servers"
      sid, dest  = ARGV[2].to_i, ARGV[3]
      fsid = sprintf("%3d", sid).gsub(/ /, "0")
      # gts  = sp "$gt.keys.join ','"
      gts = "samp,cod2,cs16"
      dir  = sp "Dir['/hosting/{#{gts}}/*_#{fsid}'].collect{|d| d if File.directory? d}.compact.first"
      puts "dir: #{dir}"
      gt   = @w['servers'][sid]['gametype']
      print "rsync ... "; c = "rsync -avhe ssh #{dir} hosting@192.168.1.60:#{gt}/"; puts "spe #{c}"; spe c; print "OK\n"
      print "db query ... "; c = "s=Server.find(#{sid}); s.host=Host.find(#{@w['hosts-name'][dest]['id']}); s.save"
      puts "sp #{c}"; sp c; print "OK\n"

      # usporedi size i zavrsi transakciju
      # start na novom serveru, ako je bio upaljen
    else
      puts "Container ID nije int"
    end
  end

  if ARGV[0] == "listall"
    puts sp "Dir['/hosting/{samp,cod2,cs16}/*_*'].collect{|d| d if File.directory? d}.compact.join \"\\n\""
  end
end
