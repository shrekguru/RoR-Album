module CustomHelpers
  require 'imgix'
  require 'digest/md5'

  def imgix_url(url, options)
    opts = { auto: 'format,compress', square: false }.merge(options)
    if opts[:square]
      opts[:fit] = 'crop'
      opts[:ar] = '1:1'
      opts.delete(:square)
    end
    client = Imgix::Client.new(domain: config[:imgix_domain], secure_url_token: config[:imgix_token], include_library_param: false).path(url)
    client.to_url(opts)
  end

  def srcset(url, sizes, opts = {})
    srcset = []
    sizes.each do |size|
      opts[:w] = size
      srcset << "#{imgix_url(url, opts)} #{size}w"
    end
    srcset.join(', ')
  end

  def gravatar_hash(email)
    Digest::MD5.hexdigest(email)
  end

  def responsive_image_tag(source_url, attributes)
    attrs = { square: false, widths: [150], loading: 'lazy' }.merge(attributes)
    square = attrs[:square]
    widths = attrs[:widths].sort.uniq
    attrs[:srcset] = srcset(source_url, widths, square: square)
    attrs[:src] = imgix_url(source_url, w: widths.first, square: square)
    attrs.delete(:square)
    attrs.delete(:widths)
    tag :img, attrs
  end

  def pluralize_without_number(number, word)
    pluralize(number, word).gsub(/^#{number}/, '').strip
  end

  def full_url(path)
    domain = ENV['URL'] || 'http://localhost:4567'
    path = path.gsub(/^\//, '')
    "#{domain}/#{path}"
  end
end
