#!/usr/bin/env ruby

# This files merges one yaml file with a second yaml file, in a way that is
# comment-preserving.

# Usage:
#  merge-yaml.rb source.yaml changes.yaml output.yaml

require 'json'
require 'yaml'

fail "Usage: #{$0} source.yaml changes.yaml output.yaml" unless ARGV.length == 3

# Given two YAML mappings, find all YAML nodes in the first mapping that
# corresponds to the nodes in the second mapping, along with the value in the
# second mapping.
def find_changes(source, change, route=[])
    unless source.is_a? YAML::Nodes::Mapping
        fail "Invalid source node near #{route.join('.')}: #{source}"
    end
    unless change.is_a? YAML::Nodes::Mapping
        fail "Invalid change node near #{route.join('.')}: #{change}"
    end
    change.children.each_slice(2).map do |want_key, new_change|
        unless want_key.is_a? YAML::Nodes::Scalar
            fail "Invalid change near #{route.join('.')}: key #{want_key.to_ruby.to_json} is not scalar"
        end
        target = source.children.each_slice(2).find do |k, v|
            k.is_a?(YAML::Nodes::Scalar) && k.value == want_key.value
        end
        if target.nil?
            fail "Could not find item in source YAML: #{(route + [want_key.value]).join('.')}"
        end
        if new_change.is_a? YAML::Nodes::Scalar
            [[target.last, new_change.value]]
        else
            find_changes(target.last, new_change, route + [want_key.value])
        end
    end.reduce(:+)
end

contents = File.read(ARGV[0])
doc = YAML.parse(contents)
changes = YAML.parse_file(ARGV[1])

replacements = find_changes(doc.root, changes.root)
# Replace starting towards the end of the file, so that we can be sure we do not
# affect chronologically later (earlier in the file) replacements as we go.
replacements.sort_by! { |node, value| [node.start_line, node.start_column] }
replacements.reverse!

lines = contents.lines # because YAML::Nodes::Node has start/end lines, not positions
replacements.each do |node, value|
    lines[node.start_line][node.start_column...node.end_column] = value.chomp
end

File.write(ARGV.last, lines.join)
