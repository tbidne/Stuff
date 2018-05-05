#!/usr/bin/ruby

require "open3"

# --------------------------- #
#           Globals           #
# --------------------------- #

$BRANCH_REGEX = /([a-zA-Z0-9\-\_]+)/
$ARG_REGEX = /^-[hmpu]+$/
$CURRENT_BRANCH = ""

$OPTION_ENABLED = {
    :help => false,
    :upstream => false,
    :master => false,
    :push => false
}

$CHAR_TO_OPTION = {
    :h => :help,
    :u => :upstream,
    :m => :master,
    :p => :push
}

# --------------------------- #
#        Git Functions        #
# --------------------------- #

def gitPush(branch)
    info("pushing to #{branch}...")
    Open3.capture3("git push origin #{branch}:#{branch}")
end

def gitCheckout(branch)
    info("checking out #{branch}")
    Open3.capture3("git checkout #{branch}")
end

def gitFastforward(branch)
    info("fastforwarding #{branch}...")
    Open3.capture3("git merge @{u} --ff-only")
end

def gitMergeMaster(branch)
    info("merging master into #{branch}...")
    Open3.capture3("git merge origin/master --ff-only")
end

def gitFetch
    info("fetching...")
    Open3.capture3("git fetch --prune")
end

# --------------------------- #
#        Helper Functions     #
# --------------------------- #

def parseArgs
    ARGV.each { |param|
        # map "--param" to :param, check to see if it's an option
        if param.start_with?("--")
            param = param.delete("-").to_sym
            if $OPTION_ENABLED.has_key? param
                $OPTION_ENABLED[param] = true
            end

        # map "-abc" to [:a, :b, :c], check to see if the flags are valid
        elsif param =~ $ARG_REGEX
            param.split("").drop(1).map!(&:to_sym).each { |c|
                if $CHAR_TO_OPTION.has_key? c
                    $OPTION_ENABLED[$CHAR_TO_OPTION[c]] = true
                end
            }
        end
    }

    # verify that at least one option has been specified
    $OPTION_ENABLED.values.include? true
end

def parseBranches(rawStr)
    branches = []
    rawStr.split("\n").each { |s|
        begin
            parsed = s.scan($BRANCH_REGEX)[0][0]
            if s.include? "*" then $CURRENT_BRANCH = parsed end
            branches << parsed
            info("parsed branch #{parsed}")
        rescue Exception => e
            err("parsing #{s} failed: #{e.message}")
        end
    }
    branches
end

def update(branch)
   return $OPTION_ENABLED[:master] ? gitMergeMaster(branch) : gitFastforward(branch)
end

def info(msg)
    puts "INFO | #{msg}"
end

def err(msg)
    puts "ERROR | #{msg}"
end

def summary(updated, unchanged, failed)
    puts
    puts "---------------------------------------------------"
    puts "                      SUMMARY                      "
    info("updated: #{updated.join(', ')}")
    info("unchanged: #{unchanged.join(', ')}")
    info("failed: #{failed.join(', ')}")
    puts "---------------------------------------------------"
    puts
end

# --------------------------- #
#        Main Functions       #
# --------------------------- #

def printHelp
    puts "Usage: fastforward [Options]\n\n" +
    "Synopsis: updates git branches that have been checked out per 'git branch' command.\n" +
    "Must specify at least one option.\n\n" +
    "Options:\n" +
    "\t-u, --upstream\tFast forwards branches based on upstream.\n" +
    "\t-m, --master\tMerges master into branches with --ff-only. Overrides -u if both are given.\n" +
    "\t-p, --push\tPushes hardcoded branches CI-NUKA and CI-NUKA-TAB to update remote.\n" +
    "\t-h, --help\tDisplays help page."
end

def merge
    gitFetch

    updated = []
    unchanged = []
    failed = []

    rawStr = Open3.capture3("git branch")[0]
    branches = parseBranches(rawStr)

    branches.each { |b|
        stdout, stderr, status = gitCheckout(b)
        if not status.success?
            err("checking out #{b} - #{stderr}")
            failed << b
            next
        end

        stdout, stderr, status = update(b)
        if not status.success?
            err("updating #{b} - #{stderr}")
            failed << b
            next
        end

        if stdout == "Already up-to-date.\n"
            unchanged << b
        else
            updated << b
        end

        info("successfully processed #{b}")
    }

    if !$CURRENT_BRANCH.empty? then gitCheckout($CURRENT_BRANCH) end

    summary(updated, unchanged, failed)
end

def pushBranches
    updated = []
    unchanged = []
    failed = []

    # hardcoded because fully automating 'git push' on random branches seems like a bad idea
    ["branch1", "branch2"].each { |b|
        stderr, stdout, status = gitPush(b)
        if not status.success?
            err("updating #{b} - #{stderr}")
            failed << b
            next
        end

        if stdout == "Everything up-to-date\n"
            unchanged << b
        else
            updated << b
        end

        info("successfully processed #{b}")
    }

    summary(updated, unchanged, failed)
end

# ---------------------------- #
#          Executable          #
# ---------------------------- #

unless parseArgs
    puts "fastforward: Bad input. Try \'fastforward --help\' for help"
    exit
end

if $OPTION_ENABLED[:help]
    printHelp
    exit
end

if $OPTION_ENABLED[:upstream] or $OPTION_ENABLED[:master]
    merge
end

if $OPTION_ENABLED[:push]
    pushBranches
end