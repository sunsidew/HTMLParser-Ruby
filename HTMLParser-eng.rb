# HTMLParser_Ruby.rb

=begin
--------------------------------------------------------------------------------------------------

	[추가적으로 개선할 사항]

	* 비교 연산자로 오인하는 경우를 방지할 필요가 있음. (), {}, ; 등 소스 내부의 비교 연산자임을 구분하는 로직 추가
		- 또는 한 차례 분석, 파싱을 진행하여 태그를 DB화하고 그를 바탕으로 재분석하는 방법이나,
		- 미리 태그 DB를 마련하여 태그 방식과 <, >, 공백을 조합하는 방식을 통해 오인 방지
	* <!-- --> 내부의 코드의 유/무효화를 설정하고 이에 대해 추가적인 조건을 추가할 필요 있음
	* 태그 이름의 대소문자 구별을 없애고, 비교 및 삽입 시에 통합하여 추산하게 함
	* attr_accesible을 사용, 클래스간 데이터 공유를 통해 클래스간 의존성을 조절
	* 단순 배열 대칭 방식에서 해시 테이블 방식으로 변경 (태그 명과 카운트 매핑)

--------------------------------------------------------------------------------------------------	
=end

# Input 클래스는 start -> init -> argv_check (valid_name?) -> name_loop -> userinput의 메서드 구성이며
# 앞 메서드에서 뒤 메서드를 호출하는 연쇄적인 방식으로 이루어져 있습니다. 먼저 argv로 HTML파일 이름에 대해 입력이 들어오는지 확인하고
# argv 입력 값이 없거나 올바르지 않을 경우 사용자 입력으로 전환하는 구성을 취하고 있습니다.

class Input
	def start # 입력 처리 후 HTML 파일 경로를 반환합니다.
		init # 입력 작업 시작
		return @filename # 결과값 리턴
	end

	def init
		@filename = ARGV[0] # argv값을 가져옵니다
		argv_check
	end

	def argv_check
		if @filename # argv값 입력이 있는 경우
			unless valid_name?(@filename) # 유효값 체크 (argv값이 올바르지 않은 값의 경우)
				name_loop # 사용자 직접 입력
			end
		else # argv값이 없는 경우
			name_loop # 입력
		end
	end

	def name_loop # 유효한 값이 나올때까지 입력받음
		begin
			userinput
			raise unless valid_name?(@filename) # 유효하지 않은 파일 이름일 경우 rescue로 패스
		rescue
			retry # begin으로 넘김
		end
	end

	def valid_name?(name) # 유효값 체크 함수
		if name =~ /.html$/ or name =~ /.htm$/ # 확장자 체크
			if File.file?(name) # 존재 유무와 정상적인(regular) 파일인지를 체크
				return true
			else
				puts "올바른 파일이 아닙니다.\n\n"
			end
		else
			puts "파일명의 형식이 올바르지 않습니다. \n\n"
		end

		return false
	end

	def userinput # 사용자 직접 입력
		begin
			print "분석할 HTML 파일명을 입력해 주십시요 : "
			@filename = STDIN.gets.chomp
			# 단순 gets로 처리하고, argv에서 유효하지 않은 값을 입력받아 사용자 입력에 들어올 경우
			# 입력 버퍼에 남아있는 argv값과 혼선되므로 STDIN을 사용.
		rescue Exception => e
			puts("HTML 파일명 입력 중 오류가 발생했습니다.")
			puts(" [오류 정보] ")
			puts("#{e.message}")
			e.backtrace.each do |trace|
				puts("#{trace}")
			end

			abort # 프로그램 종료
		end
	end
end

# Parse 클래스는 proc[ init, html_divide, search_spectag ] 형태의 메서드로 구성되었으며 filename을 넘겨받아
# init에서 사전 설정을 마치고, HTML 파일을 읽어 재귀 구조로 html tag를 최소 단위까지 나눈 후 분석하여,
# 태그 별로 분류하거나 원하는 특정 태그 값을 검색하고 Output 클래스를 호출하는 구조입니다.

