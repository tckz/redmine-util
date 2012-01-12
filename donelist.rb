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


class DoneList
  def initialize
  end

  def main(out, options)

    from = options.from_date
    to = options.to_date

    if options.verbose
      STDERR.puts "user: #{options.user}"
      STDERR.puts "from: #{from.to_date}"
      STDERR.puts "to:   #{to.to_date}"
    end

    activity = Redmine::Activity::Fetcher.new(options.user,
        :project => nil,
        :with_subprojects => true,
        :author => options.user);

    activity.scope = :all

    events = activity.events(from, to).select {|e|
        if e.kind_of?(Journal) || e.kind_of?(Issue)
          true
        else
          false
        end
    }.map {|e|
        if e.kind_of?(Journal)
          e.issue
        else
          e
        end
    }.sort {|a, b|
				# pjごと。issue自体は登場順のまま
        a.project_id <=> b.project_id 
    }

    statuses = {}
    already = {}

    current_pj = nil
    events.each {|e|
        #pp e
        if current_pj.nil? || current_pj.id != e.project_id
          project = Project.find(e.project_id)
          out.puts "--#{project.name}"
          current_pj = project
        end

        key = "#{e.class.name},#{e.id}"
        if already[key]
          next
        end
        already[key] = e

        if statuses[e.status_id]
          status = statuses[e.status_id]
        else
          status = IssueStatus.find(e.status_id)
          statuses[e.status_id] = status
        end

        mark = status.is_closed ? "*" : "o";
      mark = options.config["marker"][mark] || mark
      pj_identifier = options.config["project_identifier"][current_pj.identifier] || current_pj.identifier
        out.puts "#{mark}[#{pj_identifier}]##{e.id} #{e.subject}"
    }

    0
  end
end


options = OpenStruct.new
options.verbose = false
options.uid = nil
options.from_date = nil
options.to_date = nil
options.fn_config=nil
options.config = {}

OptionParser.new{|opt|
  # script/runner経由で動かすので$0だとrunnerになる
  opt.banner = "usage: #{File.basename(__FILE__)} [options] --user=uid"

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

  opt.on("--config=path/to/yml", "") do |v|
    options.fn_config = v
  end

  opt.on("--from-date=YYYY-MM-DD", "Default: Beginning of last week.") do |v|
    begin
      options.from_date = v.to_date
    rescue => e
      raise "*** Invalid from-date."
    end
  end

  opt.on("--this-week", "Set beginning of this week to from-date.") do |v|
      options.from_date = Date.today.beginning_of_week
	end

  opt.on("--last-week", "Set beginning of last week to from-date.") do |v|
      options.from_date = Date.today.beginning_of_week.yesterday.beginning_of_week
	end

  opt.on("--to-date=YYYY-MM-DD", "Default: 5 days after from-date.") do |v|
    begin
      options.to_date = v.to_date
    rescue => e
      raise "*** Invalid to-date."
    end
  end

  opt.on("--user=USER-ID", "Mandatory, Integer like 1..") do |v|
    options.uid = v
  end

  begin
    opt.parse!(ARGV)

    if !options.fn_config.nil?
      begin
        options.config = YAML.load_file(options.fn_config)
      rescue => e
        raise "*** Failed to load config: #{e}"
      end
    end

    if options.from_date.nil?
      options.from_date = Date.today.beginning_of_week.yesterday.beginning_of_week
    end

    if options.to_date.nil?
      options.to_date = options.from_date.advance({:days => 5}).ago(1)
    end

    if options.uid.nil?
      raise "*** Specify --user"
    end

    begin
      options.user = User.active.find(options.uid);
    rescue => e
      raise "*** Failed to find user: #{e}"
    end
  rescue RuntimeError, OptionParser::ParseError => e
    STDERR.puts opt.to_s
    STDERR.puts ""
    STDERR.puts "#{e}"
    exit 1
  end
}


app = DoneList.new
exit app.main(STDOUT, options)


# vi: ts=2 sw=2

