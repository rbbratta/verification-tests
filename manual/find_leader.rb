#!/usr/bin/env ruby

def find_leader(data)
  # for some reason "oc rsh" output contains CR, so we have to remove them
  data.delete! "\r"
  leader = data.match(/Leader:\s+(\S+)/)
  # puts leader[1]
  servers = data.match(/Servers:\n(.*)/m)
  # puts servers[1]
  servers[1].lines.each do |line|
    if line.include? "(" + leader[1]
      return line
    end
  end

end


def leader_hostname(leader)
  splits = leader.match(/\((\S+)[^:]+:([^:]+):(\d+)\)/)
  splits.captures

end

if $0 == __FILE__
  # puts ARGF.filename
  data = ARGF.read
  leader = find_leader(data)
  splits = leader_hostname(leader)
  puts splits[1]
end
