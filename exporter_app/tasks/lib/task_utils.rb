require 'uri'
require 'pathname'

class TaskUtils

  def self.http_url?(s)
    ['https', 'http'].include?(URI.parse(s).scheme)
  end

  # Like File.basename but preserve the prefix directory for an output file
  def self.export_file_basename(path, extension = '')
    orig_basename = File.basename(path, extension)
    prefix = File.basename(File.dirname(path))

    File.join(prefix, orig_basename)
  end

  def self.replace_extension(path, new_extension_sans_dot)
    Pathname.new(path).sub_ext(".#{new_extension_sans_dot}").to_s
  end

end
