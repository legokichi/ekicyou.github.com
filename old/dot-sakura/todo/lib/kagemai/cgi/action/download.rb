=begin
  Download - 添付ファイルの HTTP クライアントへの送信

  Copyright(C) 2002, 2003 FUKUOKA Tomoyuki.

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

  $Id: download.rb,v 1.2 2004/08/03 22:15:00 fukuoka Exp $
=end

require 'kagemai/cgi/action'
require 'kagemai/util'
require 'kagemai/error'
require 'kagemai/cgi/attachment_handler'

module Kagemai
  class Download < Action
    include AttachmentHandler

    class DownloadActionResult
      def initialize(file, fileinfo, download)
        @file = file
        @fileinfo = fileinfo
        @download = download
      end
      
      def respond(cgi, flush_log, show_env, out = $defout)
        $defout.print http_header(cgi, @file.stat.size)
        http_body_with_print(cgi, flush_log, show_env, out)
      end
      
      def http_header(cgi, length)
        if defined?(MOD_RUBY) then
          Apache::request.headers_out.clear
        end
        
        opts = {
          'status' => 'OK',
          'type'   => @fileinfo.mime_type,
          'length' => length,
        }
        
        if @download then
          name = convert_filename(cgi, @fileinfo.name)
          opts['Content-Disposition'] = "attachment; filename=\"#{name}\""
        end
      	cgi.header(opts)
      end
      
      def http_body_with_print(cgi, flush_log, show_env, out = $defout)
        begin
          length = 4096
          while (buf = @file.read(length))
            print buf
          end
        ensure
          @file.close
        end
        ''
      end
      
    private
      def convert_filename(cgi, name)
        from = Config[:charset]
        to   = Config[:charset]
        if cgi.ua_ie? then
          to = 'cp932'
        elsif cgi.ua_firefox? || cgi.ua_mozilla? then
          to = 'UTF-8'
        end
        conv = IconvFactory.create(to, from)
        conv.iconv(name)
      end
    end
    
    def execute()
      init_project()
      
      report_id = Util.untaint_digit_id(@cgi.get_param('r'))
      message_id = Util.untaint_digit_id(@cgi.get_param('m'))
      request_seq_id = Util.untaint_digit_id(@cgi.get_param('s')).to_i
      
      message = @project.load_report(report_id).at(message_id)
      
      element_id = @cgi.get_param('e')
      if message.has_element?(element_id)
        element_id.untaint
      else
        raise ParameterError, "Invalid element type - '#{element_id}'"
      end
      
      download = @cgi.get_param('d') == 'true'
      
      element = message.element(element_id)
      fileinfo = element.find_fileinfo(request_seq_id)
      
      if fileinfo then
        file = @project.open_attachment(fileinfo.seq)
        DownloadActionResult.new(file, fileinfo, download)
      else
        raise ParameterError, "Invalid sequence id - '#{request_seq_id}'"
      end
    end
    
    def self.name()
      'download'
    end
  end
end
