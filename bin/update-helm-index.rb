#!/usr/bin/env ruby

# This script rebuilds the helm repository index.yaml to add a new entry (or
# update, if the version already exists), such that the download URL points to
# GitHub releases.  The changes will be comitted to git.

# Usage:
#  REPO=<repo> $0 <dir>

# <dir>: A directory that contains:
#    "version.txt": A text file containing the version of the helm chart
#    "eirini-extensions-*.tgz": The chart.
# The environment variable "REPO" should be set to the path of the GitHub
# repository, such as "SUSE/eirinix-helm-release".
# The working directory must be a git repository for the helm repository.  If a
# "index.yaml" exists in the working directory, it will be updated; otherwise, a
# new file is created.

# Optional environment variables:
#   GIT_AUTHOR_NAME:   If set, git will use this as the author name.
#   GIT_AUTHOR_EMAIL:  If set, git will use this as the author email.
#   VERSION_PREFIX:    If set, use this as a prefix for GitHub version tag.

require 'date'
require 'digest'
require 'erb'
require 'rubygems/package'
require 'yaml'
require 'zlib'

# Given a path to a helm chart (tgz bundle), return its Charts.yaml contents
# as a hash.
def read_chart(path)
    file = Gem::Package::TarReader.new(Zlib::GzipReader.open(path))
    entry = file.find { |entry| entry.full_name =~ /^[^\/]+\/Chart\.yaml$/ }
    YAML.load(entry.read)
end

# The path to the directory containing the chart and version info
def files_dir
    ARGV.last
end

# The name of the chart bundle (*.tgz)
def tar_file_name
    $tar_file_name ||= Dir.glob('eirini-extensions-*.tgz', base: files_dir).first
end

# Path to the chart bundle (*.tgz)
def tar_file_path
    File.join(files_dir, tar_file_name)
end

def version
    $version ||= File.read(File.join(files_dir, 'version.txt')).strip
end

# The URL to download the chart
def chart_url
    prefix = ENV['VERSION_PREFIX'] || ''
    repo = ENV['REPO']
    fail 'Environment variable REPO is missing' unless repo
    url_version = ERB::Util.url_encode version
    file = ERB::Util.url_encode tar_file_name
    "https://github.com/#{prefix}#{repo}/releases/download/#{url_version}/#{file}"
end

# The entry in index.yaml for this chart version
def build_entry
    wanted_keys = %w(apiVersion description name)
    chart_info = read_chart(tar_file_path).select { |k, v| wanted_keys.include? k }
    digest = Digest::SHA256.file(tar_file_path).hexdigest
    result = chart_info.merge(
        created: File.ctime(tar_file_path).to_datetime.rfc3339,
        digest: digest,
        urls: [ chart_url ],
        version: version,
    )
    # Do a sort on the keys to match output of the official helm CLI
    Hash[result.transform_keys(&:to_s).to_a.sort]
end

index = begin
    YAML.load_file('index.yaml')
rescue Errno::ENOENT
    {
        apiVersion: 'v1',
        entries: {},
    }.transform_keys(&:to_s)
end
entry = build_entry
entries = index['entries'][entry['name']] ||= []
old_entry = entries.find { |e| e['version'] == entry['version']}
if old_entry.nil?
    entries << entry
    message = "Add version #{version}"
else
    old_entry.merge! entry
    message = "Update version #{version}"
end
index['generated'] = DateTime.now.rfc3339

File.open('index.yaml', 'w') { |f| YAML.dump(index, f) }

Process.wait Process.spawn('git', 'add', 'index.yaml')
fail "Git add returned #{$?.exitstatus}" unless $?.success?
git_command = %w(git)
ENV['GIT_AUTHOR_NAME'].tap { |n| git_command += ['-c', "user.name=#{n}"] if n }
ENV['GIT_AUTHOR_EMAIL'].tap { |e| git_command += ['-c', "user.email=#{e}"] if e }
git_command += [ 'commit', '-m', message ]

exec *git_command