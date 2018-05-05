#!/usr/bin/ruby

require "open3"

# --------------------------- #
#           Globals           #
# --------------------------- #

$paramToCommandMap = {
    :sym => "path/to/shell/task",
    :sym2 => "path/to/another/shell/task"
}
$paramToCommandMap.default = false

$ERR_PATH = __dir__ << "/stderr.txt"
$FINISHED = false
$SYM_FINISHED = true

# ---------------------------------- #
#          Timing Functions          #
# ---------------------------------- #

def formatTime(min, sec)
    "#{min} minutes and #{sec} seconds"
end

def readableCurrTime
    Time.now.strftime("%m/%d/%Y %H:%M")
end

def secToMin(seconds)
    min = (seconds / 60).to_i
    rem = (seconds % 60).to_i
    return min, rem
end

def printCounter
    i = 0
    while not $FINISHED
        min, sec = secToMin(i)
        print "\rRunning Time: #{formatTime(min, sec)}"
        i += 1
        sleep 1
    end
end

# ---------------------------------- #
#          Helper Functions          #
# ---------------------------------- #

def mustWait(param)
    param == :sym2 && !$SYM_FINISHED
end

def execAndTimeFn(f, param)
    start = Time.now
    output = f.call(param)
    min, sec = secToMin(Time.now - start)
    return min, sec, output
end

# returns the name of the command that failed, writes stderr to a file along with the time of failure
def handleError(cmd, stderr)
    summary = "\rError running \`#{cmd}\`"
    details = readableCurrTime << "\n\n"
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
    unless cmd = $paramToCommandMap[param]
        puts "Warning: parameter \'#{param}\' not recognized\n\n"
        return
    end

    # wait for other commands if necessary
    while mustWait(param) do end

    min, sec, stdout, stderr, status = execAndTimeFn(Open3.method(:capture3), cmd).flatten

    # update output, handle errors if necessary
    output = status.success? ? "\rSuccessfully ran \`#{cmd}\`           " :
        handleError(cmd, stderr) << "\nSee #{$ERR_PATH} for details"

    output << "\nTime elapsed: #{formatTime(min, sec)}\n\n"
    puts output

    if param == :path then $PATH_FINISHED = true end
    if param == :db then $DB_FINISHED = true end
end

def processCommandsHelper(params)
    threads = []
    params.each { | param |
        threads << Thread.new { exec(param) }
    }
    threads.each(&:join)
end

def processCommands(params)
    $SYM_FINISHED = params.include? :sym ? false : true
    processCommandsHelper(params)
end

def start(params)
    # start running timer
    counterThread = Thread.new { printCounter }

    min, sec = execAndTimeFn(method(:processCommands), params)

    # stop timer
    $FINISHED = true
    counterThread.join
    puts "Finished!\nTotal time elapsed: #{formatTime(min, sec)}"
end

# ---------------------------- #
#          Executable          #
# ---------------------------- #

# strings to symbols
ARGV.map!(&:to_sym)

if ARGV.empty?
    start([:sym])
elsif ARGV.include?(:all)
    start($paramToCommandMap.keys)
elsif ARGV.length > 4 or ARGV.include?(:help)
    puts "usage: update.rb <sym>"
else
    start(ARGV.uniq)
end