#!/usr/bin/env ruby

# This file updates `values.yaml` with values for a given release (as passed in
# via environment variables).  The result is output on standard output.
# This is not a jq/yq script so that we can preserve comments.

# Usage: tag-images.rb chart/values.yaml chart/edited-values.yaml

require 'yaml'

# Find a YAML::Nodes::Node given a root node and a path to it, assuming
# everything from the root node to the desired node are mappings.
def find_node(node, *path)
    path.each_with_index do |part, index|
        unless node.is_a? YAML::Nodes::Mapping
            route = path.first(path.length - index)
            fail "Invalid node near #{route.join('/')}: #{node}"
        end
        result = node.children.each_slice(2).find { |k, v|
            k.is_a?(YAML::Nodes::Scalar) && k.value.to_s == part.to_s
        }
        fail "Could not find node #{path.join('/')}" unless result
        node = result.last
    end
    node
end

contents = File.read(ARGV.first)
doc = YAML.parse(contents)

replacements = []

ENV.keys.select { |k| k.start_with? 'TAG_FILE_' }.each do |env_name|
    image = env_name.delete_prefix('TAG_FILE_').downcase.tr('_', '-')
    tag_file = ENV[env_name]
    fail "Could not find file #{tag_file.inspect} for #{image}" unless tag_file
    tag = File.read(tag_file)
    fail "Could not read tag file #{tag_file} for #{image}" unless tag
    if image.end_with? '-setup'
        path = image.delete_suffix('-setup'), 'setup-image', 'tag'
    else
        path = image, 'image', 'tag'
    end
    node = find_node(doc.root, *path)
    replacements << [node, tag.chomp]
    puts "Replacing tag #{path.join('.')} with #{tag.chomp}"
end

# Replace starting towards the end of the file, so that we can be sure we do not
# affect chronologically later (earlier in the file) replacements as we go.
replacements.sort_by! { |node, value| [node.start_line, node.start_column] }
replacements.reverse!

lines = contents.lines # because YAML::Nodes::Node has start/end lines
replacements.each do |node, value|
    lines[node.start_line][node.start_column...node.end_column] = value.chomp
end

File.write(ARGV.last, lines.join)
