#学籍番号取得
SID = ENV['MY_STUDENT_ID']
if !SID
  puts "\e[31mhttps://github.com/takahashilabo/monitoring_tool/blob/main/README.md の手順を実行してください。\e[m"
  exit
else 
  uid = SID
end

return if not defined?(Rails::Server) #rails s実行時以外は以下を実行させない

require 'date'
require 'fileutils'
require 'net/http'
#require 'base64'
#require 'json'

Process.fork do
  # 演習で編集するファイル一覧（アップロード対象になる）
  EDIT_FILES =<<~EOS
  Gemfile
  config/routes.rb
  config/application.rb
  app/controllers/bookmarks_controller.rb
  app/views/bookmarks/index.html.erb
  app/views/bookmarks/new.html.erb
  app/views/bookmarks/show.html.erb
  app/views/bookmarks/edit.html.erb
  app/controllers/images_controller.rb
  app/views/images/index.html.erb
  app/views/images/new.html.erb
  app/views/images/show.html.erb
  app/views/images/edit.html.erb
  app/controllers/my_objects_controller.rb
  app/views/my_objects/index.html.erb
  app/views/my_objects/edit.html.erb
  app/views/my_objects/new.html.erb
  app/controllers/students_controller.rb
  app/views/students/index.html.erb
  app/views/students/edit.html.erb
  app/views/students/new.html.erb
  app/models/student.rb
  test/controllers/students_controller_test.rb
  test/models/student_test.rb
  EOS
  
  #IPアドレス取得（本人性の確認のため）
  cmd = (`uname`[0] == 'L') ? `hostname -i` : `curl ipecho.net/plain; echo`
  ipaddr = cmd.chomp.split(' ')
  ipaddr = ipaddr[-1] if ipaddr.class == Array
  
  #コード片前後行数
  LINENUM = 5
  
  #行番号表示
  def line_number(s, c_start = 1)
    ss = ""
    c = c_start
    s.each do |e|
      ss += "%03d: " % c + e + "\n"
      c += 1
    end
    ss
  end
  
  if not File.exist?('log')
    puts 'Error: 本コマンドはRailsディレクトリ内で実行してください'
    exit(1)
  end
  
  #エラーが発生したファイル名を取得する
  def get_filename(arr)
    arr.each do |e|
      if e.include?(".rb:")
        return e.split(".rb")[0].split("/")[-1] + ".rb"
      end
      if e.include?(".erb:")
        return e.split(".erb")[0].split("/")[-1] + ".erb"
      end
    end
  end
  
  #エラーが発生したファイル名（パスつき）を取得する
  def get_filename_with_path(arr)
    arr.each do |e|
      if e.include?(".rb:")
        a = e.split(".rb")[0]
        return a.include?("(") ? a.split("(")[1] + ".rb" : a + ".rb"
      end
      if e.include?(".erb:")
        a = e.split(".erb")[0]
        return a.include?("(") ? a.split("(")[1] + ".erb" : a + ".erb"
      end
    end
  end
  
  #エラーが発生したファイル行（位置）を取得する
  def get_lineno(arr)
    arr.each do |e|
      if e.include?(".rb:")
        return e.split(".rb")[1].split(":")[1]
      end
      if e.include?(".erb:")
        return e.split(".erb")[1].split(":")[1]
      end
    end
  end
  
  #エラーメッセージにエラー行があれば、エラーファイルのエラー行周辺のコード片（String）を取得する、なければ空文字列を返す
  def get_error_code_part(arr)
    if get_lineno(arr) =~ /^\d+$/ #数字か？
      lineno = get_lineno(arr)
      fname = get_filename_with_path(arr)
      return "" if not File.exists?(fname)
      open fname, "r" do |file|
        s = file.read.split("\n")
        l = [lineno.to_i - LINENUM - 1, 0].max
        h = [lineno.to_i + LINENUM - 1, s.size - 1].min
        return line_number(s[l..h], l + 1)
      end
    end
    ""
  end
  
  #引数の文字列からエラー情報を抜き出す，
  def logfile(s)
    result = []
    arr = []
    err = false
    key = ''
    s.each_line do |line|
  #    a = line.scrub('?').chomp!
      a = line.chomp!
      begin
        l = a.split(' ')
        if l[0] == 'Started'
          if err
            err = false
            result << [key, arr[1].split(" ")[0], arr.join("\n"), get_filename(arr), get_error_code_part(arr)]
          end
          arr = [line]
          key = l[6..8].join(' ')
        elsif l[0] =~ /Error/
          err = true
        end
      rescue
      end
      arr.push(line) if err
    end
    if err
      err = false
      result << [key, arr[1].split(" ")[0], arr.join("\n"), get_filename(arr), get_error_code_part(arr)]
    end
    result
  end
  
  def file2hash
    h = Hash.new
    EDIT_FILES.each_line do |filename|
      if File.exist?(filename.chomp!)
        open filename, 'r' do |file|
          h[filename] = file.read
  #        h[filename] = file.read.gsub(/\n/, '<br>')
        end
      end
    end
    h
  end
  
  def upload(d)
    u = (!ENV['DEVMODE']) ? 'https://dmss-r653.onrender.com/upload' : 'http://localhost:3030/upload'
    uri = URI.parse(u)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.instance_of? URI::HTTPS
    request = Net::HTTP::Post.new(uri.path, {'Content-Type' => 'application/octet-stream'})
  #  request.body = JSON.generate(d)
  #  request.body = Base64.encode64(Marshal.dump(d))
    request.body = Marshal.dump(d)
    response = http.request(request)
  
    if response.code.to_i == 200
      puts "OK"
    else
      puts "NG: #{response.code}"
    end
  end
  
  LOGFILE = './log/development.log'
  
  FileUtils.touch( LOGFILE )
  
  f = open( LOGFILE )
  begin
    f.sysseek(-32, IO::SEEK_END)  #末尾から32byte取得
  rescue
    f.sysseek(0, IO::SEEK_SET)  #ファイルが32byte以下だった場合は、先頭から
  end
  
  s = ""
  while true
    f.sysread(1000, s) rescue nil
    if s.size == 0
      sleep 1
      next
    end

    #エラーを優先処理し、Startedはエラーがない場合の処理にする
    if s.include?( 'Error' )
      h = Hash.new
      logfile(s).each do |e|
        h[:uid] = uid
        h[:ipaddr] = ipaddr
        h[:error_date] = e[0]
        h[:error_msg_key] = e[1]
        h[:error_msg_detail] = e[2]
        h[:error_filename] = e[3]
        h[:error_code_part] = e[4]
        h[:error_files] = file2hash
      end
      upload(h)
      puts "最新エラーの助言を見るには以下にアクセスしてください："
      puts (!ENV['DEVMODE']) ? "https://dmss-r653.onrender.com/?uid=#{uid}" : "http://localhost:3030/?uid=#{uid}"
      next
    end

    if s.start_with?( 'Started' )
      h = Hash.new
      h[:uid] = uid
      h[:ipaddr] = ipaddr
      h[:error_date] = Time.now.strftime("%Y-%m-%d %H:%M:%S")
      h[:error_msg_key] = "200" #no error
      h[:error_msg_detail] = nil
      h[:error_filename] = nil
      h[:error_code_part] = nil
      h[:error_files] = nil
    upload(h)
    end
  end
end
