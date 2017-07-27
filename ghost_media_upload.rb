#!/usr/bin/env ruby

require 'sequel'
require 'awesome_print'
require 'thor'
require 'fileutils'
require 'date'
require 'pathname'
require 'rmagick'
require 'aws-sdk-core'
require 'time'

DATABASE_PATH = '/var/www/mahryboutte.com/content/data/ghost.db'.freeze
DROPBOX_PATH = '/home/aboutte/Dropbox/Family/mahryboutte.com'.freeze
GHOST_CONTENT = '/var/www/mahryboutte.com/content/images'.freeze
VIDEO_CONTENT = '/var/www/videos/'.freeze
S3 = Aws::S3::Client.new(region: 'us-west-2')
S3_BUCKET_QUEUE = 'mahryboutte.com-queue'.freeze
S3_BUCKET_PROCESSED = 'mahryboutte.com-processed'.freeze
YEAR = Time.now.strftime('%Y').freeze
MONTH = Time.now.strftime('%m').freeze

DB = Sequel.connect("sqlite://#{DATABASE_PATH}")

def get_ordered_directory_name(slug, counter)
  "#{DROPBOX_PATH}/#{counter}_#{slug}"
end

def auto_rotate_image(path)
  img = Magick::Image.read(path)[0]
  response = img.auto_orient!
  img.write(path) unless response.nil?
end

# input: {"clean_filename":"VideoJul1535511PM.mov","directory":"3_month-22-videos","slug":"month-22-videos"}
# return: "key1=value1&key2=value2"
def remap_tags_for_s3(tags)
  tags_string = ''
  tags.each do |tag|
    tags_string = tags_string + "#{tag[0]}=#{tag[1]}&"
  end
  tags_string[0...-1]
end

def remap_tags_from_s3(tags)
  remapped_tags = {}
  tags.each do |tag|
    remapped_tags[tag.key.to_sym] = tag.value
  end
  remapped_tags
end

def get_slug_from_ordered_directory_name(directory_name)
  directory_name.to_s.split('_').last
end

def generate_updated_img_markdown(markdown, image)
  markdown_string = "![](/content/images/#{YEAR}/#{MONTH}/#{image[:filename]})\n\n\n"
  markdown_string + markdown
end

def generate_updated_img_html(html, image)
  html_string = "<p><img src=\"/content/images/#{YEAR}/#{MONTH}/#{image[:filename]}\"/></p>\n\n"
  html_string + html
end

def generate_updated_mov_markdown(markdown, movie)
  markdown_string = "<video src=\"https://www.mahryboutte.com/videos/#{movie[:target_filename]}\" controls></video>"
  markdown_string + markdown
end

def generate_updated_mov_html(html, movie)
  html_string = "<p><video src=\"https://www.mahryboutte.com/videos/#{movie[:target_filename]}\" controls></video></p>\n\n"
  html_string + html
end
  
