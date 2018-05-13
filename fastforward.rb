#!/usr/bin/ruby

require 'open3'

# --------------------------- #
#           Globals           #
# --------------------------- #

@branch_regex = /([a-zA-Z0-9\-\_]+)/
@arg_regex = /^-[hmpu]+$/
@current_branch = ''

@option_enabled = {
  help: false,
  upstream: false,
  master: false,
  push: false
}

@char_to_option = {
  h: :help,
  u: :upstream,
  m: :master,
  p: :push
}

# --------------------------- #
#        Git Functions        #
# --------------------------- #

def git_push(branch)
  info("pushing to #{branch}...")
  Open3.capture3("git push origin #{branch}:#{branch}")
end

def git_checkout(branch)
  info("checking out #{branch}")
  Open3.capture3("git checkout #{branch}")
end

def git_fast_forward(branch)
  info("fastforwarding #{branch}...")
  Open3.capture3('git merge @{u} --ff-only')
end

def git_merge_master(branch)
  info("merging master into #{branch}...")
  Open3.capture3('git merge origin/master --ff-only')
end

def git_fetch
  info('fetching...')
  Open3.capture3('git fetch --prune')
end

# --------------------------- #
#        Helper Functions     #
# --------------------------- #

def parse_args
  ARGV.each do |param|
    # map "--param" to :param, check to see if it's an option
    if param.start_with?('--')
      param = param.delete('-').to_sym
      @option_enabled[param] = true if @option_enabled.key? param

    # map "-abc" to [:a, :b, :c], check to see if the flags are valid
    elsif param =~ @arg_regex
      param.split('').drop(1).map!(&:to_sym).each do |c|
        @option_enabled[@char_to_option[c]] = true if @char_to_option.key? c
      end
    end
  end

  # verify that at least one option has been specified
  @option_enabled.values.include? true
end

def parse_branches(raw_str)
  branches = []
  raw_str.split("\n").each do |s|
    begin
      parsed = s.scan(@branch_regex)[0][0]
      @current_branch = parsed if s.include? '*'
      branches << parsed
      info("parsed branch #{parsed}")
    rescue StandardError => e
      err("parsing #{s} failed: #{e.message}")
    end
  end
  branches
end

def update(branch)
  if @option_enabled[:master]
    git_merge_master(branch)
  else
    git_fast_forward(branch)
  end
end

def info(msg)
  puts "INFO | #{msg}"
end

def err(msg)
  puts "ERROR | #{msg}"
end

def summary(updated, unchanged, failed)
  puts
  puts '---------------------------------------------------'
  puts '                      SUMMARY                      '
  info("updated: #{updated.join(', ')}")
  info("unchanged: #{unchanged.join(', ')}")
  info("failed: #{failed.join(', ')}")
  puts '---------------------------------------------------'
  puts
end

# --------------------------- #
#        Main Functions       #
# --------------------------- #

def print_help
  puts "Usage: fastforward [Options]\n\n" \
  'Synopsis: updates git branches that have been checked out per' \
  "'git branch' command.\n" \
  "Must specify at least one option.\n\n" \
  "Options:\n" \
  "\t-u, --upstream\tFast forwards branches based on upstream.\n" \
  "\t-m, --master\tMerges master into branches with --ff-only. " \
  "Overrides -u if both are given.\n" \
  "\t-p, --push\tPushes hardcoded branches branch1 and branch2 " \
  "to update remote.\n" \
  "\t-h, --help\tDisplays help page."
end

def merge
  git_fetch

  updated = []
  unchanged = []
  failed = []

  raw_str = Open3.capture3('git branch')[0]
  branches = parse_branches(raw_str)

  branches.each do |b|
    stdout, stderr, status = git_checkout(b)
    unless status.success?
      err("checking out #{b} - #{stderr}")
      failed << b
      next
    end

    stdout, stderr, status = update(b)
    unless status.success?
      err("updating #{b} - #{stderr}")
      failed << b
      next
    end

    if stdout == 'Already up-to-date.\n'
      unchanged << b
    else
      updated << b
    end

    info("successfully processed #{b}")
  end

  git_checkout(@current_branch) unless @current_branch.empty?

  summary(updated, unchanged, failed)
end

def push_branches
  updated = []
  unchanged = []
  failed = []

  # hardcoded because fully automating 'git push' on random branches
  # seems like a bad idea
  %w[branch1 branch2].each do |b|
    stderr, stdout, status = git_push(b)
    unless status.success?
      err("updating #{b} - #{stderr}")
      failed << b
      next
    end

    if stdout == 'Everything up-to-date\n'
      unchanged << b
    else
      updated << b
    end

    info("successfully processed #{b}")
  end

  summary(updated, unchanged, failed)
end

# ---------------------------- #
#          Executable          #
# ---------------------------- #

unless parse_args
  puts "fastforward: Bad input. Try \'fastforward --help\' for help"
  exit
end

if @option_enabled[:help]
  print_help
  exit
end

merge if @option_enabled[:upstream] || @option_enabled[:master]

push_branches if @option_enabled[:push]