class Parse
	def proc(filename)
		@filename = filename
		init
		
		@f.scan(/<.*>/) do |tag_line| # 검색 -> 재귀, 분석
			html_divide(tag_line)
		end

		search_spectag # 특정 조건 태그 검색, 분석
		Output.new.print(@tag_name, @tag_count, @search_con, @size) # 처리한 결과값을 출력 클래스에 전달합니다.
	end

	def init
		begin
			@size = File.size(@filename) # 파일 사이즈
			@f = File.read(@filename) # HTML 파일 read
		rescue Exception => e
			puts("파일 읽기에 실패했습니다.")
			puts(" [오류 정보] ")
			puts("#{e.message}")
			e.backtrace.each do |trace|
				puts("#{trace}")
			end

			abort
		end

		@ban = ["html", "body", "title", "head"] # 제외할 태그
		@tag_name = Array.new # 분류할 태그 이름 배열
		@tag_count = Array.new # 분류할 태그 카운트 배열
		@search_con = Array.new # 특정 태그 결과값 저장 배열
	end

	def html_divide(now_line) # 태그 분석 (재귀) 메서드
		if now_line.scan(/<.*?>/).count == 1 # 자기 자신 이외에 태그가 없을 경우 == 최소 단위 도달
			now_name = now_line.gsub("<","").scan(/\A[0-9a-zA-Z]*/)[0] # 태그 이름 추출

			unless @ban.include?(now_name) or now_name == "" # 태그 이름이 제외 태그가 아니고, 정상 태그로 추출된 경우
				if @tag_name.include?(now_name) # 태그 목록에 등록된지를 체크
					@tag_count[@tag_name.index(now_name)] += 1 # 등록된 경우 카운트 +1
				else
					# 미등록 태그 등록
					@tag_name.push(now_name)
					@tag_count.push(1)
				end
			end
		else
			now_line.scan(/<.*?>/) do |next_line| # 재귀 작업
				html_divide(next_line)
			end
		end
	end

	def search_spectag # 특정 조건 태그 검색
		scrvar_cnt = 0
		@f.scan(/<script.*?<\/script>/m) do |script_content| # 스크립트 내부에 있는 태그만 추출
			scrvar_cnt += script_content.scan(/var /).count # 내부에서 var 변수 검색
		end

		value_cnt = @f.scan(/value=/).count # 태그 내 값을 설정하는 value 추출
		value_cnt -= @f.scan(/value=""/).count # null 값 value 제외

		# 결과값 배열에 저장
		@search_con.push(scrvar_cnt)
		@search_con.push(value_cnt)
	end
end

# Output 클래스는 Parse 클래스에 넘겨받은 결과값을 양식에 맞춰 출력하는 구조로 되어있습니다.
# print[ init(1번 항목), tag_categorize(2번 항목), search_spectag(3번 항목) ]

class Output
	def print(tag_name, tag_count, search_con, size)
		begin
			init(size)
			tag_categorize(tag_name, tag_count)
			search_spectag(search_con)
		rescue Exception => e
			abort("결과값 작성에 실패했습니다.\n [오류 정보]\n #{e.message} \n #{e.backtrace}")
		ensure
			@f.close
		end
	end

	def init(size)
		@f = File.open("report.txt","w")
		@f.write("[HTML REPORT]\n")
		@f.write("--------------------------------------------\n")
		@f.write("1.HTML 통계\n")
		@f.write("파일크기 "+size.to_s+" Bytes\n")
	end

	def tag_categorize(tag_name, tag_count)
		@f.write("\n--------------------------------------------\n")
		@f.write("2.태그별 통계\n")
		tag_name.each do |tag|
			@f.write(tag.to_s+" "+tag_count[tag_name.index(tag)].to_s+"\n")
		end
	end

	def search_spectag(search_con)
		@f.write("\n--------------------------------------------\n")
		@f.write("3.검색 조건 통계\n")
		@f.write("script 태그 내부의 var 변수 개수 = "+search_con[0].to_s+"\n")
		@f.write("태그내 value 속성 값이 있는 경우 = "+search_con[1].to_s+"\n")
	end
end

#--------------------------------------------------------------------------------------------------
#메인

filename = Input.new.start
Parse.new.proc(filename)