# this is the start of Thor
class MyCLI < Thor

  desc 'auto_rotate_images', 'auto rotate directory of images'
  method_option :path, required: true, desc: 'Subpath of images to auto rotate.  Ex: "2017/07"'
  def auto_rotate_images

    pngs = Dir["#{GHOST_CONTENT}/#{options[:path]}/*.png"]
    jpgs = Dir["#{GHOST_CONTENT}/#{options[:path]}/*.jpg"]

    images = pngs + jpgs
    images.each do |img|
      puts "Found photo: #{img}"
      auto_rotate_image(img)

    end
  end

  desc 'sync_media_from_s3', 'pull media files from S3'
  def sync_media_from_s3
    s3_objects = S3.list_objects_v2({
      bucket: S3_BUCKET_PROCESSED,
      max_keys: 1000
    }).contents
    s3_objects.each do |object|
      tags = S3.get_object_tagging({
        bucket: S3_BUCKET_PROCESSED,
        key: object.key
      }).tag_set
      tags = remap_tags_from_s3(tags)

      resp = S3.get_object(
        response_target: "#{DROPBOX_PATH}/#{tags[:directory]}/#{object.key}",
        bucket: S3_BUCKET_PROCESSED,
        key: object.key)

      resp = S3.delete_object({
        bucket: S3_BUCKET_PROCESSED,
        key: object.key
      })
    end
  end

  # set cron to run this once per day
  desc 'sync_posts_to_directories', 'Get all post titles and make sure there is an associated directory'
  def sync_posts_to_directories
    puts 'Sync posts to directories'
    # get the 3 most recently updated posts so we dont overwhelm who is using Dropbox
    posts = DB[:posts].reverse_order(:updated_at).limit(4)

    slugs = []
    # get slugs for each post
    posts.all.each do |post|
      slugs << post[:slug]
    end

    # make sure we have a dir for each slug and number them so the most recent post is on top
    counter = 1
    slugs.each do |slug|
      puts "Creating directory #{get_ordered_directory_name(slug, counter)}"
      FileUtils::mkdir_p get_ordered_directory_name(slug, counter)
      FileUtils.chown 'aboutte', 'aboutte', get_ordered_directory_name(slug, counter)
      counter += 1
    end

    # remove directories if they are not in the 3 most recently updated
    dirs = Pathname.new(DROPBOX_PATH).children.select { |c| c.directory? }
    dirs.each do |dir|
      # if the directory name is included in list of slugs we need to keep it
      next if slugs.include? get_slug_from_ordered_directory_name(dir)
      #TODO: the comparison needs to strip the order number for a clean comparison
      puts "Found dir that needs to be cleaned up: #{dir}"
      # Before deleting this dir make sure it is empty of images or videos
      FileUtils.rm_rf(dir) if (Dir.entries(dir) - %w{ . .. }).empty?
    end
  end

  desc 'sync_media_to_posts', 'Sync media into the posts'
  def sync_media_to_posts

    # movies files are .mov if uploaded directly from iPhone to DropBox
    # movies = Dir["#{DROPBOX_PATH}/**/*.mov"]
    # movies files are .m4v if imported into iPhoto and then transferred to DropBox
    m4v = Dir["#{DROPBOX_PATH}/**/*.m4v"]
    mov = Dir["#{DROPBOX_PATH}/**/*.mov"]
    movies = m4v + mov

    movies.each do |mov|
      puts "Uploading movie to S3: #{mov}"
      mov_details = {}
      mov_details[:clean_filename] = File.basename(mov).gsub(/\s+/, '').gsub(',', '')
      mov_details[:target_filename] = File.basename(mov_details[:clean_filename],File.extname(mov_details[:clean_filename])) + '.mp4'
      mov_details[:directory] = mov.split('/')[-2..-2][0]
      mov_details[:slug] = get_slug_from_ordered_directory_name(mov_details[:directory])
      File.open(mov, 'rb') do |file|
        S3.put_object(bucket: S3_BUCKET_QUEUE, key: mov_details[:clean_filename], body: file, tagging: remap_tags_for_s3(mov_details))
        FileUtils.rm(file)
      end
    end

    # If the video has been processed it will be an *.mp4 file
    mp4 = Dir["#{DROPBOX_PATH}/**/*.mp4"]
    mp4.each do |mov|
      puts "Found movie: #{mov}"
      details = {}
      details[:source] = mov
      details[:filename] = File.basename(mov)
      details[:target_filename] = File.basename(details[:filename],File.extname(details[:filename])) + '.mp4'
      details[:destination] = "#{VIDEO_CONTENT}/#{details[:filename]}"
      details[:directory] = mov.split('/')[-2..-2][0]
      details[:slug] = get_slug_from_ordered_directory_name(details[:directory])

      FileUtils.mv(details[:source], details[:destination])
      FileUtils.chown 'ghost', 'ghost', details[:destination]
      post = DB[:posts].select.where(:slug=>details[:slug]).all[0]
      markdown = generate_updated_mov_markdown(post[:markdown], details)
      html = generate_updated_mov_html(post[:html], details)
      DB[:posts].where(:slug => details[:slug]).update(:markdown => markdown, :html => html)
    end


    pngs = Dir["#{DROPBOX_PATH}/**/*.png"]
    jpgs = Dir["#{DROPBOX_PATH}/**/*.jpg"]

    images = pngs + jpgs
    images.each do |img|
      puts "Found photo: #{img}"
      details = {}
      details[:source] = img
      details[:ghost_directory] = "#{GHOST_CONTENT}/#{YEAR}/#{MONTH}"
      details[:destination] = "#{details[:ghost_directory]}/#{details[:filename]}"
      details[:filename] = File.basename(img)
      details[:directory] = img.split('/')[-2..-2][0]
      details[:slug] = get_slug_from_ordered_directory_name(details[:directory])

      FileUtils::mkdir_p details[:ghost_directory]
      FileUtils.mv(details[:source], details[:destination])
      FileUtils.chown 'ghost', 'ghost', details[:ghost_directory]
      post = DB[:posts].select.where(:slug=>details[:slug]).all[0]
      markdown = generate_updated_img_markdown(post[:markdown], details)
      html = generate_updated_img_html(post[:html], details)
      DB[:posts].where(:slug => details[:slug]).update(:markdown => markdown, :html => html)
      auto_rotate_image(details[:destination])
    end
  end
end


MyCLI.start(ARGV)
