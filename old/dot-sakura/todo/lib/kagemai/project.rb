=begin
  Project - １つのバグ管理プロジェクトを表します
  
  Copyright(C) 2002-2005 FUKUOKA Tomoyuki.
  
  This file is part of KAGEMAI.  
  
  KAGEMAI is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.
  
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
  
  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
  
  $Id: project.rb,v 1.1.1.1.2.2 2005/01/08 13:05:24 fukuoka Exp $
=end

require 'kagemai/reporttype'
require 'kagemai/config'
require 'kagemai/message_bundle'
require 'kagemai/sharedfile'
require 'kagemai/filestore'
require 'kagemai/util'
require 'kagemai/logger'
require 'kagemai/cache_manager'
require 'kagemai/recent'
require 'kagemai/mail/mail'
require 'kagemai/mail/mailer'

module Kagemai
  class ProjectConfig
    def initialize(dir, id, filename = 'config')
      dir = File.expand_path(dir)
      unless File.directory?(Util.untaint_path("#{dir}/#{id}")) then
        raise ParameterError, MessageBundle[:err_no_such_project] % [id]
      end
      
      @path = "#{dir}/#{id}/#{filename}"
      @src = load_config_file()
    end
    attr_reader :path, :src
    
    def load_config_file()
      @path = Util.untaint_path(path)
      SharedFile.read_open(@path) do |file|
        file.read.untaint
      end
    rescue Errno::ENOENT
      raise ConfigError, "Configuration file not found - '#{@path}'"
    end
  end
  
  class Project
    REPORT_TYPE_FILENAME = 'reporttype.xml'
    ID_REGEXP_STR = '[A-Za-z0-9_-]+'
    
    def Project.open(dir, id)
      Project.new(dir, id, ProjectConfig.new(dir, id))
    end
    
    def Project.instance()
      # Get Project object from TLS.
      project = Thread.current[:Project]
      unless project then
        raise Error, 'cannnot retrieve Project object from TLS.'
      end
      return project
    end
    
    def initialize(dir, id, config)
      # Store Project object to TLS.
      Thread.current[:Project] = self
      
      @dir = dir
      @id = id
      @config = config
      @lang = Config[:language]
      @charset = Config[:charset]
      @resource_dir = Config[:resource_dir]
      @message_bundle_name = Config[:message_bundle_name]
      @report_type_filename = REPORT_TYPE_FILENAME
      @data_dir = "#{@dir}/#{@id}"
      
      @mail_spool_dir = "#{@data_dir}/mail"
      
      @post_address = ''
      @admin_address = ''
      @notify_addresses = []
      
      @subject_id_figure = Config[:subject_id_figure]
      @fold_column = Config[:fold_column]
      @css_url = Config[:css_url]
      @top_page_options = TOP_PAGE_OPTIONS
      
      instance_eval(config.src)
      validate()
      
      rt_path = Util.untaint_path("#{@data_dir}/#{@report_type_filename}")
      @report_type = ReportType.load(rt_path)
      
      @db_manager = @db_manager_class.new(@data_dir, @id, @report_type, @charset)
      
      if File.exist?("#{@data_dir}/#{@message_bundle_name}") then
        MessageBundle.update("#{@data_dir}/#{@message_bundle_name}")
      end
      
      @cache_manager = CacheManager.new("#{@data_dir}/cache")
      @recent = ProjectRecent.new(self)
      
      @new_report_hooks = []
      @add_message_hooks = []
    end
    attr_reader :id, :name, :description
    attr_reader :lang, :charset
    attr_reader :data_dir
    attr_reader :report_type
    attr_reader :dir, :db_manager, :db_manager_class
    attr_reader :admin_address, :post_address, :notify_addresses
    attr_reader :subject_id_figure, :fold_column
    attr_reader :css_url
    attr_reader :top_page_options
    
    def Project.save_config(dir, id, options)
      filename = "#{dir}/#{id}/config"
      
      SharedFile.write_open(filename) do |file|
        str_params = [
          'name', 'description', 'admin_address', 'post_address', 
          'css_url', 'lang', 'charset'
        ]
        
        str_params.each do |param|
          Logger.debug('BTS', "save_project_config: key = #{param}")
          file.puts("@#{param} = #{options.fetch(param).to_s.dump}")
        end
        
        notify_addresses = options.fetch('notify_addresses')
        notify_addresses_str = 
          notify_addresses.collect{|addr| "#{addr.to_s.dump}" }.join(', ')
        file.puts("@notify_addresses = [#{notify_addresses_str}]")
        
        literal_params = [
          'subject_id_figure', 'fold_column'
        ]
        
        literal_params.each do |param|
          file.puts("@#{param} = #{options.fetch(param)}")
        end
        
        file.puts("@top_page_options = #{options.fetch('top_page_options').inspect}")
        file.puts("@db_manager_class = #{options.fetch('store')}")
      end
      
      File.chmod2(Config[:file_mode], filename)
    end
    
    def save_config(options)
      config = {
        'name'              => options.fetch('name', @name),
        'description'       => options.fetch('description', @description),
        'admin_address'     => options.fetch('admin_address', @admin_address),
        'post_address'      => options.fetch('post_address', @post_address),
        'notify_addresses'  => options.fetch('notify_addresses', @notify_addresses), 
        'subject_id_figure' => options.fetch('subject_id_figure', @subject_id_figure),
        'fold_column'       => options.fetch('fold_column', @fold_column),
        'css_url'           => options.fetch('css_url', @css_url),
        'store'             => options.fetch('store', @db_manager_class),
        'top_page_options'  => options.fetch('top_page_options', @top_page_options),
        'lang'              => options.fetch('lang', @lang),
        'charset'           => options.fetch('charset', @charset)
      }

      invalidate_cache('project', nil)
      Project.save_config(@dir, @id, config)
    end
    
    def get_param(key)
      eval("@#{key}")
    end
    
    def template_dir()
      "#{@dir}/#{id}/template"
    end
    
    def size()
      @db_manager.size()
    end
    
    def load_report(report_id)
      report = @db_manager.load(@report_type, report_id)
      report
    end
    
    def each()
      @db_manager.each(@report_type) do |report|
        yield(report)
      end
    end
    
    def search(cond_attr, cond_other, and_op, limit, offset, order)
      @db_manager.search(@report_type, cond_attr, cond_other, and_op, limit, offset, order)
    end
    
    def collect_reports(attr_name)
      @db_manager.collect_reports(@report_type, attr_name)
    end
    
    def count_reports(attr_name)
      @db_manager.count_reports(@report_type, attr_name)
    end
    
    def new_report(message, mail = true)
      report = nil
      @db_manager.transaction {
        next_id = @db_manager.next_id()
        report = Report.new(@report_type, next_id)
        report.add_message(message)
        @recent.add(report, message)
        @new_report_hooks.each {|hook| hook.call(report, message)}
        @db_manager.store(report)
      }
      invalidate_cache('project', nil)
      begin
        sendmail(report, message) if mail
      rescue MailError => e
        report.error = e
      end
      report
    end
    
    def add_message(report_id, message)
      report = nil
      @db_manager.transaction {
        report = load_report(report_id)
        report.add_message(message)
        @recent.add(report, message)
        @add_message_hooks.each {|hook| hook.call(report, message)}
        @db_manager.store(report)
      }      
      invalidate_cache('project', nil)
      begin
        sendmail(report, message)
      rescue MailError => e
        report.error = e
      end
      report
    end
    
    def store_report(report)
      @db_manager.transaction {
        @db_manager.store(report)
      }
      invalidate_cache('project', nil)
    end
    
    def update_report(report)
      @db_manager.transaction {
        @db_manager.update(report)
      }
      invalidate_cache('project', nil)
    end

    def store_attachment(attachment)
      @db_manager.store_attachment(attachment)
    end
    
    def open_attachment(seq_id)
      @db_manager.open_attachment(seq_id)
    end
    
    def synchronized(&block)
      @db_manager.synchronized(&block)
    end
    
    def validate()
      ['@name', '@description', '@lang', '@charset'].each do |var|
        unless instance_variables.include?(var)
          raise ConfigError, "'#{var}' is not defined in '#{@config.path}'"
        end
      end
      
      ['@name', '@db_manager_class', '@subject_id_figure', '@fold_column'].each do |var|
        if instance_eval(var).to_s.empty?
          raise ConfigError, "'#{var}' is not defined in '#{@config.path}'"
        end
      end
    end
    
    def add_element_type(etype)
      transaction {
        @report_type.add_element_type(etype)
        @db_manager.add_element_type(@report_type, etype)
        save_report_type()
      }
    end
    
    def delete_element_type(etype_id)
      transaction {
        @report_type.delete_element_type(etype_id)
        @db_manager.delete_element_type(@report_type, etype_id)
        save_report_type()
      }
    end
    
    def change_element_type(etype)
      transaction {
        @db_manager.change_element_type(@report_type)
        save_report_type()
      }
    end
    
    def save_report_type()
      filename = "#{@dir}/#{@id}/#{REPORT_TYPE_FILENAME}"
      SharedFile.write_open(filename) do |file|
        @report_type.store(file, @charset)
      end
      invalidate_cache('project', nil)
      File.chmod2(Config[:file_mode], filename)
    end
    
    def sendmail(report, message)
      to = report.email_addresses
      cc = []
      bcc = @notify_addresses
      
      sendmail_to(report, message, to, cc, bcc)
    end
    
    def sendmail_to(report, message, to, cc, bcc)
      return if @admin_address.to_s.empty?
      reply_to = @post_address
      
      mail = Mail.new(to, cc, bcc, reply_to, self, report, message)
      
      if mail.to_addrs.size > 0 then
        begin
          Mailer.sendmail(mail, @admin_address, *mail.to_addrs)
        rescue Exception => e
          STDERR.puts "#{e} (#{e.class})"
          STDERR.puts e.backtrace.collect{|line| "\t#{line}"}.join("\n")
          raise MailError, "#{e} (#{e.class})"
        end
      end
    end
    
    def save_mail(mail, report_id, message_id)
      filename = "#{@mail_spool_dir}/#{report_id}-#{message_id}"
      File.open(filename, 'wb') do |file|
        file.print mail
      end
      File.chmod2(Config[:file_mode], filename)
    end
    
    def add_new_report_hook(&hook)
      @new_report_hooks << hook
    end
    
    def add_add_message_hook(&hook)
      @add_message_hooks << hook
    end
    
    def load_cache(type, key)
      @cache_manager.load_cache(type, key)
    end
    
    def save_cache(type, key, data)
      @cache_manager.save_cache(type, key, data)
    end
    
    def invalidate_cache(type, key)
      @cache_manager.invalidate_cache(type, key)
    end
    
    def each_recent()
      @recent.each {|entry| yield entry}
    end
    
    ########################################################
    ## for batch
    
    def transaction()
      @db_manager.transaction {
        yield
      }
    end
    
    def new_report2(message)
      next_id = @db_manager.next_id()
      report = Report.new(@report_type, next_id)
      report.add_message(message)
      @db_manager.store(report)
      report
    end
    
    def add_message2(report_id, message)
      report = load_report(report_id)
      report.add_message(message)
      @db_manager.store(report)
      report
    end
    
  end
end
