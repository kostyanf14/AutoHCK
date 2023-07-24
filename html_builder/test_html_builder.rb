# frozen_string_literal: true

require 'erb'
require 'yaml'
require 'optparse'

RESULTS_REPORT_SECTIONS = %w[chart guest_info rejected_test previous_status url].freeze

# CLI: result.yml [--reject] [--previous]
class CLI
  attr_reader :result_yaml, :previous_result_yaml, :reject_report_sections, :result_html

  def initialize
    @parser = OptionParser.new do |parser|
      parser.banner = 'Usage: auto_hck.rb [options]'
      parser.separator ''
      define_options(parser)
      parser.on_tail('-h', '--help', 'Show this message') do
        puts parser
        exit
      end
    end
  end

  def define_options(parser)
    result_yaml_option(parser)
    previous_result_yaml_option(parser)
    reject_report_sections_option(parser)
    result_html_option(parser)
  end

  def result_yaml_option(parser)
    parser.on('--result-yaml <result_yaml>', String,
              'Platform for run test') do |result_yaml|
      @result_yaml = result_yaml
    end
  end

  def previous_result_yaml_option(parser)
    parser.on('--previous-result-yaml <previous_result_yaml>', String,
              'Platform for run test') do |previous_result_yaml|
      @previous_result_yaml = previous_result_yaml
    end
  end

  def reject_report_sections_option(parser)
    @reject_report_sections = []

    parser.on('--reject-report-sections <reject_report_sections>', Array,
              'List of section to reject from HTML results',
              '(use "--reject-report-sections=help" to list sections)') do |reject_report_sections|
      if reject_report_sections.first == 'help'
        puts RESULTS_REPORT_SECTIONS.join("\n")
        exit
      end

      extra_keys = reject_report_sections - RESULTS_REPORT_SECTIONS

      raise(AutoHCKError, "Unknown report sections: #{extra_keys.join(', ')}.") unless extra_keys.empty?

      @reject_report_sections = reject_report_sections
    end
  end

  def result_html_option(parser)
    parser.on('--result-html <result_html>', String,
              'Platform for run test') do |result_html|
      @result_html = result_html
    end
  end

  def parse(args)
    @parser.order!(args)
  end
end

class HtmlBuilder
  def initialize(cli)
    @cli = cli

    @results_template = ERB.new(File.read('report.html.erb'))
  end

  def load_results
    @current_result = YAML.load_file(@cli.result_yaml)
    return if @cli.previous_result_yaml.nil?

    @previous_result = YAML.load_file(@cli.previous_result_yaml)
  end

  def current_status(name)
    prev = @current_result['tests'].find { |p_t| p_t['name'] == name }

    return prev['status'] unless prev.nil?

    prev = @current_result['rejected_test'].find { |p_t| p_t['name'] == name }

    return 'Skipped' unless prev.nil?

    'N/A'
  end

  def previous_status(name)
    prev = @previous_result['tests'].find { |p_t| p_t['name'] == name }

    return prev['status'] unless prev.nil?

    prev = @previous_result['rejected_test'].find { |p_t| p_t['name'] == name }

    return 'Skipped' unless prev.nil?

    'N/A'
  end

  def dirty_results
    @result = {
      'tag' => @current_result['tag'],
      'url' => @current_result['url'],
      'system_info' => @current_result['system_info'],
      'sections' => RESULTS_REPORT_SECTIONS - @cli.reject_report_sections,
      'tests' => (@current_result['tests'] + @previous_result['tests']).uniq { |t| t['name'] },
      'rejected_test' => (@current_result['rejected_test'] + @previous_result['rejected_test']).uniq! { |t| t['name'] }
    }
  end

  def fix_status
    @result['tests'].each do |test|
      name = test['name']
      test['status'] = current_status(name)
      test['previous_status'] = previous_status(name)
    end

    @result['rejected_test'].each do |test|
      name = test['name']
      test['status'] = current_status(name)
      test['previous_status'] = previous_status(name)
    end
  end

  def generate_stats
    @result['test_stats'] = {
      'passed' => @result['tests'].select { |t| t['status'] == 'Passed' }.count,
      'failed' => @result['tests'].select { |t| t['status'] == 'Failed' }.count,
      'inqueue' => 0,
      'skipped' => @result['rejected_test'].count
    }
  end

  def build_html
    load_results
    dirty_results
    fix_status
    generate_stats

    File.write(@cli.result_html, @results_template.result_with_hash(@result))
  end
end

cli = CLI.new
cli.parse(ARGV)
HtmlBuilder.new(cli).build_html
