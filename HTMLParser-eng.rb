# HTMLParser_Ruby.rb

class Input
	def start # return HTML 
		init
		return @filename
	end

	def init
		@filename = ARGV[0]
		argv_check
	end

	def argv_check
		if @filename # User type argv input value
			unless valid_name?(@filename) # Bad argv value
				name_loop # Terminal input
			end
		else # argv value is null
			name_loop
		end
	end

	def name_loop # Process loop until input has valid value
		begin
			userinput
			raise unless valid_name?(@filename) # pass rescue(thiscode:28) if file name is invalid
		rescue
			retry # pass begin(thiscode:25)
		end
	end

	def valid_name?(name)
		if name =~ /.html$/ or name =~ /.htm$/ # extension check
			if File.file?(name) # file exists and is regular
				return true
			else
				puts "File isn't regular or not exists.\n\n"
			end
		else
			puts "Filename is invalid. \n\n"
		end

		return false
	end

	def userinput
		begin
			print "Type the filename(HTML) to parsing : "
			@filename = STDIN.gets.chomp
		rescue Exception => e
			puts("An error occured while typing the filename")
			puts(" [ Error Info ] ")
			puts("#{e.message}")
			e.backtrace.each do |trace|
				puts("#{trace}")
			end

			abort # quit program
		end
	end
end

class Parse
	def proc(filename)
		@filename = filename
		init
		
		@f.scan(/<.*>/) do |tag_line|
			html_divide(tag_line)
		end

		search_spectag
		Output.new.print(@tag_name, @tag_count, @search_con, @size)
	end

	def init
		begin
			@size = File.size(@filename)
			@f = File.read(@filename)
		rescue Exception => e
			puts("Failed to read file")
			puts(" [ Error Info ] ")
			puts("#{e.message}")
			e.backtrace.each do |trace|
				puts("#{trace}")
			end

			abort
		end

		@ban = ["html", "body", "title", "head"] # tag to except
		@tag_name = Array.new
		@tag_count = Array.new
		@search_con = Array.new
	end

	def html_divide(now_line)
		if now_line.scan(/<.*?>/).count == 1 # No more tag inside except itself == Minimum level
			now_name = now_line.gsub("<","").scan(/\A[0-9a-zA-Z]*/)[0] # tag name parse

			unless @ban.include?(now_name) or now_name == ""
				if @tag_name.include?(now_name) # tag list check
					@tag_count[@tag_name.index(now_name)] += 1
				else
					# tag enroll
					@tag_name.push(now_name)
					@tag_count.push(1)
				end
			end
		else
			now_line.scan(/<.*?>/) do |next_line| # backtracking
				html_divide(next_line)
			end
		end
	end

	def search_spectag # specific(custom) tag search
		scrvar_cnt = 0
		@f.scan(/<script.*?<\/script>/m) do |script_content| # parse 'var' tag inside <script />
			scrvar_cnt += script_content.scan(/var /).count
		end

		value_cnt = @f.scan(/value=/).count # parse 'value' tag except null value set
		value_cnt -= @f.scan(/value=""/).count

		# save
		@search_con.push(scrvar_cnt)
		@search_con.push(value_cnt)
	end
end

class Output
	def print(tag_name, tag_count, search_con, size)
		begin
			init(size)
			tag_categorize(tag_name, tag_count)
			search_spectag(search_con)
		rescue Exception => e
			abort("Failed to write result file.\n [ Error info ] \n #{e.message} \n #{e.backtrace}")
		ensure
			@f.close
		end
	end

	def init(size)
		@f = File.open("report.txt","w")
		@f.write("[HTML REPORT]\n")
		@f.write("--------------------------------------------\n")
		@f.write("1.HTML stats\n")
		@f.write("File size : "+size.to_s+" Bytes\n")
	end

	def tag_categorize(tag_name, tag_count)
		@f.write("\n--------------------------------------------\n")
		@f.write("2.tag stats\n")
		tag_name.each do |tag|
			@f.write(tag.to_s+" "+tag_count[tag_name.index(tag)].to_s+"\n")
		end
	end

	def search_spectag(search_con)
		@f.write("\n--------------------------------------------\n")
		@f.write("3.search condition stats\n")
		@f.write("'var' variables's counts inside <script /> = "+search_con[0].to_s+"\n")
		@f.write("'value' variables's counts = "+search_con[1].to_s+"\n")
	end
end

#--------------------------------------------------------------------------------------------------
# main

filename = Input.new.start
Parse.new.proc(filename)
