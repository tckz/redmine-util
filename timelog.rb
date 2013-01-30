#!/usr/bin/ruby
# -*- encoding: utf-8 -*-

if !defined?(Redmine)
	STDERR.puts "Please run me under Redmine, do as the script/runner do."
	exit 1
end

require "pp"
require "optparse"
require "ostruct"
require "yaml"


class Timelog
  def initialize
  end

  def main(out, options)

    if options.verbose
      STDERR.puts "user: #{options.user}"
      STDERR.puts "issue: #{options.issue}"
      STDERR.puts "activity: #{options.activity}"
    end

		begin
			time_entry ||= TimeEntry.new(
				:project => options.issue.project, 
				:issue => options.issue,
				:user => options.user,
				:spent_on => options.user.today
			)
			time_entry.activity_id = options.activity_id
			time_entry.hours = options.hours
			time_entry.save!
    rescue => e
      raise "*** Failed to create timelog. : #{e}"
    end

    0
  end
end


options = OpenStruct.new
options.verbose = false
options.uid = nil
options.issue_id = nil
options.hours = nil
options.activity_id = nil

OptionParser.new{|opt|
  opt.banner = "usage: #{File.basename(__FILE__)} [options] --user=uid --issue=issue_id --hours=hours --activity=timeentry_activity_id"

  opt.on("-e", "--environment=name", "") do |v|
    # runnerのオプション
    # ignore
  end

  opt.on("-h", "--help", "") do |v|
    # runnerのオプション。runnerで処理されるとここにはこない
    # ignore
  end

  opt.on("--verbose", "") do |v|
    options.verbose = true
  end

  opt.on("--user=USER-ID", "Mandatory, Integer like 1") do |v|
    options.uid = v
  end

  opt.on("--issue=ISSUE-ID", "Mandatory, Integer like 1") do |v|
    options.issue_id = v
  end

  opt.on("--activity=ENTRY-ACTIVITY-ID", "Mandatory, Integer like 1") do |v|
    options.activity_id = v
  end

  opt.on("--hours=spent_hours", "Mandatory, Decimal like 1.0") do |v|
    options.hours = v
  end

  begin
    opt.parse!(ARGV)

    if options.uid.nil?
      raise "*** Specify --user"
    end

    if options.issue_id.nil?
      raise "*** Specify --issue"
    end

    if options.hours.nil?
      raise "*** Specify --hours"
    end

    if options.activity_id.nil?
      raise "*** Specify --activity"
    end

    begin
      options.user = User.active.find(options.uid);
      options.issue = Issue.find(options.issue_id);
      options.activity = TimeEntryActivity.find(options.activity_id);
    rescue => e
      raise "*** #{e}"
    end

  rescue RuntimeError, OptionParser::ParseError => e
    STDERR.puts opt.to_s
    STDERR.puts ""
    STDERR.puts "#{e}"
    exit 1
  end
}


app = Timelog.new
exit app.main(STDOUT, options)


# vi: ts=2 sw=2

