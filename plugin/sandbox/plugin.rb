# -*- coding: utf-8 -*-

require 'concurrent'
require 'English'

compile_error = Class.new(RuntimeError)

install_hooks << lambda do
	system(
		'rake',
		chdir: directory
	)
end

compile = lambda do |arguments, base_name, source_file, program_file|
	IO.pipe do |read_io, write_io|
		status = Concurrent.timeout(arguments[:timeout]) do
			system(
				*format(
					arguments[:command],
					base_name: base_name,
					source_file: source_file,
					program_file: program_file,
				).split,
				out: write_io,
				err: write_io,
				chdir: directory
			)
			system(
				'chmod', 'u+x', program_file,
				out: write_io,
				err: write_io,
				chdir: directory
			)
		end

		unless status
			write_io.close_write
			raise compile_error.new(read_io.each_line.first(10).join)
		end
	end
end

run = lambda do |arguments, program_file|
	IO.pipe do |read_io, write_io|
		status = system(
			*format(
				arguments[:command],
				program_file: program_file
			).split,
			out: write_io,
			err: write_io,
			chdir: directory
		)
		write_io.close_write
		[status.nil? ? nil : $CHILD_STATUS.exitstatus, read_io.read]
	end
end

clean = lambda do |arguments, base_name, source_file, program_file|
	system(
		*format(
			arguments[:command],
			base_name: base_name,
			source_file: source_file,
			program_file: program_file,
			chdir: directory
		).split,
		chdir: directory
	)
end

functions << lambda do |_, _, command, _|
	return unless command =~ /\A(?<mode>.*)[\r\n]+(?<code>.*)/i

	mode, code = $LAST_MATCH_INFO[:mode], $LAST_MATCH_INFO[:code]

	language = config[:languages].find{|data| data[:name] =~ mode }

	return config[:display][:unknown_language] unless language

	begin
		base_name = config[:base_name]

		source_file = base_name + language[:suffix][:source]
		program_file = base_name + language[:suffix][:program]

		File.write(file_path(source_file), format(language[:template], code: code))

		compile.call(language[:compile], base_name, source_file, program_file)

		status, output = *run.call(language[:run], program_file)

		case status
		when 0 # S_RESULT_OK
			output.empty? ? config[:display][:no_output] : output
		when 1 # S_RESULT_RF
			config[:display][:restricted_function]
		when 2 # S_RESULT_ML
			config[:display][:memory_limit_exceed]
		when 3 # S_RESULT_OL
			config[:display][:output_limit_exceed]
		when 4 # S_RESULT_TL
			config[:display][:time_limit_exceed]
		when 5 # S_RESULT_RT
			config[:display][:runtime_error]
		else
			format(config[:display][:fatal], status: status)
		end
	rescue Concurrent::TimeoutError
		config[:display][:compile_timeout]
	rescue compile_error => error
		format(config[:display][:compile_failed], message: error.message)
	ensure
		clean.call(language[:clean], base_name, source_file, program_file)
	end
end