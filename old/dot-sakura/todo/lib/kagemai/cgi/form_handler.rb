=begin
  form_handler.rb - フォームのチェックをするためのモジュールです

  FormHandler を include するクラスは、インスタンス変数 @cgi に
  CGI オブジェクトを設定している必要があります。

  チェックする項目は、以下のとおりです。
    * 値が空じゃないか？
    * メールアドレスチェック付きフィールドの値は有効か？


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

  $Id: form_handler.rb,v 1.1.1.1 2004/07/06 11:44:35 fukuoka Exp $
=end

require 'kagemai/mail/mail'

module Kagemai
  module AdminAuthorization
    def check_authorization()
      unless Mode::ADMIN.current?
        raise AuthorizationError, 'Authorization required for this operation.'
      end
    end
  end

  module FormHandler
    class FormErrors
      def initialize(errors = {})
        @errors = errors
      end

      def has_id?(id)
        @errors.find{|key, earray| earray.include?(id)} != nil
      end

      def tag_class(id)
        has_id?(id) ? 'class="error"' : ''
      end

      def empty?
        @errors.empty?
      end

      def each(&block)
        @errors.each(&block)
      end
    end

    def init_form_handler()
      @errors = {}
    end
    attr_reader :errors

    def check_message_form(report_type)
      report_type.each do |etype|
        check_form_value(etype.id, 
                         etype.default, 
                         etype.email_check, 
                         etype.kind_of?(FileElementType))
      end

      valid_form?()
    end

    def valid_form?()
      Logger.debug('FormHandler', "valid_form: @errors = #{@errors.inspect}")
      @errors.empty?
    end

    def error_id?(id)
      @errors.find{|key, earray| earray.include?(id)} != nil
    end

    def tag_class(id)
      error_id?(id) ? 'class="error"' : ''
    end

    def check_form_value(id, default, email_check, attachment = false)
      unless attachment then
        value = @cgi.get_param(id, default)
        if value then
          if email_check && !valid_email_address?(value) then
            Logger.debug('FormHandler', "email_check: #{id} = #{value.inspect}")
            add_error(:err_invalid_email_address, id)
            return false
          end
        else
          Logger.debug('FormHandler', "required: #{id}")
          add_error(:err_required, id)
          return false
        end
      else
        validness, err = validate_attachment(id)
        unless validness then
          add_error(err, id)
          return false
        end
      end
      true
    end

    def check_int_value(id)
      value = @cgi.get_param(id)
      if value && /[^\d]/ =~ value then
        add_error(:err_invalid_int_value, id)
        return false
      end
      true
    end

    def valid_email_address?(address)
      RMail::Address.validate(address)
    end

    protected
    def add_error(key, value)
      unless @errors.has_key?(key) then
        @errors[key] = []
      end
      @errors[key] << value
    end
  end
end
