#!/usr/bin/env ruby

require 'sequel'
require 'awesome_print'
require 'thor'
require 'fileutils'
require 'date'
require 'pathname'
require 'rmagick'
require 'aws-sdk-core'

DATABASE_PATH = '/var/www/mahryboutte.com/content/data/ghost.db'.freeze
DROPBOX_PATH = '/home/aboutte/Dropbox/Family/mahryboutte.com'.freeze
GHOST_CONTENT = '/var/www/mahryboutte.com/content/images'.freeze
S3 = Aws::S3::Client.new(region: 'us-west-2')
S3_BUCKET = 'mahryboutte.com'.freeze
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

def remap_tags_for_s3(tags)
  remapped_tags = []
  tags.each do |tag|
    temp = {}
    temp[:key] = tag[0].to_s
    temp[:value] = tag[1]
    remapped_tags << temp
  end
  remapped_tags
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

def generate_updated_markdown(markdown, image)
  markdown_string = "![](/content/images/#{YEAR}/#{MONTH}/#{image[:filename]})\n\n\n"
  markdown_string + markdown
end

def generate_updated_html(html, image)
  html_string = "<p><img src=\"/content/images/#{YEAR}/#{MONTH}/#{image[:filename]}\"/></p>\n\n"
  html_string + html
end

# this is the start of Thor
class MyCLI < Thor

  desc 'rotate_images', 'rotate_images'
  def rotate_images
    Dir['/var/www/mahryboutte.com/content/images/**/*.jpg'].each do |jpg|
      puts "Working on image: #{jpg}"
      auto_rotate_image(jpg)
    end
  end

  desc 'sync_media_from_s3', 'pull media files from S3'
  def sync_media_from_s3
    s3_objects = S3.list_objects_v2({
      bucket: S3_BUCKET,
      max_keys: 1000,
      prefix: 'processed/IMG'
    }).contents
    s3_objects.each do |object|
      tags = S3.get_object_tagging({
        bucket: S3_BUCKET,
        key: object.key
      }).tag_set
      tags = remap_tags_from_s3(tags)

      resp = S3.get_object(
        response_target: "#{DROPBOX_PATH}/#{tags[:directory]}/#{tags[:filename]}",
        bucket: S3_BUCKET,
        key: object.key)

      resp = S3.delete_object({
        bucket: S3_BUCKET,
        key: object.key
      })
    end
  end

  # set cron to run this once per day
  desc 'sync_posts_to_directories', 'Get all post titles and make sure there is an associated directory'
  def sync_posts_to_directories
    puts 'Sync posts to directories'
    # get the 10 most recently updated posts so we dont overwhelm who is using Dropbox
    posts = DB[:posts].reverse_order(:updated_at).limit(10)

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

    # remove direcories if they are not in the 10 most recently updated
    dirs = Pathname.new(DROPBOX_PATH).children.select { |c| c.directory? }
    dirs.each do |dir|
      # if the directory name is included in list of slugs we need to keep it
      next if slugs.include? get_slug_from_ordered_directory_name(dir)
      puts "Found dir that needs to be cleaned up: #{dir}"
      # Before deleting this dir make sure it is empty of images or videos
      FileUtils.rm_rf(dir) if (Dir.entries(dir) - %w{ . .. }).empty?
    end
  end

  desc 'sync_media_to_posts', 'Sync the images into the posts'
  def sync_media_to_posts
    puts 'Syncing images into posts'

    # movies files are .mov if uploaded directly from iPhone to DropBox
    # movies = Dir["#{DROPBOX_PATH}/**/*.mov"]
    # movies files are .mp4 if imported into iPhoto and then transfered to DropBox
    movies = Dir["#{DROPBOX_PATH}/**/*.mp4"]

    movies.each do |mov|
      mov_details = {}
      mov_details[:filename] = File.basename(mov)
      mov_details[:directory] = mov.split('/')[-2..-2][0]
      mov_details[:slug] = get_slug_from_ordered_directory_name(mov_details[:directory])
      mov_details[:ghost_directory] = "#{GHOST_CONTENT}/#{YEAR}/#{MONTH}"
      File.open(mov, 'rb') do |file|
        S3.put_object(bucket: S3_BUCKET, key: "queue/#{mov_details[:filename]}", body: file)
        S3.put_object_tagging({bucket: S3_BUCKET,
          key: "queue/#{mov_details[:filename]}",
          tagging: {
            tag_set: remap_tags_for_s3(mov_details)
          }
        })
        FileUtils.rm(file)
      end
    end

    Dir["#{DROPBOX_PATH}/**/*.jpg"].each do |jpg|
      jpg_details = {}
      jpg_details[:filename] = File.basename(jpg)
      jpg_details[:directory] = jpg.split('/')[-2..-2][0]
      jpg_details[:slug] = get_slug_from_ordered_directory_name(jpg_details[:directory])
      jpg_details[:ghost_directory] = "#{GHOST_CONTENT}/#{YEAR}/#{MONTH}"

      FileUtils::mkdir_p jpg_details[:ghost_directory]
      FileUtils.mv(jpg, "#{jpg_details[:ghost_directory]}/#{jpg_details[:filename]}")
      FileUtils.chown 'ghost', 'ghost', jpg_details[:ghost_directory]
      post = DB[:posts].select.where(:slug=>jpg_details[:slug]).all[0]
      markdown = generate_updated_markdown(post[:markdown], jpg_details)
      html = generate_updated_html(post[:html], jpg_details)
      DB[:posts].where(:slug => jpg_details[:slug]).update(:markdown => markdown, :html => html)
    end
  end
end


MyCLI.start(ARGV)
