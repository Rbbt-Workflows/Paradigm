#!/usr/bin/env ruby

require 'rbbt-util'
require 'rbbt/util/simpleopt'
require 'rbbt/sources/CASCADE'

$0 = "rbbt #{$previous_commands*" "} #{ File.basename(__FILE__) }" if $previous_commands

options = SOPT.setup <<EOF

Generate st_pathway

$ #{$0} [options] <interactions> <members>

-h--help Print this help

EOF
if options[:help]
  if defined? rbbt_usage
    rbbt_usage 
  else
    puts SOPT.doc
  end
  exit 0
end

interactions, members = ARGV

t_int = TSV.open(interactions, :header_hash => '', :merge => true, :sep2 => /,\s*/)
t_mem = TSV.open(members, :header_hash => '', :sep2 => /,\s*/, :type => :flat)

puts CASCADE.process_paradigm(t_int, t_mem).read
