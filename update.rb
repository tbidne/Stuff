#!/usr/bin/ruby

require 'open3'

# --------------------------- #
#           Globals           #
# --------------------------- #

$param_to_command = {
  sym: 'path/to/shell/task',
  sym2: 'path/to/another/shell/task'
}
$param_to_command.default = false

@err_path = __dir__ << '/stderr.txt'
@finished = false
@sym_finished = true

# ---------------------------------- #
#          Timing Functions          #
# ---------------------------------- #

def format_time(min, sec)
  "#{min} minutes and #{sec} seconds"
end

def readable_curr_time
  Time.now.strftime('%m/%d/%Y %H:%M')
end

def sec_to_min(seconds)
  min = (seconds / 60).to_i
  rem = (seconds % 60).to_i
  [min, rem]
end

def print_counter
  i = 0
  until @finished
    min, sec = sec_to_min(i)
    print "\rRunning Time: #{format_time(min, sec)}"
    i += 1
    sleep 1
  end
end

# ---------------------------------- #
#          Helper Functions          #
# ---------------------------------- #

def must_wait(param)
  param == :sym2 && !@sym_finished
end

def exec_and_time_fn(func, param)
  start = Time.now
  output = func.call(param)
  min, sec = sec_to_min(Time.now - start)
  [min, sec, output]
end

# returns the name of the command that failed, writes stderr
# to a file along with the time of failure
def handle_error(cmd, stderr)
  summary = "\rError running \`#{cmd}\`"
  details = readable_curr_time << "\n\n"
  details << "**************************************************************\n"
  details << "#{summary}\n"
  details << "**************************************************************\n"
  details << stderr << "\n\n"
  File.open(@err_path, 'a') { |file| file.write(details) }
  summary
end

# ---------------------------------- #
#            Main Functions          #
# ---------------------------------- #

def exec(param)
  # if param is not found then prints error message and returns
  unless (cmd = $param_to_command[param])
    puts "Warning: parameter \'#{param}\' not recognized\n\n"
    return
  end

  # wait for other commands if necessary
  while must_wait(param) do end

  min, sec, stdout, stderr, status =
    exec_and_time_fn(Open3.method(:capture3), cmd).flatten

  # update output, handle errors if necessary
  success = "\rSuccessfully ran \`%s\`           "
  err = "\nSee %s for details"
  output = success % cmd
  output = handle_error(cmd, stderr) << err % @err_path unless status.success?

  output << "\nTime elapsed: #{format_time(min, sec)}\n\n"
  puts output

  @sym_finished = true if param == :sym
end

def process_commands_helper(params)
  threads = []
  params.each do |param|
    threads << Thread.new { exec(param) }
  end
  threads.each(&:join)
end

def process_commands(params)
  @sym_finished = params.include? :sym ? false : true
  process_commands_helper(params)
end

def start(params)
  # start running timer
  counter_thread = Thread.new { print_counter }

  min, sec = exec_and_time_fn(method(:process_commands), params)

  # stop timer
  @finished = true
  counter_thread.join
  puts "Finished!\nTotal time elapsed: #{format_time(min, sec)}"
end

# ---------------------------- #
#          Executable          #
# ---------------------------- #

# strings to symbols
ARGV.map!(&:to_sym)

if ARGV.empty?
  start([:sym])
elsif ARGV.include?(:all)
  start($param_to_command.keys)
elsif ARGV.length > 4 || ARGV.include?(:help)
  puts 'usage: update.rb <sym>'
else
  start(ARGV.uniq)
end
