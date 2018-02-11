#!/usr/bin/env ruby

require 'sequel'
require 'awesome_print'
require 'thor'
require 'fileutils'
require 'date'
require 'pathname'
require 'time'

GHOST_DATABASE_PATH = '/var/www/mahryboutte.com/content/data/ghost.db'.freeze
INSTAGRAM_DATABASE_PATH = '/mnt/andy/instastories-backup/stories.sqlite3'.freeze
GHOST_CONTENT = '/var/www/mahryboutte.com/content/images'.freeze
GHOST_VIDEO_CONTENT = '/var/www/videos'
INSTAGRAM_CONTENT = '/mnt/andy/instastories-backup/files/ournativepine'.freeze
YEAR = Time.now.strftime('%Y').freeze
MONTH = Time.now.strftime('%m').freeze

GHOST_DB = Sequel.connect("sqlite://#{GHOST_DATABASE_PATH}")
INSTAGRAM_DB = Sequel.connect("sqlite://#{INSTAGRAM_DATABASE_PATH}")

def generate_updated_img_markdown(markdown, metadata)
  markdown_string = "![](/content/images/#{metadata[:instagram][:year]}/#{metadata[:instagram][:month]}/#{metadata[:instagram][:source_filename]})\n\n\n"
  markdown_string + markdown
end

def generate_updated_img_html(html, metadata)
  html_string = "<p><img src=\"/content/images/#{metadata[:instagram][:year]}/#{metadata[:instagram][:month]}/#{metadata[:instagram][:source_filename]}\"/></p>\n\n"
  html_string + html
end

def generate_updated_video_markdown(markdown, metadata)
  markdown_string = "<video src=\"https://www.mahryboutte.com/videos/#{metadata[:instagram][:source_filename]}\" controls></video>"
  markdown_string + markdown
end

def generate_updated_video_html(html, metadata)
  html_string = "<p><video src=\"https://www.mahryboutte.com/videos/#{metadata[:instagram][:source_filename]}\" controls></video></p>\n\n"
  html_string + html
end

# this is the start of Thor
class MyCLI < Thor

  desc 'sync_media_to_posts', 'Sync media into the posts'
  def sync_media_to_posts

    jpgs = Dir["#{INSTAGRAM_CONTENT}/**/*.jpg"]
    mp4s = Dir["#{INSTAGRAM_CONTENT}/**/*.mp4"]
    # files = jpgs + mp4s
    files = mp4s + jpgs

    files.each do |file|
      puts "Working on file #{file}"
      metadata = {}
      metadata[:instagram] = {}
      metadata[:ghost] = {}
      metadata[:instagram][:path] = INSTAGRAM_CONTENT
      metadata[:instagram][:username] = file.split('/')[-2..-2][0]
      metadata[:instagram][:source_filename] = File.basename(file)
      metadata[:instagram][:source_path] = "#{INSTAGRAM_CONTENT}/#{metadata[:instagram][:source_filename]}"

      begin
        _instagram_database_entry = INSTAGRAM_DB[:entries].select.where(:filename => "#{metadata[:instagram][:username]}/#{metadata[:instagram][:source_filename]}").all[0]
      rescue => e
        puts "There was an error when looking up file #{metadata[:instagram][:source_filename]}: #{e}"
        abort
      end

      metadata[:instagram][:epoch_timestamp] = _instagram_database_entry[:taken_at]
      metadata[:instagram][:year] = Time.at(metadata[:instagram][:epoch_timestamp]).strftime("%Y")
      metadata[:instagram][:month] = Time.at(metadata[:instagram][:epoch_timestamp]).strftime("%m")
      metadata[:instagram][:day] = Time.at(metadata[:instagram][:epoch_timestamp]).strftime("%d")

      metadata[:ghost][:content_type] = nil
      if metadata[:instagram][:source_filename].include?('.jpg')
        metadata[:ghost][:media_tag_id] = 6
        metadata[:ghost][:content_type] = :picture
      elsif metadata[:instagram][:source_filename].include?('.mp4')
        metadata[:ghost][:media_tag_id] = 8
        metadata[:ghost][:content_type] = :video
      end

      metadata[:ghost][:path] = "#{GHOST_CONTENT}/#{metadata[:instagram][:year]}/#{metadata[:instagram][:month]}"

      metadata[:ghost][:date_tag_id] = nil
      metadata[:ghost][:post_id] = nil

      begin
        metadata[:ghost][:date_tag_id] = GHOST_DB[:tags].select.where(:name=>"#{metadata[:instagram][:year]}/#{metadata[:instagram][:month]}").all[0][:id]

        _tag_matches = GHOST_DB[:posts_tags].select.where(tag_id: [metadata[:ghost][:date_tag_id], metadata[:ghost][:media_tag_id]]).all
        _post_ids = []
        _tag_matches.each do |match|
          _post_ids << match[:post_id]
        end
        metadata[:ghost][:post_id] = _post_ids.detect{ |e| _post_ids.count(e) > 1 }
      rescue => e
        puts "There was an error when looking up which Ghost post file #{metadata[:instagram][:source_filename]} should get posted to: #{e}"
        abort
      end

      _ghost_post_data = GHOST_DB[:posts].select.where(:id=>metadata[:ghost][:post_id]).all[0]
      metadata[:ghost][:pre_markdown] = _ghost_post_data[:markdown]
      metadata[:ghost][:pre_html] = _ghost_post_data[:html]

      if metadata[:ghost][:content_type] == :video
        metadata[:ghost][:destination_path] = "#{GHOST_VIDEO_CONTENT}/#{metadata[:instagram][:source_filename]}"
        metadata[:ghost][:post_markdown] = generate_updated_video_markdown(metadata[:ghost][:pre_markdown], metadata)
        metadata[:ghost][:post_html] = generate_updated_video_html(metadata[:ghost][:pre_html], metadata)
      elsif metadata[:ghost][:content_type] == :picture
        metadata[:ghost][:destination_path] = "#{metadata[:ghost][:path]}/#{metadata[:instagram][:source_filename]}"
        metadata[:ghost][:post_markdown] = generate_updated_img_markdown(metadata[:ghost][:pre_markdown], metadata)
        metadata[:ghost][:post_html] = generate_updated_img_html(metadata[:ghost][:pre_html], metadata)
      end

      FileUtils::mkdir_p metadata[:ghost][:path]
      FileUtils.mv(metadata[:instagram][:source_path], metadata[:ghost][:destination_path])
      FileUtils.chown 'ghost', 'ghost', metadata[:ghost][:destination_path]

      begin
        GHOST_DB[:posts].where(:id =>metadata[:ghost][:post_id]).update(:markdown => metadata[:ghost][:post_markdown], :html => metadata[:ghost][:post_html])
      rescue => e
        puts "There was an error updating post ID #{metadata[:ghost][:post_id]} with file #{metadata[:instagram][:source_filename]}: #{e}"
      end
      puts "Finished working on file #{file}"
    end
  end
end

MyCLI.start(ARGV)