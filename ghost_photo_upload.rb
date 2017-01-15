#!/usr/bin/env ruby

require 'sequel'
require 'awesome_print'
require 'thor'
require 'fileutils'
require 'date'
require 'pathname'

DATABASE_PATH = '/var/www/mahryboutte.com/content/data/ghost.db'.freeze
DROPBOX_PATH = '/home/aboutte/Dropbox/Family/mahryboutte.com'.freeze
GHOST_CONTENT = '/var/www/mahryboutte.com/content/images'.freeze
YEAR = Time.now.strftime('%Y').freeze
MONTH = Time.now.strftime('%m').freeze

DB = Sequel.connect("sqlite://#{DATABASE_PATH}")

def get_ordered_directory_name(slug, counter)
  "#{DROPBOX_PATH}/#{counter}_#{slug}"
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

    videos = Dir["#{DROPBOX_PATH}/**/*.mov"]

    Dir["#{DROPBOX_PATH}/**/*.jpg"].each do |jpg|
      image = {}
      image[:filename] = File.basename(jpg)
      image[:directory] = jpg.split('/')[-2..-2][0]
      image[:slug] = get_slug_from_ordered_directory_name(image[:directory])
      image[:ghost_directory] = "#{GHOST_CONTENT}/#{YEAR}/#{MONTH}"

      FileUtils::mkdir_p image[:ghost_directory]
      FileUtils.mv(jpg, "#{image[:ghost_directory]}/#{image[:filename]}")
      FileUtils.chown 'ghost', 'ghost', image[:ghost_directory]
      post = DB[:posts].select.where(:slug=>image[:slug]).all[0]
      markdown = generate_updated_markdown(post[:markdown], image)
      html = generate_updated_html(post[:html], image)
      DB[:posts].where(:slug => image[:slug]).update(:markdown => markdown, :html => html)
    end
  end
end


MyCLI.start(ARGV)
