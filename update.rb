#!/usr/bin/ruby

require "open3"

# --------------------------- #
#           Globals           #
# --------------------------- #

$param_to_command = {
    :sym => "path/to/shell/task",
    :sym2 => "path/to/another/shell/task"
}
$param_to_command.default = false

$ERR_PATH = __dir__ << "/stderr.txt"
$FINISHED = false
$SYM_FINISHED = true

# ---------------------------------- #
#          Timing Functions          #
# ---------------------------------- #

def format_time(min, sec)
    "#{min} minutes and #{sec} seconds"
end

def readable_curr_time
    Time.now.strftime("%m/%d/%Y %H:%M")
end

def sec_to_min(seconds)
    min = (seconds / 60).to_i
    rem = (seconds % 60).to_i
    return min, rem
end

def print_counter
    i = 0
    while not $FINISHED
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
    param == :sym2 && !$SYM_FINISHED
end

def exec_and_time_fn(f, param)
    start = Time.now
    output = f.call(param)
    min, sec = sec_to_min(Time.now - start)
    return min, sec, output
end

# returns the name of the command that failed, writes stderr to a file along with the time of failure
def handle_error(cmd, stderr)
    summary = "\rError running \`#{cmd}\`"
    details = readable_curr_time << "\n\n"
    details << "*****************************************************************************\n"
    details << "#{summary}\n"
    details << "*****************************************************************************\n"
    details << stderr << "\n\n"
    File.open($ERR_PATH, 'a') { | file | file.write(details) }
    summary
end

# ---------------------------------- #
#            Main Functions          #
# ---------------------------------- #

def exec(param)
    # if param is not found then prints error message and returns
    unless cmd = $param_to_command[param]
        puts "Warning: parameter \'#{param}\' not recognized\n\n"
        return
    end

    # wait for other commands if necessary
    while must_wait(param) do end

    min, sec, stdout, stderr, status = exec_and_time_fn(Open3.method(:capture3), cmd).flatten

    # update output, handle errors if necessary
    output = status.success? ? "\rSuccessfully ran \`#{cmd}\`           " :
        handle_error(cmd, stderr) << "\nSee #{$ERR_PATH} for details"

    output << "\nTime elapsed: #{format_time(min, sec)}\n\n"
    puts output

    if param == :path then $PATH_FINISHED = true end
    if param == :db then $DB_FINISHED = true end
end

def process_commands_helper(params)
    threads = []
    params.each { | param |
        threads << Thread.new { exec(param) }
    }
    threads.each(&:join)
end

def process_commands(params)
    $SYM_FINISHED = params.include? :sym ? false : true
    process_commands_helper(params)
end

def start(params)
    # start running timer
    counter_thread = Thread.new { print_counter }

    min, sec = exec_and_time_fn(method(:process_commands), params)

    # stop timer
    $FINISHED = true
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
elsif ARGV.length > 4 or ARGV.include?(:help)
    puts "usage: update.rb <sym>"
else
    start(ARGV.uniq)
end