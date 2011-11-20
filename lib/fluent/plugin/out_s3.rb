module Fluent


class S3Output < Fluent::TimeSlicedOutput
  Fluent::Plugin.register_output('s3', self)

  def initialize
    super
    require 'aws-sdk'
    require 'zlib'
    require 'time'
    require 'tempfile'
  end

  config_param :path, :string, :default => ""
  config_param :time_format, :string, :default => nil

  config_param :aws_key_id, :string
  config_param :aws_sec_key, :string
  config_param :s3_bucket, :string

  def configure(conf)
    super

    @timef = TimeFormatter.new(@time_format, @localtime)
  end

  def start
    super
    @s3 = AWS::S3.new(
      :access_key_id=>@aws_key_id,
      :secret_access_key=>@aws_sec_key)
    @bucket = @s3.buckets[@s3_bucket]
  end

  def format(tag, time, record)
    time_str = @timef.format(time)
    "#{time_str}\t#{tag}\t#{record.to_json}\n"
  end

  def write(chunk)
    i = 0
    begin
      s3path = "#{@path}#{chunk.key}_#{i}.gz"
      i += 1
    end while @bucket.objects[s3path].exists?

    tmp = Tempfile.new("s3-")
    w = Zlib::GzipWriter.new(tmp)
    begin
      chunk.write_to(w)
      w.close
      @bucket.objects[s3path].write(Pathname.new(tmp.path))
    ensure
      w.close rescue nil
    end
  end
end


end
