# frozen_string_literal: true

require 'English'
require 'tempfile'

require_relative '../exceptions'
require_relative 'cmd_run'

# AutoHCK module
module AutoHCK
  # Helper module
  module Helper
    def run_cmd(...)
      CmdRun.new(@logger, ...).wait
    end

    def run_cmd_no_fail(...)
      CmdRun.new(@logger, ...).wait_no_fail
    end

    def file_gsub(src, dst, gsub_list)
      content = File.read(src)
      gsub_list.each do |k, v|
        content = content.gsub(k, v)
      end
      File.write(dst, content)
    end
  end
end
